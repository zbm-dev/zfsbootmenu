.PHONY: install zfsbootmenu

install: zfsbootmenu
	install -t $(DESTDIR)$(PREFIX)/etc/zfsbootmenu/ -D etc/zfsbootmenu/config.ini
	install -t $(DESTDIR)$(PREFIX)/etc/zfsbootmenu/dracut.conf.d/ -D etc/zfsbootmenu/dracut.conf.d/*
	install -m 0755 -t $(DESTDIR)$(PREFIX)/usr/lib/dracut/modules.d/90zfsbootmenu -D 90zfsbootmenu/*
	install -m 0755 bin/generate-zbm $(DESTDIR)$(PREFIX)/bin/generate-zbm
