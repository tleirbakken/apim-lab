# -----------------------------------------------------------------------------
# versions.tf - Terraform and provider pinning, plus provider configuration.
# Bootstrap runs locally once as the operator (az login). It creates everything
# the GitHub pipeline needs before the pipeline itself can run.
# -----------------------------------------------------------------------------

# Pins the Terraform CLI and provider versions.
# Why: unpinned versions let a new release change behaviour between runs. CI
# pins the same Terraform version so local and pipeline runs behave the same.
# azurerm stays on 4.x on purpose: 5.x exists, but upgrading is a separate
# decision after reading the 5.0 upgrade guide.
terraform {
  required_version = "~> 1.15"

  required_providers {
    # Creates all Azure resources in this layer.
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.81"
    }
    # Generates the storage account name suffix (see main.tf).
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
  }
}

# Configures how azurerm authenticates and which subscription it targets.
# Why: authentication comes from the Azure CLI session (az login), so no
# credentials live in the code. azurerm 4.x requires subscription_id to be set
# explicitly.
provider "azurerm" {
  # Required by azurerm, even when empty. Holds provider-wide behaviour toggles.
  features {}

  subscription_id = var.subscription_id

  # Shared key is disabled on the state account, so data plane calls (creating
  # the container, reading blob properties) must use Entra ID instead of keys.
  # Without this the provider tries to fetch account keys and fails.
  storage_use_azuread = true
}
