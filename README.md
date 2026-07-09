# ecommerce-infrastructure

Deployment and shared-CI repository for the ecommerce platform. This is **not a service** — it
owns no runtime business logic. It packages every deployable, defines the local and production
environments, and is the single source of truth for CI/CD across the workspace.

## Contents

| Path | What it is |
|---|---|
| `helm/` | One thin Helm chart per deployable (5 Go services, 3 Nuxt UIs) plus a shared library chart (`shared-helpers`) that holds all the real template logic. |
| `environments/local/` | Local dev stack: **k3d + Tilt + docker-compose**. |
| `environments/production/` | Live **Hetzner k3s** environment: values, raw manifests, SOPS secrets, and an ops Makefile driven over an SSH tunnel. |
| `docker/` | Dockerfiles used by **release CI** (`Dockerfile.go`, `.nuxt`, `.seeder`, `.logto-seed`). |
| `cmd/seeder/` | Standalone Go program (own module) that seeds demo data into a tenant via the service APIs. |
| `cmd/logto-seed/` | Standalone Go program (own module) that bootstraps Logto and writes credentials into a k8s Secret. |
| `.github/workflows/` | **Reusable** (`workflow_call`) workflows called by every service/UI/api repo. |

## Helm: thin-chart / library-chart pattern

All template logic lives in `helm/shared-helpers` (a Helm **library** chart, `type: library`).
Every app chart is deliberately thin — its `templates/*.yaml` are one-line `include` calls into
`shared.*` definitions, and its `values.yaml` supplies the knobs.

- **To change how *all* services deploy** (probes, config mounting, pod spec, labels), edit
  `helm/shared-helpers/templates/_*.tpl` — this affects every chart at once.
- **To change one service**, edit that chart's `values.yaml`, or the per-environment values
  under `environments/*/values/`.
- After changing `shared-helpers`, **bump its `version:`**, update the `dependencies` pin in each
  consuming `Chart.yaml`, and run `helm dependency update`. Locally the `Tiltfile` runs
  `helm dependency build` automatically.
- Charts vendor the built library under `charts/*.tgz` — git-ignored, rebuilt on demand. Never
  hand-edit `charts/*.tgz` or `Chart.lock`.

### Values layering

A chart's own `values.yaml` holds safe defaults (image repo, probes, `service.port: 8080`,
ingress disabled). The real config is layered per environment:

- **Local**: `environments/local/values/<chart>.yaml` (+ `values.debug.yaml` for Go services,
  which wires Delve). The full app config (`mongo`, `kafka`, `security.jwks`, `observability`,
  `tenant.grpc`) is passed as a `config:` block mounted as a ConfigMap at `/configs/config.yaml`.
- **Prod**: `environments/production/values/<chart>.yaml`.

## Two sets of Dockerfiles

There are two `Dockerfile.go` (and friends), and they are **not** the same:

| Path | Used by | Behavior |
|---|---|---|
| `docker/Dockerfile.go` | **release CI** (`go-release.yml`) | Pins `go.mod` versions; multi-target (`base-release` / `debug-release`); distroless. Consumed via checkout of this repo into `infra/`, so paths like `infra/docker/Dockerfile.go` are load-bearing. |
| `environments/local/docker/Dockerfile.go` | **Tilt** (local) | Reconstructs a `go.work` inside the image from local sources. Tilt passes `API_DEPS`, the Dockerfile `go work use`s each api module — so local api changes flow into the image with no release/tag/bump. Bundles Delve; ubuntu runtime. |

If you add an api dependency to a service, update its `api_deps` in the `Tiltfile` or the local
build fails with "API dependency not found".

## Local environment

Run everything from `environments/local/`. Requires `k3d kubectl tilt helm docker`
(`make tools-check`).

```bash
make init      # one-time: create k3d cluster + inject host CA + install Traefik + Alloy
make dev       # tilt up — starts docker-compose deps AND builds/deploys all services with hot-reload
make up/down   # start/stop the cluster (keeps data)
make clean     # tear everything down (cluster, infra, volumes)
make urls      # print every URL + demo creds
```

`make dev` is all you need day-to-day: the `Tiltfile` brings up the docker-compose deps (Mongo,
Redpanda, MinIO + imgproxy, Grafana stack, Logto) via `docker_compose(...)`. `make docker` starts
those same deps **without** Tilt (e.g. running a service from your IDE against local infra).

Layout:

- **k3d cluster** (`k3d-cluster.yaml`, context `k3d-dev-cluster`, namespace `dev`). Traefik and
  Grafana Alloy are installed as Helm charts by `make init` / `make up`.
- **Heavy deps run in docker-compose, not k8s** (`compose/*.yml`), on an external
  `shared-network`.
- **Services + UIs run in k8s via Tilt**, built from the local Dockerfiles. Go services expose
  Delve on per-service ports (`2345`–`2352`, see `GO_SERVICES` in the `Tiltfile`).
