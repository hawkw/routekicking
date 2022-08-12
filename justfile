export LINKERD2_VERSION := "edge-22.8.2"
cluster := "routekicking"

_ctx := "k3d-" + cluster
_rootdir := `pwd`
export INSTALLROOT := _rootdir + "/.linkerd2"
_l5d := INSTALLROOT + "/bin/linkerd" + " --context " + _ctx
_kubectl := "kubectl --context " + _ctx
_cat := ```
    if command -v bat >/dev/null 2>&1; then
        echo "bat --pager=never "
    else
        echo "cat"
    fi
    ```

# lists available recipes
default:
    @just --list

# run a GET request the provided `path` from the provided curl `pod`
curl pod path:
    {{ _kubectl }} exec curl-{{ pod }} -it \
        --container curl \
        -- /bin/sh -c 'curl -v http://hokay:8080{{ path }}'


# apply a Kubernetes manifest to the cluster
apply manifest *args='':
    @{{ _cat }} {{ manifest }}
    {{ _kubectl }} apply -f {{ manifest }} {{ args }}

# run a Linkerd command
linkerd *args: _install-cli
    @{{ _l5d }} {{ args }}

# run a kubectl command
kubectl *args:
    @{{ _kubectl }} {{ args }}

# set up a k3d cluster
k3d-create:
    #!/usr/bin/env bash
    set -euo pipefail
    set -x

    # make sure a k3d cluster exists
    if ! k3d cluster list {{ cluster }} >/dev/null 2>/dev/null; then
        k3d cluster create {{ cluster }}
    else
        k3d kubeconfig merge "$cluster"
    fi

# tear down the k3d cluster
k3d-delete:
    k3d cluster delete {{ cluster }}

# create a k3d cluster and install linkerd
setup: k3d-create && install-linkerd install-viz

# watch authzs for the named resource
watch-authz resource namespace='':
    watch --interval 1 {{ _l5d }} \
    {{ if namespace != '' { '--namespace ' + namespace } else { '' } }} \
    viz authz {{ resource }}

# install linkerd in the k3d cluster
install-linkerd: _install-cli
    {{ _l5d }} check --pre
    {{ _l5d }} install  --crds | {{ _kubectl }} apply -f -
    {{ _l5d }} install | {{ _kubectl }} apply -f -
    {{ _l5d }} check

# install the linkerd-viz extension in the k3d cluster
install-viz: _install-cli
    {{ _l5d }} viz install | {{ _kubectl  }} apply -f -
    {{ _l5d }} viz check

install-booksapp:
    {{ _kubectl }} create ns booksapp
    {{ _l5d }} inject booksapp/booksapp.yml | {{ _kubectl }} -n booksapp apply -f -
    {{ _kubectl }} -n booksapp rollout status deploy/webapp
    {{ _kubectl }} -n booksapp get po

# install the linkerd cli
_install-cli:
    #!/usr/bin/env bash
    set -euo pipefail

    mkdir -p "$INSTALLROOT"

    if [[ ! -x "${INSTALLROOT}/bin/linkerd" ]]; then
        curl --proto '=https' --tlsv1.2 -sSfL https://run.linkerd.io/install | sh
    fi
