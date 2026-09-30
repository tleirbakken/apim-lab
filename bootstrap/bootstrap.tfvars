# Values for this bootstrap run. Pass with: terraform plan -var-file=bootstrap.tfvars
# Why committed: a subscription ID is an identifier, not a secret. Never add
# credentials here; authentication comes from az login.

subscription_id = "0e2aca92-b024-46cc-bebc-a03d4284aa6c" # TODO: set your subscription ID
