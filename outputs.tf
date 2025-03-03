output "api_gateway_invoke_url" {
  description = "Invoke URL for the API Gateway"
  value       = "${aws_api_gateway_deployment.deployment.invoke_url}${aws_api_gateway_stage.prod.stage_name}/${aws_api_gateway_resource.contact_resource.path_part}"
}