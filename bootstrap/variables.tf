# -----------------------------------------------------------------------------
# variables.tf - Inputs to the bootstrap layer.
# Only values that differ between setups are variables. Everything else is
# fixed in the code so the naming convention cannot drift.
# -----------------------------------------------------------------------------

# Which subscription to deploy into.
# Why: no default, so a run can never land in whatever subscription the CLI
# happens to point at. Set in bootstrap.tfvars.
variable "subscription_id" {
  description = "Subscription that hosts the Terraform state and the lab resources."
  type        = string
}

# Region for the state resource group, storage account and identities.
# Why westeurope: the region used across the lab. The identities are regional
# resources, but their tokens work against any region.
variable "location" {
  description = "Azure region for the bootstrap resources."
  type        = string
  default     = "westeurope"
}

# The GitHub repository the identities trust.
# Why a variable: it is part of both federated credential subjects (identity.tf).
# A fork or rename only needs a change here.
variable "github_repo" {
  description = "GitHub repository in <owner>/<name> format, used in the federated credential subjects."
  type        = string
  default     = "tleirbakken/apim-lab"
}

# The GitHub environment that approves apply.
# Why: the apply identity trusts only tokens from jobs bound to this environment,
# so the environment's required reviewers become the approval gate.
variable "github_environment" {
  description = "GitHub environment that gates apply. The apply identity trusts only this environment."
  type        = string
  default     = "lab"
}

# Allowlist of roles the apply identity may grant or remove (see rbac.tf).
# Why: later phases need role assignments (for example APIM managed identity ->
# Key Vault) without giving the pipeline Owner. Add GUIDs here when a new phase
# needs a new role. GUIDs, not names, because the RBAC condition matches on the
# role definition ID.
variable "assignable_role_ids" {
  description = "Role definition GUIDs the apply identity may assign or remove. Everything else (Owner, User Access Administrator, RBAC Administrator) is denied by the condition."
  type        = list(string)
  default = [
    "4633458b-17de-408a-b874-0445c86b69e6", # Key Vault Secrets User
  ]
}
