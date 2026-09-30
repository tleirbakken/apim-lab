# Roadmap

**Current phase: 1 — Repo and pipeline**

| Phase | Build | Learn |
|---|---|---|
| 1. Pipeline | Repo, OIDC, remote state, plan on PR / apply on merge with approval | GitHub Actions, secretless auth |
| 2. Network | Hub/spoke VNets, NSGs, subnets for APIM, App Gateway, Private Endpoints | Segmentation, peering |
| 3. Private backend | Function/Container App + Key Vault behind Private Endpoints, Private DNS zones | PE + DNS resolution |
| 4. APIM internal | APIM internal mode, App Gateway in front, DNS records for gateway/portal | Internal vs. internet-facing traffic |
| 5. APIM config as code | APIs, products, policies in a separate workflow (APIOps) | Separating infra and API lifecycle |
| 6. Second tenant | DNS Private Resolver, cross-tenant Private Endpoint approval | Advanced DNS, cross-tenant Private Link |

## Phase 1 — Repo and pipeline

**Goal:** a PR produces a `terraform plan` as a PR comment; a merge to `main` runs `apply`
after approval. Zero secrets in GitHub.

### Design decisions

| Decision | Choice | Reason |
|---|---|---|
| Identity type | User-assigned managed identity (not App Registration) | No Entra app object lifecycle, lives in Azure RBAC, supports federated credentials |
| Number of identities | Two: `id-gh-plan-lab` and `id-gh-apply-lab` | Least privilege; PRs must not be able to write |
| Plan permissions | Reader on subscription + Storage Blob Data Contributor on state container | Plan writes the state lock |
| Apply permissions | Contributor + Role Based Access Control Administrator with condition | Later phases need role assignments (APIM MI → Key Vault) without Owner |
| State auth | Shared key disabled, Entra auth in backend (`use_azuread_auth`, `use_oidc`) | No access keys anywhere |
| GitHub values | Tenant/subscription/client IDs as repo *variables*, not secrets | Not secret; readable in logs when debugging |

### Federated credential subjects

- Plan identity: `repo:<org>/apim-lab:pull_request`
- Apply identity: `repo:<org>/apim-lab:environment:lab`

A job with `environment: lab` always gets the environment subject regardless of branch,
so the environment's required reviewers are the real approval gate.

### Order of work

1. Create the repo (decide public vs. private — see gotchas).
2. Write `bootstrap/`: RG, storage account (shared key off, versioning, blob soft delete),
   container `tfstate`, two UAMIs, federated credentials, role assignments.
3. Run bootstrap locally with `az login`. Then add a `backend` block and run
   `terraform init -migrate-state` so bootstrap state also lives in the storage account.
4. Add outputs as repo variables: `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`,
   `AZURE_CLIENT_ID_PLAN`, `AZURE_CLIENT_ID_APPLY`.
5. Create GitHub environment `lab` with myself as required reviewer.
6. `infra/envs/lab` with one trivial resource (an RG) to prove the pipeline.
7. `tf-plan.yml`, test with a PR.
8. `tf-apply.yml`, test with a merge.
9. Write `docs/phase-1.md`.

### Gotchas

- Workflows need `permissions: id-token: write` or OIDC fails with an unhelpful error.
- Environment required reviewers on private repos require GitHub Enterprise. Free, Pro and
  Team only get them on public repos. Verify against current GitHub docs.
- With shared key disabled, the bootstrap provider needs `storage_use_azuread = true`.
- Re-planning inside apply can diverge from the plan approved on the PR. Acceptable in the
  lab; document it. Alternative: pass the plan file as an artifact.

### Done when

- PR gets a plan comment, run as `id-gh-plan-lab`
- Merge waits for approval and applies as `id-gh-apply-lab`
- No secrets in the repo, no access keys enabled on the state storage account
- `docs/phase-1.md` explains the trust chain from GitHub token to Azure role

## Later-phase gotchas to remember

- APIM classic internal VNet injection requires Developer or Premium. v2 tiers differ
  (Standard v2: outbound VNet integration + inbound PE; Premium v2: injection). Check docs.
- APIM Developer deploys in 30–45 min; don't tear it down routinely.
- APIM is soft-deleted on destroy; reusing the name requires a purge.
- Internal mode NSG needs inbound `ApiManagement` service tag on 3443 and
  `AzureLoadBalancer` on 6390.
- Private Endpoint state storage blocks GitHub-hosted runners: self-hosted runner in the
  VNet or a documented exception.
- App Gateway WAF v2 and APIM are the cost drivers: keep a destroy workflow for App Gateway.
