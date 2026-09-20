
## 2.0.0

This is a release with **breaking changes** to resource names
and two values keys. First make a backup of your database and media files.

* upgrade to wger 2.7, also have a look at the release note of the wger app:
  https://github.com/wger-project/wger/releases/tag/2.7
* **before upgrading** make sure `app.timezone` is set correctly and treat it as
  fixed afterwards: the 2.7 migrations convert the old workout session dates
  using this zone
* new wger 2.7 settings: `app.maxSessionLengthHours` (default `5`),
  `app.showAppStoreLinks` (default `true`) and `app.global.useXForwardedHost`
  (default `false`)
* powersync sync rules updated for wger 2.7: the removed `weight_weightentry`
  table is gone, body weight entries are synced as measurements. Stop powersync
  while the wger 2.7 database migrations run, then start it again (use
  `powersync.replicas`, a `kubectl scale` is reverted by `helm upgrade`):

  ```bash
  helm upgrade ... --set powersync.replicas=0
  kubectl -n <namespace> rollout status deploy <release>-app   # migrations done
  helm upgrade ...
  ```
  PowerSync reprocesses all buckets once with the new rules.
* powersync `api.parameters.max_parameter_query_results` raised to 10000 as a
  workaround for the PSYNC_S2305 bug with large nutrition logs
* new optional OAuth2/OIDC provider: `app.oauth2Provider.enabled` (default
  `false`) creates the `<release>-oidc` secret with a generated signing key
  (or `app.oauth2Provider.secret.privateKey`)

### Breaking: resources are now prefixed with the release name

All fixed-name resources are now named `<release>-<suffix>`, so several
releases can share a namespace:

| old name | new name |
|----------------------|--------------------------|
| secret `django` | `<release>-django` |
| secret `mail` | `<release>-mail` |
| secret `jwt` | `<release>-jwt` |
| secret `flower` | `<release>-flower` |
| secret `redis` | `<release>-redis` |
| secret `powersync` | `<release>-powersync` |
| pvc `wger-media` | `<release>-media` |
| pvc `wger-static` | `<release>-static` |
| pvc `wger-celery-beat` | `<release>-celery-beat` |

(the `wger-pg-init` ConfigMap keeps its static name — it must match the
untemplatable `postgres.extraScripts` subchart value)

Upgrade notes:

* **Generated passwords are preserved automatically**: on the first upgrade
  the new secrets copy their values from the old unprefixed ones.
* **PVCs / your data**: if your release is named `wger` the media and static
  PVC names are unchanged (`wger-media` etc.) and nothing happens. For any
  other release name, point the chart at your existing claims **before**
  upgrading, otherwise the volumes are recreated empty:

  ```yaml
  app:
    persistence:
      existingClaim:
        enabled: true
        media: wger-media
        static: wger-static
        celeryBeat: wger-celery-beat
  ```
* **JWT**: the keygen hook creates fresh keys under `<release>-jwt`, so mobile
  clients have to log in again once. To avoid this, pin the old secret name:

  ```yaml
  app:
    jwt:
      secret:
        name: "jwt"
  ```
  (the same opt-out works for the django, mail and flower secret names)
* **Redis authentication**: if you enabled it, update the `secretKeyRef` in
  your `redis.env` values block from `redis` to `<release>-redis`.
* The old unprefixed secrets are left behind and can be deleted once the
  upgrade is verified.

### Breaking: `PullPolicy` renamed to `pullPolicy`

`app.global.image.PullPolicy` and `powersync.image.PullPolicy` are now
lowercase `pullPolicy`. Installs still using the old key fail with a clear
error message instead of silently ignoring the setting.

### Behavior changes

* pods no longer restart on every `helm upgrade`: the random `rollme`
  annotation was replaced with checksums over the values that feed the
  secrets and mounted configmaps. Pods restart only when their configuration
  actually changes. Exception: while `app.jwt.secret.update: true` is set
  without explicit keys, every upgrade still restarts the JWT consumers.
* the django `SECRET_KEY` and the flower password are no longer regenerated
  on every upgrade — user sessions now survive upgrades
* the celery sync/cache booleans (`celery.syncExercises`, `celery.syncImages`,
  `celery.syncVideos`, `celery.warmupExercisesCache`,
  `celery.warmupExercisesCacheAll`) can now actually be set to `false`;
  previously `false` was silently rendered as `"True"`
* the powersync database initialization hook now runs
  `./manage.py setup-powersync-storage` in its own pod using the wger image
  instead of `kubectl exec`-ing into the app pod; the pod-exec
  ServiceAccount/Role/RoleBinding were removed
* the nginx pod now restarts when its configmap changes (previously it kept
  running with the old config)

### Other changes

* new CronJob `<release>-powersync-compact` runs the powersync service's
  `compact` command daily (at 03:00) to reclaim sync bucket storage, which
  self-hosted instances don't do on their own. Configure via
  `powersync.compact.enabled` / `schedule` / `resources`
* initContainer and hook images are pinned and configurable:
  `app.global.initImage` (default `docker.io/busybox:1.37`) and
  `app.jwt.keygenImage` (default `docker.io/alpine:3.22`)
* the `wger-pg-init` ConfigMap is only created when `postgres.enabled` is true
* standard labels (`app.kubernetes.io/instance`, `version`, `managed-by`,
  `helm.sh/chart`) added to all chart resources
* removed unused values `app.proxyCount` (use `app.global.proxyCount`) and
  `powersync.replicasWorker`
* removed the unused `REFRESH_TOKEN_LIFETIME` template fallback of 2880; the
  effective default stays 2880 (hours) as set in `values.yaml`
