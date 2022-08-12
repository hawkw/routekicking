## steps

0. **setup**
  create cluster (`k3d`), install linkerd + viz

  ```console
  just setup
  ```

1. **deploy hokay & curl**

   ```console
   just apply manifests/hokay.yml
   ```

   curl pod without linkerd injected:
   ```console
   just apply manifests/curl-uninjected.yml
   ```

   curl pod with linkerd, but an unauthenticated service account:
   ```console
   just apply manifests/curl-no-authz.yml
   ```

   curl pod with a service account that will be authenticated:
   ```console
   just apply manifests/curl-authz.yml
   ```

2. **unauthenticated reqs are permitted**
   ```console
   # should succeed
   just curl uninjected /hello
   just curl uninjected /world
   ```

   ```console
   # should also succeed
   just curl no-authz /hello
   just curl no-authz /world
   ```

   ```console
   # also succeeds
   just curl authz /hello
   just curl authz /world
   ```

3. **create policies**
   ```console
   just apply manifests/policy.yml
   ```

   in another terminal, you may want to run:
   ```
   just watch-authz deploy/hokay
   ```

4. **allow any authenticated to reach `/hello`**:
   ```console
   just apply manifests/hello-rt.yml
   ```

   meshed curls can access `/hello`:
   ```console
   just curl authz /hello
   just curl no-authz /hello
   ```

   unmeshed curl fails (should get a 403 Forbidden):
   ```console
   just curl uninjected /hello
   ```

   no one can access `/world` (will fail with 404 as the route is not found):
   ```console
   just curl authz /world
   just curl no-authz /world
   just curl uninjected /world
   ```

4. **allow only blessed ServiceAccounts to reach `/world`**:
    ```console
   just apply manifests/world-rt.yml
   ```

   blessed curl can access `/world`:
   ```console
   just curl authz /world
   ```

   nothing else can access `/world` (will fail with 403 Forbidden):
   ```console
   just curl no-authz /world
   just curl uninjected /world
   ```