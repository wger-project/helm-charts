# Development Setup

The following is done on a Fedora Desktop to run a minikube rootless setup. For setting it up you need administrative rights.

## Prepare the system

First install the required network component `slirp4netns`

```bash
sudo dnf install slirp4netns
```

Now map additional UIDs and GIDs for your user, to be able to use the users IDs from inside the containers.

* https://docs.podman.io/en/latest/markdown/podman.1.html?highlight=rootless#rootless-mode

Map additional UID/GID for your user:

```bash
sudo usermod --add-subuids 10000-75535 USERNAME
sudo usermod --add-subgids 10000-75535 USERNAME
```

So this was the only parts where root priviledges are needed.

## Prepare minicube

Now install and setup minikube with the calico network driver. Assuming you have `~/bin` in your `$PATH` environment variable.

```bash
wget https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 -O ~/bin/minikube
chmod 755 ~/bin/minikube

minikube config set rootless true
minikube config set driver podman
minikube config set container-runtime containerd

minikube start --cni calico
```

Now you have a running cluster on your machine.

Minikube comes with a integrated `kubectl` command. So you can run `kubectl` commands, without downloaded `kubectl` binary:

```bash
minikube kubectl -- get pods -A
```

But for using `helm` and our convenience, we install `kubectl` alongside `minikube`:

```bash
wget "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" -O ~/bin/kubectl
```

Finally we install `helm`, into `~/bin`:

```bash
export HELM_INSTALL_DIR=~/bin; export USE_SUDO=false; curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

## Setup wger

You can install wger without any changes to the `values.yaml`, this will run wger in development mode.

First clone the `wger-helm-charts` repository and optionally create `your_values.yaml` file:

```bash
git clone https://github.com/wger-project/helm-charts.git
cd helm-charts
vi your_values.yaml
```

The following is a example of `your_values.yaml`:

```yaml
app:
  environment:
      # x-real-ip - remote ip - x-forward-for  -
    - name: GUNICORN_CMD_ARGS
      value: "--timeout 240 --workers=2 --access-logformat '%({x-real-ip}i)s %(l)s %(h)s %(l)s %({x-forwarded-for}i)s %(l)s %(t)s \"%(r)s\" %(s)s %(b)s \"%(f)s\" \"%(a)s\"' --access-logfile - --error-logfile -"
  nginx:
    enabled: true
  axes:
    enabled: true
celery:
  enabled: true
  flower:
    enabled: true
```

Deploy the helm chart from the cloned git repo. Omit `-f ../../your_values.yaml` when you don't have the file:

```bash
cd helm-charts/charts/wger
helm dependency update
helm upgrade --install wger . -n wger --create-namespace -f ../../your_values.yaml
```

To access the webinterface, you can port forward `8000` from the wger app to a port on your machine, be aware you need a high port number, which doesn't require root priviledges.

```bash
export POD=$(kubectl get pods -n wger -l "app.kubernetes.io/name=wger-app" -o jsonpath="{.items[0].metadata.name}")
echo "wger runs on: http://localhost:10001"; kubectl -n wger port-forward ${POD} 10001:8000
```

Go to http://localhost:10001 and login as `admin` `adminadmin` ;-)

## Advanced Setup

Install the local-path storage provisioner from ranger to later add your local wger code in a volume:

```bash
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.25/deploy/local-path-storage.yaml
```

When you activated `nginx` persistent storage will be automatically activated as a requirement. You can see the volumes (pv) and it's claims (pvc):

```bash
kubectl get pv
kubectl get pvc -n wger
```

There is a special claim `code` which will not be created but will overload the wger django code, this can be used to mount your local development code into the setup.

Add the following to `your_values.yaml`.

```yaml
app:
  persistence:
    existingClaim:
      code: wger-code
```

Manually create a volume and claim for your local wger code. For this add a new file `wger-code.yaml` and apply it to the cluster:

```yaml
TBD
```

```bash
kubectl apply -n wger -f ../../wger-code-volume.yaml
```

Activate the new values with the `wger-code` volume in the containers:

```bash
helm upgrade --install wger . -n wger --create-namespace -f ../../your_values.yaml
```

## Uninstall wger

To uninstall:

```bash
helm -n wger uninstall wger
kubectl -n wger delete -f ../../wger-code-volume.yaml
kubectl delete ns wger
```

