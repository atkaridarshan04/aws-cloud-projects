# Define your DynamoDB Table
resource "aws_dynamodb_table" "employee_directory" {
  name             = "${var.name}-EmployeeDirectoryTable"
  billing_mode     = "PAY_PER_REQUEST"
  hash_key         = "Id"

  attribute {
    name = "Id"
    type = "S"
  }

  tags = {
    Name = "${var.name}-EmployeeDirectoryTable"
  }
}