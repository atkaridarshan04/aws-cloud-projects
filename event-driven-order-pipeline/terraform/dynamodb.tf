##############################################
# --- DynamoDB Table: orders --- #
##############################################

# Stores every order that passes through the pipeline.
# order_id is the partition key — used for idempotent writes in the DB writer Lambda.
resource "aws_dynamodb_table" "orders" {
  name         = "orders"
  billing_mode = "PROVISIONED" # Stays in free tier (1 RCU / 1 WCU)

  read_capacity  = 1
  write_capacity = 1

  # Partition key — must be unique per order
  hash_key = "order_id"

  attribute {
    name = "order_id"
    type = "S" # String
  }
}
