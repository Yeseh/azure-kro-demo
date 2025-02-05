# This is simply following the documentation on bootstrapping flux in a github repository using SSH
# see: https://github.com/fluxcd/terraform-provider-flux/blob/main/examples/github-self-managed-ssh-keypair/main.tf

resource "kind_cluster" "this" {
    name = "azure-kro"
}

# Create a gitrepository that is going to house this code
resource "github_repository" "this" {
    name = "azure-kro-demo"
    description = "Project to demo kubernetes resource orchestrator on Azure"
    visibility = "public"
    auto_init = true
}

# Generate a new keypair to access the git repository
# for serious use, store in keyvault or other secret management tool
resource "tls_private_key" "flux" {
    algorithm = "ECDSA"
    ecdsa_curve = "P256"
}

resource "github_repository_deploy_key" "this" {
    title = "Flux"
    repository = github_repository.this.name
    key = tls_private_key.flux.public_key_openssh
    read_only = false
}


# Bootstrap fluxcd
resource "kubernetes_namespace" "flux_system" {
  metadata {
    name = "flux-system"
  }

  lifecycle {
    ignore_changes = [metadata]
  }
}

resource "kubernetes_secret" "ssh_keypair" {
  metadata {
    name      = "flux-system"
    namespace = "flux-system"
  }

  type = "Opaque"

  data = {
    "identity.pub" = tls_private_key.flux.public_key_openssh
    "identity"     = tls_private_key.flux.private_key_pem
    "known_hosts"  = "github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg="
  }

  depends_on = [kubernetes_namespace.flux_system]
}

resource "flux_bootstrap_git" "this" {
  depends_on = [
    github_repository_deploy_key.this, 
    kubernetes_secret.ssh_keypair
  ]

  disable_secret_creation = true
  embedded_manifests      = true
  path                    = "clusters/control-plane"
}




