DESTDIR=
PREFIX=/usr
CONFDIR=/etc/zfsbootmenu
MODDIR=$(PREFIX)/share
DRACUTDIR=$(PREFIX)/lib/dracut/modules.d
INITCPIODIR=$(PREFIX)/lib/initcpio
MANDIR=$(PREFIX)/share/man
BINDIR=$(PREFIX)/bin
EXAMPLES=$(PREFIX)/share/examples/zfsbootmenu

VERSION=$(shell grep 'our $$VERSION' bin/generate-zbm | \
	head -n 1 | sed -e "s/.*=[[:space:]]*'//" -e "s/'.*//" )

.PHONY: install core dracut initcpio zbm-release show-version

install: core dracut initcpio zbm-release

core:
	./install-tree.sh zfsbootmenu "$(DESTDIR)/$(MODDIR)/zfsbootmenu"
	install -m 0644 -t "$(DESTDIR)/$(CONFDIR)" -D etc/zfsbootmenu/config.yaml
	install -m 0755 -t "$(DESTDIR)/$(BINDIR)" -D bin/*
	install -m 0644 -t "$(DESTDIR)/$(MANDIR)/man5" -D docs/man/dist/man5/*.5
	install -m 0644 -t "$(DESTDIR)/$(MANDIR)/man7" -D docs/man/dist/man7/*.7
	install -m 0644 -t "$(DESTDIR)/$(MANDIR)/man8" -D docs/man/dist/man8/*.8
	install -m 0755 -t "$(DESTDIR)/$(EXAMPLES)/hooks" -D contrib/*
	install -m 0755 -t "$(DESTDIR)/$(EXAMPLES)" -D examples/*

dracut:
	./install-tree.sh dracut "$(DESTDIR)/$(DRACUTDIR)/90zfsbootmenu"
	install -m 0644 -t \
		"$(DESTDIR)/$(CONFDIR)/dracut.conf.d/" \
		-D etc/zfsbootmenu/dracut.conf.d/*

initcpio:
	./install-tree.sh initcpio "$(DESTDIR)/$(INITCPIODIR)"
	install -m 0644 -t "$(DESTDIR)/$(CONFDIR)" -D etc/zfsbootmenu/mkinitcpio.conf

zbm-release:
	[ -n "$(VERSION)" ] && sed -e 's/@@VERSION@@/$(VERSION)/' \
		zfsbootmenu/zbm-release > "$(DESTDIR)/$(MODDIR)/zfsbootmenu/zbm-release"

show-version:
	@echo $(VERSION)
