ARGUMENTS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
TERRAFORM_GLOBAL_OPTIONS := "-chdir=terraform"
OPTIONS := $(firstword $(ARGUMENTS))

CYAN := \033[36m
RESET := \033[0m

.PHONY: help
help:
	@printf "$(CYAN)%-30s$(RESET) %s\n" "apply" "Applies a new state."
	@printf "$(CYAN)%-30s$(RESET) %s\n" "comment-pr" "Posts the terraform plan as a PR comment."
	@printf "$(CYAN)%-30s$(RESET) %s\n" "help" "Display help for available targets"
	@printf "$(CYAN)%-30s$(RESET) %s\n" "init" "Initializes the terraform state backend."
	@printf "$(CYAN)%-30s$(RESET) %s\n" "output" "Show outputs of the entire state."
	@printf "$(CYAN)%-30s$(RESET) %s\n" "plan" "Runs a plan."
	@printf "$(CYAN)%-30s$(RESET) %s\n" "plan-destroy" "Shows what a destroy would do."
	@printf "$(CYAN)%-30s$(RESET) %s\n" "list" "Lists resources in the state."
	@printf "$(CYAN)%-30s$(RESET) %s\n" "rm" "Removes resource(s) from the state. Usage: make rm '<resource_address>'"
	@printf "$(CYAN)%-30s$(RESET) %s\n" "show" "Shows resources"
	@printf "$(CYAN)%-30s$(RESET) %s\n" "upgrade" "Gets any provider updates"

.PHONY: apply
apply: init
	@tofu $(TERRAFORM_GLOBAL_OPTIONS) apply -input=true -refresh=true "terraform.tfplan"

.PHONY: init
init:
	@./tools/tf-helper.sh $(TERRAFORM_GLOBAL_OPTIONS)

.PHONY: output
output: init
	@tofu $(TERRAFORM_GLOBAL_OPTIONS) output -json

.PHONY: list
list:
	@tofu $(TERRAFORM_GLOBAL_OPTIONS) state list

.PHONY: rm
rm:
	@tofu $(TERRAFORM_GLOBAL_OPTIONS) state rm $(OPTIONS)

.PHONY: plan
plan: init
	@tofu $(TERRAFORM_GLOBAL_OPTIONS) plan -out=terraform.tfplan

.PHONY: comment-pr
comment-pr:
	@./tools/tf-comment-pr.sh $(TERRAFORM_GLOBAL_OPTIONS)

.PHONY: plan-destroy
plan-destroy: init
	@tofu $(TERRAFORM_GLOBAL_OPTIONS) plan -input=false -refresh=true -destroy -out=terraform.tfplan

.PHONY: show
show: init
	@tofu $(TERRAFORM_GLOBAL_OPTIONS) show

upgrade:
	@tofu $(TERRAFORM_GLOBAL_OPTIONS) init -upgrade

.PHONY: FORCE
%: FORCE
	@if [ "$(MAKECMDGOALS)" != "help" ] \
		&& [ "$(MAKECMDGOALS)" = "" ]; then \
		echo "No targets specified, check README.md"; \
		exit 1; \
	fi
