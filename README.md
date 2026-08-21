# PhoenixApp

A batteries-included Phoenix 1.7 / LiveView 1.0 application: authentication and
account security, a CMS, a storefront, a forum, real-time chat, a windowed
"desktop" UI, a job scheduler, a GraphQL endpoint, and a multiplayer **games
platform API** — deployed to Kubernetes with kustomize overlays.

It is a working application (it runs phxlive.net), published so it can be read,
forked and stripped for parts. **It is a monolith, not a generator.** There is no
`mix phx.new.batteries` here — you clone it, delete the contexts you do not want,
and keep the ones you do. The sections below are organised to make that
practical: each subsystem says what it is and roughly what removing it costs.

---

## Contents

- [What's in the box](#whats-in-the-box)
- [Requirements](#requirements)
- [Quick start](#quick-start)
- [Configuration](#configuration)
- [Architecture](#architecture)
- [HTTP API](#http-api)
- [Assets](#assets)
- [Testing and linting](#testing-and-linting)
- [Deployment](#deployment)
- [Operations](#operations)
- [Security notes](#security-notes)
- [Using this as a starting point](#using-this-as-a-starting-point)
- [License](#license)

---

## What's in the box

| Subsystem | What it gives you | Where |
|---|---|---|
| **Accounts & auth** | Registration, email verification by 6-digit code, login by email *or* username, password reset, Guardian JWT sessions, 2FA scaffolding | `lib/phoenix_app/accounts`, `auth` |
| **Account security** | Login-attempt tracking, lockout after repeated failures, device fingerprinting, block/allow identifier lists, behavioural bot signals, IP rate limiting | `lib/phoenix_app/security`, `rate_limiter.ex` |
| **Content / CMS** | Posts, pages, comments, media library with tags, plus a WordPress-shaped `cms_*` set (posts, terms, taxonomies, meta) | `lib/phoenix_app/content` |
| **Commerce** | Products, categories, carts, orders, order items, checkout LiveView | `lib/phoenix_app/commerce` |
| **Forum & social** | Channels, threads, attachments, presence | `lib/phoenix_app/forum`, `social` |
| **Chat** | Phoenix Channels with presence, optional Redis bridge for cross-pod delivery | `lib/phoenix_app_web/channels`, `redis_pubsub.ex` |
| **Desktop UI** | A taskbar-and-windows shell rendered as a global `live_component` on every authenticated page — not a route | `lib/phoenix_app/desktop`, `phoenix_desktop_live.ex` |
| **Scheduler** | Recurring events, manual run/pause/resume, and a secret-authenticated webhook trigger | `lib/phoenix_app/scheduler` |
| **Files & media** | Uploads via Arc, image processing, avatars, user file storage | `lib/phoenix_app/files`, `media_processor.ex` |
| **Notifications & email** | Swoosh + SMTP, HTML templates, delivery logging | `lib/phoenix_app/email`, `notifications` |
| **Moderation & audit** | Audit log, moderation queue, admin LiveViews | `lib/phoenix_app/moderation`, `audit.ex` |
| **GraphQL** | Absinthe schema with Dataloader | `lib/phoenix_app_web/schema.ex`, `resolvers` |
| **Games platform** | Accounts→characters→shards→player-authored world instances, with a Kubernetes launcher. **Its own database.** | `lib/phoenix_app/games` |
| **Kubernetes** | An ~80-line in-cluster API client using the pod's own service account | `lib/phoenix_app/kubernetes.ex` |

The **games platform** is the least generic and the most actively developed part.
If you are here for a web app, it is the first thing to delete — it is cleanly
separated behind its own Ecto repo and its own router scope. If you are here
*because* of it, see [Architecture](#architecture).

---

## Requirements

| | |
|---|---|
| Elixir | `~> 1.19.0` |
| Erlang/OTP | matching your Elixir build |
| Database | PostgreSQL-compatible. Defaults point at host `db`, port `26257` — override for a stock local Postgres (see [Configuration](#configuration)) |
| Node | only inside the assets container — see [Assets](#assets) |
| Redis | optional; enables cross-pod pubsub |
| Docker | recommended for assets; required for the deploy scripts |
| Kubernetes | optional; k3s manifests provided |

---

## Quick start

```bash
git clone https://github.com/ray-rios/phoenixlive
cd phoenixlive

# Point at your database before the first run (see Configuration).
export DB_HOST=localhost DB_PORT=5432 DB_USERNAME=postgres DB_PASSWORD=postgres

mix setup          # deps.get + ecto.setup + assets.setup + assets.build
mix phx.server
```

Then:

| | |
|---|---|
| App | http://localhost:4000 |
| Health check | http://localhost:4000/health |
| GraphiQL (dev only) | http://localhost:4000/api/graphiql |
| MailHog, if you run one | http://localhost:8025 |

`mix setup` runs migrations for **both** repos and seeds the main one.

### Creating a verified user without a mail server

```bash
curl -X POST http://localhost:4000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","name":"TestUser","password":"SecurePass123!"}'

curl -X POST http://localhost:4000/api/auth/dev-verify \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com"}'

curl -X POST http://localhost:4000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"SecurePass123!"}'
```

> **`dev-verify` marks any address verified, without authentication.** It is gated
> on `:allow_dev_verify`, which is set only in `config/dev.exs` and
> `config/test.exs`; in production the route 404s. **Do not "fix" that 404 by
> enabling the flag** — register with someone else's address, call this, log in as
> them is the entire attack.

---

## Configuration

Everything is environment variables. Nothing secret is committed.

### Database

Two independent Ecto repos, two databases.

| Variable | Default | Applies to |
|---|---|---|
| `DB_HOST` | `db` | both |
| `DB_PORT` | `26257` | both |
| `DB_USERNAME` | `root` | both |
| `DB_PASSWORD` | `postgres` | both |
| `DB_NAME` | `phoenixapp_dev` | main repo |
| `GAMES_DB_NAME` | `phoenix_games_dev` | games repo |
| `DATABASE_URL` / `GAMES_DATABASE_URL` | — | production; override the pieces above |
| `POOL_SIZE` | | production pool sizing |

The defaults assume a container named `db` on port 26257. **For a stock local
Postgres set `DB_HOST=localhost` and `DB_PORT=5432`.**

### Secrets — generate these before deploying

```bash
mix phx.gen.secret 64   # SECRET_KEY_BASE
mix phx.gen.secret 32   # LIVE_VIEW_SIGNING_SALT
mix phx.gen.secret      # GUARDIAN_SECRET_KEY
```

| Variable | Purpose |
|---|---|
| `SECRET_KEY_BASE` | Phoenix session/cookie signing |
| `LIVE_VIEW_SIGNING_SALT` | LiveView session signing |
| `GUARDIAN_SECRET_KEY` | JWT signing |
| `GAMES_SERVER_API_KEY` | **Master credential.** Lets its holder act on behalf of *any* user through the games API. Server-side only |
| `PROJECTS_API_KEY` | Read-only access to the calendar/projects endpoint |

### Web, mail, cache

| Variable | Notes |
|---|---|
| `PHOENIX_HOST`, `PORT` | public host and bind port |
| `CORS_ALLOWED_ORIGINS` | comma-separated |
| `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS`, `SMTP_VERIFY` | dev defaults to port 1025 (MailHog) |
| `ENABLE_REDIS`, `REDIS_URL` | set both to bridge pubsub across pods |

### Games platform orchestration

Only read when the app is running inside a cluster.

`HOLOSIM_IMAGE`, `HOLOSIM_IMAGE_PULL_POLICY`, `HOLOSIM_COMMAND`, `HOLOSIM_SECRET_NAME`,
`HOLOSIM_PUBLIC_HOST`, `HOLOSIM_PORT_MIN`, `HOLOSIM_PORT_MAX`, `HOLOSIM_TTL_SECONDS`,
`HOLOSIM_MAX_LIFETIME_SECONDS`

---

## Architecture

### Two databases, on purpose

```
PhoenixApp.Repo          phoenixapp_dev        site: users, content, commerce, forum, …
PhoenixApp.GamesRepo     phoenix_games_dev     games: games, characters, servers, world instances
                         priv/games_repo/migrations
```

Game data is isolated so a game can be wiped, migrated or restored without
touching the website, and so the games API can eventually move to its own service
without a data untangling exercise.

**The consequence to know about:** game tables cannot have a foreign key to
`users`, because `users` lives in the other database. Every `user_id` in
`GamesRepo` is a bare `binary_id`, and referential integrity there is the
application's job. That is a deliberate trade, and it is why the games contexts
always take a `user_id` rather than a `%User{}`.

### Redis is optional and additive

Without it, `Phoenix.PubSub` works normally within one node. With `ENABLE_REDIS`,
a small bridge subscribes to channel patterns (`channel:*`, `presence:channel:*`,
`chat:channels`) and forwards Redis messages into the local PubSub, publishing
outward as well, so several pods see each other's events. Nothing else changes.

### Kubernetes client

`PhoenixApp.Kubernetes` is deliberately ~80 lines against one resource: create a
Job, ask whether it started, delete it. It authenticates with the pod's own
projected service account — nothing to configure, no secret to rotate, identical
in k3s and managed clusters. **It verifies the cluster CA.** Outside a pod,
`in_cluster?/0` reports false and the launcher treats that as "orchestration
unavailable" rather than falling back to something surprising.

---

## HTTP API

All JSON. Authentication is a Guardian bearer token unless stated otherwise.

### Auth

```
POST /api/auth/register             POST /api/auth/verify-code
POST /api/auth/login                POST /api/auth/verify-email
POST /api/auth/logout               POST /api/auth/resend-verification
POST /api/auth/authenticate         POST /api/auth/verify
POST /api/auth/verify-bearer        POST /api/auth/dev-verify      (dev only)
GET  /api/auth/users
```

### Games platform

Under `/api/games/:game_slug`. Accepts a **player bearer token**, or an
`X-API-Key` matching `GAMES_SERVER_API_KEY` for a trusted dedicated game server
acting on a player's behalf (which must also pass `user_id`).

```
GET|POST            /characters
GET|PUT|DELETE      /characters/:id
GET                 /servers
POST                /servers/heartbeat            server key only
POST                /servers/offline              server key only
GET|POST            /holosims
GET|PUT|DELETE      /holosims/:id
POST|DELETE         /holosims/:id/members[/:member_user_id]
POST                /holosims/:id/accept
POST                /holosims/:id/launch
GET                 /holosims/:id/status
PUT                 /holosims/:id/state           server key only
GET                 /holosims/:id/access/:target_user_id   server key only
```

Two of these are load-bearing for security and worth copying if you build
something similar:

- **`/servers/heartbeat` and `/servers/offline` reject a player token.** If a
  player could register a server, they could advertise one they control to
  everyone browsing the server list. That is phishing, not cheating.
- **`/holosims/:id/access/:user_id` is the instance's independent gate.** With one
  server process per world, an address is all a stranger would need. The instance
  asks the hub on every join, so a revoked invitation takes effect immediately.

Server liveness is heartbeat **age**, not deregistration — a crashed server never
gets to deregister.

### Scheduler, projects, GraphQL

```
GET|POST            /api/scheduler/events
GET|PUT|DELETE      /api/scheduler/events/:id
POST                /api/scheduler/events/:id/{run,pause,resume}
GET                 /api/scheduler/project-events
POST                /api/webhooks/scheduler/:secret        public, secret in path
GET                 /api/projects/calendar                 bearer or X-API-Key
*                   /api/graphql
*                   /api/graphiql                          dev only
GET                 /health
GET                 /api/status
```

---

## Assets

**`mix assets.*` will not run npm on your host unless you opt in.** The aliases
shell out to `scripts/dev-assets.sh`, which runs the toolchain in a container.

```bash
./scripts/dev-assets.sh build
./scripts/dev-assets.sh ci
./scripts/dev-assets.sh run type-check
./scripts/dev-assets.sh run lint
./scripts/dev-assets.sh run deploy
```

This exists because host npm installs were repeatedly destructive on Windows and
non-reproducible between machines. If you are on Linux and want host npm, run it
in `assets/` directly — the guard is on the mix aliases, not on you.

---

## Testing and linting

```bash
mix test          # creates and migrates the test databases first
mix lint          # format check, eslint, tsc, credo --strict, sobelow, dialyzer
```

`warnings_as_errors` is on in `:dev` and `:test` and off in `:prod`, so a
warning fails your build but never blocks a release.

---

## Deployment

Kustomize overlays for k3s:

```
k3s/base/               deployment, services, PVCs, ingress
k3s/overlays/dev/       development namespace
k3s/overlays/prod/      production namespace
k3s/jobs/               one-shot maintenance jobs
k3s/ssl/                TLS material
```

```bash
kubectl apply -k k3s/overlays/dev
kubectl apply -k k3s/overlays/prod
kubectl rollout restart deployment/phoenix-web -n phoenixapp
```

`deploy-prod.sh` wraps build, push and rollout. `deploy-game.sh` builds the
dedicated game server image.

Migrations run through the release, not through mix:

```bash
kubectl exec -n phoenixapp deploy/phoenix-web -- \
  /app/bin/phoenix_app eval "PhoenixApp.Release.migrate()"
```

**`k3s/overlays/prod/secrets.yaml`, `ingress.yaml` and `mailhog-auth-secret.yaml`
are gitignored.** Copy the dev equivalents, change every value, and keep them out
of version control.

---

## Operations

```bash
./postgres-ops.sh backup|restore|list|clean|connect|size|logs
./redis-ops.sh    backup|restore|monitor|keys "chat:*"|flush
./phx-start.sh
```

`redis-ops.sh flush` deletes everything. It is not guarded.

---

## Security notes

Read before deploying, not after.

- **`GAMES_SERVER_API_KEY` is a master credential.** It authorises acting as any
  user. Keep it server-side, rotate it if an image leaks, and never put it in a
  config file that gets baked into a client.
- **`dev-verify` must stay 404 in production.** See the warning in
  [Quick start](#quick-start).
- **Rate limiting is per IP.** Everything behind one NAT shares a budget; in
  development every local client is `127.0.0.1`, so rapid restarts will earn you a
  `429` that reads exactly like a wrong password.
- **Never commit `k3s/overlays/prod/secrets.yaml`.** It is in `.gitignore`;
  keep it that way.
- **Backups and uploads are gitignored** (`backups/`, `uploads/`,
  `priv/static/uploads/`). Database dumps contain user records — check before you
  change those rules.
- **Sobelow runs in `mix lint`.** Take its findings seriously; it is there for a
  reason.

---

## Using this as a starting point

An honest map of what it costs to remove each piece, largest win first:

| Remove | Effort | Notes |
|---|---|---|
| Games platform | **Low** | Own repo, own router scope, own migrations. Delete `lib/phoenix_app/games`, `games_repo.ex`, `priv/games_repo`, the `/api/games` scope, and drop `PhoenixApp.GamesRepo` from `ecto_repos` |
| Commerce | Low | Contexts, LiveViews and tables are self-contained; check the profile page for order links |
| Forum / social | Low–medium | Shares presence and notifications with chat |
| Desktop UI | Medium | It is rendered from the app layout on every authenticated page, so removal is a layout edit plus the component tree |
| CMS | Medium | The `cms_*` tables are independent of `posts`; you can drop one and keep the other |
| Accounts / auth / security | — | Load-bearing. This is the part most worth keeping |

The pieces most likely to be useful on their own: the **security stack** (device
fingerprints, identifier lists, lockout, rate limiting), the **assets-in-a-container
policy**, and the **Kubernetes client**.

---

## License

MIT — see [`LICENSE`](LICENSE).

Without a license file, published code is "all rights reserved" by default and
nobody may legally fork it. The `LICENSE` file was added on 2026-08-21 to match
the intent this README had always stated; **confirm the copyright holder line
reads the way you want it to.**
