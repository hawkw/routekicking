# linkerd route policy testing/demos

## requirements

to run these demos, you will need:
- `just`, a task runner: https://just.systems/
- a Kubernetes cluster:
  + the justfile will automatically set up a `k3d` cluster if you have `k3d` on your machine: https://k3d.io/v5.4.4/
  + or, configure your own kubernetes cluster some other way
  
## hokay demo

0. **setup**
   create cluster (`k3d`), install linkerd + viz

   ```shell
   :; just setup
   ```

1. **deploy hokay & curl**

   ```shell
   :; just apply manifests/hokay.yml
   ```

   curl pod without linkerd injected:
   ```shell
   :; just apply manifests/curl-uninjected.yml
   ```

   curl pod with linkerd, but an unauthenticated service account:
   ```shell
   :; just apply manifests/curl-no-authz.yml
   ```

   curl pod with a service account that will be authenticated:
   ```shell
   :; just apply manifests/curl-authz.yml
   ```

2. **unauthenticated reqs are permitted**
   ```shell
   # should succeed
   :; just curl uninjected /hello
   :; just curl uninjected /world
   ```

   ```shell
   # should also succeed
   :; just curl no-authz /hello
   :; just curl no-authz /world
   ```

   ```shell
   # also succeeds
   :; just curl authz /hello
   :; just curl authz /world
   ```

3. **create policies**
   ```shell
   :; just apply manifests/policy.yml
   ```

   in another terminal, you may want to run:
   ```
   :; just watch-authz deploy/hokay
   ```

4. **allow any authenticated to reach `/hello`**:
   ```shell
   :; just apply manifests/hello-rt.yml
   ```

   meshed curls can access `/hello`:
   ```shell
   :; just curl authz /hello
   :; just curl no-authz /hello
   ```

   unmeshed curl fails (should get a 403 Forbidden):
   ```shell
   :; just curl uninjected /hello
   ```

   no one can access `/world` (will fail with 404 as the route is not found):
   ```shell
   :; just curl authz /world
   :; just curl no-authz /world
   :; just curl uninjected /world
   ```

4. **allow only blessed ServiceAccounts to reach `/world`**:
    ```shell
   :; just apply manifests/world-rt.yml
   ```

   blessed curl can access `/world`:
   ```shell
   :; just curl authz /world
   ```

   nothing else can access `/world` (will fail with 403 Forbidden):
   ```shell
   :; just curl no-authz /world
   :; just curl uninjected /world
   ```

## booksapp demo

this is more of a "real world" demo of per-route policy that may be useful for
docs etc.

0. **setup**

   create cluster (`k3d`), install linkerd + viz (skip this step if the cluster
   already exists)

   ```shell
   :; just setup
   ```

1. **install booksapp**
   ```shell
   :; just install-booksapp
   ```

2. **create policy resources for `authors` svc**

   both the `books` service and the `webapp` service are clients of the
   `authors` service. however, the `books` service should only send `GET`
   requests to the `/authors/:id.json` route, while the `webapp` service may
   also send `DELETE` requests, if the user deletes an existing author.

   therefore, we'll create separate MeshTLSAuthentication resources for the
   `books` and `webapp` services.

   first, let's see what's currently going on:
   ```shell
   :; just linkerd viz authz deploy/authors -n booksapp
   ```

   output should look sorta like this
   ```shell
   ROUTE    SERVER          AUTHORIZATION_POLICY  SERVER_AUTHORIZATION  SUCCESS     RPS  LATENCY_P50  LATENCY_P95  LATENCY_P99
   probe    authors-server                                              100.00%  0.1rps          1ms          1ms          1ms
   default  authors-server  [UNAUTHORIZED]        [UNAUTHORIZED]              -  9.8rps            -            -            -
   ```

   create Server resource for `authors`:
   ```shell
   :; just apply booksapp/authors-policy.yml -n booksapp
   ```

   create HTTPRoute, AuthorizationPolicy, and MeshTLSAuthentication resources
   for `GET /authors`:
   ```shell
   :; just apply booksapp/authors-get.yml
   ```

   this will allow both the `webapp` and `books` ServiceAccounts to send `GET`
   requests to `authors`.

   because we've created an HTTPRoute for `authors`, the default route for probes
   will no longer be used, so we must create one as well:
   ```shell
   :; just apply booksapp/authors-probe.yml
   ```

   we now have two AuthorizationPolicy resources defined for `authors`:
   ```shell
   :; just linkerd authz -n booksapp deploy/authors
   ROUTE                SERVER          AUTHORIZATION_POLICY   SERVER_AUTHORIZATION
   authors-get-route    authors-server  authors-get-policy
   authors-probe-route  authors-server  authors-probe-policy
   ```

   note that requests from the `books` service to `authors` are still
   succeeding:

   ```shell
   :; just linkerd viz stat deploy/books -n booksapp
   /home/eliza/Code/routekicking/.linkerd2/bin/linkerd --context k3d-routekicking viz stat deploy/books -n booksapp
   NAME    MESHED   SUCCESS      RPS   LATENCY_P50   LATENCY_P95   LATENCY_P99   TCP_CONN
   books      1/1   100.00%   0.4rps           1ms           1ms           1ms          6
   ```

3. **create additional policy for mutating `authors`**

   however, if we port forward to the web UI, we'll notice that we can no longer
   add or delete authors:
   ```shell
   :; kubectl -n booksapp port-forward svc/webapp 7000 &
   open http://localhost:700
   ```

   this is because the existing authorization policy only authorizes the `GET
   /authors.json` and `GET /authors/:id.json` routes.

   apply the HTTPRoute and AuthorizationPolicy that will authorize *only* the
   `webapp` ServiceAccount to `DELETE` and `PUT` to `/authors/:id.json` and
   `POST /authors.json`:

   ```shell
   :; just apply booksapp/authors-modify.yml
   ```

   ```shell
   :; just linkerd authz -n booksapp deploy/authors
   ROUTE                 SERVER          AUTHORIZATION_POLICY   SERVER_AUTHORIZATION
   authors-probe-route   authors-server  authors-probe-policy
   authors-modify-route  authors-server  authors-modify-policy
   authors-get-route     authors-server  authors-get-policy
   ```

   now, we can create and delete books from the web UI, but no other ServiceAccounts
   will be authorized to create, delete, or modify authors.

4. **now you try!**

   we've now restricted which ServiceAccounts are permitted to access various
   routes on the `authors` service. next, we might similarly want to restrict
   access to the `books` service.
