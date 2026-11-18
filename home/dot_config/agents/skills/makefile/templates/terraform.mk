# ---- terraform: needs terraform (mise), tflint (Mason or mise); secrets via the repo's mise env ----
TF_DIR := .
.PHONY: terraform/init terraform/tidy terraform/lint terraform/test terraform/audit terraform/build terraform/updatedep
terraform/init:
	terraform -chdir=$(TF_DIR) init -input=false
terraform/tidy:
	terraform fmt -recursive $(TF_DIR)
terraform/lint:
	terraform fmt -check -recursive $(TF_DIR)
	terraform -chdir=$(TF_DIR) validate
	tflint --chdir=$(TF_DIR)
terraform/test terraform/audit terraform/build:
	@:
terraform/updatedep:
	terraform -chdir=$(TF_DIR) init -upgrade -input=false
##plan: Show what terraform would change (read-only)
.PHONY: plan
plan:
	terraform -chdir=$(TF_DIR) plan -input=false
##deploy/terraform: Apply infrastructure changes (needs confirm=yes)
.PHONY: deploy/terraform
deploy/terraform:
	@test "$(confirm)" = yes || { echo "this applies infrastructure changes: make deploy/terraform confirm=yes"; exit 1; }
	terraform -chdir=$(TF_DIR) apply -input=false
