.DEFAULT_GOAL := help

SPHINXOPTS    ?=
WATCHEXEC     ?= watchexec
VENV          ?= env
PIP_FLAGS     ?= -q
SERVEOPTS     ?=
SUDO          ?= sudo
INSTALLOPTS   ?= -Su
SOURCEDIR     = .
BUILDDIR      = _build

VOID_PKGS     = python3-rst2ansi watchexec

# Use the virtual environment if it exists
ifneq ("$(wildcard $(VENV)/bin/sphinx-build)","")
	SPHINXBUILD ?= $(VENV)/bin/sphinx-build
	PYTHON ?= $(VENV)/bin/python3
else
	SPHINXBUILD ?= sphinx-build
	PYTHON ?= python3
endif

.PHONY: help setup serve watch envclean requirements.txt Makefile setup-void gen-man

help:
	@echo "Use \033[94mmake setup\033[m to set up a virtual environment."
	@echo "Use \033[94mmake setup-void\033[m to install dependencies on Void Linux."
	@echo "Use \033[94mmake serve\033[m to run a simple HTTP server for viewing the html docs."
	@echo "Use \033[94mmake watch\033[m to run 'make serve' but reload when changes are detected."
	@echo "Use \033[94mmake envclean\033[m to remove the virtual environment."
ifneq ("$(wildcard $(VENV))","")
	@echo
	@$(SPHINXBUILD) -M $@ "$(SOURCEDIR)" "$(BUILDDIR)" $(SPHINXOPTS)
endif

gen-man: man
	@rm -rf $(SOURCEDIR)/man/dist
	@cp -r $(BUILDDIR)/man $(SOURCEDIR)/man/dist

setup-void:
	@$(SUDO) xbps-install $(INSTALLOPTS) $(VOID_PKGS)
	@$(MAKE) $(MAKEFLAGS) setup

setup: $(VENV)/req_done

serve: html
	@$(PYTHON) -m http.server -d "$(BUILDDIR)/html" $(SERVEOPTS)

watch:
	@$(WATCHEXEC) --restart --workdir "$(SOURCEDIR)" --project-origin "$(SOURCEDIR)/.." -e rst,md,css,ico,svg,png,py -- make clean serve

envclean:
	@rm -rf $(VENV)

clean-void: envclean
	@$(SUDO) xbps-remove -R $(VOID_PKGS)

$(VENV)/success:
ifeq ("$(wildcard $(VENV))","")
	@echo "Creating the virtual environment at $(VENV)"
	@$(PYTHON) -m venv $(VENV)
endif
	# This must always be touched, or the wildcard rule will trigger
	@touch $(VENV)/success

$(VENV)/req_done: requirements.txt $(VENV)/success
	@echo "Installing dependencies from requirements.txt"
	@$(VENV)/bin/pip install $(PIP_FLAGS) -U pip wheel && \
		$(VENV)/bin/pip install $(PIP_FLAGS) -U -r requirements.txt
	@touch $(VENV)/req_done

# Man-page generation fails unless HTML documentation is built first
man:: html

%:: Makefile
	@$(SPHINXBUILD) -M $@ "$(SOURCEDIR)" "$(BUILDDIR)" $(SPHINXOPTS)
