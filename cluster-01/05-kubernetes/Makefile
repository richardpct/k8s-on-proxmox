.DEFAULT_GOAL  := help
TERRAFORM_LOCK := .terraform.lock.hcl
SECRET_ENV     := ~/terraform/k8s-on-proxmox/tofu_vars_secrets

.PHONY: help
help: ## Show help
	@echo "Usage: make TARGET\n"
	@echo "Targets:"
	@awk -F ":.* ##" '/^[^#].*:.*##/{printf "%-13s%s\n", $$1, $$2}' \
	$(MAKEFILE_LIST) \
	| grep -v awk

$(TERRAFORM_LOCK):
	. $(SECRET_ENV) && \
	tofu init

.PHONY: init
init: $(TERRAFORM_LOCK) ## Init

.PHONY: apply
apply: init ## Create the infrastructure
	. $(SECRET_ENV) && \
	gtime make apply -C ../04-infra && \
	gtime tofu apply -auto-approve

.PHONY: plan
plan: init ## Dry run
	. $(SECRET_ENV) && \
	tofu plan

.PHONY: destroy
destroy: ## Destroy the infrastructure
	. $(SECRET_ENV) && \
	tofu state ls | while read; do tofu state rm $$REPLY; done
	. $(SECRET_ENV) && \
	tofu destroy -auto-approve && make destroy -C ../04-infra

.PHONY: clean
clean: ## Clean
	rm -rfv .terraform*
