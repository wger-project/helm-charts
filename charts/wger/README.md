# wger

Helm charts for wger deployment on Kubernetes.

* https://wger.readthedocs.io


## Introduction

This chart bootstraps a wger deployment on a Kubernetes cluster using the Helm package manager, alongside with a PostgreSQL for a database and Redis as a caching service.

For a more productive environment you have to enable nginx as a reverse proxy. This will enable gunicorn in the wger image and will require persistent storages for at least django's media and static files.


## Prerequisites

* Kubernetes 1.15+
* Helm 3.0+
* PV infrastructure on the cluster persistence is needed
* Ingress infrastructure for exposing the installation


## Installing the chart

You can install the chart by adding our helm repository. Starting the wger container takes a long time for the first time it even takes longer, so add `--timeout 15m` to the helm command.

```bash
helm repo add github-wger https://wger-project.github.io/helm-charts

helm install wger github-wger/wger \
  --timeout 15m \
  --version 1.0.0 \
  -n wger \
  --create-namespace
  -f values.yaml
```

But first you need to make a copy of [values.yaml](values.yaml) and modify it for your needs.

There is a example of the `values.yaml` in the [example folder](/example/) with the most basic settings.

Please see the [parameters section](#parameters).


## Parameters

The following table contains the configuration parameters of the chart with their default values.
For additional configuration of the Groundhog2k's PostgreSQL and Redis charts, please check the [additional information](#additional-information).


### Globals

| Name                          | Description                                           | Type    | Default Value |
|-------------------------------|-------------------------------------------------------|---------|---------------|
| `app.global.image.registry`   | Image to use for the wger deployment                  | String  | `docker.io`   |
| `app.global.image.repository` | Image to use for the wger deployment                  | String  | `wger/server` |
| `app.global.image.tag`        | Takes the `Chart.yaml` `appversion` when empty. wger is developed as a rolling release | String | `latest` |
| `app.global.image.PullPolicy` | [Pull policy](https://kubernetes.io/docs/concepts/containers/images/#image-pull-policy) to use for the image | String | `Always` |
| `app.global.annotations`      | Annotations to attach to each resource, apart from the ingress and the persistence objects | Dictionary | `{}` |
| `app.global.replicas`         | Number of webserver instances that should be running. | Integer | `1`           |
| `app.global.securityContext`  | Pod security context                                  | Object  | see [values.yaml](charts/wger/values.yaml) |


### Mail

| Name                     | Description                                  | Type    | Default Value   |
|--------------------------|----------------------------------------------|---------|-----------------|
| `app.mail.enabled`       | Enable mail client configuration             | Boolean | `false`         |
| `app.mail.server`        | Mailserver                                   | String  | `null`          |
| `app.mail.port`          | Mailserver Port                              | String  | `587`           |
| `app.mail.user`          | Mailserver User                              | String  | `null`          |
| `app.mail.from_email`    | From Email Address                           | String  | `null`          |
| `app.mail.secret.name`   | Name of the secret for the mail password     | String  | `mail`          |
| `app.mail.secret.key`    | Key in the secret used for the mail password | String  | `mail-password` |
| `app.mail.secret.update` | Enable or disable changes to the secret with the values | Boolean | `false` |
| `app.mail.django_admins` | Django admins to receive internal server error, don't enable it when not needed | String | `null` |


### Django

| Name                                                   | Description                          | Type   | Default Value |
|--------------------------------------------------------|--------------------------------------|--------|---------------|
| `app.django.secret.name`                               | Name of the secret                   | String | `django` |
| `app.django.secret.key`                                | Key for the `SECRET_KEY`             | String | `randAlphaNum 50` |
| `app.django.cache.timeout`                             | Cache timeout in seconds             | String | `1296000` |
| `app.django.existingDatabase.enabled`                  | Enable existing database, you need to set `postgres.enabled: false` | Boolean | `false` |
| `app.django.existingDatabase.engine`                   | Set database engine                  | String | `django.db.backends.postgresql` |
| `app.django.existingDatabase.host`                     | Database hostname                    | String | `{{ .Release.Name }}-postgres` |
| `app.django.existingDatabase.port`                     | Database port                        | Integer | `postgres.service.port` |
| `app.django.existingDatabase.dbname`                   | Name of the database                 | String | `wger` |
| `app.django.existingDatabase.dbuser`                   | Database User                        | String | `wger` |
| `app.django.existingDatabase.dbpw`                     | Database Password                    | String | `null` |
| `app.django.existingDatabase.existingSecret.name`      | Name of a existing secret. If you like to use this for the database credentials | String | `null` |
| `app.django.existingDatabase.existingSecret.dbnameKey` | Key containing the database name. Optional; will take `app.django.existingDatabase.dbname` if not set | String | `null` |
| `app.django.existingDatabase.existingSecret.dbuserKey` | Key containing the database user     | String | `null` |
| `app.django.existingDatabase.existingSecret.dbpwKey`   | Key containing the database password | String | `null` |


### Service for the wger app

| Name                      | Description                          | Type       | Default Value |
|---------------------------|--------------------------------------|------------|---------------|
| `app.service.type`        | Sets the http service type           | String     | `ClusterIP`   |
| `app.service.port`        | Port for the service                 | Integer    | `80`          |
| `app.service.annotations` | Annotations to attach to the service | Dictionary | `{}`          |


### Celery

Celery requires persistent volumes.

| Name                            | Description                   | Type       | Default Value     |
|---------------------------------|-------------------------------|------------|-------------------|
| `celery.enabled`                | Enable celery for sync        | Boolean    | `True`            |
| `celery.annotations`            | Annotations                   | Dictionary | `{}`              |
| `celery.replicas`               | Enable celery for sync        | Integer    | `1`               |
| `celery.replicasWorker`         | Enable celery for sync        | Integer    | `1`               |
| `celery.securityContext`        | Pod security context          | Object     | see [values.yaml](values.yaml) |
| `celery.syncExercises`          | sync exercises                | Boolean    | `True`            |
| `celery.syncImages`             | sync exercise images          | Boolean    | `True`            |
| `celery.syncVideos`             | sync exercise videos          | Boolean    | `True`            |
| `celery.ingredientsFrom`        | source for ingredients, possible values `WGER`,`OFF` | String  | `WGER`  |
| `celery.flower.enabled`         | enable flower webinterface for celery | Boolean    | `False`   |
| `celery.flower.secret.name`     | Name of the secret            | String     | `flower`          |
| `celery.flower.secret.password` | Password for the webinterface | String     | `randAlphaNum 50` |


## JWT

| Name                           | Description                              | Type    | Default Value     |
|--------------------------------|------------------------------------------|---------|-------------------|
| `app.jwt.secret.name`          | Name of the secret                       | String  | `jwt`             |
| `app.jwt.secret.update`        | Update content of the current secret     | Boolean | `false`           |
| `app.jwt.secret.privateKey`    | Private Key for JWT                      | String  | auto created new key |
| `app.jwt.secret.publicKey`     | Public Key for JWT                       | String  | auto created new key |
| `app.jwt.accessTokenLifetime`  | Duration of the access token, in minutes | String  | `10`              |
| `app.jwt.refreshTokenLifetime` | Duration of the refresh token, in hours  | String  | `24`              |


## Axes

| Name                                 | Description                   | Type | Default Value |
|--------------------------------------|-------------------------------|------|---------------|
| `app.axes.enabled`                   | Enable [axes](https://django-axes.readthedocs.io/en/latest/index.html) Bruteforce protection | Boolean | `false` |
| `app.axes.lockoutParameters`         | List (comma separated string) | String | `"ip_address"` |
| `app.axes.failureLimit`              | Limit of failed auth          | String | `10` |
| `app.axes.cooloffTime`               | in Minutes                    | String | `30` |
| `app.axes.ipwareProxyCount`          | Count of proxies              | String | `0` |
| `app.axes.ipwareMetaPrecedenceOrder` | Proxy header magnitude | List (comma separated string) | `"HTTP_X_FORWARDED_FOR,REMOTE_ADDR"` |


## Nginx

| Name                        | Description                           | Type       | Default Value  |
|-----------------------------|---------------------------------------|------------|----------------|
| `nginx.image`               | Image to use for the nginx proxy      | String     | `nginx:stable` |
| `nginx.imagePullPolicy`     | [Pull policy](https://kubernetes.io/docs/concepts/containers/images/#image-pull-policy) to use for the image | String | `IfNotPresent` |
| `nginx.service.type`        | Sets the http service type            | String     | `ClusterIP`    |
| `nginx.service.port`        | Port for the service                  | Integer    | `80`           |
| `nginx.service.annotations` | Annotations to attach to the service  | Dictionary | `{}`           |

## Powersync

| Name                        | Description                           | Type       | Default Value  |
|-----------------------------|---------------------------------------|------------|----------------|
| `powersync.image.registry`    | Image registry                       | String     | `docker.io`    |
| `powersync.image.repository`  | Image repostory                      | String     | `journeyapps/powersync-service` |
| `powersync.image.tag`         | Image tag                            | String     | `latest`       |
| `powersync.image.PullPolicy`  | Image pull policy                    | String     | `IfNotPresent` |
| `powersync.annotations`       | Annotations to attach to the service | Dictionary | `{}`           |
| `powersync.replicas`          | Number of webserver instances that should be running | Integer | `1` |
| `powersync.replicasWorker`    | Number replica workers               | Integer    | `1`            |
| `powersync.securityContext`   | Pod security context                 | Object     | see [values.yaml](charts/wger/values.yaml) |
| `powersync.serviceApi.type`        | Sets the http service type            | String     | `ClusterIP`    |
| `powersync.serviceApi.port`        | Port for the service                  | Integer    | `8080`         |
| `powersync.serviceApi.annotations` | Annotations to attach to the service  | Dictionary | `{}`           |
| `powersync.servicePrometheus.type`        | Sets the http service type            | String     | `ClusterIP`    |
| `powersync.servicePrometheus.port`        | Port for the service                  | Integer    | `9090`         |
| `powersync.servicePrometheus.annotations` | Annotations to attach to the service  | Dictionary | `{}`           |
| `powersync.configPath`        | Path to the powersync config                      | String     | `/config/powersync.yaml` |
| `powersync.jwksURL`           | URI for JWK auth                     | String     | `http://{{ .Release.Name }}-http:80/api/v2/powersync-keys` |


## Ingress

| Name                       | Description                                | Type       | Default Value     |
|----------------------------|--------------------------------------------|------------|-------------------|
| `ingress.enabled`          | Whether to enable ingress. If `false`, the options from below are ignored | Boolean | `false` |
| `ingress.ingressClassName` | The ClassName that this ingress should use | String     | ``                |
| `ingress.url`              | The URL that this ingress should use       | String     | `fit.example.com` |
| `ingress.tls`              | Whether to enable TLS. If using cert-manager, the correct annotations have to be set | Boolean | `true` |
| `ingress.annotations`      | Annotations to attach to the ingress       | Dictionary | `{}`              |


## Persistence

| Name                                    | Description                                                        | Type | Default Value |
|-----------------------------------------|--------------------------------------------------------------------|------|---------------|
| `app.persistence.existingClaim.enabled` | Whether to use a existing persistent storage claim. If `false`, the options from below are ignored | Boolean | `false` |
| `app.persistence.existingClaim.media`   | Name of the pvc for the media data when existingClaim is enabled   | String     | `null` |
| `app.persistence.existingClaim.static`  | Name of the pvc for the static data when existingClaim is enabled  | String     | `null` |
| `app.persistence.storageClass`          | StorageClass for the PVCs                                          | String     | `""` |
| `app.persistence.accessModes`           | Access modes for the PVCs                                          | Array      | `["ReadWriteMany"]` |
| `app.persistence.size`                  | PVC size                                                           | String     | `8Gi` |
| `app.persistence.annotations`           | Annotations to attach to the persistence objects (PVC and PV)      | Dictionary | `{}` |


## Application Resources

Most containers have their `resources` setting: see [values.yaml](values.yaml).


### Environment Variables

| Name              | Description | Type | Default Value |
|-------------------|-------------|------|---------------|
| `app.environment` | Array of objects, representing additional environment variables to set for the deployment. | Array | see [_helpers.yaml](templates/_helpers.tpl) and [values.yaml](values.yaml) |

There are more possible ENV variables, than the ones used in the deployment. Please check [prod.env](https://github.com/wger-project/docker/blob/master/config/prod.env).


### PostgreSQL and Redis settings

The following settings are declared in the groundhog2k Helm charts.


#### PostgreSQL

wger-app requires for the django database migrations the superuser privileges, so we grant the `postgres.userDatabase.name` `SUPERUSER` with a `postgres.extraScripts`.

| Name | Description | Type | Default Value |
|------|-------------|------|---------------|
| `postgres.enabled` | Enable the PostgreSQL chart | Boolean | `True` |
| `postgres.settings.superuser	` | Superuser name | String | `postgres` |
| `postgres.settings.superuserPassword` | Password of superuser | String | `postgres` |
| `postgres.userDatabase.name` | Database name to use for wger | String | `wger` |
| `postgres.userDatabase.user` | Username to use for wger | String | `wger` |
| `postgres.userDatabase.password` | Password for wger user | String | `wger` |
| `postgres.extraScripts` | A configmap used to grant privileges | String | `wger-pg-init` |
| `postgres.service.port` | PostreSQL service port | Integer | `5432` |
| `postgres.storage.persistentVolumeClaimName` | PVC name when existing storage volume should be used | String | `Nil` |
| `postgres.storage.requestedSize` | Size for new PVC, when no existing PVC is used | Integer | `8Gi` |
| `postgres.storage.className` | Storage class name when no existing storage used, takes the cluster default when `Nil` | String | `Nil` |


#### Redis

| Name | Description | Type | Default Value |
|------|-------------|------|---------------|
| `redis.enabled` | Enable the redis chart | Boolean | `true` |
| `redis.auth.enabled` | Whether to enable redis login. | Boolean | `false` |
| `redis.auth.password` | Password for redis login. Not required if `redis.auth.enabled` is `false` | String | `randAlphaNum 25` |
| `redis.service.serverPort` | Redis server service port | Integer | `6379` |
| `redis.storage.persistentVolumeClaimName` | PVC name when existing storage volume should be used | String | `Nil` |
| `redis.storage.requestedSize` | Size for new PVC, when no existing PVC is used | String | `Nil` |
| `redis.storage.className` | Storage class name when no existing storage used, takes the cluster default when `Nil` | String | `Nil` |


## Celery

* https://wger.readthedocs.io/en/latest/celery.html

Celery is used to sync exercises or ingredients. The user for the flower webinterface is `wger`.


### Monitoring


#### Commandline

* https://docs.celeryq.dev/en/stable/userguide/monitoring.html#celery-events-curses-monitor

```bash
export POD=$(kubectl get pods -n wger -l "app.kubernetes.io/name=wger-celery-worker" -o jsonpath="{.items[0].metadata.name}")
kubectl -n wger exec -ti $POD -- bash

celery -A wger events
```

`celery events` is a simple curses monitor displaying task and worker history.


#### Flower Webinterface

If you have enabled flower you can, for example use port forwarding to connect to the web interface.

```bash
export POD=$(kubectl get pods -n wger -l "app.kubernetes.io/name=wger-celery-worker" -o jsonpath="{.items[0].metadata.name}")
kubectl -n wger port-forward ${POD} 8080:5555
```

Open the browser to http://localhost:8080

Get the password for the flower webinterface:

```bash
kubectl -n wger get secret flower -o jsonpath='{.data.password}' | base64 -d
```


## Axes

Bruteforce protection. Depending on your setup, you may need to configure axes to your proxy setup otherwise it will block by default the IP which can be your reverse proxy.

* https://django-axes.readthedocs.io/en/latest/4_configuration.html#configuring-reverse-proxies
* https://django-axes.readthedocs.io/en/latest/5_customization.html#customizing-lockout-parameters

```bash
python3 manage.py axes_reset
python3 manage.py axes_reset_ip [IP]
python3 manage.py axes_reset_username [USERNAME]
```

To temporary disable privacy mode to see the blocked ip in the log you can login to the container and add the following setting:

```bash
echo "AXES_SENSITIVE_PARAMETERS = []" >>settings.py
```


## Upgrading

Wger has started making releases from version 2.4, so from helm chart version 0.2.5 charts are pinned to a specific wger version.

```sh
# update the repo
helm repo update github-wger

# list versions from repo
helm search repo github-wger/wger -l --devel

# list the installed version
helm -n wger list

helm upgrade \
  --timeout 15m \
  --install wger github-wger/wger \
  --version 0.3.0 \
  -n wger \
  --create-namespace
  -f values.yaml
```


### Postgres Upgrade Notes

It is sadly not possible to automatically upgrade between postgres versions, you need to perform the upgrade manually. Since the amount of data the app generates is small a simple dump and restore is the simplest way to do this.

If you pulled new changes from this repo and got the error message "The data directory was initialized by PostgreSQL version 12, which is not compatible with this version 15." this is for you.

See also <https://github.com/docker-library/postgres/issues/37>

The following requires a persistent storage for the postgresql database.

**Before doing the upgrade**, go inside the container and dump the database:

```bash
export POD=$(kubectl get pods -n wger -l "app.kubernetes.io/name=postgres" -o jsonpath="{.items[0].metadata.name}")
kubectl -n wger exec -ti $POD -c postgres -- bash

pg_dumpall --clean --username wger -f /var/lib/postgresql/data/dump.sql
```

If you however missed that, you need to know which postgres version you where running before. First stop the current postgres and wger app.

```bash
# stop the current wger deployment
kubectl -n wger scale --replicas=0 deploy wger-app wger-powersync wger-nginx wger-celery wger-celery-worker
# stop the postgres sts
kubectl -n wger scale --replicas=0 sts wger-postgres
```

Create a job dumping the database `job-dump.yaml`, fill in the postgres version you where running:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: dbdump
spec:
  template:
    spec:
      containers:
      - name: dbdump
        image: postgres:14
        lifecycle:
          postStart:
            exec:
              command: ["/bin/bash", "-c", "until `pg_dumpall --clean --username wger -f /var/lib/postgresql/data/dump.sql && runuser -u postgres -- pg_ctl stop`; do sleep 2; done"]
        volumeMounts:
        - mountPath: /var/lib/postgresql/data
          name: wger-db
        env:
          - name: PGDATA
            value: "/var/lib/postgresql/data/pg"
          - name: POSTGRES_HOST_AUTH_METHOD
            value: trust
      volumes:
        - name: wger-db
          persistentVolumeClaim:
            claimName: wger-db
      restartPolicy: Never
  backoffLimit: 4
```

```bash
kubectl -n wger apply -f job-dump.yaml
```

Now move away the current db in your storage, so that the new postges image will create a new one -> this needs to be done accessing your storage from outside the cluster or add it to the `command` in the `job-dump.yaml`:

```bash
# move the old database -> can be removed after the upgrade was successful
mv /var/lib/postgresql/data/pg /var/lib/postgresql/data/pg-$(date +%Y-%m-%d)
```

Upgrade wger chart, but disable the wger django app, so that the database will not be created, for this you can temporary set the app replicas to `0` in your `values.yaml`:

```yaml
app:
  global:
    replicas: 0
```

```bash
helm upgrade \
  --timeout 15m \
  --install wger github-wger/wger \
  --version 0.3.0 \
  -n wger \
  --create-namespace
  -f values.yaml
```

Now you should have running the new postgres version. Go inside the new container and import the database dump with:

```bash
cat /var/lib/postgresql/data/dump.sql | psql --username wger --dbname wger
```

Also reset the database password to the one you used, the default is `wger`:

```bash
psql --username wger --dbname wger -c "ALTER USER wger WITH PASSWORD 'wger';"
```

Start the wger app, don't forget to set back the replicas in your `values.yaml` as well:

```bash
kubectl -n wger scale --replicas=1 deploy wger-app wger-powersync wger-nginx wger-celery wger-celery-worker
```


## Uninstalling

To uninstall remove the helm release we called `wger` during installation:

```bash
helm -n wger delete wger
```


## Contributing

Please check the [contributing guidelines](https://wger.readthedocs.io/en/latest/tips_and_tricks.html#contributing) of the wger project.

Generally:

* if you have a problem, create an issue in [the issue tracker](https://github.com/wger-project/helm-charts/issues)
* if you have a cool idea, create a fork and send pull requests
* assure that your code is well-formed (hint: [`helm lint`](https://helm.sh/docs/helm/helm_lint/) is a useful command). This is enforced using continuous integration.


## Contact

Feel free to contact us if you found this useful or if there was something that didn't behave as you expected. We can't fix what we don't know about, so please report liberally. If you're not sure if something is a bug or not, feel free to file a bug anyway.

* discord: https://discord.gg/rPWFv6W
* issue tracker: https://github.com/wger-project/helm-charts/issues
* twitter: https://twitter.com/wger_project


## Additional information

* [groundhog2k PostgreSQL chart](https://github.com/groundhog2k/helm-charts/tree/master/charts/postgres)
* [groundhog2k Redis chart](https://github.com/groundhog2k/helm-charts/tree/master/charts/redis)
