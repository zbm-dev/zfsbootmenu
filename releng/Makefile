.DEFAULT_GOAL := help

SUDO          ?= sudo
INSTALLOPTS   ?= -Su

VOID_PKGS     = buildah podman git github-cli signify python3-rst2ansi

.PHONY: help setup-void clean-void

help:
	@echo "Use \033[94mmake setup-void\033[m to install dependencies on Void Linux."
	@echo "Use \033[94mmake clean-void\033[m to remove dependencies on Void Linux."

setup-void:
	@$(SUDO) xbps-install $(INSTALLOPTS) $(VOID_PKGS)

clean-void:
	@$(SUDO) xbps-remove -R $(VOID_PKGS)
