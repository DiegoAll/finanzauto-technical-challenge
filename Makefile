SHELL := /bin/bash
.DEFAULT_GOAL := help

# Local settings (endpoint, region, secret key). Not versioned; see .env.example.
-include .env
export

ENV ?= dev
ENVIRONMENTS := dev uat prod

# Floci account per environment (12-digit AWS_ACCESS_KEY_ID = account ID).
ACCOUNT_dev  := 111111111111
ACCOUNT_uat  := 222222222222
ACCOUNT_prod := 333333333333

.PHONY: help check-env floci-up floci-down bootstrap-plan bootstrap-apply bootstrap-all

help: ## Show available targets
	@grep -hE '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "}; {printf "  %-15s %s\n", $$1, $$2}'

check-env:
	@if [[ ! " $(ENVIRONMENTS) " =~ " $(ENV) " ]]; then echo "ENV must be one of: $(ENVIRONMENTS)"; exit 1; fi

floci-up: ## Start the AWS emulator
	docker compose up -d

floci-down: ## Stop the AWS emulator (state is kept)
	docker compose down

bootstrap-plan: check-env ## Plan the state bucket for ENV and save it to a plan file
	cd infra/bootstrap && \
	export AWS_ACCESS_KEY_ID=$(ACCOUNT_$(ENV)) && \
	terraform init -input=false && \
	terraform workspace select -or-create $(ENV) && \
	terraform plan -input=false -out=$(ENV).tfplan

bootstrap-apply: check-env ## Apply the saved plan for ENV (run bootstrap-plan first)
	cd infra/bootstrap && \
	export AWS_ACCESS_KEY_ID=$(ACCOUNT_$(ENV)) && \
	terraform workspace select $(ENV) && \
	terraform apply -input=false $(ENV).tfplan && \
	rm -f $(ENV).tfplan

bootstrap-all: ## Plan and apply the state buckets for all environments
	@for env in $(ENVIRONMENTS); do $(MAKE) --no-print-directory bootstrap-plan bootstrap-apply ENV=$$env; done
