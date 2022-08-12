## steps

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