#!/usr/bin/env python3
"""Publish a staged RaysSpaceSim client as the live launcher release.

    python scripts/publish_client_release.py --build-id <tag> \
        --staged RaysSpaceSim/Saved/ClientBuild/Windows \
        --launcher RaysSpaceSim/Launcher/bin/RaysSpaceSimLauncher.exe

Steps (see PhoenixApp.Games.Releases on the hub):
  1. hash every staged file (cached by path+size+mtime - the pak is GBs)
  2. ask the hub which hashes it does not have yet
  3. stream only those into the blob store with `kubectl exec -i` - no HTTP,
     so the ingress body-size and timeout limits never apply
  4. record the manifest and make it live

THE API KEY IS NEVER STORED. It comes from $GAMES_SERVER_API_KEY, or failing
that is read from the cluster's phoenix-secrets at run time, and it only ever
travels in a request header.
"""

import argparse
import base64
import hashlib
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request

# Debug symbols and UAT bookkeeping stay on disk; players do not need them.
EXCLUDE_SUFFIXES = (".pdb", ".debug", ".sym")
EXCLUDE_PREFIXES = ("Manifest_",)

PREREQ_NAME = "UEPrereqSetup_x64.exe"


def log(msg):
    print(msg, flush=True)


def die(msg):
    print("ERROR: " + msg, file=sys.stderr, flush=True)
    sys.exit(1)


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while True:
            chunk = f.read(8 * 1024 * 1024)
            if not chunk:
                break
            h.update(chunk)
    return h.hexdigest()


def load_cache(path):
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


def save_cache(path, cache):
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(cache, f)
    os.replace(tmp, path)


def hash_with_cache(path, cache):
    st = os.stat(path)
    key = os.path.abspath(path)
    hit = cache.get(key)
    if hit and hit["size"] == st.st_size and hit["mtime"] == st.st_mtime_ns:
        return hit["sha256"], st.st_size
    sha = sha256_file(path)
    cache[key] = {"size": st.st_size, "mtime": st.st_mtime_ns, "sha256": sha}
    return sha, st.st_size


def collect(staged, cache):
    files = []
    for root, _dirs, names in os.walk(staged):
        for name in names:
            if name.endswith(EXCLUDE_SUFFIXES) or name.startswith(EXCLUDE_PREFIXES):
                continue
            full = os.path.join(root, name)
            rel = os.path.relpath(full, staged).replace("\\", "/")
            sha, size = hash_with_cache(full, cache)
            files.append({"path": rel, "size": size, "sha256": sha, "_local": full})
    files.sort(key=lambda e: e["path"].lower())
    return files


def kubectl(args, **kw):
    return subprocess.run(["kubectl"] + args, **kw)


def api_key(namespace):
    key = os.environ.get("GAMES_SERVER_API_KEY", "").strip()
    if key:
        return key
    r = kubectl(["get", "secret", "phoenix-secrets", "-n", namespace,
                 "-o", "jsonpath={.data.GAMES_SERVER_API_KEY}"],
                capture_output=True, text=True)
    if r.returncode != 0 or not r.stdout.strip():
        die("No GAMES_SERVER_API_KEY in the environment and could not read it from "
            "secret phoenix-secrets: " + (r.stderr or "").strip())
    return base64.b64decode(r.stdout.strip()).decode("utf-8").strip()


def post(hub, path, key, body):
    req = urllib.request.Request(
        hub.rstrip("/") + path,
        data=json.dumps(body).encode("utf-8"),
        headers={"Content-Type": "application/json", "Accept": "application/json",
                 "X-API-Key": key},
        method="POST")
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        text = e.read().decode("utf-8", "replace")
        die("%s %s -> HTTP %d: %s" % ("POST", path, e.code, text[:500]))


def upload_blob(namespace, local, sha):
    target = "/app/client_releases/blobs/" + sha
    # .part then mv: a half-finished copy must never sit under the real name,
    # because the hub serves anything named like a hash.
    cmd = ["exec", "-i", "-n", namespace, "deploy/phoenix-web", "-c", "phoenix", "--",
           "sh", "-c", "cat > %s.part && mv %s.part %s" % (target, target, target)]
    with open(local, "rb") as f:
        r = kubectl(cmd, stdin=f, capture_output=True)
    if r.returncode != 0:
        die("upload of %s failed: %s" % (local, r.stderr.decode("utf-8", "replace").strip()))


