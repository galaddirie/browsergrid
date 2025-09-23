# NOTE: On Windows, prefer WSL/git-bash. PowerShell may not work.

######################################################
# Defaults
######################################################
ENVIRONMENT ?= server
BROWSER ?= chrome
BROWSER_TYPES := chrome chromium

######################################################
# Compose files
######################################################
SERVER_FILES := -f docker/docker-compose.server.yml
BROWSER_FILES := -f docker/docker-compose.browser.yml
DEV_FILES := -f docker/docker-compose.dev.yml
 
######################################################
# docker compose command (v2 or legacy)
######################################################
DOCKER_COMPOSE_COMMAND = $(shell if docker compose version > /dev/null 2>&1; then echo "docker compose"; else echo "docker-compose"; fi)

######################################################
# Utilities
######################################################
check_browser = $(filter $(1),$(BROWSER_TYPES))

######################################################
# Environment targets
######################################################
.PHONY: server browser dev session help status

help:
	@echo "Browsergrid Makefile - Usage"
	@echo "======================================================="
	@echo "Environment targets:"
	@echo "  make server                 Set environment to server"
	@echo "  make dev                    Set environment to development"
	@echo "  make browser [BROWSER=chrome] Set environment to browser (supported: $(BROWSER_TYPES))"
	@echo ""
	@echo "Operation targets:"
	@echo "  make build                  Build containers"
	@echo "  make up                     Start containers"
	@echo "  make down                   Stop and remove containers"
	@echo "  make clean                  Remove containers and images"
	@echo "  make logs                   View logs"
	@echo "  make status                 Show status"
	@echo "  make restart|config|pull|stop  Server-only helpers"
	@echo ""
	@echo "Elixir/Phoenix commands (inside dev containers):"
	@echo "  make dev-iex                IEx shell"
	@echo "  make dev-shell              Bash in server container"
	@echo "  make dev-deps               mix deps.get"
	@echo "  make dev-migrate            mix ecto.migrate"
	@echo "  make dev-reset              mix ecto.reset"
	@echo "  make migrate-generate NAME=my_migration  mix ecto.gen.migration"
	@echo "  make migrate-rollback [STEPS=1]         mix ecto.rollback"
	@echo "  make migrate-status         mix ecto.migrations"
	@echo ""
	@echo "Testing:"
	@echo "  make test                   Run all tests in test runner"
	@echo "  make test path/to/file.exs  Run specific test file"
	@echo ""
	@echo "Current configuration:"
	@echo "  Environment: $(ENVIRONMENT)"
	@if [ "$(ENVIRONMENT)" = "browser" ]; then \
		echo "  Browser: $(BROWSER)"; \
	fi

status:
	@echo "Environment: $(ENVIRONMENT)"
	@if [ "$(ENVIRONMENT)" = "browser" ]; then \
		echo "Browser: $(BROWSER)"; \
	fi
	@echo ""
	@echo "Running containers:" 
	@if [ "$(ENVIRONMENT)" = "server" ] || [ "$(ENVIRONMENT)" = "browser" ] || [ "$(ENVIRONMENT)" = "dev" ]; then \
		$(DOCKER_COMPOSE_COMMAND) $(FILES) ps; \
	else \
		echo "Error: Unknown environment '$(ENVIRONMENT)'"; \
		exit 1; \
	fi

server:
	$(eval ENVIRONMENT := server)
	$(eval FILES := $(SERVER_FILES))
	@echo "Environment set to: server"

browser:
	@if [ -z "$(call check_browser,$(BROWSER))" ]; then \
		echo "Error: Invalid browser type '$(BROWSER)'"; \
		echo "Supported browsers: $(BROWSER_TYPES)"; \
		exit 1; \
	fi
	$(eval ENVIRONMENT := browser)
	$(eval FILES := $(BROWSER_FILES))
	@echo "Environment set to: browser ($(BROWSER))"

dev:
	$(eval ENVIRONMENT := dev)
	$(eval FILES := $(DEV_FILES))
	@echo "Environment set to: development"

session:
	@echo "Session environment has been replaced by browser environment. Use 'make browser'."

######################################################
# Operations
######################################################
.PHONY: build up down clean logs shell restart config pull stop

build:
	@if [ "$(ENVIRONMENT)" = "server" ]; then \
		echo "Building server containers..."; \
		$(DOCKER_COMPOSE_COMMAND) $(FILES) build; \
	elif [ "$(ENVIRONMENT)" = "dev" ]; then \
		echo "Building development containers..."; \
		$(DOCKER_COMPOSE_COMMAND) $(FILES) build; \
	elif [ "$(ENVIRONMENT)" = "browser" ]; then \
		echo "Building browser base..."; \
		BROWSER=$(BROWSER) $(DOCKER_COMPOSE_COMMAND) $(FILES) build base; \
		echo "Building $(BROWSER) image..."; \
		BROWSER=$(BROWSER) $(DOCKER_COMPOSE_COMMAND) $(FILES) build browser; \
	else \
		echo "Error: Unknown environment '$(ENVIRONMENT)'"; \
		exit 1; \
	fi

up:
	@if [ "$(ENVIRONMENT)" = "server" ]; then \
		echo "Starting server containers..."; \
		$(DOCKER_COMPOSE_COMMAND) $(FILES) up -d; \
	elif [ "$(ENVIRONMENT)" = "dev" ]; then \
		echo "Starting dev containers..."; \
		$(DOCKER_COMPOSE_COMMAND) $(FILES) up -d; \
	elif [ "$(ENVIRONMENT)" = "browser" ]; then \
		echo "Starting services with $(BROWSER)..."; \
		BROWSER=$(BROWSER) $(DOCKER_COMPOSE_COMMAND) $(FILES) up -d browser; \
	else \
		echo "Error: Unknown environment '$(ENVIRONMENT)'"; \
		exit 1; \
	fi

