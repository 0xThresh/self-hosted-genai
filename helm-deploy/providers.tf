provider "aws" {
  profile = "default"
  region  = "us-west-2"
}

# TODO: Replace with kubeconfig file
provider "helm" {
  kubernetes {
    host                   = module.genai-eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.genai-eks.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", local.cluster_name, "--output", "json"]
    }
  }
}