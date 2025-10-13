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
	tofu state rm module.kubernetes.helm_release.argo-cd 2> /dev/null || true
	tofu state rm module.kubernetes.helm_release.argocd-apps 2> /dev/null || true
	tofu state rm module.kubernetes.helm_release.cilium 2> /dev/null || true
	tofu state rm module.kubernetes.helm_release.vault 2> /dev/null || true
	tofu state rm module.kubernetes.data.terraform_remote_state.certificate 2> /dev/null || true
	tofu state rm module.kubernetes.null_resource.ceph-csi-secret 2> /dev/null || true
	tofu state rm module.kubernetes.null_resource.default-tls-cert 2> /dev/null || true
	tofu state rm module.kubernetes.null_resource.wait-vault-up 2> /dev/null || true
	tofu state rm module.kubernetes.null_resource.wait_kubernetes_ready 2> /dev/null || true
	tofu state rm module.kubernetes.vault_generic_secret.ceph-cluster-id 2> /dev/null || true
	make destroy -C ../04-infra

.PHONY: clean
clean: ## Clean
	rm -rfv .terraform*
