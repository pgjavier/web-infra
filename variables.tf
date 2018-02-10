variable "public_key_path" {
  description = "Enter the path to the SSH Public Key to add to AWS."
  default = "key/id_rsa.pub"
}

variable "aws_region" {
  description = "AWS region to launch servers."
  default     = "us-east-2"
}
