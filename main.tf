locals {
  cloudflare_ip = "104.28.254.46/32"
  sk_home_ip = "103.252.200.190/32"
  jx_home_ip = "124.246.123.51/32"
  andy_home_ip = "49.245.48.72/32"
  office_den_ip = "61.16.70.114/32"
  office_sivergate_ip = "129.126.179.57/32"
  vapt1_ip = "101.100.168.210/32"
  vapt2_ip = "101.100.168.211/32"

}

resource "aws_api_gateway_rest_api" "main" {
  name = "api-gateway-${var.name}"
  endpoint_configuration {
    types = ["REGIONAL"]
  }
  binary_media_types = ["image/jpeg", "multipart/form-data"]
}

resource "aws_api_gateway_rest_api_policy" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        Effect : "Allow",
        Principal : "*",
        Action : "execute-api:Invoke",
        Resource : "${aws_api_gateway_rest_api.main.execution_arn}/*/*/*"
      },
     ]
  })

#   policy = <<EOF
# {
#   "Version": "2012-10-17",
#   "Statement": [{
#       "Effect": "Allow",
#       "Principal": "*",
#       "Action": "execute-api:Invoke",
#       "Resource": "${aws_api_gateway_rest_api.main.execution_arn}/*/*/*"
#     }
#   ]
# }
# EOF
#   policy = <<EOF
# {
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Effect": "Allow",
#       "Principal": "*",
#       "Action": "execute-api:Invoke",
#       "Resource": "${aws_api_gateway_rest_api.main.execution_arn}/*/*/*",
#       "Condition": {
#         "IpAddress": {
#           "aws:SourceIp": ["104.28.254.46/32", "175.156.111.106/32"]
#         }
#       }
#     },
#     {
#       "Effect": "Deny",
#       "Principal": "*",
#       "Action": "execute-api:Invoke",
#       "Resource": "${aws_api_gateway_rest_api.main.execution_arn}/*/*/*",
#       "Condition": {
#         "NotIpAddress": {
#           "aws:SourceIp": ["104.28.254.46/32", "175.156.111.106/32"]
#         }
#       }
#     }
#   ]
# }
# EOF
}

resource "aws_api_gateway_resource" "api" {
  rest_api_id = "${aws_api_gateway_rest_api.main.id}"
  parent_id   = "${aws_api_gateway_rest_api.main.root_resource_id}"
  path_part   = "api"
}

resource "aws_api_gateway_resource" "main" {
  count = length(var.apis)
  rest_api_id = "${aws_api_gateway_rest_api.main.id}"
  parent_id   = "${aws_api_gateway_resource.api.id}"
  path_part   = var.apis[count.index].path
}

resource "aws_api_gateway_resource" "lambda" {
  count = length(var.lambda_apis)
  rest_api_id = "${aws_api_gateway_rest_api.main.id}"
  parent_id   = "${aws_api_gateway_resource.api.id}"
  path_part   = var.lambda_apis[count.index].path
}

# resource "aws_api_gateway_resource" "proxy" {
#   count = length(var.apis)
#   rest_api_id = "${aws_api_gateway_rest_api.main.id}"
#   parent_id   = "${aws_api_gateway_resource.main[count.index].id}"
#   path_part   = "{proxy+}"
# }

resource "aws_api_gateway_method" "lambda" {
  count = length(var.lambda_apis)
  rest_api_id   = "${aws_api_gateway_rest_api.main.id}"
  resource_id   = "${aws_api_gateway_resource.lambda[count.index].id}"
  http_method   = "ANY"
  authorization = "NONE"
  api_key_required = true

  request_parameters = {
    "method.request.path.proxy" = true
  }

  # request_validator_id = aws_api_gateway_request_validator.main.id
  # request_models = { "application/json" = "Error" }
}

resource "aws_api_gateway_method" "main" {
  count = length(var.apis)
  rest_api_id   = "${aws_api_gateway_rest_api.main.id}"
  resource_id   = "${aws_api_gateway_resource.main[count.index].id}"
  http_method   = "ANY"
  authorization = "NONE"
  api_key_required = true

  request_parameters = {
    "method.request.path.proxy" = true
  }
}

resource "aws_api_gateway_method_settings" "main" {
  rest_api_id = "${aws_api_gateway_rest_api.main.id}"
  stage_name  = "${aws_api_gateway_stage.main.stage_name}"
  method_path = "*/*"
  settings {
    logging_level = "INFO"
    data_trace_enabled = true
    metrics_enabled = true
  }
}

