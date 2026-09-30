# apim-lab

Home lab that closes three competence gaps in one project: Azure API Management (APIM),
advanced Azure networking (Private Endpoints, Private DNS, segmentation, DNS Private Resolver)
and GitHub Actions. Everything is deployed with Terraform through GitHub Actions using OIDC.

## How to work with me

- I write the code myself. Your role is structure, ordering, review and explanation.
  Do NOT generate complete files or modules unless I explicitly ask for it.
- When I ask "what next?": give the next concrete step, which file it goes in, and why.
- When reviewing: reference file and line, explain the reason, and be direct about gaps
  (security, least privilege, idempotency, naming). Don't soften findings.
- Give an opinionated recommendation with reasoning. Only lay out tradeoffs when there is a
  genuine choice.
- Respond in Norwegian. Keep technical terms, resource names and code in English.
- Flag anything that has changed recently in Azure, azurerm or GitHub Actions, and point me
  to the official docs rather than guessing.
- Use plan mode for anything touching more than one file.

## Hard rules

- Never run `terraform apply`, `terraform destroy`, or `az` commands that create, change or
  delete resources. `init`, `fmt`, `validate` and `plan` are fine.
- No secrets in the repo. OIDC federated credentials only: no client secrets, no storage
  account access keys (shared key access is disabled on the state account).
- Managed identities + RBAC, least privilege. Owner is never the answer.
- Never read or print `.tfstate` files.

## Stack and conventions

- Terraform with a pinned `azurerm ~> 4.x` provider and pinned Terraform version in CI.
  Check current versions before bumping.
- Naming: Microsoft CAF abbreviations (`rg-`, `vnet-`, `snet-`, `nsg-`, `apim-`, `agw-`,
  `kv-`, `st-`, `id-`, `pe-`) plus `-lab` suffix.
- One module per layer in `infra/modules/`; `infra/envs/lab/` only composes modules.
- Every module has `variables.tf` with descriptions and types, and `outputs.tf`.
- `terraform fmt` must pass; CI enforces `fmt -check` and `validate`.
- Each phase gets `docs/phase-N.md` explaining decisions with file and line references.

## Repo layout

```
.github/workflows/   tf-plan.yml (PR), tf-apply.yml (push main, environment "lab")
bootstrap/           run locally once: state storage, UAMIs, federated creds, RBAC
infra/envs/lab/      backend, providers, composition, lab.tfvars
infra/modules/       network, backend, apim, appgw
docs/                roadmap.md, phase-N.md
```

## Target architecture

Internet → Application Gateway (WAF v2) → APIM (internal VNet mode) → backend
(Function/Container App behind Private Endpoint) → Key Vault (Private Endpoint).
A second tenant consumes services via DNS Private Resolver and cross-tenant Private Link.

## Roadmap and current phase

@docs/roadmap.md
