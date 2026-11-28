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

.PHONY: help check-env floci-up floci-down bootstrap-plan bootstrap-apply bootstrap-all tf-init tf-plan tf-apply tf-output smoke backup restore-test

# Optional image override, e.g. IMAGE=ghcr.io/owner/repo/traccar:<sha>. The CD sets it; empty uses the tfvars value.
IMAGE ?=

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

tf-init: check-env ## Init infra/environments against the state bucket of ENV
	cd infra/environments && \
	export AWS_ACCESS_KEY_ID=$(ACCOUNT_$(ENV)) && \
	terraform init -input=false -reconfigure -backend-config=envs/$(ENV).s3.tfbackend

tf-plan: tf-init ## Plan ENV with its tfvars and save it to a plan file
	cd infra/environments && \
	export AWS_ACCESS_KEY_ID=$(ACCOUNT_$(ENV)) && \
	terraform plan -input=false -var-file=envs/$(ENV).tfvars $(if $(IMAGE),-var image=$(IMAGE)) -out=$(ENV).tfplan

tf-apply: check-env ## Apply the saved plan for ENV (run tf-plan first)
	cd infra/environments && \
	export AWS_ACCESS_KEY_ID=$(ACCOUNT_$(ENV)) && \
	terraform apply -input=false $(ENV).tfplan && \
	rm -f $(ENV).tfplan

tf-output: tf-init ## Show the outputs of ENV
	cd infra/environments && \
	export AWS_ACCESS_KEY_ID=$(ACCOUNT_$(ENV)) && \
	terraform output

smoke: tf-init ## Check that ENV runs exactly the deployed task definition and Traccar answers /api/server
	cd infra/environments && \
	export AWS_ACCESS_KEY_ID=$(ACCOUNT_$(ENV)) && \
	url=$$(terraform output -raw web_url) && \
	cluster=$$(terraform output -raw cluster_name) && \
	service=$$(terraform output -raw service_name) && \
	expected=$$(terraform output -raw task_definition_arn) && \
	echo "Expected task definition: $$expected" && \
	for i in $$(seq 1 30); do \
		tasks=$$(aws ecs list-tasks --cluster "$$cluster" --service-name "$$service" --desired-status RUNNING --query 'taskArns' --output text); \
		running=""; \
		if [ -n "$$tasks" ] && [ "$$tasks" != "None" ]; then \
			running=$$(aws ecs describe-tasks --cluster "$$cluster" --tasks $$tasks \
				--query 'tasks[?lastStatus==`RUNNING`].taskDefinitionArn' --output text | tr '\t' '\n' | sort -u); \
		fi; \
		if [ "$$running" = "$$expected" ] && curl -sf --max-time 5 "$$url/api/server" > /dev/null; then \
			echo "Traccar $(ENV) is up at $$url running $$running"; exit 0; \
		fi; \
		echo "Waiting for Traccar $(ENV) ($$i/30): running=[$${running:-none}]"; sleep 10; \
	done; \
	echo "Traccar $(ENV) is not running the expected task definition or not answering at $$url"; exit 1

backup: tf-init ## Dump the database of ENV (default prod) to its S3 backup bucket
	export AWS_ACCESS_KEY_ID=$(ACCOUNT_$(ENV)) && scripts/backup.sh $(ENV)

restore-test: tf-init ## Restore the latest backup of ENV into a temporary database and compare row counts
	export AWS_ACCESS_KEY_ID=$(ACCOUNT_$(ENV)) && scripts/restore-test.sh $(ENV)
