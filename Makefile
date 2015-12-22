bindir = $(DESTDIR)/usr/bin

install:
	install -m 0555 spotify_backup.rb $(bindir)/spotify-backup

uninstall:
	rm -f $(bindir)/spotify-backup
