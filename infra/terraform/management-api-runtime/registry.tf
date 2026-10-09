# ------------------------------------------------------------------
# OCIR — repo privado `management-api` (tags dev/prod/<git-sha>).
# Pull na VM: instance principal (dynamic group + read repos) via
# docker-credential/temporário — sem credencial persistida na VM.
# Push no CI: auth token do usuário Terraform -> secrets OCIR_* da API.
# ------------------------------------------------------------------
data "oci_objectstorage_namespace" "this" {
  compartment_id = local.compartment_id
}

data "oci_identity_user" "tf" {
  user_id = var.user_ocid
}

locals {
  ocir_registry   = "${var.ocir_region_key}.ocir.io"
  ocir_namespace  = data.oci_objectstorage_namespace.this.namespace
  ocir_image_repo = "${local.ocir_registry}/${local.ocir_namespace}/${var.ocir_repo_name}"
  ocir_push_user  = "${local.ocir_namespace}/${data.oci_identity_user.tf.name}"
}

resource "oci_artifacts_container_repository" "api" {
  compartment_id = local.compartment_id
  display_name   = var.ocir_repo_name
  is_public      = false
  is_immutable   = false

  readme {
    content = "Imagens da ecolchain-management-api (tags: dev, prod, <git-sha>)"
    format  = "text/markdown"
  }
}

resource "oci_identity_dynamic_group" "vm" {
  compartment_id = local.compartment_id
  name           = "mgmt-api-runtime-vm"
  description    = "VM do runtime da management-api (instance principal)"
  matching_rule  = "ANY {instance.id = '${oci_core_instance.dev.id}', instance.id = '${oci_core_instance.prod.id}'}"
}

resource "oci_identity_policy" "vm_ocir_pull" {
  compartment_id = local.compartment_id
  name           = "mgmt-api-runtime-ocir-pull"
  description    = "Permite a VM puxar imagens do OCIR via instance principal"

  # `manage repos` só seria necessário para push a partir da VM (não usado).
  statements = [
    "Allow dynamic-group ${oci_identity_dynamic_group.vm.name} to read repos in tenancy"
  ]
}

# Auth token para `docker login` no CI da API (push). OCI limita a 2
# auth tokens por usuário — se o apply falhar por limite, gerar um
# usuário dedicado ou informar um token existente via secret manual.
resource "oci_identity_auth_token" "ocir_push" {
  user_id     = var.user_ocid
  description = "management-api CI push OCIR (repos OCIR_USERNAME/OCIR_AUTH_TOKEN)"
}
