# Plugins

Each folder here is a PhxLive plugin, WordPress-style: drop a folder in, deploy, then
activate it on **/admin/plugins**. See PHXLIVE.md §9 for the full contract.

```
plugins/<slug>/
  README.md
  lib/<slug>/plugin.ex          <Slug>.Plugin - `use Phxlive.Plugin, slug: "<slug>", ...`
  lib/<slug>/...                your contexts and schemas
  lib/<slug>_web/...            your LiveViews and controllers
  lib/<slug>_web/routes.ex      `use Phxlive.Plugin.Routes` - api do ... end / browser do ... end
  priv/games_repo/migrations/   your tables, prefixed <slug>_
  priv/repo/migrations/         (optional) site-database tables
  assets/js/index.ts            `export const hooks = {...}`: your LiveView hooks
  test/test_helper.exs          required by mix (may be empty)
  test/                         runs with `mix test`
```

Rules of the road:

- The folder name is the slug: lowercase letters, digits and underscores
  (`web_lobby`). It names your module (`WebLobby.Plugin`), prefixes your tables
  (`web_lobby_zones`) and is your game slug unless `game/0` says otherwise.
- Use your own namespace (`WebLobby`, `WebLobbyWeb`), never `Phxlive.*`.
- Talk to the hub only through its public contexts (`Phxlive.Games`, `Phxlive.Drive`,
  `Phxlive.Entitlements`, ...). Core code never references a plugin.
- API routes mount at `/api/games/<game slug>/...`; pages at `/games/<slug>/...`.
- Run migrations with `mix phxlive.migrate` (plain `mix ecto.migrate` only sees `priv/`).
  Migration versions share one table with core: use real timestamps.
- JavaScript: your `assets/js/index.ts` is picked up automatically on the next asset build.
  Hook names are global, so make them distinctive. Import npm packages through the shims in
  `assets/js/vendor/` (e.g. `import * as THREE from "../../../../assets/js/vendor/three"`);
  esbuild can't see `node_modules` from here.
- A private plugin can be its own git repository cloned into this folder; list it in
  the repository's `.gitignore` so it stays out of the public repo.

`web_lobby/` is the reference plugin: copy it to start your own.
