##############################################
# --- Cognito User Pool --- #
##############################################

# The user pool is the managed user directory.
# It handles signup, login, password policies, email verification, and JWT issuance.
resource "aws_cognito_user_pool" "main" {
  name = "saas-user-pool"

  # Users sign in with their email address
  username_attributes = ["email"]

  # Automatically verify email on signup — Cognito sends a confirmation code
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length    = 8
    require_uppercase = true
    require_lowercase = true
    require_numbers   = true
    require_symbols   = false
  }

  # custom:tenant_id — immutable (mutable = false) so a user can never change their tenant
  # custom:role — mutable so an admin can promote a user later
  schema {
    name                = "tenant_id"
    attribute_data_type = "String"
    mutable             = false
    required            = false
    string_attribute_constraints {
      min_length = 1
      max_length = 100
    }
  }

  schema {
    name                = "role"
    attribute_data_type = "String"
    mutable             = true
    required            = false
    string_attribute_constraints {
      min_length = 1
      max_length = 20
    }
  }
}

##############################################
# --- Cognito App Client --- #
##############################################

# The app client is what our Lambda functions use to call Cognito APIs.
# No client secret — this is a public client (server-side Lambda flow).
resource "aws_cognito_user_pool_client" "main" {
  name         = "saas-app-client"
  user_pool_id = aws_cognito_user_pool.main.id

  # No client secret — our Lambda calls Cognito directly with just the client ID
  generate_secret = false

  # USER_PASSWORD_AUTH — Lambda sends credentials to Cognito over TLS
  # ALLOW_REFRESH_TOKEN_AUTH — allows silent token renewal without re-login
  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]

  # Read and write permissions for our custom attributes
  # Without these, Lambda cannot set or read custom:tenant_id and custom:role
  read_attributes  = ["email", "custom:tenant_id", "custom:role"]
  write_attributes = ["email", "custom:tenant_id", "custom:role"]
}
