.PHONY: init plan apply apply-dev apply-stage apply-prod destroy fmt validate lint tflint pre-commit docs help

ENV ?= dev

init:
	cd terraform/environments/$(ENV) && terraform init

plan:
	cd terraform/environments/$(ENV) && terraform plan -var-file="terraform.tfvars"

apply:
	cd terraform/environments/$(ENV) && terraform apply -var-file="terraform.tfvars" -auto-approve

apply-dev:
	cd terraform/environments/dev && terraform apply -var-file="terraform.tfvars" -auto-approve

apply-stage:
	cd terraform/environments/stage && terraform apply -var-file="terraform.tfvars" -auto-approve

apply-prod:
	cd terraform/environments/prod && terraform apply -var-file="terraform.tfvars" -auto-approve

destroy:
	cd terraform/environments/$(ENV) && terraform destroy -var-file="terraform.tfvars" -auto-approve

fmt:
	cd terraform/environments/$(ENV) && terraform fmt -recursive

validate:
	cd terraform/environments/$(ENV) && terraform validate

lint: tflint pre-commit

tflint:
	@echo "Running TFLint..."
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