- Ingress via Traefik at `*.127.0.0.1.nip.io`; Tilt dashboard at `localhost:10350`.
- **Dependency ordering**: `logto-seed` (compose) creates the `logto-credentials` k8s Secret;
  every service `resource_deps` on it. Don't remove that edge or services start without auth
  creds.

The host CA cert (`certs/ca-certificates.crt`, copied from `/etc/ssl/certs` at Tilt startup and
baked into images) exists for a corporate TLS-interception proxy. It's git-ignored.

## Production environment

Live target: a single **Hetzner VPS running k3s** (not k3d), namespaces `prod` +
`observability`. Heavy deps are **managed external services** (MongoDB Atlas, Cloudflare R2,
Grafana Cloud via an Alloy DaemonSet); Redpanda, imgproxy, Logto, Postgres, and Traefik +
cert-manager run in-cluster. Run everything from `environments/production/`.

**kubectl needs an SSH tunnel** — there is no public k3s API endpoint:

```bash
make kubeconfig   # once: fetch k3s.yaml → ~/.kube/config-hetzner
make tunnel       # open SSH tunnel to :6443 (host alias "hetzner")
make status | health | events | logs SVC=catalog-service
make deploy-svc SVC=catalog-service [TAG=0.1.9]   # manual hotfix deploy (fallback)
make seed TENANT_SLUG=<slug>                       # trigger seeder Job from the CronJob
make logto-seed                                    # one-time Logto config Job
```

**Deploys are normally automated CD, not `make deploy-svc`.** A service release triggers the
reusable `.github/workflows/deploy.yml`, which checks out this repo and `helm upgrade`s
`helm/<service>` into `prod` with `environments/production/values/<service>.yaml` and
`--set image.tag=<release>`. `make deploy-svc` is the manual fallback for hotfixes.

**Secrets are SOPS-encrypted** (`k8s/secrets.enc.yaml`, age key in `.sops.yaml`, only the `data`
field encrypted). Never commit decrypted secrets or write them to disk.

```bash
make secrets-view    # decrypt to stdout only
make secrets-edit    # edit in place
make setup-secrets   # sops decrypt | kubectl apply
```

## CI/CD: reusable workflows

Everything in `.github/workflows/` is `workflow_call`-triggered and **called by the other repos**
— editing them changes CI for the entire workspace, so treat changes as cross-cutting.

| Workflow | Purpose |
|---|---|
| `go-ci.yml` | Lint (gofmt + goimports + golangci-lint) + test (`-race`, coverage threshold) + govulncheck. Called by every Go service/api repo. |
| `nuxt-ci.yml` | pnpm lint + typecheck + build. |
| `go-release.yml` / `nuxt-release.yml` | Build image via the **release** Dockerfile here, Trivy-scan (fails on HIGH/CRITICAL), push to `ghcr.io/sokol111/<repo>`, tag + GitHub Release. |
| `api-release.yml` | For `-api` repos: buf breaking-change check, verify `gen/` is current, publish the TS package, tag + release. |
| `deploy.yml` | The CD entrypoint (see Production above). |
| `seeder-release.yml` / `logto-seed.yml` | Build & push the two `cmd/` images; `logto-seed.yml` also runs the Job against prod. |

Images are published to `ghcr.io/sokol111/*`. Versions come from a repo's `VERSION` file (Go) or
`package.json` (Nuxt); release jobs refuse to run if the tag already exists.

## Seeders (`cmd/`)

Each is a **separate Go module** (own `go.mod`), not part of the root `go.work`.

- **`cmd/seeder`** — loads `data/*.json` (products, categories, attributes) + `assets/*.jpg`,
  then drives the services' APIs to populate a tenant. Runs as a k8s CronJob defined in the
  tenant-service chart (`helm/ecommerce-tenant-service/templates/seeder-cronjob.yaml`); trigger a
  one-off with `make seed TENANT_SLUG=<slug>`. Image: `ecommerce-seeder`.
- **`cmd/logto-seed`** — bootstraps Logto (applications, M2M creds, resources) from `seed.json`,
  writing results into a k8s Secret via client-go. Image: `ecommerce-logto-seed`.

## Conventions & gotchas

- **Commit per-repo.** This repo is independent; a change here that supports a service change is a
  separate commit from the service repo's.
- **Never hand-edit `charts/*.tgz`, `Chart.lock`, or anything git-ignored** — regenerate with helm.
- **YAML is 2-space** (`.editorconfig`); Makefiles are tab-indented. Both env Makefiles use strict
  shell flags (`-eu -o pipefail`), and the local Makefile treats undefined make vars as errors.
- When adding a **new deployable**: create `helm/<name>/` (thin chart depending on
  `shared-helpers`), add per-env values under `environments/*/values/<name>.yaml`, register it in
  the `Tiltfile` (`GO_SERVICES` or `UI_SERVICES`, with `api_deps`), and add it to the prod
  `SERVICES` list in `environments/production/makefiles/deploy.mk`.
- `docs/kubectl-cheatsheet.md` has handy prod inspection commands.
