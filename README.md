# wger

Helm charts for wger deployment on Kubernetes

## TL;DR

If you know what you are doing, you can go ahead and run these commands to install wger. Otherwise, keep on reading!

```bash
git clone https://github.com/wger-project/helm-charts.git
helm dependency update
helm upgrade --install wger . --namespace wger --create-namespace
```

## Introduction

This chart bootstraps a wger deployment on a Kubernetes cluster using the Helm package manager, alongside with a PostgreSQL for a database and Redis as a caching service.

## Prerequisites

* Kubernetes 1.12+
* Helm 3.0+
* PV infrastructure on the cluster if persistence is needed
* Ingress infrastructure for exposing the installation

## Installing the chart

Currently, there is no Helm package offered, so you will have to clone the repository:

```bash
git clone https://github.com/wger-project/helm-charts.git
cd helm-charts
```

Afterwards, install the dependencies for the chart:

```bash
helm dependency update
```

To install the chart as a release named `wger`, run the following command:

```bash
helm upgrade --install wger . --namespace wger --create-namespace
```

This will install the chart with the defaults, stated in `values.yaml`.
They are fine if you are testing wger out, but should be changed for production.
Please see the [parameters section](#parameters).

## Parameters

The following table contains the configuration parameters of the chart with their default values.
For additional configuration of the Bitnami PostgreSQL and Redis, please check the [additional information](#additional-information).

### Globals

| Name | Description | Type | Default Value |
|------|-------------|------|---------------|
| `app.global.image` | Image to use for the wger deployment | String | `wger/server:latest` |
| `app.global.imagePullPolicy` | [Pull policy](https://kubernetes.io/docs/concepts/containers/images/#image-pull-policy) to use for the image | String | `Always` |
| `app.global.annotations` | Annotations to attach to each resource, apart from the ingress and the persistence objects | Dictionary | `{}` |

### Ingress

| Name | Description | Type | Default Value |
|------|-------------|------|---------------|
| `app.ingress.enabled` | Whether to enable ingress. If `false`, the options from below are ignored | Boolean | `false` |
| `app.ingress.url` | The URL that this ingress should use | String | `fit.example.com` |
| `app.ingress.tls` | Whether to enable TLS. If using cert-manager, the correct annotations have to be set | Boolean | `true` |
| `app.ingress.annotations` | Annotations to attach to the ingress | Dictionary | `{}` |

### Persistence

| Name | Description | Type | Default Value |
|------|-------------|------|---------------|
| `app.persistence.enabled` | Whether to enable persistent storage. If `false`, the options from below are ignored | Boolean | `false` |
| `app.persistence.storageClass` | StorageClass for the PVCs | String | `""` |
| `app.persistence.accessModes` | Access modes for the PVCs | Array | `["ReadWriteOnce"]` |
| `app.persistence.size` | PVC size | String | `8Gi` |
| `app.persistence.annotations` | Annotations to attach to the persistence objects (PVC and PV) | Dictionary | `{}` |

### Application Resources

| Name | Description | Type | Default Value |
|------|-------------|------|---------------|
| `app.resources.requests.memory` | Amount of memory that the app requests for running. Keep this value low to allow the pod to get admitted on a node. | String | `128Mi` |
| `app.resources.requests.cpu` |  Amount of CPU that the app requests for running. Keep this value low to allow the pod to get admitted on a node. | String | `100m` |
| `app.resources.limits.memory` |  Maximum amount of memory that the app is allowed to use. | String | `512Mi` |
| `app.resources.limits.cpu` | Maximum amount of CPU that the app is allowed to use. | String | `500m` |

### Environment Variables

| Name | Description | Type | Default Value |
|------|-------------|------|---------------|
| `app.environment` | Array of objects, representing additional environment variables to set for the deployment. | Array | `[{name: TIME_ZONE, value: UTC}, {name: ENABLE_EMAIL, value: "False"}]` |

If you are interested in the environment variables that use values from the helm charts, please see [templates/statefulset.yaml](templates/statefulset.yaml).

### PostgreSQL and Redis settings

The application reuses the following settings directly from the Bitnami Helm charts, so you don't have to declare them twice:

#### PostgreSQL

| Name | Description | Type | Default Value |
|------|-------------|------|---------------|
| `postgresql.global.postgresql.postgresqlDatabase` | PostgreSQL database name to use for wger | String | `wger` |
| `postgresql.global.postgresql.postgresqlUsername` | PostgreSQL username to use for wger | String | `wger` |
| `postgresql.global.postgresql.postgresqlPassword` | PostgreSQL password to use for wger | String | `wger` |
| `postgresql.global.postgresql.servicePort` | Port for the PostgreSQL deployment | Integer | `5432` |

#### Redis

| Name | Description | Type | Default Value |
|------|-------------|------|---------------|
| `redis.auth.enabled` | Whether to enable redis login. Currently, only `false` is supported | Boolean | `false` |
| `redis.auth.password` | Password for redis login. Not required if `redis.auth.enabled` is `false` | String | `wger` |
| `redis.master.containerPort` | Port for the Redis deployment | Integer | `6379` |

## Upgrading

To upgrade to a new wger release, all you have to do is change the image that the deployment uses.
Please ensure that the correct input policy has been set.

For PostgreSQL and Redis upgrades, please check the Bitnami documentation, linked at the end of the README.

## Uninstalling

To uninstall a release called `wger`:

```bash
helm delete wger
```

## Contributing

Please check the [contributing guidelines](https://wger.readthedocs.io/en/latest/tips_and_tricks.html#contributing) of the wger project.

Generally:

* if you have a problem, create an issue in [the issue tracker](https://github.com/wger-project/helm-charts/issues)
* if you have a cool idea, create a fork and send pull requests
* assure that your code is well-formed (hint: [`helm lint`](https://helm.sh/docs/helm/helm_lint/) is a useful command). This is enforced using continuous integration.

## Developing locally

In order to develop locally, you will need [minikube](https://minikube.sigs.k8s.io/docs/) installed.
It sets a local Kubernetes cluster that you can use for testing the Helm chart.

If this is your first time developing a Helm chart, you'd want to try the following:

```bash
# start minikube
$ minikube start

# deploy the helm chart using the command from above
$ helm dependency update
$ helm upgrade --install wger . --namespace wger --create-namespace

# observe that the pods start correctly
$ kubectl get pods -n wger
NAME                    READY   STATUS    RESTARTS      AGE
wger-app-0              1/1     Running   1 (71s ago)   3m7s
wger-postgresql-0       1/1     Running   3 (88s ago)   22h
wger-redis-master-0     1/1     Running   3 (71s ago)   22h
wger-redis-replicas-0   1/1     Running   3 (71s ago)   22h
wger-redis-replicas-1   1/1     Running   3 (71s ago)   22h
wger-redis-replicas-2   1/1     Running   3 (71s ago)   22h

# read the logs from the pods
$ kubectl logs wger-app-0 -n wger
PostgreSQL started :)
*** Database does not exist, creating one now
Operations to perform:
  Apply all migrations: auth, authtoken, config, contenttypes, core, easy_thumbnails, exercises, gallery, gym, mailer, manager, measurements, nutrition, sessions, sites, weight
Running migrations:
  Applying contenttypes.0001_initial... OK
.....

# if you need to debug something in the pods, you can start a shell
$ kubectl exec -it wger-app-0 -n wger -- bash
wger@wger-app-0:~/src$

# start a local proxy to test the web interface
# Wger will then be available on http://localhost:8001/api/v1/namespaces/wger/services/wger-http:8000/proxy/en
$ kubectl proxy
Starting to serve on 127.0.0.1:8001

# when you are finished with the testing, stop minikube
$ minikube stop

# if you'd like to start clean, you can delete the whole cluster
$ minikube delete
```

## Contact

Feel free to contact us if you found this useful or if there was something that didn't behave as you expected. We can't fix what we don't know about, so please report liberally. If you're not sure if something is a bug or not, feel free to file a bug anyway.

* discord: https://discord.gg/rPWFv6W
* issue tracker: https://github.com/wger-project/helm-charts/issues
* twitter: https://twitter.com/wger_project

## Additional information

* [Bitnami PostgreSQL chart](https://github.com/bitnami/charts/tree/master/bitnami/postgresql)

* [Bitnami Redis chart](https://github.com/bitnami/charts/tree/master/bitnami/redis)
