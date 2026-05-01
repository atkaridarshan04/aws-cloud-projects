variable "cluster_name"             { type = string }
variable "cluster_role_arn"          { type = string }
variable "fargate_execution_role_arn" { type = string }
variable "public_subnet_ids"         { type = list(string) }
variable "private_subnet_ids"        { type = list(string) }
