variable "name" {
  type        = string
  description = "The name of the cluster"
}

variable "nlb_arn" {
  type = string
  description = "The ARN of the internal NLB"
}

variable "app_port" {
  type = number 
  description = "The Application port"
}

variable "nlb_dns_name" {
  type = string
  description = "The DNS name of the internal NLB"
}

variable "apis" {
  default = []
}

variable "lambda_apis" {
  default = []
}

variable "integration_input_type" {
  type = string 
  description = "The integration input's type."
}

variable "integration_http_method" {
  type = string 
  default = "ANY"
  description = "The integration HTTP method (GET, POST, PUT, DELETE, HEAD, OPTIONs, ANY, PATCH) specifying how API Gateway will interact with the back end."
}

variable "stage" {
  type = string
}

variable "deployment" {
  type = string
}

variable "fqdn" {
}

variable "cert_arn" {
}

variable "allowed_ips" {
  default = []
}
