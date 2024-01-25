output "api_name" {
  value = aws_api_gateway_rest_api.main.name
}

output "api_stage" {
  value = aws_api_gateway_stage.main.stage_name
}

output "invoke_url" {
  value = replace(aws_api_gateway_deployment.main.invoke_url,"/(https://)|(/)/","")
}

output "execution_arn" {
  value = aws_api_gateway_rest_api.main.execution_arn
}
