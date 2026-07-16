# ============================================================
# DynamoDB table storing the visitor count.
# One item: { id = "visitors", count = <number> }
# ============================================================

resource "aws_dynamodb_table" "visitors" {
  name         = "${var.project_name}-visitors"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"   # String
  }
}

# Seed the initial counter item at count = 0
resource "aws_dynamodb_table_item" "counter_seed" {
  table_name = aws_dynamodb_table.visitors.name
  hash_key   = aws_dynamodb_table.visitors.hash_key

  item = jsonencode({
    id    = { S = "visitors" }
    count = { N = "0" }
  })

  # Only seed once — don't overwrite the live count on future applies
  lifecycle {
    ignore_changes = [item]
  }
}

output "dynamodb_table_name" {
  value       = aws_dynamodb_table.visitors.name
  description = "DynamoDB table for visitor counter"
}
