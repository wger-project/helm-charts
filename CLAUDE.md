# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Helm chart for deploying [wger](https://wger.readthedocs.io) (a Django-based workout/nutrition manager) on Kubernetes. The single chart lives in `charts/wger/`. There is no application source code here — only the chart, its templates, and CI.

## Commands

All commands run from `charts/wger/` unless noted.

```bash
# Pull subchart dependencies (postgres, redis) — required before lint/install
helm dependency update

# Render templates locally without a cluster (fastest feedback loop)
helm template wger . -f ../../example/prod_values.yaml
helm template wger . --set celery.enabled=true   # render with a flag toggled

# Lint as CI does (chart-testing). Compares against the target branch.
ct lint --target-branch master

# Install / upgrade against a live cluster
helm upgrade --install wger . -n wger --create-namespace -f ../../example/prod_values.yaml
```

`DEVEL.md` documents a full rootless minikube (podman + calico) dev environment, including UID/GID subuid mapping and how to port-forward the app pod's container port `8080` (not the service port) to reach the web UI.

## CI / release

- `.github/workflows/lint-test.yml` runs `ct lint` on PRs/pushes to `master`. The `ct install` step is **intentionally disabled** because the kind cluster can't provide `ReadWriteMany` storage, which celery requires.
- `.github/workflows/chart-release.yml` runs `chart-releaser` on push to `master` and `dev`. It only packages a version not already released (`CR_SKIP_EXISTING: true`) and does **not** mark releases as latest. Bump `version` in `Chart.yaml` to cut a release.

## Architecture

The chart renders **five separate Deployments** (one `templates/deployment-<component>.yaml` file each; celery and celery-worker share `deployment-celery.yaml`), each named `{{ .Release.Name }}-<component>`:

- **`-app`** (`deployment-wger.yaml`) — the wger Django server (gunicorn). Has a busybox initContainer (`initContainer.pgonly.command`) that blocks until postgres and redis are reachable.
- **`-nginx`** — reverse proxy serving Django's media/static files; gated on production setups needing persistent storage.
- **`-powersync`** — `journeyapps/powersync-service` for the mobile app's offline sync. Connects to the same postgres DB via a dedicated `powersync` DB user. Its storage schema is initialized by a **post-install hook Job** (`templates/hooks/setup-powersync-storage.yaml`) that waits for postgres/redis/nginx, then `kubectl exec`s `./manage.py setup-powersync-storage` in the running app pod. This requires the django DB user to be a superuser, granted via the `wger-pg-init` ConfigMap (`configmap-postgres.yaml`) mounted as a postgres init script.
- **`-celery`** — celery-beat scheduler + optional celery-flower web UI. Only meaningful when `celery.enabled=true`.
- **`-celery-worker`** — celery task workers. Its initContainer (`initContainer.web.command`) additionally waits for the nginx service.

Subcharts: **postgres** and **redis** come from the [groundhog2k](https://groundhog2k.github.io/helm-charts) repo (pinned in `Chart.yaml` / `Chart.lock`, conditioned on `postgres.enabled` / `redis.enabled`).

### Environment variable composition (`_helpers.tpl`)

This is the heart of the chart and where most behavior lives. Key named templates:

- **`wger.env.default`** — builds the full default env list (email, cache/redis, django, axes brute-force protection, JWT, gunicorn tuning, exercise sync). Celery-related vars are only emitted when `celery.enabled`.
- **`wger.env`** — merges `wger.env.default` with user-supplied `app.environment` entries, letting users **override any default var by name** (custom entries with a matching name replace the default). Use this, not the raw default, when adding env to containers.
- **`database.settings`** — emits `DJANGO_DB_*` env. Branches three ways: in-cluster postgres (reads the groundhog2k-created `{Release}-postgres` secret), an `existingDatabase` with inline credentials, or an `existingDatabase.existingSecret` (keys default to `USERDB_USER` / `USERDB_PASSWORD` / `USERDB_NAME`).
- **`powersync.settings`** — builds the powersync DB URIs by referencing both the `powersync` and django DB secrets; relies on `$(VAR)` shell-style interpolation across env entries.

When changing app configuration, prefer editing the `wger.env.default` template over hardcoding env in the Deployment.

### Secret & JWT key handling

Secrets are created via Helm templates annotated as `pre-install,pre-upgrade,pre-rollback` hooks (`secret-*.yaml`). The recurring **generate-or-preserve password pattern**: if a password value is set in `values.yaml`, use it; otherwise on upgrade `lookup` the existing secret and reuse its value, and only `randAlphaNum` a fresh one on first install. Follow this pattern (see `secret-powersync.yaml`, `secret-redis.yaml`) for any new generated credential.

JWT keys are special: `templates/hooks/jwt-keygen.yaml` runs a **pre-install/upgrade Job** that uses `jose` + `kubectl apply` to generate RS256 JWK keys and write the `jwt` secret. The `manipulatejwt` / `manipulatemail` helpers in `_helpers.tpl` decide (returning the string `"doit"`) whether a secret should be (re)generated based on existence and the `*.secret.update` flag.

### RBAC for hook Jobs

`serviceaccount.yaml`, `role.yaml`, and `rolebinding.yaml` (all pre-install/upgrade/rollback hooks) define **two ServiceAccounts** for the hook Jobs:

- `{{ .Release.Name }}-keygen` → bound to `{{ .Release.Name }}-secret-role` (create/patch/update/get on secrets) — used by the JWT keygen Job.
- `{{ .Release.Name }}-powersync-initdb` → bound to `{{ .Release.Name }}-pod-exec-role` (get/list on pods, create on `pods/exec`) — used by the powersync storage-setup Job.

## Conventions

- Resource names are always `{{ .Release.Name }}-<suffix>`; in-cluster service DNS is referenced the same way (e.g. `{{ .Release.Name }}-postgres`, `{{ .Release.Name }}-redis`, `{{ .Release.Name }}-http` for nginx).
- `app.global.image.tag` defaults to `.Chart.AppVersion` when empty — bump `appVersion` in `Chart.yaml` to track a new wger release.
- The full parameter reference lives in `charts/wger/README.md` (a generated table). Keep it in sync when adding or renaming values.
