#!/usr/bin/env python3
"""
Extract the RaysSpaceSim C++ surface into codemap.json.

This is the generator behind /admin/raysspacesim/codebase. It reads only
headers (.h) for structure and makes one pass over .cpp files for call counts
and the replication index, so it needs no build and takes a couple of seconds.

USAGE
    python extract.py [game-root] [output.json]

    game-root   defaults to $CODEMAP_GAME_ROOT, then to the RaysSpaceSim
                directory beside this repo (../../RaysSpaceSim from here).
    output      defaults to $CODEMAP_OUT, then to codemap.json beside this
                script - which is the copy the Phoenix release bakes in.

NO HARDCODED PATHS.
This script used to open with ROOT = "~/mnt/RaysSpaceSim", which is a path that
exists on exactly one machine in one tool. deploy-game.sh runs from Git Bash on
Windows, so the hardcoded form made the script unrunnable by the only thing
that was ever going to run it automatically. Roots come from the caller now.

IT MUST EMIT THE WHOLE FILE.
The earlier version wrote only {"modules": ...}, and `deps`,
`replication_index` and `generated_from` were bolted on afterwards by hand.
That is drift by construction: the page reads four keys and the script produced
one. Everything the page reads is produced here, in one run, or the page has no
business trusting it.

Exit status is 0 only if at least one module was found and parsed - so a caller
that points it at the wrong directory learns that from the exit code rather
than from an empty page three days later.
"""

import os, re, sys, json, subprocess, collections
from datetime import datetime, timezone

HERE = os.path.dirname(os.path.abspath(__file__))

def _default_root():
    # priv/codemap/extract.py -> up two -> the PhxLive repo root -> RaysSpaceSim
    return os.path.normpath(os.path.join(HERE, "..", "..", "RaysSpaceSim"))

ROOT = os.path.abspath(os.path.expanduser(
    (sys.argv[1] if len(sys.argv) > 1 else None)
    or os.environ.get("CODEMAP_GAME_ROOT")
    or _default_root()
))

OUT = os.path.abspath(os.path.expanduser(
    (sys.argv[2] if len(sys.argv) > 2 else None)
    or os.environ.get("CODEMAP_OUT")
    or os.path.join(HERE, "codemap.json")
))

if not os.path.isdir(ROOT):
    sys.stderr.write("extract.py: no such game root: %s\n" % ROOT)
    sys.stderr.write("Pass it as the first argument or set CODEMAP_GAME_ROOT.\n")
    sys.exit(2)

DOC_CAP = 600

MODULES = [
    ("RSS",             "Source/RSS",                        "game module"),
    ("Cosmos",          "Plugins/Cosmos/Source/Cosmos",       "plugin"),
    ("PhxAccount",      "Plugins/PhxAccount/Source/PhxAccount","plugin"),
    ("Cockpit_UI",      "Plugins/Cockpit_UI/Source",          "plugin"),
    ("RSSAuthTerminal", "Plugins/RSSAuthTerminal/Source",     "plugin"),
    ("Box3DPhysics",    "Plugins/Box3DPhysics/Source",        "plugin (partly vendored)"),
]

CLS = re.compile(r"(?:^|\n)\s*(?:UCLASS|USTRUCT|UINTERFACE)\s*\(([^)]*)\)\s*\n\s*(class|struct)\s+(?:\w+_API\s+)?([A-Za-z_]\w*)\s*(?::\s*public\s+([\w:<>]+))?")
PLAINCLS = re.compile(r"(?:^|\n)\s*(class|struct)\s+\w+_API\s+([A-Za-z_]\w*)\s*(?::\s*public\s+([\w:<>]+))?")
UFUNC = re.compile(r"UFUNCTION\s*\(([^)]*)\)")
UPROP = re.compile(r"UPROPERTY\s*\(([^)]*)\)")

def strip_block_comments(s):
    return re.sub(r"/\*.*?\*/", "", s, flags=re.S)

