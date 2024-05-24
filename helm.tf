# Adds the NVIDIA Device Plugin to enable GPU access on Ollama pods
resource "helm_release" "nvidia_device_plugin" {
  name       = "nvidia-device-plugin"
  depends_on = [module.ollama-eks]

  repository = "https://nvidia.github.io/k8s-device-plugin"
  chart      = "nvidia-device-plugin"
  namespace  = "kube-system"
  version    = "0.15.0"
}


# ALB ingress controller
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.7.2"
  depends_on = [module.ollama-eks]

  set {
    name  = "clusterName"
    value = local.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }
}

# External DNS controller
resource "helm_release" "external_dns" {
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  namespace  = "kube-system"
  depends_on = [module.ollama-eks]
}

resource "helm_release" "ollama_small_fim" {
  name       = "ollama-small-fim"
  depends_on = [module.ollama-eks, helm_release.nvidia_device_plugin]

  repository       = "https://otwld.github.io/ollama-helm"
  chart            = "ollama"
  namespace        = "genai"
  create_namespace = true

  # Models to load on Ollama on startup
  set_list {
    name  = "ollama.models"
    value = local.code_models
  }

  # Enables Ollama to answer multiple requests concurrently
  set {
    name  = "ollama.extraEnv.OLLAMA_NUM_PARALLEL"
    value = 10
  }

  # Keeps models loaded in Ollama to prevent load delay
  set {
    name  = "ollama.extraEnv.KEEP_ALIVE"
    value = "-1"
  }
}

resource "helm_release" "ollama_small_chat" {
  name       = "ollama-small-chat"
  depends_on = [module.ollama-eks, helm_release.nvidia_device_plugin]

  repository       = "https://otwld.github.io/ollama-helm"
  chart            = "ollama"
  namespace        = "genai"
  create_namespace = true

  # Models to load on Ollama on startup
  set_list {
    name  = "ollama.models"
    value = local.chat_models
  }

  # Enables Ollama to answer multiple requests concurrently
  set {
    name  = "ollama.extraEnv.OLLAMA_NUM_PARALLEL"
    value = 10
  }

  # Keeps models loaded in Ollama to prevent load delay
  set {
    name  = "ollama.extraEnv.KEEP_ALIVE"
    value = "-1"
  }
}

resource "helm_release" "open_webui" {
  name       = "open-webui"
  depends_on = [module.ollama-eks, helm_release.aws_load_balancer_controller]

  repository       = "https://helm.openwebui.com"
  chart            = "open-webui"
  namespace        = "genai"
  create_namespace = true
  version          = "2.0.2"

  # Sets the names of the Ollama services for Open WebUI to use 
  set_list {
    name  = "ollamaUrls"
    value = ["http://ollama-small-chat.genai.svc.cluster.local:11434", "http://ollama-small-fim.genai.svc.cluster.local:11434"]
  }

  # Disable the built-in Ollama deployment since we have multiple backends
  set {
    name  = "ollama.enabled"
    value = false
  }

  # Image takes a while to pull which slows down startup, so only pull if the image isn't present
  set {
    name  = "image.pullPolicy"
    value = "IfNotPresent"
  }

  set {
    name  = "image.tag"
    value = "v0.1.124"
  }

  set {
    name  = "persistence.size"
    value = local.openwebui_pvc_size
  }

  # Optional - uncomment if using GP3 storage, requires a separate StorageClass to be deployed
  # Read more here: https://aws.amazon.com/blogs/containers/migrating-amazon-eks-clusters-from-gp2-to-gp3-ebs-volumes/
  # set {
  #   name = "persistence.storageClass"
  #   value = "gp3"
  # }

  # Set ingress on Open WebUI to provision access through AWS ALB
  set {
    name  = "ingress.enabled"
    value = "true"
  }

  # Sets the external FQDN of the WebUI
  set {
    name  = "ingress.annotations.external-dns\\.alpha\\.kubernetes\\.io/hostname"
    value = local.fqdn
  }

  set {
    name  = "ingress.annotations.alb\\.ingress\\.kubernetes\\.io/load-balancer-name"
    value = "open-webui-alb"
  }

  set {
    name  = "ingress.annotations.kubernetes\\.io/ingress\\.class"
    value = "alb"
  }

  set {
    name  = "ingress.annotations.alb\\.ingress\\.kubernetes\\.io/target-type"
    value = "ip"
  }

  set {
    name  = "ingress.annotations.alb\\.ingress\\.kubernetes\\.io/scheme"
    value = "internet-facing"
  }

  set {
    name  = "ingress.annotations.alb\\.ingress\\.kubernetes\\.io/security-groups"
    value = aws_security_group.open-webui-ingress-sg.id
  }

  set {
    name  = "ingress.annotations.alb\\.ingress\\.kubernetes\\.io/listen-ports"
    value = jsonencode([{ "HTTPS" : 443 }])
  }

  set {
    name  = "ingress.annotations.alb\\.ingress\\.kubernetes\\.io/certificate-arn"
    value = aws_acm_certificate.webui.arn
  }
}
