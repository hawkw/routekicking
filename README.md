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
   /home/eliza/Code/routekicking/.linkerd2/bin/linkerd --context k3d-routekicking viz authz deploy/authors -n booksapp
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

   note that requests from the `books` service to `authors` are still
   succeeding:

   ```shell
   :; just linkerd viz stat deploy/books -n booksapp
   /home/eliza/Code/routekicking/.linkerd2/bin/linkerd --context k3d-routekicking viz stat deploy/books -n booksapp
   NAME    MESHED   SUCCESS      RPS   LATENCY_P50   LATENCY_P95   LATENCY_P99   TCP_CONN
   books      1/1   100.00%   0.4rps           1ms           1ms           1ms          6
   ```