# Copies dev-toolkit templates into current directory, never overwrites files
# Download: curl -fsSLO https://raw.githubusercontent.com/jonserr/dev-toolkit/main/toolkit.mk
# Copy:     make -f toolkit.mk backend
# Repo:     make -f toolkit.mk init-private my-repo
# Both:     make -f toolkit.mk backend init-public my-repo
# Every target also copies base files and agent templates

SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help

ARCHIVE_URL := https://github.com/jonserr/dev-toolkit/archive/refs/heads/main.tar.gz
# Local toolkit folder for testing, empty downloads from GitHub
TOOLKIT_DIR ?=

# Stack targets expand to several profiles
stack_backend := python containers docs
stack_frontend := node containers docs
stack_fullstack := python node containers docs
stack_hpc := python bash slurm docs

STACKS := backend frontend fullstack hpc
LANGS := base python java node bash docker slurm docs all
TARGETS := $(STACKS) $(LANGS)
INIT_TARGETS := init-private init-public

GOALS := $(filter $(TARGETS),$(MAKECMDGOALS))
INIT := $(filter $(INIT_TARGETS),$(MAKECMDGOALS))
# Any other word after init-* is repo name, default is folder name
REPO_NAME := $(firstword $(filter-out $(TARGETS) $(INIT_TARGETS),$(MAKECMDGOALS)))
# Stack names expand, docker maps to containers, base adds nothing extra
PROFILES := $(sort $(foreach g,$(filter-out base,$(GOALS)),$(or $(stack_$(g)),$(patsubst docker,containers,$(g)))))

ifeq ($(words $(INIT)),2)
  $(error Use init-private or init-public, not both)
endif

# Gets toolkit from local folder or GitHub archive into $src, temp folder removed on exit
FETCH = tmp="$$(mktemp -d)"; trap 'rm -rf "$$tmp"' EXIT; \
	if [ -n "$(TOOLKIT_DIR)" ]; then src="$(TOOLKIT_DIR)"; else \
		echo "Downloading $(ARCHIVE_URL)"; \
		curl -fsSL "$(ARCHIVE_URL)" -o "$$tmp/toolkit.tar.gz" || { echo "Download failed, check repo is public and pushed"; exit 1; }; \
		tar -xzf "$$tmp/toolkit.tar.gz" -C "$$tmp" --strip-components=1; src="$$tmp"; fi; \
	[ -f "$$src/tooling/new-project.sh" ] || { echo "Toolkit not found in $$src"; exit 1; }

COPY = $(FETCH); bash "$$src/tooling/new-project.sh" . base agents $(PROFILES)

# git init, copy templates, commit, create GitHub repo with gh, push
CREATE_REPO = $(FETCH); bash "$$src/tooling/setup-gh.sh" --toolkit "$$src" --commit --create --push \
	$(if $(REPO_NAME),--name "$(REPO_NAME)") $(if $(filter init-public,$(INIT)),--public) $(PROFILES)

.PHONY: help $(TARGETS) $(INIT_TARGETS)

help:
	@echo "Usage: make -f toolkit.mk <target> [<target> ...]"
	@echo
	@echo "Stacks:"
	@echo "  backend    Python API + Docker + docs"
	@echo "  frontend   Node/TypeScript app + Docker + docs"
	@echo "  fullstack  backend + frontend"
	@echo "  hpc        Python + Bash + SLURM + docs"
	@echo
	@echo "Single tools:"
	@echo "  base       editorconfig, gitignore, env, Makefile, CI security, agents, SDD"
	@echo "  python     pyproject, requirements, uv setup, logging, Ruff, Python CI"
	@echo "  java       logback.xml, Java CI"
	@echo "  node       Prettier, Node CI"
	@echo "  bash       logging.sh, benchmark.sh, ShellCheck CI"
	@echo "  docker     Dockerfile, compose, devcontainer, Docker CI"
	@echo "  slurm      SLURM job templates, Apptainer"
	@echo "  docs       README, CHANGELOG, RUNBOOK"
	@echo "  all        everything"
	@echo
	@echo "GitHub repo (needs gh auth login):"
	@echo "  init-private [name]   git init, copy templates, commit, create private repo, push"
	@echo "  init-public [name]    same as init-private, public repo"
	@echo "  name defaults to current folder name, add a stack to include it"
	@echo
	@echo "Every target includes base"

# First requested target copies everything, init-* does copy itself when present
$(TARGETS):
	@$(if $(INIT),:,$(if $(filter $@,$(firstword $(GOALS))),$(COPY),:))

$(INIT_TARGETS):
	@$(CREATE_REPO)

# Repo name is a goal word, this rule makes it a no-op
ifneq ($(and $(INIT),$(REPO_NAME)),)
$(REPO_NAME):
	@:
endif
