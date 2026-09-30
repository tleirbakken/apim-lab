# -----------------------------------------------------------------------------
# outputs.tf - Values needed after bootstrap.
# The first four become GitHub repo variables (not secrets). They are
# identifiers, not credentials: without a matching federated credential, a
# client ID gives no access. Keeping them visible makes logs easy to debug.
# The last three go into the `backend "azurerm"` blocks.
# -----------------------------------------------------------------------------

# Tells azure/login which Entra tenant to exchange the OIDC token with.
output "tenant_id" {
  description = "Entra tenant ID. GitHub variable AZURE_TENANT_ID."
  value       = data.azurerm_client_config.current.tenant_id
}

# The subscription the workflows and the provider target.
output "subscription_id" {
  description = "Subscription ID. GitHub variable AZURE_SUBSCRIPTION_ID."
  value       = data.azurerm_subscription.current.subscription_id
}

# Tells tf-plan.yml which identity to log in as.
# Note: client_id (application ID), not principal_id (object ID). Login uses
# client_id; RBAC uses principal_id.
output "client_id_plan" {
  description = "Client ID of id-gh-plan-lab. GitHub variable AZURE_CLIENT_ID_PLAN."
  value       = azurerm_user_assigned_identity.plan.client_id
}

# Tells tf-apply.yml which identity to log in as.
output "client_id_apply" {
  description = "Client ID of id-gh-apply-lab. GitHub variable AZURE_CLIENT_ID_APPLY."
  value       = azurerm_user_assigned_identity.apply.client_id
}

# Backend setting: resource_group_name.
output "state_resource_group_name" {
  description = "Resource group for the backend block."
  value       = azurerm_resource_group.state.name
}

# Backend setting: storage_account_name. Printed because it contains the random suffix.
output "state_storage_account_name" {
  description = "Storage account for the backend block."
  value       = azurerm_storage_account.state.name
}

# Backend setting: container_name.
output "state_container_name" {
  description = "Container for the backend block."
  value       = azurerm_storage_container.tfstate.name
}
