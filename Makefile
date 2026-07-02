# Bravo Fintech MVP — developer commands.
# All commands run inside Docker so a clean clone needs only Docker + Make.
.DEFAULT_GOAL := help
.PHONY: help up run down build migrate seed test lint smoke deploy web-build web-test k8s-validate console logs ps

COMPOSE := docker compose
SERVICES ?=

help: ## List available commands
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

up: ## Boot the full stack (api + worker + frontend + postgres + redis); waits until the api is healthy
	$(COMPOSE) up -d --build --wait

run: up seed ## Boot the full stack and seed sample data

down: ## Stop and remove containers
	$(COMPOSE) down

build: ## Build the api image
	$(COMPOSE) build

migrate: ## Create/migrate the database (incl. PL/pgSQL triggers)
	$(COMPOSE) run --rm api ./bin/rails db:prepare

seed: ## Load seed data (users per role + sample applications)
	$(COMPOSE) run --rm api ./bin/rails db:seed

test: ## Run the full test suite (RSpec)
	$(COMPOSE) run --rm -e RAILS_ENV=test api bash -c "./bin/rails db:prepare && bundle exec rspec"

lint: ## Run static analysis (RuboCop + bundler-audit)
	$(COMPOSE) run --rm api bash -c "bundle exec rubocop && bundle exec bundle-audit check --update"

smoke: ## End-to-end smoke against the running stack (login, countries, list, create)
	@./bin/smoke.sh

deploy: ## Apply the Kubernetes manifests to the current kube-context (needs a cluster + pushed images)
	kubectl apply -f k8s/

web-build: ## Build the frontend (tsc + vite)
	$(COMPOSE) run --rm frontend sh -c "npm install --no-fund --no-audit && npm run build"

web-test: ## Run the frontend component tests
	$(COMPOSE) run --rm frontend sh -c "npm install --no-fund --no-audit && npm test"

k8s-validate: ## Validate the Kubernetes manifests (schema check; no cluster needed)
	docker run --rm -v "$$(pwd)/k8s":/k8s ghcr.io/yannh/kubeconform:latest \
		-strict -summary -kubernetes-version 1.30.0 /k8s/
	@echo "In a cluster you can also run: kubectl apply --dry-run=client -f k8s/"

console: ## Open a Rails console
	$(COMPOSE) run --rm api ./bin/rails console

logs: ## Tail logs for all services, or pass SERVICES="api worker"
	$(COMPOSE) logs -f $(SERVICES)

ps: ## Show running containers
	$(COMPOSE) ps
