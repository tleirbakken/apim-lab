# -----------------------------------------------------------------------------
# main.tf - Remote state storage for all Terraform layers in this repo.
# One resource group, one storage account and one container. No access keys:
# every client (operator, plan identity, apply identity) authenticates with
# Entra ID and is authorised by RBAC on the container.
# -----------------------------------------------------------------------------

# Shared values used by more than one file.
# Why: tags and OIDC constants are defined once so they cannot differ between
# resources.
locals {
  # Standard tags for cost tracking and ownership in the portal.
  tags = {
    project    = "apim-lab"
    layer      = "bootstrap"
    managed_by = "terraform"
  }

  # GitHub's OIDC token issuer. Entra checks that incoming tokens were issued here.
  oidc_issuer = "https://token.actions.githubusercontent.com"
  # The audience Entra expects when exchanging an external token for an Azure token.
  oidc_audience = "api://AzureADTokenExchange"
}

# Reads who is running Terraform (tenant ID and object ID from az login).
# Why: the operator's object ID gets state access in rbac.tf, and the tenant ID
# is an output for GitHub, both without hardcoding anything.
data "azurerm_client_config" "current" {}

# Reads the target subscription.
# Why: its full resource ID (/subscriptions/<id>) is the scope for the
# subscription-level role assignments in rbac.tf.
data "azurerm_subscription" "current" {}

# Six-character suffix for the storage account name.
# Why: storage account names are globally unique across all of Azure, so
# "sttfstatelab" alone is likely taken. The value is stored in state and stays
# the same on later runs, so the account is not recreated.
resource "random_string" "state_suffix" {
  length  = 6
  lower   = true
  upper   = false # Storage account names allow only lowercase letters and digits.
  numeric = true
  special = false
}

# Resource group for the state account and the two pipeline identities.
# Why a separate group: bootstrap resources outlive the lab. Deleting the lab
# resource groups must never take the state or the pipeline identities with it.
resource "azurerm_resource_group" "state" {
  name     = "rg-tfstate-lab"
  location = var.location
  tags     = local.tags
}

# Storage account that holds the Terraform state files.
# Why these settings: state can contain sensitive values, so the account is
# hardened (no keys, TLS 1.2, no public blobs) and protected against deletion
# (versioning and soft delete).
resource "azurerm_storage_account" "state" {
  name                     = "sttfstatelab${random_string.state_suffix.result}"
  resource_group_name      = azurerm_resource_group.state.name
  location                 = azurerm_resource_group.state.location
  account_tier             = "Standard"
  account_replication_type = "LRS" # Lab: one region is enough; versioning covers mistakes.

  # Disables account keys and SAS tokens. Only Entra ID + RBAC can reach data.
  # This is what makes "no secrets anywhere" true for state.
  shared_access_key_enabled = false
  # Makes the portal use Entra ID when browsing blobs, since there are no keys.
  default_to_oauth_authentication = true
  # Rejects plain HTTP.
  https_traffic_only_enabled = true
  # Rejects outdated TLS versions.
  min_tls_version = "TLS1_2"
  # Prevents any container from ever being set to anonymous public read.
  allow_nested_items_to_be_public = false

  # Public network access stays on: GitHub-hosted runners have no fixed IPs.
  # Deliberate lab exception, documented in docs/phase-1.md.

  blob_properties {
    # Every write keeps the previous version, so a bad apply or corrupt state
    # can be rolled back to an earlier state file.
    versioning_enabled = true

    # Deleted blobs (state files) can be restored for 30 days.
    delete_retention_policy {
      days = 30
    }

    # A deleted container can be restored for 30 days.
    container_delete_retention_policy {
      days = 30
    }
  }

  tags = local.tags
}

# Container that holds one state file per layer (bootstrap, lab, ...).
# Why storage_account_id: azurerm 4.x creates the container through the ARM
# API when given the account ID. That makes .id an ARM resource ID, which is
# what RBAC scopes in rbac.tf need. storage_account_name is deprecated.
resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.state.id
  container_access_type = "private" # No anonymous access; RBAC only.
}
