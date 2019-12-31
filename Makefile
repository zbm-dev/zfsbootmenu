.PHONY: install zfsbootmenu

install: zfsbootmenu
	install -t $(DESTDIR)/etc/zfsbootmenu/ -D etc/zfsbootmenu/config.ini
	install -t $(DESTDIR)/etc/zfsbootmenu/dracut.conf.d/ -D etc/zfsbootmenu/dracut.conf.d/*
	install -m 0755 -t $(DESTDIR)/usr/lib/dracut/modules.d/90zfsbootmenu -D 90zfsbootmenu/*
	install -m 0755 -t $(DESTDIR)$(PREFIX)/bin/ -D bin/generate-zbm