def doc_before(lines, idx, limit=14):
    """Collect the /// or // comment block immediately above a declaration."""
    out = []
    i = idx - 1
    while i >= 0 and len(out) < limit:
        t = lines[i].strip()
        if t.startswith("///") or t.startswith("//"):
            out.append(re.sub(r"^/+<?\s?", "", t)); i -= 1
        elif t.startswith("*") or t.startswith("/*") or t.endswith("*/"):
            out.append(re.sub(r"^[/*]+\s?|\s*\*/$", "", t)); i -= 1
        elif t == "" and out:
            break
        elif t.startswith(("UFUNCTION", "UPROPERTY", "UCLASS", "USTRUCT")):
            i -= 1
        else:
            break
    out.reverse()
    txt = " ".join(x for x in out if x).strip()
    return re.sub(r"\s+", " ", txt)

def file_header(lines, limit=60):
    """The leading // comment block of a file, before any code."""
    out = []
    for L in lines[:limit]:
        t = L.strip()
        if t.startswith("//"):
            out.append(re.sub(r"^/+<?\s?", "", t))
        elif t == "":
            if out:
                break
            continue
        else:
            break
    return re.sub(r"\s+", " ", " ".join(x for x in out if x)).strip()


def machine_of(spec):
    s = spec.replace(" ", "")
    if "Server" in s:       return ("server-rpc",  "owning client \u2192 server")
    if "NetMulticast" in s: return ("multicast",   "server \u2192 everyone")
    if re.search(r"\bClient\b", s): return ("client-rpc", "server \u2192 owning client")
    if "BlueprintPure" in s: return ("pure", "read-only, any machine")
    return (None, None)

def parse_params(sig):
    m = re.search(r"\((.*)\)", sig, re.S)
    if not m: return []
    inner = m.group(1).strip()
    if not inner: return []
    parts, depth, cur = [], 0, ""
    for ch in inner:
        if ch in "<([": depth += 1
        elif ch in ">)]": depth -= 1
        if ch == "," and depth == 0:
            parts.append(cur); cur = ""
        else: cur += ch
    if cur.strip(): parts.append(cur)
    out = []
    for p in parts:
        p = p.strip()
        d = None
        if "=" in p:
            p, d = p.split("=", 1); p, d = p.strip(), d.strip()
        pm = re.match(r"^(.*?[\s\*&])(\w+)$", p)
        if pm: out.append({"type": pm.group(1).strip(), "name": pm.group(2), "default": d})
        else:  out.append({"type": p, "name": "", "default": d})
    return out

modules = []
all_fn_names = set()

