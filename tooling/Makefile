# Language-agnostic project commands
# Detects Python (uv), Maven, Gradle, or Node from project files
# Override any command: make test TEST_CMD="pytest -x"
# Run `make` or `make help` to list targets

SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help
MAKEFLAGS += --no-builtin-rules --no-print-directory

PROJECT := $(notdir $(CURDIR))
IMAGE ?= $(PROJECT):dev
COMPOSE ?= docker compose
SERVICE ?= app
SH_FILES := $(shell git ls-files '*.sh' '*.bash' '*.sbatch' 2>/dev/null)
VERSION := $(shell git describe --tags --always --dirty 2>/dev/null || echo unknown)

# Toolchain detection, first match wins
ifneq ($(wildcard pyproject.toml),)
  STACK := python
  TOOLS := uv
  SETUP_CMD ?= uv sync --all-groups
  LINT_CMD ?= uv run ruff check . && uv run ruff format --check .
  FORMAT_CMD ?= uv run ruff check --fix . && uv run ruff format .
  TYPECHECK_CMD ?= uv run mypy src
  TEST_CMD ?= uv run pytest
  COVERAGE_CMD ?= uv run pytest --cov --cov-report=term-missing --cov-report=html
  BUILD_CMD ?= uv build
  RUN_CMD ?= uv run $(PROJECT)
  UPDATE_CMD ?= uv lock --upgrade && uv sync --all-groups
  OUTDATED_CMD ?= uv tree --outdated --depth 1
  AUDIT_CMD ?= uvx pip-audit==2.9.0
  SHELL_CMD ?= uv run python
