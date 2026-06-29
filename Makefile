# Bravo Fintech MVP — developer commands.
# All commands run inside Docker so a clean clone needs only Docker + Make.
.DEFAULT_GOAL := help
.PHONY: help up down build migrate seed test lint console logs ps

COMPOSE := docker compose

help: ## List available commands
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

up: ## Boot api + postgres + redis and wait until the api is healthy
	$(COMPOSE) up -d --build --wait

down: ## Stop and remove containers
	$(COMPOSE) down

build: ## Build the api image
	$(COMPOSE) build

migrate: ## Create/migrate the database (incl. PL/pgSQL triggers)
	$(COMPOSE) run --rm api ./bin/rails db:prepare

seed: ## Load seed data (users per role + sample applications)
	$(COMPOSE) run --rm api ./bin/rails db:seed

test: ## Run the full test suite
	$(COMPOSE) run --rm -e RAILS_ENV=test api bash -c "./bin/rails db:prepare && ./bin/rails test"

lint: ## Run static analysis (wired up in T002)
	@echo "lint: RuboCop + bundler-audit are wired in T002"

console: ## Open a Rails console
	$(COMPOSE) run --rm api ./bin/rails console

logs: ## Tail api logs
	$(COMPOSE) logs -f api

ps: ## Show running containers
	$(COMPOSE) ps
