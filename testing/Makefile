.DEFAULT_GOAL := help

SUDO          ?= sudo
INSTALLOPTS   ?= -Su

VOID_PKGS     = perl-boolean perl-Sort-Versions lsof yq-go qemu-firmware qemu-img qemu-system-amd64

.PHONY: help setup-void clean-void

help:
	@echo "Use \033[94mmake setup-void\033[m to install dependencies on Void Linux."
	@echo "Use \033[94mmake clean-void\033[m to remove dependencies on Void Linux."

setup-void:
	@$(SUDO) xbps-install $(INSTALLOPTS) $(VOID_PKGS)

clean-void:
	@$(SUDO) xbps-remove -R $(VOID_PKGS)
