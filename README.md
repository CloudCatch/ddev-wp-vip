# WordPress VIP skeleton + DDEV local

Repeatable local development for [WordPress VIP Go](https://docs.wpvip.com/wordpress-skeleton/) repos using [DDEV](https://ddev.com/). Matches hosted VIP layout: repo-root `plugins/`, `themes/`, `client-mu-plugins/`, `vip-config/`, etc., with WordPress core in `wordpress/` and platform code in `mu-plugins/` (cloned, not committed).

Repository: https://github.com/CloudCatch/ddev-wp-vip.git

## Prerequisites

- [DDEV](https://ddev.com/get-started/) (v1.24+)
- Git
- Docker running

## Quick start (recommended)

One-liner — run from anywhere (clones the template, then asks a few questions):

```bash
curl -fsSL https://raw.githubusercontent.com/CloudCatch/ddev-wp-vip/main/bin/new-project.sh | bash
```

Or from an existing template clone:

```bash
git clone https://github.com/CloudCatch/ddev-wp-vip.git my-new-site
cd my-new-site
chmod +x bin/*.sh
./bin/new-project.sh
```

The wizard asks for:

- Project directory and DDEV site name
- VIP app source: **clone git URL**, **existing local path**, or **empty skeleton**
- VIP application slug + environment (auto-detected from `config/.vip.*.yml` when present)
- Database: **sync from VIP** or **fresh WordPress install**

Then it runs everything: integrate DDEV tooling, `vip-setup`, `ddev start`, database sync/install, and media proxy.

Running `./bin/bootstrap.sh` with no arguments also launches the wizard.

### Manual / advanced

<details>
<summary>Step-by-step (integrate, bootstrap, sync)</summary>

#### Greenfield (empty skeleton)

```bash
git clone https://github.com/CloudCatch/ddev-wp-vip.git my-new-site
cd my-new-site
chmod +x bin/*.sh
./bin/bootstrap.sh my-new-site
```

#### Existing VIP application repo (e.g. wpcomvip/compliancetrainingpartners-com)

```bash
git clone git@github.com:wpcomvip/compliancetrainingpartners-com.git ctp-local
git clone https://github.com/CloudCatch/ddev-wp-vip.git /tmp/ddev-wp-vip
/tmp/ddev-wp-vip/bin/integrate-vip-app.sh ~/path/to/ctp-local
cd ~/path/to/ctp-local
./bin/configure-project.sh ctp-local
./bin/vip-setup.sh && ddev start
ddev vip-db-sync
```

**vip-config:** `vip-config/vip-config.php` is never overwritten. DDEV settings live in `vip-config/vip-config-ddev.php`.

</details>

Default admin (fresh install only): **vipgo / password** at `https://<project>.ddev.site/wp-admin/`

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
# or: cp config/vip-sync.yaml.example config/vip-sync.yaml  (then edit app/env)
```

`config/vip-sync.yaml` is gitignored and stores only:

- `app` — VIP application slug (e.g. `example-app`)
- `env` — source environment to export (`develop`, `staging`, `production`)

**Search-replace (no manual site URL)**

URLs are not prompted or stored in `vip-sync.yaml`. The sync command resolves them automatically:

1. **Preferred:** [VIP data sync config](https://docs.wpvip.com/databases/data-sync/config-file/) at `config/.vip.<app>.<env>.yml` (same file VIP uses for production → non-production syncs). For non-production exports, domains in the exported DB are typically the `domain_map` *values*; for `production`, the *keys*. Order in the file is preserved (important for overlapping domains).
2. **Fallback:** VIP-CLI queries `wp option get siteurl/home` and `wp site list` on `@app.env`.

Add or copy a data sync config for your app (see [`config/.vip.example.develop.yml.example`](config/.vip.example.develop.yml.example)):

```bash
cp config/.vip.example.develop.yml.example config/.vip.my-app.develop.yml
# edit domain_map for your network
```

Local URL is always derived from DDEV (`https://<project>.ddev.site`).

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

## Proxy missing media to VIP

Like VIP dev-env [`--media-redirect-domain`](https://docs.wpvip.com/vip-local-development-environment/add-media-content/): local `/wp-content/uploads/` is checked first; missing files redirect to the VIP host (302).

Requires `config/vip-sync.yaml`. Domain resolution order:

1. `media_redirect_domain` in `config/vip-sync.yaml` (optional override)
2. VIP-CLI `siteurl` on `@app.production`
3. Primary domain from `config/.vip.<app>.<env>.yml` `domain_map`
4. VIP-CLI `siteurl` on `@app.<env>`

```bash
ddev vip-media-proxy-update   # alias: ddev vip-media-proxy
ddev restart                  # reload nginx
```

Runs automatically on `ddev start` (when `vip-sync.yaml` exists). Also runs at the end of `ddev vip-db-sync`.

Generated config: `.ddev/nginx/vip-media-proxy.conf` (gitignored).

**Limitation:** Same as VIP dev-env — does not work for multisite with Access-Controlled Files enabled.

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
| `./bin/new-project.sh` | **Interactive wizard** — recommended entry point |
| `./bin/bootstrap.sh [name]` | Non-interactive setup (no args = launches wizard) |
| `./bin/integrate-vip-app.sh [target]` | Add DDEV tooling to an existing VIP repo (or import app code with `--source`) |
| `./bin/configure-project.sh [name]` | Rename DDEV project only (updates `config.yaml` + site ID) |
| `./bin/vip-setup.sh` | Clone mu-plugins, DDEV add-ons, wp-config (idempotent) |
| `./bin/update-vip-mu-plugins.sh` or `ddev vip-mu-plugins-update` | Pull latest VIP platform mu-plugins |
| `./bin/configure-vip-sync.sh` | Create `config/vip-sync.yaml` for DB sync |
| `./bin/sync-vip-db.sh` or `ddev vip-db-sync` | Export VIP Platform DB and import into DDEV |
| `./bin/update-vip-media-proxy.sh` or `ddev vip-media-proxy-update` | Nginx redirect for missing uploads |
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
