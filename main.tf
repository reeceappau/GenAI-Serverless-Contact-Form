terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-2"
}

data "archive_file" "lambda_package" {
  type        = "zip"
  source_file = "lambda_function.py"
  output_path = "lambda_function.zip"
}

# Lambda Function
resource "aws_lambda_function" "contact_form_handler" {
  function_name = "GISContactFormHandler"
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.12" # Replace with your preferred Python runtime
  role          = aws_iam_role.lambda_exec_role.arn

  filename         = data.archive_file.lambda_package.output_path
  source_code_hash = data.archive_file.lambda_package.output_base64sha256

  environment {
    variables = {
      RECEIVER_EMAIL   = var.receiver_email
      SENDER_EMAIL     = var.sender_email
      SENDER_NAME      = var.sender_name
      SES_REGION       = var.ses_region
      BEDROCK_REGION   = var.bedrock_region
      BEDROCK_MODEL_ID = var.bedrock_model_id
    }
  }

  memory_size = 128
  timeout     = 10
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_exec_role" {
  name = "gis_lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for CloudWatch Logs
resource "aws_iam_role_policy" "lambda_logs_policy" {
  role = aws_iam_role.lambda_exec_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# IAM Policy for SES
resource "aws_iam_role_policy" "lambda_ses_policy" {
  role = aws_iam_role.lambda_exec_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ses:SendEmail"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# IAM Policy for Bedrock
resource "aws_iam_role_policy" "lambda_bedrock_policy" {
  role = aws_iam_role.lambda_exec_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "bedrock:InvokeModel"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# API Gateway
resource "aws_api_gateway_rest_api" "contact_form_api" {
  name        = "GISContactFormAPI"
  description = "API for handling contact form submissions"
  endpoint_configuration {
    types = ["EDGE"]
  }
}

# API Gateway Resource
resource "aws_api_gateway_resource" "contact_resource" {
  rest_api_id = aws_api_gateway_rest_api.contact_form_api.id
  parent_id   = aws_api_gateway_rest_api.contact_form_api.root_resource_id
  path_part   = "contact"
}

# API Gateway POST Method
resource "aws_api_gateway_method" "post_method" {
  rest_api_id   = aws_api_gateway_rest_api.contact_form_api.id
  resource_id   = aws_api_gateway_resource.contact_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

# API Gateway Integration with Lambda
resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.contact_form_api.id
  resource_id             = aws_api_gateway_resource.contact_resource.id
  http_method             = aws_api_gateway_method.post_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.contact_form_handler.invoke_arn
}

# API Gateway Deployment
resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.contact_form_api.id

  # Add triggers to redeploy when any API Gateway configuration changes
  triggers = {
    redeployment = sha1(jsonencode({
      lambda_integration = aws_api_gateway_integration.lambda_integration.id
      lambda_function    = aws_lambda_function.contact_form_handler.arn
    }))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [aws_api_gateway_integration.lambda_integration]
}

# API Gateway Stage
resource "aws_api_gateway_stage" "prod" {
  stage_name    = "prod"
  rest_api_id   = aws_api_gateway_rest_api.contact_form_api.id
  deployment_id = aws_api_gateway_deployment.deployment.id
}

# Lambda Permission for API Gateway
resource "aws_lambda_permission" "api_gateway_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.contact_form_handler.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.contact_form_api.execution_arn}/*/POST/contact"
}