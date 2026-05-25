init:
\tterraform init

fmt:
\tterraform fmt -recursive

validate:
\tterraform validate

lint:
\ttflint

security:
\ttfsec .
\tcheckov -d .

plan:
\tterraform plan

apply:
\tterraform apply

destroy:
\tterraform destroy

# ----- Additional targets -----
.PHONY: test docs lint precommit apply-dev destroy-dev

test:
	cd tests && go test -v ./...

docs:
	@for mod in terraform/modules/*/; do \
		if [ -f "$${mod}/main.tf" ]; then \
			terraform-docs markdown table "$${mod}" > "$${mod}/README.md"; \
			echo "Updated $${mod}/README.md"; \
		fi \
	done

lint: precommit

precommit:
	pre-commit run --all-files

apply-dev:
	cd terraform/environments/dev && terraform apply -auto-approve

destroy-dev:
	cd terraform/environments/dev && terraform destroy -auto-approve
