# codemap

`codemap.json` is the data behind **/admin/raysspacesim/codebase**: a generated
snapshot of the RaysSpaceSim C++ surface - every module, class, function
signature, and what replicates to whom - extracted from the headers.

It is checked in rather than generated at runtime, deliberately. The Phoenix app
cannot reach `C:\PhxLive\RaysSpaceSim` from the cluster: the game is a separate
repository, is gitignored by PhxLive, and is not in the web image. A pod has no
header to parse. So the map travels as data, and the page can only ever be as
current as this file - which is why every screen states the commit it came from.

## Regenerating

Automatic. `./deploy-game.sh` runs the extractor after every successful cook, so
the map refreshes whenever the game code that produced an image did.

By hand, when you have edited headers but do not want to wait for a build:

    ./deploy-game.sh --codemap

Directly, if you want to point it somewhere else:

    python priv/codemap/extract.py <game-root> <output.json>

Both roots default sensibly - the game repo beside this one, and `codemap.json`
in this directory - and both can be set with `CODEMAP_GAME_ROOT` / `CODEMAP_OUT`.
The script reads only `.h` files for structure and makes one pass over `.cpp`
for call counts and the replication index, so it needs no build and takes a
couple of seconds.

## Getting a regenerated map onto the site

Two routes, and they are not interchangeable:

1. **`./deploy-prod.sh`** - rebuilds the web image, which is what carries
   `priv/`. This is the durable one: the new snapshot is baked in and every pod
   that ever starts from that image has it.

2. **Upload it on `/admin/raysspacesim`** - the Code map card takes a
   `codemap.json` and serves it in preference to the baked copy. This skips the
   deploy, and it lasts until the pod restarts. Use it to refresh the map
   mid-session; do not treat it as a substitute for (1).

There is no "regenerate" button on the admin page and there will not be one. The
pod has no game repo and no Python; a button that could only ever fail is worse
than an honest explanation of where the parser actually runs.

## What the page checks

The card on `/admin/raysspacesim` compares the snapshot's commit against the tag
of the live game image (`HOLOSIM_IMAGE`, which `deploy-game.sh` writes from the
game repo's SHA). Those two agreeing is the closest available answer to "is this
map describing what is running", and when they disagree the badge reads Stale
rather than OK. A code map that is quietly three weeks old is worse than no code
map: it answers confidently and wrongly.

## Keeping extract.py and codemap.json in step

Everything the page reads - `modules`, `deps`, `replication_index`,
`generated_from` - is produced by one run of `extract.py`. That was not always
true: for a while the script emitted only `modules` and the other three keys
were added by hand afterwards, which is drift by construction. If you add a key
the page reads, add it to the script in the same change.