else ifneq ($(wildcard pom.xml),)
  STACK := maven
  MVN := $(if $(wildcard mvnw),./mvnw,mvn)
  TOOLS := java $(MVN)
  SETUP_CMD ?= $(MVN) -q dependency:resolve
  LINT_CMD ?= $(MVN) -q -DskipTests verify
  FORMAT_CMD ?= $(MVN) spotless:apply
  TEST_CMD ?= $(MVN) test
  COVERAGE_CMD ?= $(MVN) verify jacoco:report
  BUILD_CMD ?= $(MVN) -DskipTests package
  RUN_CMD ?= java -jar target/*.jar
  OUTDATED_CMD ?= $(MVN) -q versions:display-dependency-updates
  AUDIT_CMD ?= $(MVN) org.owasp:dependency-check-maven:check
  SHELL_CMD ?= jshell
else ifneq ($(wildcard build.gradle build.gradle.kts),)
  STACK := gradle
  GRADLE := $(if $(wildcard gradlew),./gradlew,gradle)
  TOOLS := java $(GRADLE)
  SETUP_CMD ?= $(GRADLE) dependencies --quiet
  LINT_CMD ?= $(GRADLE) check -x test
  FORMAT_CMD ?= $(GRADLE) spotlessApply
  TEST_CMD ?= $(GRADLE) test
  COVERAGE_CMD ?= $(GRADLE) test jacocoTestReport
  BUILD_CMD ?= $(GRADLE) build -x test
  RUN_CMD ?= $(GRADLE) run
  UPDATE_CMD ?= $(GRADLE) dependencies --refresh-dependencies
  SHELL_CMD ?= jshell
else ifneq ($(wildcard package.json),)
  STACK := node
  TOOLS := node npm
  SETUP_CMD ?= npm ci
  LINT_CMD ?= npm run lint
  FORMAT_CMD ?= npm run format
  TYPECHECK_CMD ?= npx tsc --noEmit
  TEST_CMD ?= npm test
  COVERAGE_CMD ?= npm test -- --coverage
  BUILD_CMD ?= npm run build
  RUN_CMD ?= npm start
  UPDATE_CMD ?= npm update
  OUTDATED_CMD ?= npm outdated
  AUDIT_CMD ?= npm audit --audit-level=high
  SHELL_CMD ?= node
else
  STACK := none
endif

# Runs command variable, fails with hint when stack has none
run_or_hint = $(if $($(1)),$($(1)),{ echo "No $(1) for stack '$(STACK)', set $(1)=... or edit Makefile"; exit 1; })

.PHONY: help info doctor version setup lint format typecheck test coverage check \
	build run shell update outdated audit hooks todo clean distclean \
	docker-build docker-run docker-shell up down restart rebuild logs ps

##@ General

help: ## Show available targets
	@echo "Project: $(PROJECT)  Stack: $(STACK)  Version: $(VERSION)"
	@awk 'BEGIN {FS = ":.*## "} \
		/^##@/ {printf "\n\033[1m%s\033[0m\n", substr($$0, 5)} \
		/^[a-zA-Z_-]+:.*## / {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

info: ## Show detected commands
	@printf '%-10s %s\n' stack "$(STACK)" setup "$(SETUP_CMD)" lint "$(LINT_CMD)" \
		test "$(TEST_CMD)" build "$(BUILD_CMD)" run "$(RUN_CMD)" update "$(UPDATE_CMD)" audit "$(AUDIT_CMD)"

doctor: ## Check required tools are installed
	@missing=0; for t in git $(TOOLS) docker shellcheck; do \
		if command -v $$t >/dev/null 2>&1; then printf '  ok       %s\n' "$$t"; \
		else printf '  missing  %s\n' "$$t"; missing=1; fi; done; \
	[ $$missing -eq 0 ] || echo "Install missing tools before running setup"

version: ## Show version from git tags
	@echo $(VERSION)

##@ Development

setup: ## Install dependencies, git hooks, and .env
	@$(call run_or_hint,SETUP_CMD)
	@if [ -f .pre-commit-config.yaml ] && command -v uvx >/dev/null; then uvx pre-commit install; fi
	@if [ -f .env.example ] && [ ! -f .env ]; then cp .env.example .env && echo "Created .env from .env.example"; fi

run: ## Run application locally
	@$(call run_or_hint,RUN_CMD)

shell: ## Open language REPL with project dependencies
	@$(call run_or_hint,SHELL_CMD)

##@ Quality

lint: ## Check code without changes
	@$(call run_or_hint,LINT_CMD)
	@if [ -n "$(SH_FILES)" ]; then shellcheck $(SH_FILES); fi

format: ## Apply formatting and safe fixes
	@$(call run_or_hint,FORMAT_CMD)
	@if [ -n "$(SH_FILES)" ] && command -v shfmt >/dev/null; then shfmt -w -ci $(filter-out %.sbatch,$(SH_FILES)); fi

typecheck: ## Run static type checks
	@$(call run_or_hint,TYPECHECK_CMD)

test: ## Run tests
	@$(call run_or_hint,TEST_CMD)

coverage: ## Run tests with coverage report
	@$(call run_or_hint,COVERAGE_CMD)

check: lint test ## Run lint and tests

hooks: ## Run all pre-commit hooks on all files
	uvx pre-commit run --all-files

todo: ## List TODO, FIXME, and HACK comments
	@git grep --untracked -nwE 'TODO|FIXME|HACK' -- ':!Makefile' 2>/dev/null || echo "None found"

##@ Dependencies

update: ## Upgrade dependencies within allowed ranges
	@$(call run_or_hint,UPDATE_CMD)

outdated: ## List dependencies with newer versions
	@$(call run_or_hint,OUTDATED_CMD)

audit: ## Scan dependencies for known vulnerabilities
	@$(call run_or_hint,AUDIT_CMD)

##@ Build

build: ## Build package or artifact
	@$(call run_or_hint,BUILD_CMD)

clean: ## Remove caches and build output
	rm -rf .pytest_cache .ruff_cache .mypy_cache .coverage htmlcov reports dist build target .gradle coverage
	find . -type d -name __pycache__ -prune -exec rm -rf {} +

distclean: clean ## Remove caches plus installed dependencies
	rm -rf .venv node_modules

##@ Containers

docker-build: ## Build container image
	docker build -t $(IMAGE) --build-arg VERSION=$(VERSION) .

docker-run: ## Run container image with .env
	docker run --rm -it $(if $(wildcard .env),--env-file .env) -p 8000:8000 $(IMAGE)

docker-shell: ## Open shell in running compose service
	$(COMPOSE) exec $(SERVICE) sh

up: ## Start compose services and wait for health
	$(COMPOSE) up -d --wait

down: ## Stop compose services
	$(COMPOSE) down

restart: ## Restart compose services
	$(COMPOSE) restart

rebuild: ## Rebuild images and recreate compose services
	$(COMPOSE) up -d --build --force-recreate --wait

logs: ## Follow compose logs
	$(COMPOSE) logs -f --tail=100

ps: ## Show compose service status
	$(COMPOSE) ps
