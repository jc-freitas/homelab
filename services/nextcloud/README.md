# Nextcloud

Collectives provides collaborative notes and nested pages. Deck provides shared
kanban boards. Each person uses their own Nextcloud account.

## Apps

```sh
docker exec -u www-data nextcloud-app-1 php occ app:install collectives
docker exec -u www-data nextcloud-app-1 php occ app:install deck
```

Share a collective through its Nextcloud Team. Share the corresponding Deck
board separately and grant collaborators edit access.

## Background jobs

Install the included systemd units on the server:

```sh
install -m 644 nextcloud-cron.service nextcloud-cron.timer /etc/systemd/system/
docker exec -u www-data nextcloud-app-1 php occ background:cron
systemctl daemon-reload
systemctl enable --now nextcloud-cron.timer
```

The timer runs every five minutes. Check execution with:

```sh
systemctl list-timers nextcloud-cron.timer
journalctl -u nextcloud-cron.service
```

## Configuration

- `REDIS_HOST` selects the Redis service for distributed cache and file locking.
- `TRUSTED_PROXIES` lists the reverse proxy addresses.
- `overwrite.cli.url` must use the public HTTPS address for emailed links.
- System SMTP is configured independently of accounts in Nextcloud Mail.
- CPU shares are relative scheduling weights, not reserved CPU or hard limits.

## Backups

Back up the database, `config.php`, user files and appdata together. Collectives
stores note content in appdata; a database dump alone does not include it.
SMTP credentials in `config.php` belong in encrypted backups, outside Git.

References: [Collectives](https://github.com/nextcloud/collectives),
[Deck](https://github.com/nextcloud/deck).
