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

# Golden-file template tests (run from the repo root). CI fails on any diff.
tests/golden-test.sh
tests/golden-test.sh --update   # after intentional changes; review git diff of tests/golden/

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
- **`-powersync`** — `journeyapps/powersync-service` for the mobile app's offline sync. Connects to the same postgres DB via a dedicated `powersync` DB user. Its storage schema is initialized by a **post-install hook Job** (`templates/hooks/setup-powersync-storage.yaml`) that runs `./manage.py setup-powersync-storage` in its own pod using the wger image and the same env as the app container (no RBAC needed); an initContainer waits for postgres/redis and the app service (endpoints appear only after migrations). This requires the django DB user to be a superuser, granted via the `wger-pg-init` ConfigMap (`configmap-postgres.yaml`) mounted as a postgres init script.
- **`-celery`** — celery-beat scheduler + optional celery-flower web UI. Only meaningful when `celery.enabled=true`.
- **`-celery-worker`** — celery task workers. Its initContainer (`initContainer.web.command`) additionally waits for the nginx service.

Subcharts: **postgres** and **redis** come from the [groundhog2k](https://groundhog2k.github.io/helm-charts) repo (pinned in `Chart.yaml` / `Chart.lock`, conditioned on `postgres.enabled` / `redis.enabled`).

### Environment variable composition (`_helpers.tpl`)

This is the heart of the chart and where most behavior lives. Key named templates:

- **`wger.image`** / **`wger.labels`** — the wger image reference and the common resource labels (instance/version/managed-by/chart). `wger.labels` is metadata-only: never add it (or new keys) to pod template / selector labels — selectors are immutable.
- **`wger.env.default`** — builds the full default env list (email, cache/redis, django, axes brute-force protection, JWT, gunicorn tuning, exercise sync). Celery-related vars are only emitted when `celery.enabled`.
- **`wger.env`** — merges `wger.env.default` with user-supplied `app.environment` entries, letting users **override any default var by name** (custom entries with a matching name replace the default). Use this, not the raw default, when adding env to containers.
- **`wger.env.secrets`** — the secret-backed env entries shared by the app and all celery containers: django `SECRET_KEY`, mail password, `CELERY_BROKER`/`CELERY_BACKEND` URLs (with or without redis auth), flower password.
- **`database.settings`** — emits `DJANGO_DB_*` env. Branches three ways: in-cluster postgres (reads the groundhog2k-created `{Release}-postgres` secret), an `existingDatabase` with inline credentials, or an `existingDatabase.existingSecret` (key names come from `existingSecret.dbuserKey`/`dbpwKey`; a null `dbnameKey` falls back to the inline `dbname` value).
- **`powersync.settings`** — builds the powersync DB URIs by referencing both the `{Release}-powersync` and django DB secrets; relies on `$(VAR)` shell-style interpolation across env entries.
- **`wger.rollme.annotations`** — pod-template annotations that drive restarts on upgrade: a `checksum/secrets` hash (via `wger.checksum.secrets`) over every value that feeds a referenced secret, plus a `rollme` random value **only** while `app.jwt.secret.update=true` with no key supplied (hook regenerates keys each upgrade, invisible to checksums). Deployments mounting a ConfigMap (nginx, powersync) additionally carry a `checksum/config` hash of the ConfigMap template. Pods therefore restart only when their config actually changes — never add an unconditional `rollme`.

When changing app configuration, prefer editing the `wger.env.default` template over hardcoding env in the Deployment.

### Secret & JWT key handling

Secrets are created via Helm templates annotated as `pre-install,pre-upgrade,pre-rollback` hooks (`secret-*.yaml`). The **generate-or-preserve password pattern** lives in the `wger.secretValue` helper (`_helpers.tpl`): if a value is set in `values.yaml`, use it; otherwise `lookup` the existing secret and reuse its value; only `randAlphaNum` a fresh one when neither exists. Use this helper (see `secret-django.yaml` for the simplest call) for any new generated credential.

JWT keys are special: `templates/hooks/jwt-keygen.yaml` runs a **pre-install/upgrade Job** that uses `jose` + `kubectl apply` to generate RS256 JWK keys and write the `jwt` secret. The `manipulatejwt` / `manipulatemail` helpers in `_helpers.tpl` decide (returning the string `"doit"`) whether a secret should be (re)generated based on existence and the `*.secret.update` flag.

### RBAC for hook Jobs

`serviceaccount.yaml`, `role.yaml`, and `rolebinding.yaml` (all pre-install/upgrade/rollback hooks) define one ServiceAccount: `{{ .Release.Name }}-keygen`, bound to `{{ .Release.Name }}-secret-role` (create/patch/update/get on secrets), used by the JWT keygen Job. The powersync storage-setup Job needs no RBAC — it talks only to the database.

## Conventions

- Resource names are always `{{ .Release.Name }}-<suffix>`; in-cluster service DNS is referenced the same way (e.g. `{{ .Release.Name }}-postgres`, `{{ .Release.Name }}-redis`, `{{ .Release.Name }}-http` for nginx). User-nameable secrets get their release-prefixed default via the `wger.secretName.*` helpers — use those, never the raw value. Sole exception: the `wger-pg-init` ConfigMap stays static because it must match the untemplatable `postgres.extraScripts` subchart value.
- `app.global.image.tag` defaults to `.Chart.AppVersion` when empty — bump `appVersion` in `Chart.yaml` to track a new wger release.
- Static defaults live in `values.yaml`, not in templates. Only use `| default` for computed fallbacks (release-derived names, `.Chart.AppVersion`, cross-value defaults) or where `null` is a deliberate sentinel (e.g. `existingClaim.*`, `jwksURL`, generated passwords/keys).
- The full parameter reference lives in `charts/wger/README.md` (a generated table). Keep it in sync when adding or renaming values.
