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
		-backend-config="key=${TF_VAR_key_kubernetes}" \
		-backend-config="region=${TF_VAR_region}"

.PHONY: init
init: $(TERRAFORM_LOCK) ## Init

.PHONY: apply
apply: init ## Create the infrastructure
	gtime make apply -C ../04-infra && gtime tofu apply -auto-approve

.PHONY: plan
plan: init ## Dry run
	tofu plan

.PHONY: destroy
destroy: ## Destroy the infrastructure
	tofu state ls | while read; do tofu state rm $$REPLY; done
	tofu destroy -auto-approve && make destroy -C ../04-infra

.PHONY: clean
clean: ## Clean
	rm -rfv .terraform*
