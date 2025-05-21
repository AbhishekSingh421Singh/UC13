output "api_endpoint" {
  value = aws_apigatewayv2_api.http_api.api_endpoint
}

output "cognito_user_pool_id" {
  value = aws_cognito_user_pool.user_pool.id
}

output "cognito_client_id" {
  value = aws_cognito_user_pool_client.user_pool_client.id
}