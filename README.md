# GIS Contact Form API

  

This project sets up a serverless contact form API using AWS services, including Lambda, API Gateway, and SES. It allows users to submit contact forms, which are then processed by an AWS Lambda function. The Lambda function sends the submitted data to a specified recipient via SES and invokes a model using AWS Bedrock.

  
  

## Setup Instructions

  

### 1. Install Terraform

  

To set up this project, ensure you have [Terraform](https://www.terraform.io/) installed on your machine.

  

### 2. Configure AWS Credentials

  

Make sure your AWS credentials are configured on your local machine. You can set them using the AWS CLI:

  

```bash
aws  configure
```

### 3. Initialize Terraform

Navigate to the project directory and initialize Terraform to download the necessary provider plugins:

```bash
terraform init
```

### 4. Set Variables

Create a ***terraform.tfvars*** file in your project directory to define the necessary environment variables for your Lambda function and other resources.

```bash
receiver_email   = "your_receiver_email@example.com"
sender_email     = "your_sender_email@example.com"
sender_name      = "Your Name"
ses_region       = "us-east-1"
bedrock_region   = "us-west-2"
bedrock_model_id = "your-bedrock-model-id"
```

### 5. Apply the Terraform Configuration
Run the following command to apply the Terraform configuration and provision the resources. Terraform will show the changes that will be made before applying them.

```bash
terraform apply
```

### 6. Access the API

After Terraform successfully applies the configuration, you can access the API. Retrieve the API endpoint by running the following command:

```bash
terraform output api_gateway_invoke_url
```