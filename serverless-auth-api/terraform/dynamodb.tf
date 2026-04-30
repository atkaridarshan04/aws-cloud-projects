##############################################
# --- DynamoDB Table: projects --- #
##############################################

# Multi-tenant pool model — all tenants share one table.
# tenant_id (partition key) + project_id (sort key) = composite primary key.
# Every query is scoped to a tenant_id, making cross-tenant access structurally impossible.
resource "aws_dynamodb_table" "projects" {
  name         = "projects"
  billing_mode = "PROVISIONED"

  read_capacity  = 1
  write_capacity = 1

  # Partition key — all items for a tenant live in the same partition
  hash_key = "tenant_id"

  # Sort key — uniquely identifies a project within a tenant
  range_key = "project_id"

  attribute {
    name = "tenant_id"
    type = "S"
  }

  attribute {
    name = "project_id"
    type = "S"
  }
}
