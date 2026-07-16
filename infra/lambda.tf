# ============================================================
# Lambda function that increments the visitor counter,
# plus its least-privilege IAM role.
# ============================================================

# ---- Package the Python file into a zip Terraform can deploy ----
data "archive_file" "counter_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/counter.py"
  output_path = "${path.module}/../lambda/counter.zip"
}

# ---- IAM role Lambda assumes when it runs ----
resource "aws_iam_role" "lambda_exec" {
  name = "${var.project_name}-lambda-exec"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

# ---- Permission: write CloudWatch logs (basic Lambda logging) ----
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# ---- Permission: update ONLY our DynamoDB table (least privilege) ----
resource "aws_iam_role_policy" "lambda_dynamodb" {
  name = "${var.project_name}-lambda-dynamodb"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["dynamodb:UpdateItem", "dynamodb:GetItem"]
      Resource = aws_dynamodb_table.visitors.arn
    }]
  })
}

# ---- The Lambda function ----
resource "aws_lambda_function" "counter" {
  function_name    = "${var.project_name}-counter"
  filename         = data.archive_file.counter_zip.output_path
  source_code_hash = data.archive_file.counter_zip.output_base64sha256
  handler          = "counter.handler"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda_exec.arn
  timeout          = 10

  environment {
    variables = {
      TABLE_NAME     = aws_dynamodb_table.visitors.name
      ALLOWED_ORIGIN = "https://${var.domain_name}"
    }
  }
}

output "lambda_function_name" {
  value       = aws_lambda_function.counter.function_name
  description = "Visitor counter Lambda"
}
