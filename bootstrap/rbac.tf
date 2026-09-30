# -----------------------------------------------------------------------------
# rbac.tf - What each identity is allowed to do once it has logged in.
#
# Summary:
#   plan     Reader (subscription) + Storage Blob Data Contributor (state container)
#   apply    Contributor + RBAC Administrator with condition (subscription)
#            + Storage Blob Data Contributor (state container)
#   operator Storage Blob Data Contributor (state container)
#
# principal_type is set on every assignment. Why: a newly created identity can
# take a while to replicate in Entra ID. With principal_type set, ARM skips the
# lookup and the assignment does not fail on a fresh principal. It is also
# required when the assigner is limited by an ABAC condition on PrincipalType.
# -----------------------------------------------------------------------------

locals {
  # The allowlist as a comma-separated string, the format the condition expects.
  assignable_role_ids = join(", ", var.assignable_role_ids)

  # ABAC condition on the apply identity's RBAC Administrator role.
  # Why: RBAC Administrator alone can assign any role, including Owner, which
  # would let the pipeline make itself Owner. This condition limits it to the
  # roles in var.assignable_role_ids.
  #
  # How to read it: each block says "either this is not the action I restrict,
  # OR the role involved is on the allowlist".
  #   Block 1 (write):  creating an assignment -> the requested role must be listed.
  #   Block 2 (delete): removing an assignment -> the existing role must be listed,
  #                     so the pipeline cannot remove assignments it did not
  #                     create (for example the operator's Owner).
  # Owner, User Access Administrator and RBAC Administrator are not on the list,
  # so they are denied implicitly.
  rbac_admin_condition = <<-EOT
    (
     (
      !(ActionMatches{'Microsoft.Authorization/roleAssignments/write'})
     )
     OR
     (
      @Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {${local.assignable_role_ids}}
     )
    )
    AND
    (
     (
      !(ActionMatches{'Microsoft.Authorization/roleAssignments/delete'})
     )
     OR
     (
      @Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {${local.assignable_role_ids}}
     )
    )
  EOT
}

# --- Plan identity: read everything, write only the state lock ---

# Lets `terraform plan` read the current state of every resource it compares
# against. Reader has no write actions, so unreviewed PR code cannot change anything.
resource "azurerm_role_assignment" "plan_reader" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.plan.principal_id
  principal_type       = "ServicePrincipal"
}

# Lets plan read the state file and take the state lock. Terraform locks by
# taking a lease on the blob, which is a write, so Reader is not enough.
# Why container scope, not account: least privilege. The identity only sees this container.
resource "azurerm_role_assignment" "plan_state" {
  scope                = azurerm_storage_container.tfstate.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.plan.principal_id
  principal_type       = "ServicePrincipal"
}

# --- Apply identity: manage resources, write state, assign only allowlisted roles ---

# Lets apply create, change and delete resources in the subscription.
# Why not Owner: Contributor cannot assign roles. That right is granted
# separately below, with a condition.
resource "azurerm_role_assignment" "apply_contributor" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.apply.principal_id
  principal_type       = "ServicePrincipal"
}

# Lets apply read and write the state file.
# Why it is needed: Contributor covers the control plane only. It has no data
# actions, so it cannot read or write blobs.
resource "azurerm_role_assignment" "apply_state" {
  scope                = azurerm_storage_container.tfstate.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.apply.principal_id
  principal_type       = "ServicePrincipal"
}

# Lets apply create role assignments for workload identities in later phases
# (for example APIM managed identity -> Key Vault Secrets User). The condition
# limits it to the allowlisted roles.
resource "azurerm_role_assignment" "apply_rbac_admin" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Role Based Access Control Administrator"
  principal_id         = azurerm_user_assigned_identity.apply.principal_id
  principal_type       = "ServicePrincipal"
  condition_version    = "2.0" # The syntax version for ActionMatches/@Request/@Resource conditions.
  condition            = local.rbac_admin_condition
}

# --- The operator running bootstrap: needed for `terraform init -migrate-state` ---

# Lets you (the az login user) read and write state blobs.
# Why: with shared key disabled, even Owner on the subscription cannot read
# blobs, because Owner has no data actions. Without this, migrating bootstrap
# state into the container fails with 403.
resource "azurerm_role_assignment" "operator_state" {
  scope                = azurerm_storage_container.tfstate.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
  principal_type       = "User"
}
