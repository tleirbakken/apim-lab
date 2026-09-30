# -----------------------------------------------------------------------------
# identity.tf - The two identities GitHub Actions logs in as, and the trust
# between GitHub's OIDC tokens and those identities.
#
# Flow: a workflow asks GitHub for an OIDC token -> the token's subject claim
# describes the run (PR or environment) -> Entra finds a federated credential
# with a matching issuer, audience and subject -> it issues an Azure token for
# that identity. No client secret exists at any point.
# -----------------------------------------------------------------------------

# Identity used by the plan workflow on pull requests.
# Why user-assigned managed identity instead of an App Registration: it lives in
# Azure (RBAC, tags, lifecycle in Terraform), has no Entra app object to
# manage, and supports federated credentials.
resource "azurerm_user_assigned_identity" "plan" {
  name                = "id-gh-plan-lab"
  resource_group_name = azurerm_resource_group.state.name
  location            = azurerm_resource_group.state.location
  tags                = local.tags
}

# Identity used by the apply workflow after merge and approval.
# Why a separate identity: least privilege. PR code runs before review, so the
# PR identity must never be able to write. Only this identity can.
resource "azurerm_user_assigned_identity" "apply" {
  name                = "id-gh-apply-lab"
  resource_group_name = azurerm_resource_group.state.name
  location            = azurerm_resource_group.state.location
  tags                = local.tags
}

# Trust: pull_request runs in this repo may log in as the plan identity.
# Why it is safe: every PR gets this token, including PRs with unreviewed code,
# so the plan identity is read-only (Reader + the state lock, see rbac.tf).
# Note: on a public repo, PRs from forks do not get OIDC tokens by default.
resource "azurerm_federated_identity_credential" "plan" {
  name                      = "gh-pull-request"
  user_assigned_identity_id = azurerm_user_assigned_identity.plan.id
  issuer                    = local.oidc_issuer
  audience                  = [local.oidc_audience]
  # Must match the token's "sub" claim exactly. GitHub sets it to this value
  # for workflows triggered by pull_request.
  subject = "repo:${var.github_repo}:pull_request"
}

# Trust: only jobs bound to the "lab" environment may log in as apply.
# Why the environment subject: a job with `environment: lab` gets this subject
# regardless of branch. The environment's required reviewers therefore become
# the real approval gate before any token with write access is issued.
resource "azurerm_federated_identity_credential" "apply" {
  name                      = "gh-environment-${var.github_environment}"
  user_assigned_identity_id = azurerm_user_assigned_identity.apply.id
  issuer                    = local.oidc_issuer
  audience                  = [local.oidc_audience]
  subject                   = "repo:${var.github_repo}:environment:${var.github_environment}"
}
