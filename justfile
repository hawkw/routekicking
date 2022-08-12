export LINKERD2_VERSION := "edge-22.8.2"
cluster := "routekicking"

_ctx := "k3d-" + cluster
_rootdir := `pwd`
export INSTALLROOT := _rootdir + "/.linkerd2"
_l5d := INSTALLROOT + "/bin/linkerd"
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
    kubectl exec curl-{{ pod }} -it \
        --context {{ _ctx }} \
        --container curl \
        -- /bin/sh -c 'curl -v http://hokay:8080{{ path }}'


# apply a Kubernetes manifest to the cluster
apply manifest:
    @ {{ _cat }} {{ manifest }}
    kubectl apply --context {{ _ctx }} -f {{ manifest }}

# run a Linkerd command
linkerd *args: _install-cli
    {{ _l5d }} --context {{ _ctx }} {{ args }}

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
watch-authz resource:
    watch --interval 1 {{ _l5d }} --context {{ _ctx }} viz authz {{ resource }}

# install linkerd in the k3d cluster
install-linkerd: _install-cli
    {{ _l5d }} --context {{ _ctx }} check --pre
    {{ _l5d }} install --context {{ _ctx }} --crds | kubectl apply --context {{ _ctx }} -f -
    {{ _l5d }} install | kubectl apply --context {{ _ctx }} -f -
    {{ _l5d }} --context {{ _ctx }} check

# install the linkerd-viz extension in the k3d cluster
install-viz: _install-cli
    {{ _l5d }} --context {{ _ctx }} viz install | kubectl apply -f -
    {{ _l5d }} --context {{ _ctx }} viz check

# install the linkerd cli
_install-cli:
    #!/usr/bin/env bash
    set -euo pipefail

    mkdir -p "$INSTALLROOT"

    if [[ ! -x {{ _l5d }} ]]; then
        curl --proto '=https' --tlsv1.2 -sSfL https://run.linkerd.io/install | sh
    fi
