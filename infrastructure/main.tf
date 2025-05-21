# IAM Role for Lambda
resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda Function
resource "aws_lambda_function" "hello_world" {
  function_name = var.lambda_function_name
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "handler.lambda_handler"
  runtime       = "python3.11"
  filename      = "${path.module}/../src/hello_world.zip"
  source_code_hash = filebase64sha256("${path.module}/../src/hello_world.zip")
}

# API Gateway HTTP API
resource "aws_apigatewayv2_api" "http_api" {
  name          = "hello-world-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.http_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.hello_world.invoke_arn
  integration_method = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "default_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "GET /"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_stage" "default_stage" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "allow_apigw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.hello_world.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

# Cognito User Pool and Client
resource "aws_cognito_user_pool" "user_pool" {
  name = "hello-world-user-pool"
}

resource "aws_cognito_user_pool_client" "user_pool_client" {
  name         = "hello-world-client"
  user_pool_id = aws_cognito_user_pool.user_pool.id
  generate_secret = false
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows = ["code"]
  allowed_oauth_scopes = ["openid"]
  callback_urls = ["https://example.com/callback"]  # Replace with your frontend URL
  supported_identity_providers = ["COGNITO"]
}

# API Gateway Cognito Authorizer
resource "aws_apigatewayv2_authorizer" "cognito_auth" {
  api_id = aws_apigatewayv2_api.http_api.id
  authorizer_type = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name = "CognitoAuthorizer"
  jwt_configuration {
    audience = [aws_cognito_user_pool_client.user_pool_client.id]
    issuer = "https://cognito-idp.${var.aws_region}.amazonaws.com/${aws_cognito_user_pool.user_pool.id}"
  }
}

# Secured Route with Cognito Authorizer
resource "aws_apigatewayv2_route" "secured_route" {
  api_id       = aws_apigatewayv2_api.http_api.id
  route_key    = "GET /secure"
  target       = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
  authorizer_id = aws_apigatewayv2_authorizer.cognito_auth.id
}