for mod, rel, kind in MODULES:
    base = os.path.join(ROOT, rel)
    if not os.path.isdir(base): continue
    classes = []
    for dp, _, fs in os.walk(base):
        if "Intermediate" in dp or "box3d_src" in dp or "ThirdParty" in dp: continue
        for f in sorted(fs):
            if not f.endswith(".h"): continue
            path = os.path.join(dp, f)
            raw = open(path, encoding="utf-8-sig", errors="ignore").read()
            lines = raw.split("\n")
            src = strip_block_comments(raw)
            # find class declarations with their line index in the ORIGINAL file
            decls = []
            for m in CLS.finditer(raw):
                decls.append((raw[:m.start()].count("\n"), m.group(3), m.group(4), m.group(1), m.group(2)))
            for m in PLAINCLS.finditer(raw):
                nm = m.group(2)
                if any(d[1] == nm for d in decls): continue
                decls.append((raw[:m.start()].count("\n"), nm, m.group(3), "", m.group(1)))
            decls.sort()
            for di, (ln, name, basecls, uspec, ckind) in enumerate(decls):
                end = decls[di+1][0] if di+1 < len(decls) else len(lines)
                body = "\n".join(lines[ln:end])
                bodyl = lines[ln:end]
                fns, props = [], []
                for i, L in enumerate(bodyl):
                    t = L.strip()
                    if t.startswith(("//", "*", "/*")): continue
                    # UPROPERTY
                    if t.startswith("UPROPERTY"):
                        spec = UPROP.search(t)
                        nxt = bodyl[i+1].strip() if i+1 < len(bodyl) else ""
                        pm = re.match(r"^([\w:<>,\s\*&]+?)\s+(\w+)\s*(?:=.*)?;", nxt)
                        if pm and spec:
                            sp = spec.group(1)
                            rep = None
                            if "ReplicatedUsing" in sp:
                                rep = "ReplicatedUsing=" + (re.search(r"ReplicatedUsing\s*=\s*(\w+)", sp).group(1)
                                                            if re.search(r"ReplicatedUsing\s*=\s*(\w+)", sp) else "?")
                            elif re.search(r"\bReplicated\b", sp): rep = "Replicated"
                            props.append({"type": pm.group(1).strip(), "name": pm.group(2),
                                          "spec": sp.strip(), "replicated": rep,
                                          "doc": doc_before(bodyl, i)})
                        continue
                    # functions
                    if "(" not in t or t.startswith(("UFUNCTION","UCLASS","USTRUCT","GENERATED","DECLARE_","#")):
                        continue
                    if not (t.endswith(";") or t.endswith("{") or t.endswith("}")): continue
                    fm = re.match(r"^(?:(virtual|static|FORCEINLINE|inline)\s+)*([\w:<>,\s\*&]+?)\s+(\w+)\s*\((.*)$", t)
                    if not fm: continue
                    fname = fm.group(3)
                    if fname in ("if","for","while","switch","return","GENERATED_BODY"): continue
                    ret = fm.group(2).strip()
                    if ret in ("class","struct","enum","return"): continue
                    # gather multi-line signature
                    sig = t; j = i
                    while sig.count("(") > sig.count(")") and j+1 < len(bodyl):
                        j += 1; sig += " " + bodyl[j].strip()
                    uf = None; mach = (None, None)
                    if i > 0:
                        for back in range(1, 4):
                            if i-back < 0: break
                            pt = bodyl[i-back].strip()
                            if pt.startswith("UFUNCTION"):
                                uf = UFUNC.search(pt).group(1).strip(); mach = machine_of(uf); break
                            if pt and not pt.startswith(("//","*","/*")): break
                    fns.append({
                        "name": fname, "ret": ret,
                        "sig": re.sub(r"\s+", " ", sig).rstrip("{").strip(),
                        "params": parse_params(sig),
                        "const": bool(re.search(r"\)\s*const", sig)),
                        "virtual": "virtual" in t.split(fname)[0],
                        "static": "static" in t.split(fname)[0],
                        "inline_body": sig.rstrip().endswith("{") or "{" in sig,
                        # THE `override` KEYWORD, NOT A LIST OF ENGINE NAMES.
                        #
                        # A name list flags `void Tick(float)` on a plain helper
                        # struct as an engine override, which is wrong and makes
                        # the badge mean nothing. `override` is the compiler's
                        # own answer to the same question.
                        "engine_override": bool(re.search(r"\boverride\b", sig)),
                        "ufunction": uf, "machine": mach[0], "machine_note": mach[1],
                        "doc": doc_before(bodyl, i),
                    })
                    all_fn_names.add(fname)
                if not fns and not props and not uspec: continue
                # THE DOC IS USUALLY AT THE TOP OF THE FILE, NOT ABOVE THE CLASS.
                #
                # House style in this codebase is a long `//` header explaining
                # the whole file, then `#pragma once`, then the class with
                # nothing above it. Reading only the lines directly above the
                # declaration therefore found nothing for exactly the classes
                # that are best documented. Fall back to that header for every
                # class in the file, not just the first: a header describing
                # "the celestial body and its three helper structs" is the best
                # available description of each of those four, and a blank card
                # is worse than a shared one.
                cdoc = doc_before(lines, ln)
                if not cdoc:
                    cdoc = file_header(lines)
                # Capped. Some of these headers run to two thousand characters,
                # and a card that opens with an essay is a card nobody reads.
                if len(cdoc) > DOC_CAP:
                    cdoc = cdoc[: DOC_CAP - 1].rstrip() + "\u2026"

                classes.append({
                    "name": name, "base": basecls or "", "kind": ckind,
                    "uspec": uspec, "file": os.path.relpath(path, ROOT).replace("\\","/"),
                    "doc": cdoc,
                    "functions": fns, "properties": props,
                })
    modules.append({"name": mod, "kind": kind, "classes": classes})

