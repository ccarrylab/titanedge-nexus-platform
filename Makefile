.PHONY: test test-static test-unit test-integration init plan apply destroy fmt lint

test: test-static test-unit

test-static:
	cd tests && go test -v ./...

test-unit:
	cd terraform/modules/vpc && terraform init -backend=false -input=false > /dev/null && terraform test
	cd terraform/environments/dev && terraform init -backend=false -input=false > /dev/null && terraform test

test-integration:
	cd tests && go mod tidy && go test -v -tags=integration -timeout 30m ./...

fmt:
	terraform fmt -recursive terraform/

lint:
	cd tests && go vet ./...

init:
	cd terraform/environments/dev && terraform init -reconfigure

plan:
	cd terraform/environments/dev && terraform plan

apply:
	cd terraform/environments/dev && terraform apply

destroy:
	@echo "⚠️  WARNING: This will destroy ALL infrastructure in the dev environment."
	@read -p "Type the environment name to confirm [dev]: " confirm; \
	if [ "$$confirm" != "dev" ]; then \
		echo "Aborted."; exit 1; \
	fi
	cd terraform/environments/dev && terraform destroy
