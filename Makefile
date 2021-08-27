DESTDIR=
PREFIX=/usr
CONFDIR=/etc/zfsbootmenu
MODDIR=$(PREFIX)/lib/dracut/modules.d
MANDIR=$(PREFIX)/share/man
BINDIR=$(PREFIX)/bin
EXAMPLES=$(PREFIX)/share/examples/zfsbootmenu

.PHONY: install default

default:

install:
	# Recursively install non-executable parts of the Dracut module
	find 90zfsbootmenu -type f -not -perm /111 -exec \
		install -Dm 0644 "{}" "$(DESTDIR)$(MODDIR)/{}" \;
	# Executable parts of the module
	find 90zfsbootmenu -type f -perm /111 -exec \
		install -Dm 0755 "{}" "$(DESTDIR)$(MODDIR)/{}" \;
	install -m 0644 -t "$(DESTDIR)$(CONFDIR)" -D etc/zfsbootmenu/config.yaml
	install -m 0644 -t "$(DESTDIR)$(CONFDIR)/dracut.conf.d/" -D etc/zfsbootmenu/dracut.conf.d/*
	install -m 0755 -t "$(DESTDIR)$(BINDIR)" -D bin/generate-zbm
	install -m 0644 -t "$(DESTDIR)$(MANDIR)/man5" -D man/generate-zbm.5
	install -m 0644 -t "$(DESTDIR)$(MANDIR)/man7" -D man/zfsbootmenu.7
	install -m 0644 -t "$(DESTDIR)$(MANDIR)/man8" -D man/generate-zbm.8
	install -m 0755 -t "$(DESTDIR)$(EXAMPLES)" -D contrib/*
