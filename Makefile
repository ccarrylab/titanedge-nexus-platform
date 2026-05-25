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
