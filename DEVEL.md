# Development Setup

The following is done on a Fedora Desktop to run a minikube rootless setup. For setting it up you need administrative rights.

## Prepare the system

The network namespace of the Node components has to have a non-loopback interface, which can be for example configured with slirp4netns, VPNKit, or lxc-user-nic(1).

Let's install the network component `slirp4netns`

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

Check your `~/.kube` folder if you have a old minikube config and (re)move it.

```bash
wget https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 -O ~/bin/minikube
chmod 755 ~/bin/minikube

minikube config set rootless true
minikube config set driver podman
minikube config set container-runtime containerd

minikube start --cni calico
```

Download `kubectl`, into `~/bin`:

```bash
wget "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" -O ~/bin/kubectl
```

Download `helm`, into `~/bin`:

```bash
export HELM_INSTALL_DIR=~/bin; export USE_SUDO=false; curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

In your `~/.kube/config` set the IP of your host instead of `127.0.0.1`, to make helm work (may not be neccessary).

## Setup wger

First clone the `wger-helm-charts` repository and optionally create your own values file based on `example/devel.yaml`:

```bash
git clone https://github.com/wger-project/helm-charts.git
cd helm-charts
```

Deploy the helm chart from your local files:

```bash
cd charts/wger
helm dependency update
helm upgrade --install wger . -n wger --create-namespace -f ../../example/devel.yaml
```

To access the webinterface, you can port forward `8080` from the wger app to a port on your machine, be aware you need a high port number, which doesn't require root priviledges.

Also note you need to connect to the container port directly not the service port.

```bash
export POD=$(kubectl get pods -n wger -l "app.kubernetes.io/name=wger-app" -o jsonpath="{.items[0].metadata.name}")
echo "wger runs on: http://localhost:10001"; kubectl -n wger port-forward ${POD} 10001:8080
```

Go to http://localhost:10001 and login as `admin` `adminadmin` ;-)

## Uninstall wger

To uninstall:

```bash
helm -n wger uninstall wger
kubectl delete ns wger
```

## Stop and remove minikube setup

You can delete the whole cluster, including your config settings:

```bash
minikube delete
```