# resource "aws_api_gateway_request_validator" "main" {
#   name                        = "Validate body"
#   rest_api_id                 = aws_api_gateway_rest_api.main.id
#   validate_request_body       = true
#   validate_request_parameters = false
# }

resource "aws_api_gateway_integration" "lambda" {
  count = length(var.lambda_apis)
  rest_api_id = "${aws_api_gateway_rest_api.main.id}"
  resource_id = "${aws_api_gateway_resource.lambda[count.index].id}"
  http_method = "${aws_api_gateway_method.lambda[count.index].http_method}"

  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_apis[count.index].lambda

  request_templates = {
    "application/json" = <<EOF
{
}
EOF
  }
}

resource "aws_api_gateway_integration" "main" {
  count = length(var.apis)
  rest_api_id = "${aws_api_gateway_rest_api.main.id}"
  resource_id   = "${aws_api_gateway_resource.main[count.index].id}"
  http_method = "${aws_api_gateway_method.main[count.index].http_method}"

  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }

  type                    = var.integration_input_type
  uri                     = "http://${var.nlb_dns_name}:${var.apis[count.index].port}/${var.apis[count.index].path}/{proxy}"
  integration_http_method = var.integration_http_method

  connection_type = "VPC_LINK"
  connection_id   = "${aws_api_gateway_vpc_link.this[0].id}"
}

resource "aws_api_gateway_deployment" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  # stage_name = "${var.deployment}"
  depends_on = [aws_api_gateway_method.main, aws_api_gateway_integration.main]


  variables = {
    # just to trigger redeploy on resource changes
    resources = join(", ", aws_api_gateway_resource.main.*.id)
    policy_hash = md5(aws_api_gateway_rest_api_policy.main.policy)

    # note: redeployment might be required with other gateway changes.
    # when necessary run `terraform taint <this resource's address>`
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_vpc_link" "this" {
  count = var.nlb_arn == "" ? 0 : 1
  name = "vpc-link-${var.name}"
  target_arns = [var.nlb_arn]
}

resource "aws_api_gateway_client_certificate" "main" {
}

resource "aws_api_gateway_stage" "main" {
  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = aws_api_gateway_rest_api.main.id
  client_certificate_id = aws_api_gateway_client_certificate.main.id
  stage_name    = var.stage
}

resource "aws_api_gateway_domain_name" "main" {
  count = var.fqdn == "" ? 0 : 1
  domain_name = var.fqdn

  endpoint_configuration {
    types = ["REGIONAL"]
  }
  regional_certificate_arn = var.cert_arn
}

resource "aws_api_gateway_base_path_mapping" "main" {
  count = var.fqdn == "" ? 0 : 1
  api_id      = aws_api_gateway_rest_api.main.id
  stage_name  = aws_api_gateway_stage.main.stage_name
  domain_name = aws_api_gateway_domain_name.main[0].domain_name
}

resource "aws_api_gateway_usage_plan" "main" {
  name         = var.name

  api_stages {
    api_id = aws_api_gateway_rest_api.main.id
    stage  = aws_api_gateway_stage.main.stage_name
  }
}

resource "aws_wafv2_web_acl" "main" {
  name  = var.name
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = var.name
    sampled_requests_enabled   = true
  }
}

resource "aws_wafv2_web_acl_association" "main" {
  resource_arn = aws_api_gateway_stage.main.arn
  web_acl_arn  = aws_wafv2_web_acl.main.arn
}

resource "aws_wafv2_web_acl_logging_configuration" "main" {
  log_destination_configs = [aws_cloudwatch_log_group.main.arn]
  resource_arn            = aws_wafv2_web_acl.main.arn
}

resource "aws_cloudwatch_log_group" "main" {
  name              = "aws-waf-logs-apigw-${var.name}"
  retention_in_days = 120
}

resource "aws_iam_role" "api_gateway_account_role" {
  name = "api-gateway-account-role"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "apigateway.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "api_gateway_cloudwatch_policy" {
  name = "api-gateway-cloudwatch-policy"
  role = aws_iam_role.api_gateway_account_role.id
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:PutLogEvents",
          "logs:GetLogEvents",
          "logs:FilterLogEvents"
        ],
        "Resource" : "*"
      }
    ]
  })
}

resource "aws_api_gateway_account" "api_gateway_account" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_account_role.arn
}
