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
