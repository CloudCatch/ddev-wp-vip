# WordPress VIP skeleton + DDEV local

Repeatable local development for [WordPress VIP Go](https://docs.wpvip.com/wordpress-skeleton/) repos using [DDEV](https://ddev.com/). Matches hosted VIP layout: repo-root `plugins/`, `themes/`, `client-mu-plugins/`, `vip-config/`, etc., with WordPress core in `wordpress/` and platform code in `mu-plugins/` (cloned, not committed).

Repository: https://github.com/CloudCatch/ddev-wp-vip.git

## Prerequisites

- [DDEV](https://ddev.com/get-started/) (v1.24+)
- Git
- Docker running

## Spin up a new site (from this template)

```bash
# Option A: clone and bootstrap in one go
git clone https://github.com/CloudCatch/ddev-wp-vip.git my-new-site
cd my-new-site
chmod +x bin/*.sh
./bin/bootstrap.sh my-new-site

# Option B: copy an existing checkout, then bootstrap (name defaults to folder name)
cp -R ddev-wp-vip my-other-site
cd my-other-site
rm -rf .git   # if copying an existing checkout
git init
./bin/bootstrap.sh
```

`bootstrap.sh` will:

1. Set the DDEV project name (and a unique `FILES_CLIENT_SITE_ID` for VIP Search)
2. Clone [VIP platform mu-plugins](https://github.com/Automattic/vip-go-mu-plugins-built) into `mu-plugins/`
3. Install DDEV memcached + elasticsearch add-ons (if missing)
4. Copy `config/wp-config.php.sample` → `wordpress/wp-config.php` and `config/wp-config-ddev.php` → `wordpress/wp-config-ddev.php`
5. Run `ddev start` and install WordPress core

Default admin: **vipgo / password** at `https://<project>.ddev.site/wp-admin/`

## Day-to-day commands

```bash
ddev start
ddev wp plugin list
ddev wp vip-search index --setup --skip-confirm   # optional, first time
ddev stop
```

## Update VIP platform mu-plugins

Platform code in `mu-plugins/` is cloned from [vip-go-mu-plugins-built](https://github.com/Automattic/vip-go-mu-plugins-built) and gitignored. To pull the latest:

```bash
ddev vip-mu-plugins-update
# alias: ddev vip-mu-plugins
```

Or without DDEV running:

```bash
./bin/update-vip-mu-plugins.sh
```

Override the source repo with `VIP_MU_PLUGINS_REPO` (same as `bin/vip-setup.sh`). Local changes in `mu-plugins/` are discarded on update.

## Sync database from VIP Platform

Pull a database backup from a VIP Platform environment into local DDEV. This uses [`vip export sql`](https://docs.wpvip.com/vip-cli/commands/export/sql/) + `ddev import-db` (not `vip dev-env sync sql`, which targets VIP Local Dev Environment / Landono — see [VIP database sync docs](https://docs.wpvip.com/vip-local-development-environment/add-database-content/)).

**Prerequisites**

- [VIP-CLI](https://docs.wpvip.com/vip-cli/) installed and authenticated (`npm install -g @automattic/vip`, then `vip`)
- Org admin or App admin role for the source VIP application/environment
- DDEV project running (`ddev start`)

**One-time setup**

```bash
./bin/configure-vip-sync.sh
# or: cp config/vip-sync.yaml.example config/vip-sync.yaml  (then edit)
```

`config/vip-sync.yaml` is gitignored and stores:

- `app` — VIP application slug (e.g. `example-app`)
- `env` — `develop`, `staging`, or `production`
- `remote_url` — hosted site URL to search-replace (local URL is derived from DDEV)

**Sync**

```bash
ddev vip-db-sync
# alias: ddev vip-sync-db
```

The command shows a summary and asks for confirmation before overwriting the local database. Flags:

```bash
ddev vip-db-sync --yes              # skip confirmation
ddev vip-db-sync --generate-backup  # fresh VIP backup before export
ddev vip-db-sync --dry-run          # preview only
```

After sync, optionally reindex Enterprise Search:

```bash
ddev wp vip-search index --setup --skip-confirm
```

**Notes**

- Exports are saved under `private/vip-sync/` (gitignored).
- The imported database keeps VIP/production users; the local `vipgo` user only exists after a fresh `./bin/install-wordpress.sh` install.

## Repo layout (VIP skeleton)

| Path | In git? | Purpose |
|------|---------|---------|
| `.ddev/` | yes | DDEV + VIP bind mounts, add-ons, hooks |
| `bin/` | yes | Bootstrap and setup scripts |
| `config/` | yes | `wp-config` sample, VIP sync config example, elasticsearch + vip-config snippets |
| `client-mu-plugins/` | yes | Your always-on MU plugins |
| `vip-config/` | yes | Environment constants (like hosted VIP) |
| `plugins/`, `themes/` | placeholder only | Empty except `index.php`; add your code locally |
| `images/`, `private/` | yes | Static assets / non-web files (empty placeholders) |
| `mu-plugins/` | **no** | VIP platform ( `./bin/vip-setup.sh` ) |
| `wordpress/` | **no** | WP core ( `./bin/install-wordpress.sh` ) |

DDEV bind-mounts the skeleton dirs into `wordpress/wp-content/` via `.ddev/docker-compose.vip.yaml` — same idea as `vip dev-env`.

## Scripts

| Script | When to use |
|--------|-------------|
| `./bin/bootstrap.sh [name]` | Fresh clone: configure, start, install everything |
| `./bin/configure-project.sh [name]` | Rename DDEV project only (updates `config.yaml` + site ID) |
| `./bin/vip-setup.sh` | Clone mu-plugins, DDEV add-ons, wp-config (idempotent) |
| `./bin/update-vip-mu-plugins.sh` or `ddev vip-mu-plugins-update` | Pull latest VIP platform mu-plugins |
| `./bin/configure-vip-sync.sh` | Create `config/vip-sync.yaml` for DB sync |
| `./bin/sync-vip-db.sh` or `ddev vip-db-sync` | Export VIP Platform DB and import into DDEV |
| `./bin/install-wordpress.sh` | Download WP core + run install (requires `ddev start`) |

## Overlay onto an existing VIP skeleton

If you already have a VIP application repo, copy only the **local env** pieces:

| Copy from this repo | Into your repo |
|---------------------|----------------|
| `.ddev/config.vip.yaml` | `.ddev/config.vip.yaml` |
| `.ddev/docker-compose.vip.yaml` | `.ddev/docker-compose.vip.yaml` |
| `.ddev/vip-post-start.sh` | `.ddev/vip-post-start.sh` |
| `.ddev/docker-compose.memcached.yaml` + `addon-metadata/memcached/` | same |
| `.ddev/docker-compose.elasticsearch.yaml` + `addon-metadata/elasticsearch/` + `elasticsearch/` | same |
| `bin/*.sh` | `bin/` |
| `config/*` | `config/` |
| `wp-cli.yml` | root |
| `.gitignore` entries for `/mu-plugins/` and `/wordpress/` | merge into yours |

Then set `docroot: wordpress` in `.ddev/config.yaml`, merge `config/vip-config.local.php.example` into your `vip-config/vip-config.php`, copy `config/ddev-elasticsearch.php` → `client-mu-plugins/ddev-elasticsearch.php`, and run `./bin/vip-setup.sh`.

## Services

| Service | Endpoint |
|---------|----------|
| Web | `https://<project>.ddev.site` |
| Memcached | `memcached:11211` |
| Elasticsearch | `https://<project>.ddev.site:9201` |

Object cache uses hosted VIP wiring: `php-memcached` → `mu-plugins/drop-ins/object-cache.php`.

## GitHub template

https://github.com/CloudCatch/ddev-wp-vip

Mark this repository as a **Template repository** in GitHub settings, then use **Use this template** to create new projects with the same DDEV + VIP layout.
