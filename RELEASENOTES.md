## 0.1.6

* get the database credentials from the secret, like the postgres chart does

### Upgrade

#### postgres superuser

The superuser was named `wger`, but this seems to lead to a error in the postgres docker image:

```bash
FATAL:  role "postgres" does not exist
```

So you need to manually add a `postgres` superuser:

```bash
kubectl -n wger exec -ti wger-postgres-0 -- bash
psql -U wger

CREATE ROLE postgres WITH LOGIN SUPERUSER PASSWORD 'postgres';
```

As well set the settings in your `values.yaml`:

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

#### Name of the postgres secret

For postgres we set `fullnameOverride: wger-postgres`, this will be used to name the secret upon the first installation. So when upgrading and you have used a different helm release name than `wger` you need to modify `[yourname]-postgres` in your `values.yaml`.