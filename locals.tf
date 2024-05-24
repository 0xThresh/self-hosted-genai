# Edit the values below to match your desired configuration
locals {
  region             = "us-west-2"         # Region you want to deploy into
  vpc_name           = "ollama-vpc"        # Name of VPC that will be created
  cluster_name       = "ollama-dev"        # Name of the EKS cluster that will be created
  cluster_version    = "1.29"              # Version of EKS to use
  openwebui_pvc_size = "20Gi"              # Size of Open WebUI PVC; higher size = more documents stored for RAG
  code_models        = ["codellama:code"]  # Models to pre-load for code autocompletion (FIM)
  chat_models        = ["llama3:instruct"] # Models to pre-load for chat
  domain_name        = "0xthresh.xyz"      # Route53 domain to use for the web UI hostname
  public_hostname    = "webui"             # Public hostname to use for UI hostname 
  fqdn               = "${local.public_hostname}.${local.domain_name}" # FQDN of the public hostname
}