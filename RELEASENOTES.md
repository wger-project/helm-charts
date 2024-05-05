## 0.2.0

* redis upgrade
* postgres minor upgrade

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

* setting a redis password is now possible

This requires you to set the following `env` and `args`, when enabling it.

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
