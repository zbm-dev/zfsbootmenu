.DEFAULT_GOAL := help

SPHINXOPTS    ?=
SPHINXBUILD   ?= sphinx-build
PYTHON        ?= python3
VENV          ?= env
PIP_FLAGS     ?= -q
SERVEOPTS     ?=
SUDO          ?= sudo
INSTALLOPTS   ?= -Su
SOURCEDIR     = .
BUILDDIR      = _build

VOID_PKGS     = python3-rst2ansi python3-sphinx-tabs python3-sphinx_rtd_theme python3-recommonmark

.PHONY: help setup serve envclean requirements.txt Makefile setup-void gen-man

help:
	@echo "Use \033[94mmake setup\033[m to set up a virtual environment."
	@echo "Use \033[94mmake setup-void\033[m to install dependencies on Void Linux."
	@echo "Use \033[94mmake serve\033[m to run a simple HTTP server for viewing the html docs."
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

setup: $(VENV)/req_done

serve: html
	@$(PYTHON) -m http.server -d "$(BUILDDIR)/html" $(SERVEOPTS)

envclean:
	@rm -rf $(VENV)

clean-void:
	@$(SUDO) xbps-remove -R $(VOID_PKGS)

$(VENV)/success:
ifeq ("$(wildcard $(VENV))","")
	@echo "Creating the virtual environment at $(VENV)"
	@$(PYTHON) -m venv $(VENV)
	@touch $(VENV)/success
endif

$(VENV)/req_done: requirements.txt $(VENV)/success
	@echo "Installing dependencies from requirements.txt"
	@. $(VENV)/bin/activate && \
		pip install $(PIP_FLAGS) -U pip wheel && \
		pip install $(PIP_FLAGS) -U -r requirements.txt
	@touch $(VENV)/req_done

%:: Makefile
	@$(SPHINXBUILD) -M $@ "$(SOURCEDIR)" "$(BUILDDIR)" $(SPHINXOPTS)