# ---- caller counts: one pass over every .cpp ------------------------------
callers = collections.Counter()
callsite = collections.defaultdict(set)
for mod, rel, _ in MODULES:
    base = os.path.join(ROOT, rel)
    for dp, _, fs in os.walk(base):
        if "Intermediate" in dp or "box3d_src" in dp: continue
        for f in fs:
            if not f.endswith(".cpp"): continue
            s = strip_block_comments(open(os.path.join(dp,f), encoding="utf-8-sig", errors="ignore").read())
            s = re.sub(r"//[^\n]*", "", s)
            for n in set(re.findall(r"\b(\w+)\s*\(", s)):
                if n in all_fn_names:
                    callers[n] += len(re.findall(r"\b%s\s*\(" % re.escape(n), s))
                    callsite[n].add(f)
for m in modules:
    for c in m["classes"]:
        for fn in c["functions"]:
            # An override has no meaningful call count. The engine calls it, not
            # this codebase, and the textual pass would happily attribute every
            # `Tick(` in the tree to whichever class declared one. null renders
            # as "engine override" instead of as a number that is a lie.
            if fn.get("engine_override"):
                fn["calls"] = None
                fn["called_in"] = []
            else:
                fn["calls"] = callers.get(fn["name"], 0)
                fn["called_in"] = sorted(callsite.get(fn["name"], []))[:6]


# ---- module dependency graph, from the .Build.cs files --------------------
#
# This is the one relationship in the codebase the compiler actually enforces:
# UnrealBuildTool rejects a dependency cycle outright, so "RSS publicly depends
# on Cosmos" is also the proof that Cosmos can never depend on RSS. The page
# states that as a hard constraint, so it had better read it from the build
# files rather than from someone's memory.
DEPLIST = re.compile(
    r"(Public|Private)DependencyModuleNames\s*\.\s*Add(?:Range)?\s*\(\s*"
    r"(?:new\s+string\s*\[\s*\]\s*)?\{(.*?)\}",
    re.S,
)

deps = {}
for mod, rel, _ in MODULES:
    base = os.path.join(ROOT, rel)
    if not os.path.isdir(base):
        continue
    # KEYED BY THE .Build.cs, NOT BY THE ENTRY IN MODULES.
    #
    # One plugin directory can hold several UBT modules - Box3DPhysics/Source
    # contains Box3D, Box3DPhysics and Box3DMass, each with its own Build.cs and
    # its own dependency list. Merging them under the plugin's name produced a
    # single fictional module that depended on itself, which is precisely the
    # kind of false edge this graph exists to rule out.
    for dp, _dirs, fs in os.walk(base):
        if "Intermediate" in dp or "Binaries" in dp:
            continue
        for f in fs:
            if not f.endswith(".Build.cs"):
                continue
            ubt_module = f[: -len(".Build.cs")]
            entry = deps.setdefault(ubt_module, {"public": [], "private": []})
            src = strip_block_comments(
                open(os.path.join(dp, f), encoding="utf-8-sig", errors="ignore").read()
            )
            src = re.sub(r"//[^\n]*", "", src)
            for kind, inner in DEPLIST.findall(src):
                names = [n.strip().strip('"') for n in inner.split(",")]
                key = kind.lower()
                for n in names:
                    if n and n not in entry[key]:
                        entry[key].append(n)

