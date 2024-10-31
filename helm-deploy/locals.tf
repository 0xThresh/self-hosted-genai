# data "aws_acm_certificate" "amazon_issued" {
#   domain      = ""
#   types       = ["AMAZON_ISSUED"]
#   most_recent = true
# }

locals {
  ingress_sg_id       = ""
  acm_certificate_arn = ""
}