## 0.2.3

* fix initContainer when flower is not enabled
* add NOTES.txt
* add wger icon

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