# ---- replication index, from GetLifetimeReplicatedProps -------------------
#
# UPROPERTY(Replicated) is only half of it. What a property costs on the wire
# and who receives it is decided by the DOREPLIFETIME_CONDITION line in
# GetLifetimeReplicatedProps, and the two halves live in different files. A
# property marked Replicated in the header and absent here does not replicate
# at all - which is a bug the header alone cannot show you, so the page shows
# this list rather than the header flags.
GLRP = re.compile(
    r"void\s+(\w+)::GetLifetimeReplicatedProps\s*\([^)]*\)\s*const\s*\{(.*?)\n\}",
    re.S,
)
DOREP = re.compile(r"DOREPLIFETIME(?:_CONDITION(?:_NOTIFY)?)?\s*\(\s*(\w+)\s*,\s*(\w+)\s*(?:,\s*(\w+))?")

replication_index = {}
for mod, rel, _ in MODULES:
    base = os.path.join(ROOT, rel)
    if not os.path.isdir(base):
        continue
    for dp, _dirs, fs in os.walk(base):
        if "Intermediate" in dp or "box3d_src" in dp:
            continue
        for f in fs:
            if not f.endswith(".cpp"):
                continue
            src = strip_block_comments(
                open(os.path.join(dp, f), encoding="utf-8-sig", errors="ignore").read()
            )
            src = re.sub(r"//[^\n]*", "", src)
            for cls, bodytxt in GLRP.findall(src):
                for _owner, prop, cond in DOREP.findall(bodytxt):
                    replication_index.setdefault(cls, {})[prop] = cond or "COND_None"

# Hang each class's own slice off the class, so a card can show what that class
# puts on the wire without the template having to cross-reference the index.
for m in modules:
    for c in m["classes"]:
        rep = replication_index.get(c["name"], {})
        c["replication"] = rep
        # And onto the property itself: the header says a property replicates,
        # this says to whom. They come from different files and the pairing is
        # the only place both halves are visible at once.
        for p in c["properties"]:
            if p["name"] in rep:
                p["cond"] = rep[p["name"]]

# ---- provenance -----------------------------------------------------------
#
# A code map with no commit on it is worse than no code map: it answers
# confidently and there is no way to tell how long ago it stopped being true.
def _git(*args):
    try:
        return subprocess.check_output(
            ["git", "-C", ROOT] + list(args),
            stderr=subprocess.DEVNULL,
        ).decode("utf-8", "replace").strip()
    except Exception:
        return ""

sha = _git("rev-parse", "--short", "HEAD") or "nogit"
dirty = "-dirty" if _git("status", "--porcelain") else ""
generated_from = "%s @ %s%s" % (os.path.basename(ROOT), sha, dirty)

payload = {
    "modules": modules,
    "deps": deps,
    "replication_index": replication_index,
    "generated_from": generated_from,
    "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "game_commit": sha,
    "game_dirty": bool(dirty),
}

os.makedirs(os.path.dirname(OUT) or ".", exist_ok=True)
with open(OUT, "w", encoding="utf-8") as fh:
    json.dump(payload, fh, indent=1)

n_classes = sum(len(m["classes"]) for m in modules)
n_fns = sum(len(c["functions"]) for m in modules for c in m["classes"])
n_props = sum(len(c["properties"]) for m in modules for c in m["classes"])

print("wrote %s (%.0f KB)" % (OUT, os.path.getsize(OUT) / 1024.0))
print("  from %s" % generated_from)
for m in modules:
    print("  %-18s %3d classes  %4d fns  %4d props" % (
        m["name"], len(m["classes"]),
        sum(len(c["functions"]) for c in m["classes"]),
        sum(len(c["properties"]) for c in m["classes"])))
print("  %-18s %3d classes  %4d fns  %4d props  %d replicated props in %d classes" % (
    "TOTAL", n_classes, n_fns, n_props,
    sum(len(v) for v in replication_index.values()), len(replication_index)))

# A run that found nothing is a wrong root, not an empty codebase. Say so with
# the exit code, because the caller is a build script and does not read prose.
if not modules:
    sys.stderr.write("extract.py: parsed no modules under %s - wrong game root?\n" % ROOT)
    sys.exit(1)
