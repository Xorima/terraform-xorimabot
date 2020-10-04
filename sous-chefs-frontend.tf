resource "kubernetes_namespace" "sous-chefs-frontend" {
  metadata {
    labels = {
      purpose = "sous-chefs"
    }
    name = "sous-chefs-frontend"
  }
}

resource "kubernetes_secret" "webhook-github-sous-chef-frontend" {
  metadata {
    name      = "github-webhook"
    namespace = kubernetes_namespace.sous-chefs-frontend.metadata[0].name
  }

  data = {
    hmac_secret_token = var.github_hmac_secret_token
    github_token      = var.github_xorimabot_token
  }
}


resource "kubernetes_deployment" "labelvalidator-sous-chef-frontend" {
  metadata {
    name      = "labelvalidator"
    namespace = kubernetes_namespace.sous-chefs-frontend.metadata[0].name
    labels = {
      app = "labelvalidator"
    }

  }
  spec {
    replicas = 2
    selector {
      match_labels = {
        app = "labelvalidator"
      }
    }
    template {
      metadata {
        labels = {
          app = "labelvalidator"
        }
      }
      spec {
        container {
          name  = "labelvalidator"
          image = "xorima/github-cookstyle-runner:${local.app_version.labelvalidator}"
          env {
            name = "SECRET_TOKEN"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.webhook-github-sous-chef-frontend.metadata[0].name
                key  = "hmac_secret_token"
              }
            }
          }
          env {
            name = "GITHUB_TOKEN"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.webhook-github-sous-chef-frontend.metadata[0].name
                key  = "github_token"
              }
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "labelvalidator-sous-chef-frontend" {
  metadata {
    name      = "labelvalidator"
    namespace = kubernetes_namespace.sous-chefs-frontend.metadata.0.name
  }
  spec {
    selector = {
      app = kubernetes_deployment.labelvalidator-sous-chef-frontend.metadata.0.labels.app
    }
    port {
      protocol    = "TCP"
      port        = 80
      target_port = 4567
    }
  }
}

resource "kubernetes_ingress" "labelvalidator-sous-chef-frontend" {
  metadata {
    name = "labelvalidator"
    annotations = {
      "cert-manager.io/cluster-issuer" = "letsencrypt-staging"
    }
  }
  spec {
    rule {
      host = "${var.host_labelvalidator}.${var.cloudflare_dns_zone_filer}"
      http {
        path {
          path = "/"
          backend {
            service_name = kubernetes_service.labelvalidator-sous-chef-frontend.metadata.0.name
            service_port = kubernetes_service.labelvalidator-sous-chef-frontend.spec.0.port.0.port
          }
        }
      }
    }
    tls {
      secret_name = "labelvalidator-tls"
    }

  }
}

resource "cloudflare_record" "charts" {
  zone_id = local.cloudflare_dns_zone_id
  name    = "charts"
  value   = local.kubernetes_public_ip
  type    = "A"
  ttl     = 1
}