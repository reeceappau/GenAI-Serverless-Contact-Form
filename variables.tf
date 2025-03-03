variable "receiver_email" {
  description = "The email address to receive form submissions"
  type        = string
}

variable "sender_email" {
  description = "The email address used to send form submissions"
  type        = string
}

variable "sender_name" {
  description = "The name associated with the sender email"
  type        = string
}

variable "ses_region" {
  description = "The AWS region for SES"
  type        = string
  default     = "eu-west-2"
}

variable "bedrock_region" {
  description = "The AWS region for Bedrock"
  type        = string
  default     = "us-east-2"
}

variable "bedrock_model_id" {
  description = "The Bedrock model ID used for inference"
  type        = string
}
