# skyportal-k8s-deploy

Helm chart for [SkyPortal](https://github.com/skyportal/skyportal) on Kubernetes, **split across
pods** (app / message-bus / workers + in-cluster Postgres) using baselayer's TCP message bus. 


## Setup

The following is a sample sequence of deployment.

```bash
export NS=skyportal; kubectl create namespace $NS

# 1. Image — build for the cluster's arch (amd64) or pods exec-format-error.
git submodule update --init --recursive
docker buildx build --platform linux/amd64 -t ghcr.io/<org>/skyportal:<tag> --push .
#    Make the ghcr package PUBLIC (the org "allow public" toggle alone isn't enough) or add an imagePullSecret.

# 2. Google OAuth client (console.cloud.google.com -> Credentials -> Web app):
#      JS origin https://<host> ; redirect URI https://<host>/complete/google-oauth2/

# 3. Secret + values
cp secrets.example.yaml secrets.yaml          # fill: postgres-password, app.secret_key,
kubectl apply -n $NS -f secrets.yaml          #   server.host/port:443/ssl, the Google key+secret.
#    values: image.{repository,tag}; persistentData.storageClassName=<RWX class>;
#            postgres.storage.storageClassName=<RWO> (empty=default); ingress.{className,host}.

# 4. Deploy
helm install skyportal ./chart -n $NS -f my-values.yaml --set image.tag=<tag>

# 5. Schema (fresh DB is empty; make checks `nginx -v`, which lives at /usr/sbin)
APP=$(kubectl -n $NS get pod -l skyportal.role=app -o jsonpath='{.items[0].metadata.name}')
kubectl -n $NS exec "$APP" -- bash -lc \
  'cd /skyportal && . .venv/bin/activate && export PATH=/usr/sbin:$PATH && make db_init && make db_create_tables'
#    optional seed: append `&& make load_seed_data` (telescopes/instruments) or `load_demo_data`.

# 6. Admin + login
kubectl -n $NS exec "$APP" -- bash -lc \
  'cd /skyportal && . .venv/bin/activate && export PATH=/usr/sbin:$PATH && PYTHONPATH=. python skyportal/initial_setup.py $FLAGS --adminusername=<your-google-email>'
kubectl -n $NS exec skyportal-postgres-0 -- psql -U skyportal -d skyportal -c \
  "UPDATE users u SET oauth_uid = s.uid FROM usersocialauths s WHERE s.user_id = u.id;"
#    Then Login -> Google at https://<host> as Super admin.
```