def human(n):
    for unit in ("B", "KB", "MB", "GB"):
        if n < 1024 or unit == "GB":
            return "%.1f %s" % (n, unit) if unit != "B" else "%d B" % n
        n /= 1024.0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--build-id", required=True)
    ap.add_argument("--staged", required=True)
    ap.add_argument("--launcher", required=True)
    ap.add_argument("--hub", default=os.environ.get("PHX_HUB_URL", "https://phxlive.net"))
    ap.add_argument("--slug", default="rays-space-sim")
    ap.add_argument("--namespace", default="phoenixapp")
    ap.add_argument("--cache", default=None)
    ap.add_argument("--notes", default=None)
    a = ap.parse_args()

    if not os.path.isdir(a.staged):
        die("no staged client at " + a.staged)
    if not os.path.isfile(a.launcher):
        die("no launcher exe at " + a.launcher)

    cache_path = a.cache or os.path.join(os.path.dirname(os.path.abspath(a.staged)), "..", "ClientHashCache.json")
    cache_path = os.path.normpath(cache_path)
    cache = load_cache(cache_path)

    log("Hashing %s ..." % a.staged)
    t0 = time.time()
    files = collect(a.staged, cache)
    l_sha, l_size = hash_with_cache(a.launcher, cache)
    save_cache(cache_path, cache)
    total = sum(f["size"] for f in files)
    log("  %d files, %s, hashed in %.0fs" % (len(files), human(total), time.time() - t0))

    # The exe the launcher starts: the bootstrap at the root of the staged
    # folder (UE names it after the target). Exactly one, or stop and say so.
    root_exes = [f["path"] for f in files if "/" not in f["path"] and f["path"].lower().endswith(".exe")]
    if len(root_exes) != 1:
        die("expected exactly one .exe at the root of the staged client, found: %r" % root_exes)
    exe = root_exes[0]
    prereq = next((f["path"] for f in files if f["path"].endswith("/" + PREREQ_NAME)), None)
    log("  game exe: %s" % exe)
    log("  prereqs : %s" % (prereq or "(none staged)"))

    key = api_key(a.namespace)
    base = "/api/games/%s/releases" % a.slug

    entries = [{"sha256": f["sha256"], "size": f["size"]} for f in files]
    entries.append({"sha256": l_sha, "size": l_size})
    missing = set(post(a.hub, base + "/missing", key, {"entries": entries}).get("missing", []))

    by_sha = {}
    for f in files:
        by_sha.setdefault(f["sha256"], f["_local"])
    by_sha.setdefault(l_sha, a.launcher)

    up_bytes = sum(os.path.getsize(by_sha[s]) for s in missing)
    log("Uploading %d new blob(s), %s (the rest are already on the hub)" % (len(missing), human(up_bytes)))
    for i, sha in enumerate(sorted(missing), 1):
        local = by_sha[sha]
        log("  [%d/%d] %s  %s" % (i, len(missing), human(os.path.getsize(local)), os.path.basename(local)))
        upload_blob(a.namespace, local, sha)

    still = post(a.hub, base + "/missing", key, {"entries": entries}).get("missing", [])
    if still:
        die("%d blob(s) still missing after upload, e.g. %s" % (len(still), still[0]))

    body = {
        "build_id": a.build_id,
        "files": [{k: f[k] for k in ("path", "size", "sha256")} for f in files],
        "launcher": {"sha256": l_sha, "size": l_size, "version": l_sha[:12]},
        "exe": exe,
        "prereq": prereq,
        "notes": a.notes,
    }
    res = post(a.hub, base, key, body)
    if not res.get("success"):
        die("publish refused: %r" % res)
    log("Release %s is live (%s)." % (res.get("build_id"), human(res.get("total_bytes") or total)))


if __name__ == "__main__":
    main()
