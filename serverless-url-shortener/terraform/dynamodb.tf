###################################
# --- DynamoDB Table Setup --- #
###################################

# DynamoDB table to store short URL mappings
resource "aws_dynamodb_table" "short_urls" {
  name = var.dynamodb_table_name  # Table name from variables

  # On-demand billing:
  # - No capacity planning
  # - Automatically scales
  billing_mode = "PAY_PER_REQUEST"

  # Primary key (Partition Key)
  # Each short URL is uniquely identified by shortId
  hash_key = "shortId"

  # Define the primary key attribute
  attribute {
    name = "shortId"
    type = "S" # String type
  }
}


# Example item:
#   shortId: "abc123"
#   longUrl: "https://example.com/page"