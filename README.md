## steps

0. **setup**
  create cluster (`k3d`), install linkerd + viz

  ```console
  :; bin/setup
  ```

1. **deploy hokay & curl**

   ```console
   :; kubectl apply -f manifests/hokay.yml
   ```

   curl pod without linkerd injected:
   ```console
   :; kubectl apply -f manifests/curl-no-linkerd.yml
   ```

   curl pod with linkerd, but an unauthenticated service account:
   ```console
   :; kubectl apply -f manifests/curl-no-authz.yml
   ```

    curl pod with a service account that will be authenticated:
   ```console
   :; kubectl apply -f manifests/curl-authz.yml
   ```

2. **unauthenticated reqs are permitted**
   ```console
   # should succeed
   :; kubectl exec curl-uninjected -it -- /bin/sh -c 'curl -v http://hokay:8080/hello'
   :; kubectl exec curl-uninjected -it -- /bin/sh -c 'curl -v http://hokay:8080/world'
   ```

   ```console
   # should also succeed
   :; kubectl exec curl-no-authz -c curl -it -- /bin/sh -c 'curl -v http://hokay:8080/hello'
   :; kubectl exec curl-no-authz -c curl -it -- /bin/sh -c 'curl -v http://hokay:8080/world'
   ```

   ```console
   # also succeeds
   :; kubectl exec curl-authz -c curl -it -- /bin/sh -c 'curl -v http://hokay:8080/hello'
   :; kubectl exec curl-authz -c curl -it -- /bin/sh -c 'curl -v http://hokay:8080/world'
   ```

3. **create policies**
   ```console
   :; kubectl apply -f manifests/policy.yml
   ```

4. **allow any authenticated to reach `/hello`**:
    ```console
   :; kubectl apply -f manifests/hello-rt.yml
   ```

   meshed curls can access `/hello`:
   ```console
   :; kubectl exec curl-no-authz -c curl -it -- /bin/sh -c 'curl -v http://hokay:8080/hello'
   :; kubectl exec curl-authz -c curl -it -- /bin/sh -c 'curl -v http://hokay:8080/hello'
   ```

   unmeshed curl fails (should get a 403 Forbidden):
   ```console
   :; kubectl exec curl-uninjected -c curl -it -- /bin/sh -c 'curl -v http://hokay:8080/hello'
   ```

   no one can access `/world` (will fail with 404 as the route is not found):
   ```console
   :; kubectl exec curl-no-authz -c curl -it -- /bin/sh -c 'curl -v http://hokay:8080/world'
   :; kubectl exec curl-authz -c curl -it -- /bin/sh -c 'curl -v http://hokay:8080/world'
   :; kubectl exec curl-uninjected -c curl -it -- /bin/sh -c 'curl -v http://hokay:8080/world'
   ```

4. **allow only blessed ServiceAccounts to reach `/world`**:
    ```console
   :; kubectl apply -f manifests/world-rt.yml
   ```

   blessed curl can access `/world`:
   ```console
   :; kubectl exec curl-authz -c curl -it -- /bin/sh -c 'curl -v http://hokay:8080/hello'
   ```

    nothing else can access `/world` (will fail with 403 Forbidden):
   ```console
   :; kubectl exec curl-no-authz -c curl -it -- /bin/sh -c 'curl -v http://hokay:8080/world'
   :; kubectl exec curl-uninjected -c curl -it -- /bin/sh -c 'curl -v http://hokay:8080/world'
   ```