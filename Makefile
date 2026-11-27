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

.PHONY: help check-env floci-up floci-down bootstrap bootstrap-all

help: ## Show available targets
	@grep -hE '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "}; {printf "  %-15s %s\n", $$1, $$2}'

check-env:
	@if [[ ! " $(ENVIRONMENTS) " =~ " $(ENV) " ]]; then echo "ENV must be one of: $(ENVIRONMENTS)"; exit 1; fi

floci-up: ## Start the AWS emulator
	docker compose up -d

floci-down: ## Stop the AWS emulator (state is kept)
	docker compose down

bootstrap: check-env ## Create the Terraform state bucket for ENV (dev|uat|prod)
	cd infra/bootstrap && \
	export AWS_ACCESS_KEY_ID=$(ACCOUNT_$(ENV)) && \
	terraform init -input=false && \
	terraform workspace select -or-create $(ENV) && \
	terraform apply

bootstrap-all: ## Create the state buckets for all environments
	@for env in $(ENVIRONMENTS); do $(MAKE) --no-print-directory bootstrap ENV=$$env; done
