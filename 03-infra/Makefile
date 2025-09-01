.DEFAULT_GOAL  := help
TERRAFORM_LOCK := .terraform.lock.hcl

.PHONY: help
help: ## Show help
	@echo "Usage: make TARGET\n"
	@echo "Targets:"
	@awk -F ":.* ##" '/^[^#].*:.*##/{printf "%-13s%s\n", $$1, $$2}' \
	$(MAKEFILE_LIST) \
	| grep -v awk

$(TERRAFORM_LOCK):
	tofu init \
		-backend-config="bucket=${TF_VAR_bucket}" \
		-backend-config="key=${TF_VAR_key_infra}" \
		-backend-config="region=${TF_VAR_region}"

.PHONY: init
init: $(TERRAFORM_LOCK) ## Init

.PHONY: apply
apply: init ## Create the infrastructure
	gtime tofu apply -auto-approve

.PHONY: plan
plan: init ## Dry run
	tofu plan

.PHONY: destroy
destroy: ## Destroy the infrastructure
	tofu state rm helm_release.argo-cd || true
	tofu state rm helm_release.argocd-apps || true
	tofu state rm helm_release.cilium || true
	tofu state rm helm_release.vault || true
	tofu state rm helm_release.kyverno || true
	tofu state rm vault_generic_secret.ceph-cluster-id || true
	tofu destroy -auto-approve
	@rm -fv *.backup

.PHONY: clean
clean: ## Clean
	rm -rfv .terraform*