* defaults now live in `values.yaml` instead of being duplicated in the
  templates; `app.mail.port` (587), `app.django.existingDatabase.engine`,
  `existingSecret.dbuserKey`/`dbpwKey` (`USERDB_USER`/`USERDB_PASSWORD`) and
  `powersync.configPath` now show their real defaults
* large internal template refactoring (shared env/image/label/secret helpers),
  no rendering changes beyond the ones listed above

## 1.0.0

This is a major upgrade and has breaking changes. Please review the

* [`values.yaml`](https://github.com/wger-project/helm-charts/blob/master/charts/wger/values.yaml)

file and update your own. Also have a look at the release note of the wger app:

* https://github.com/wger-project/wger/releases/tag/2.6

First make a backup of your database and media files.

Compared to the docker compose setup the helm chart takes care of the following tasks
automatically, so don't get confused with the documentation:

* creates a jwt private and public key
* setups the powersync database

If you upgrade a existing installation the kubernetes jwt secret already exists
from the previous installation. You have to remove the jwt secret, alternatively
you can set `update: true`, this will force the private and public key to
be regenerated on every install and upgrade:

```yaml
app:
  jwt:
    secret:
      name: "jwt"
      update: true
```

The now unused signing key remains in the secret, but serves no purpose.

**The first start and even restarting the wger container takes a long time as we now use a
post-install hook the helm command can timeout, you have to use `--timeout 15m` on the helm
command.**

* upgrade to wger 2.6
* minor upgrade postgres to 15.18
* minor upgrade redis to 8.8.0
* new powersync service for offline sync for the mobile app introduced
* new service accounts introduced for jwt autogeneration and powersync database initialization
* JWT signing key has been removed
* autogenerated JWT keys with a pre-install and pre-update hook
* can append to the current jwt secret
* nginx and persistent storage is now mandatory
* nginx get's it's own deployment
* remove wger-code volume definitions
* service and target ports changed
* add resource setting possibility for most containers
* reorganize yamls
* path in nginx for the static and media files changed, to match docker compose setup
* celery enabled by default
* REFRESH_TOKEN_LIFETIME default changed from 24 to 2880
* EXERCISE_CACHE_TTL default changed from 18000 to 2419200
* AXES_IPWARE_PROXY_COUNT default changed from 0 to 1
* CELERY_WORKER_CONCURRENCY added with default 4
* CACHE_API_EXERCISES_CELERY added with default True
* CACHE_API_EXERCISES_CELERY_FORCE_UPDATE added with default True
* replaced .Values.app.axes.ipwareProxyCount with .Values.app.global.proxyCount
* NUMBER_OF_PROXIES added with default 1 (for REST Framework)

### Post Install Tasks

* Some unused thumbnail sizes have been deleted, run `./manage.py prune-thumbnails` to delete dangling files
* The default location for ingredient images has changed. Please run `./manage migrate-ingredient-image-paths` to migrate existing entries. Note that this is technically optional, as the old paths will continue working, but it is advised for consistency.

## 0.3.0

* upgrade to wger 2.5

## 0.2.5

* wger starts using releases
* use wger version 2.4
* minor upgrade postgres
* major upgrade redis

## 0.2.4

* support existing database
  * credentials in the `values.yaml`
  * credentials in a existing secret
* minor upgrade postgres
* minor upgrade redis

## 0.2.3

* fix initContainer when flower is not enabled
* add NOTES.txt
* move README.md and LICENSE into package
* add wger icon
* add to https://artifacthub.io

## 0.2.2

* Every helm upgrade will restart the deployments
* Create/Update secrets in pre-* hooks

### Mail settings

* Values to setup the mail configuration
* Creates a new secret for the mail password
* Manually created secrets can be used with:
```yaml
app:
  mail:
    secret:
      name: yoursecret
      key: yourkey
```

## 0.2.1

* fixes #54 Database migration fails
* fix celery redis password
* update development setup

## 0.2.0

* redis upgrade
* postgres minor upgrade
* setting a redis password is now possible

### Upgrade

#### Postgres values change

Upgraded chart from groundhog2k for postgres requires changes to the `values.yml`:

```yaml
postgres:
  settings:
    superuser:
      value: postgres
    superuserPassword:
      value: XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  userDatabase:
    name:
      value: wger
    user:
      value: wger
    password:
      value: XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

#### Redis password

When enabling the redis password after the installation (upgrade), it is required to set the password once in the `values.yml`, as soon as the secret is created it can be removed.

```yaml
redis:
  auth:
    enabled: true
    password: XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

Enabling redis authentication, requires you to set the following `env` and `args`, for the redis container:

```yaml
redis:
  auth:
    enabled: true
  # Additional environment variables (Redis server and Sentinel)
  env:
    - name: REDIS_PASSWORD
      valueFrom:
        secretKeyRef:
          name: redis
          key: redis-password
  # Arguments for the container entrypoint process (Redis server)
  args:
    - "--requirepass $(REDIS_PASSWORD)"
```

## 0.1.6

* get the database credentials from the secret, like the postgres chart does

### Upgrade

#### postgres superuser

The superuser was named `wger`, but this seems to lead to a error in the postgres docker image:

```bash
FATAL:  role "postgres" does not exist
```

So if you are upgrading, you need to manually add a `postgres` superuser:

```bash
kubectl -n wger exec -ti wger-postgres-0 -- bash
psql -U wger

CREATE ROLE postgres WITH LOGIN SUPERUSER PASSWORD 'postgres';
```

As well set the following settings in your `values.yaml`:

```yaml
postgres:
  settings:
    superuser: postgres
    superuserPassword: postgres
  userDatabase:
    name: wger
    user: wger
    password: wger
```