down:
	@if [ "$(ENVIRONMENT)" = "server" ] || [ "$(ENVIRONMENT)" = "browser" ] || [ "$(ENVIRONMENT)" = "dev" ]; then \
		echo "Stopping $(ENVIRONMENT) containers..."; \
		$(DOCKER_COMPOSE_COMMAND) $(FILES) down; \
	else \
		echo "Error: Unknown environment '$(ENVIRONMENT)'"; \
		exit 1; \
	fi

clean:
	@if [ "$(ENVIRONMENT)" = "server" ] || [ "$(ENVIRONMENT)" = "browser" ] || [ "$(ENVIRONMENT)" = "dev" ]; then \
		echo "Cleaning $(ENVIRONMENT) containers and images..."; \
		$(DOCKER_COMPOSE_COMMAND) $(FILES) down --rmi all; \
	else \
		echo "Error: Unknown environment '$(ENVIRONMENT)'"; \
		exit 1; \
	fi

logs:
	@if [ "$(ENVIRONMENT)" = "server" ] || [ "$(ENVIRONMENT)" = "dev" ]; then \
		$(DOCKER_COMPOSE_COMMAND) $(FILES) logs -f; \
	elif [ "$(ENVIRONMENT)" = "browser" ]; then \
		BROWSER=$(BROWSER) $(DOCKER_COMPOSE_COMMAND) $(FILES) logs -f browser; \
	else \
		echo "Error: Unknown environment '$(ENVIRONMENT)'"; \
		exit 1; \
	fi

shell:
	@if [ "$(ENVIRONMENT)" = "browser" ]; then \
		echo "Opening shell in $(BROWSER) container..."; \
		BROWSER=$(BROWSER) $(DOCKER_COMPOSE_COMMAND) $(FILES) exec browser /bin/bash; \
	elif [ "$(ENVIRONMENT)" = "server" ] || [ "$(ENVIRONMENT)" = "dev" ]; then \
		echo "Opening shell in server container..."; \
		$(DOCKER_COMPOSE_COMMAND) $(FILES) exec browsergrid bash; \
	else \
		echo "Error: Unknown environment '$(ENVIRONMENT)'"; \
		exit 1; \
	fi

restart:
	@if [ "$(ENVIRONMENT)" = "server" ]; then \
		$(DOCKER_COMPOSE_COMMAND) $(FILES) restart; \
	else \
		echo "Error: 'restart' is server-only"; \
		exit 1; \
	fi

config:
	@if [ "$(ENVIRONMENT)" = "server" ]; then \
		$(DOCKER_COMPOSE_COMMAND) $(FILES) config; \
	else \
		echo "Error: 'config' is server-only"; \
		exit 1; \
	fi

pull:
	@if [ "$(ENVIRONMENT)" = "server" ]; then \
		$(DOCKER_COMPOSE_COMMAND) $(FILES) pull; \
	else \
		echo "Error: 'pull' is server-only"; \
		exit 1; \
	fi

stop:
	@if [ "$(ENVIRONMENT)" = "server" ]; then \
		$(DOCKER_COMPOSE_COMMAND) $(FILES) stop; \
	else \
		echo "Error: 'stop' is server-only"; \
		exit 1; \
	fi

######################################################
# Elixir / Ecto helpers (dev env)
######################################################
.PHONY: dev-shell dev-iex dev-deps dev-migrate dev-reset migrate-generate migrate-rollback migrate-status

dev-shell:
	$(DOCKER_COMPOSE_COMMAND) $(DEV_FILES) exec browsergrid bash

dev-iex:
	$(DOCKER_COMPOSE_COMMAND) $(DEV_FILES) exec browsergrid iex -S mix

dev-deps:
	$(DOCKER_COMPOSE_COMMAND) $(DEV_FILES) exec browsergrid mix deps.get

dev-migrate:
	$(DOCKER_COMPOSE_COMMAND) $(DEV_FILES) exec browsergrid mix ecto.migrate

dev-reset:
	$(DOCKER_COMPOSE_COMMAND) $(DEV_FILES) exec browsergrid mix ecto.reset

migrate-generate:
	@if [ -z "$(NAME)" ]; then \
		echo "Error: Provide NAME=<migration_name>"; \
		exit 1; \
	fi; \
	$(DOCKER_COMPOSE_COMMAND) $(DEV_FILES) exec browsergrid mix ecto.gen.migration $(NAME)

migrate-rollback:
	$(DOCKER_COMPOSE_COMMAND) $(DEV_FILES) exec browsergrid mix ecto.rollback $(if $(STEPS),--step $(STEPS),)

migrate-status:
	$(DOCKER_COMPOSE_COMMAND) $(DEV_FILES) exec browsergrid mix ecto.migrations

######################################################
# Testing (preserve existing behavior)
######################################################
.PHONY: test dev-test

dev-test:
	$(DOCKER_COMPOSE_COMMAND) $(DEV_FILES) exec browsergrid mix test

test:
	$(DOCKER_COMPOSE_COMMAND) $(DEV_FILES) exec test_runner mix test $(if $(filter-out $@,$(MAKECMDGOALS)),$(filter-out $@,$(MAKECMDGOALS)),)

######################################################
# Cleanup
######################################################
.PHONY: clean clean-all

clean:
	docker system prune -f

clean-all:
	docker system prune -a -f

######################################################
# Defaults
######################################################
.DEFAULT_GOAL := help