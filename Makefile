.PHONY: init plan apply apply-dev apply-stage apply-prod destroy fmt validate lint tflint pre-commit docs help

ENV ?= dev

init:
	cd terraform && terraform init

plan:
	cd terraform && terraform plan -var-file="environments/$(ENV)/terraform.tfvars"

apply-dev:
	cd terraform && terraform apply -var-file="environments/dev/terraform.tfvars" -auto-approve

apply-stage:
	cd terraform && terraform apply -var-file="environments/stage/terraform.tfvars" -auto-approve

apply-prod:
	cd terraform && terraform apply -var-file="environments/prod/terraform.tfvars" -auto-approve

destroy:
	cd terraform && terraform destroy -var-file="environments/$(ENV)/terraform.tfvars"

fmt:
	cd terraform && terraform fmt -recursive

validate:
	cd terraform && terraform validate

lint: tflint pre-commit

tflint:
	cd terraform && tflint --init && tflint -f compact

pre-commit:
	pre-commit run --all-files

docs:
	@for mod in terraform/modules/*/; do \
		echo "Generating docs for $$mod"; \
		terraform-docs markdown table --output-file README.md $$mod; \
	done

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'
