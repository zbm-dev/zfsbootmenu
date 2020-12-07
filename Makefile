.PHONY: install default

default:

install:
	install -m 0644 -t $(DESTDIR)/etc/zfsbootmenu/ -D etc/zfsbootmenu/config.yaml
	install -m 0644 -t $(DESTDIR)/etc/zfsbootmenu/dracut.conf.d/ -D etc/zfsbootmenu/dracut.conf.d/*
	install -m 0755 -t $(DESTDIR)/usr/lib/dracut/modules.d/90zfsbootmenu -D 90zfsbootmenu/*
	install -m 0755 -t $(DESTDIR)$(PREFIX)/bin/ -D bin/generate-zbm
	install -m 0644 -t $(DESTDIR)/usr/share/man/man5/ -D man/generate-zbm.5
	install -m 0644 -t $(DESTDIR)/usr/share/man/man7/ -D man/zfsbootmenu.7
	install -m 0644 -t $(DESTDIR)/usr/share/man/man8/ -D man/generate-zbm.8
	install -m 0755 -t $(DESTDIR)/usr/share/examples/zfsbootmenu/ -D contrib/xhci-teardown.sh
