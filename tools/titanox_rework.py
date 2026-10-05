#!/usr/bin/env python3
# Titanox full rework: game tables -> per brawler data, dead code removal, wiring, report.
# Default is a dry run: nothing is written unless --apply is passed.
import argparse, csv, io, json, os, re, subprocess, sys, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "tools", "data")
ASSET = "https://raw.githubusercontent.com/tailsjs/brawl-stars-assets/master/%s/%s/%s"

SUBDIR = {"texts.csv": "localization"}
VERSION = "69.230"

TABLES = {
    "characters.csv": 400,
    "skills.csv": 600,
    "projectiles_logic.csv": 600,
    "texts.csv": 5000,
}

REPORT = {"stage": [], "changed": [], "removed_symbols": [], "removed_defines": [], "kept_defines": [], "candidates": [],
          "skipped": [], "generated": [], "checks": []}


def say(kind, msg):
    REPORT["stage"].append("%s: %s" % (kind, msg))
    print("[%s] %s" % (kind, msg))


def read(path):
    with io.open(os.path.join(ROOT, path), "r", encoding="utf-8", errors="replace") as f:
        return f.read()


def write(path, text, apply):
    full = os.path.join(ROOT, path)
    before = os.path.getsize(full) if os.path.exists(full) else -1
    if not apply:
        REPORT["changed"].append("%s (dry, %d -> %d bytes)" % (path, before, len(text)))
        return
    d = os.path.dirname(full)
    if d and not os.path.isdir(d):
        os.makedirs(d)
    with io.open(full, "w", encoding="utf-8") as f:
        f.write(text)
    REPORT["changed"].append("%s (%d -> %d bytes)" % (path, before, len(text)))


def remove(path, apply):
    full = os.path.join(ROOT, path)
    if not os.path.exists(full):
        return
    if apply:
        os.remove(full)
        REPORT["changed"].append("%s (deleted)" % path)


# ---------------------------------------------------------------- data
def fetch_tables(apply):
    if not os.path.isdir(DATA) and apply:
        os.makedirs(DATA)
    for name, minrows in TABLES.items():
        p = os.path.join(DATA, name)
        if not os.path.exists(p) or os.path.getsize(p) < 1000:
            url = ASSET % (VERSION, SUBDIR.get(name, "csv_logic"), name)
            say("data", "fetching %s" % url)
            with urllib.request.urlopen(url, timeout=60) as r:
                body = r.read()
            if apply:
                with io.open(p, "wb") as f:
                    f.write(body)
        if not os.path.exists(p):
            raise SystemExit("table missing and dry run cannot fetch: %s" % p)
        n = sum(1 for _ in io.open(p, encoding="utf-8", errors="replace"))
        REPORT["checks"].append("%s rows=%d" % (name, n))
        if n < minrows:
            raise SystemExit("table %s has %d rows, expected at least %d" % (name, n, minrows))


def rows(name):
    p = os.path.join(DATA, name)
    out = []
    for x in csv.DictReader(io.open(p, encoding="utf-8", errors="replace")):
        n = (x.get("Name") or "").strip()
        if not n or n in ("string", "int", "boolean", "float", "Name"):
            continue
        out.append({(k or "").strip(): (v or "").strip() for k, v in x.items() if k})
    return out


def num(v, d=-1):
    try:
        return int(float(v))
    except Exception:
        return d


def flag(v):
    return 1 if v == "true" else 0


def build_heroes():
    TITLES = {}
    for r in csv.DictReader(io.open(os.path.join(DATA, "texts.csv"), encoding="utf-8", errors="replace")):
        k = (r.get("TID") or "").strip()
        if k:
            TITLES[k] = (r.get("EN") or "").strip()

    P = {r["Name"]: r for r in rows("projectiles_logic.csv")}
    S = {r["Name"]: r for r in rows("skills.csv")}
    CH = rows("characters.csv")

    def proj(n):
        r = P.get(n)
        if not r:
            return None
        return {"speed": num(r.get("Speed")), "radius": num(r.get("Radius")),
                "beam": flag(r.get("IsBeam")), "px": flag(r.get("PiercesCharacters")),
                "pw": flag(r.get("PiercesEnvironment")), "bounce": num(r.get("BouncePercent"), 0),
                "grav": num(r.get("Gravity"), 0), "chain": flag(r.get("ChainsToEnemies")),
                "icw": flag(r.get("IgnoreCloseWalls"))}

    def skill(n):
        r = S.get(n)
        if not r:
            return None
        pl = [x.strip() for x in re.split(r"[;,]", r.get("Projectiles", "")) if x.strip()]
        return {"cast": num(r.get("CastingTime")), "bullets": num(r.get("NumBulletsInOneAttack")),
                "between": num(r.get("MsBetweenAttacks")), "spread": num(r.get("Spread")),
                "cd": num(r.get("Cooldown")), "recharge": num(r.get("RechargeTime")),
                "charge": num(r.get("MaxCharge")), "range": num(r.get("MaxCastingRange")),
                "proj": pl}

    out = []
    for h in sorted((r for r in CH if r.get("Type") in ("Hero", "Her0")), key=lambda r: r["Name"]):
        w = skill(h.get("WeaponSkill", ""))
        u = skill(h.get("UltimateSkill", ""))
        p = proj(h.get("AutoAttackProjectile", ""))
        if not p and w and w["proj"]:
            p = proj(w["proj"][0])
        up = proj(u["proj"][0]) if (u and u["proj"]) else None
        wp = p or {}
        upp = up or {}
        out.append({
            "name": h["Name"],
            "title": (TITLES.get((h.get("TID") or "").strip(), "") or h["Name"]).replace(chr(34), chr(39)).replace(chr(92), "/")[:40],
            "hp": num(h.get("Hitpoints")), "speed": num(h.get("Speed")),
            "radius": num(h.get("CollisionRadius")),
            "wSpeed": wp.get("speed", -1), "wRadius": wp.get("radius", -1),
            "wCast": (w or {}).get("cast", -1), "wBullets": (w or {}).get("bullets", -1),
            "wBetween": (w or {}).get("between", -1), "wSpread": (w or {}).get("spread", -1),
            "wCd": (w or {}).get("cd", -1), "wRecharge": (w or {}).get("recharge", -1),
            "wCharge": (w or {}).get("charge", -1),
            "uSpeed": upp.get("speed", -1), "uRadius": upp.get("radius", -1),
            "uBullets": (u or {}).get("bullets", -1), "uSpread": (u or {}).get("spread", -1),
            "uRecharge": (u or {}).get("recharge", -1),
            "flags": hero_flags(p),
        })
    return out, P


def hero_flags(p):
    if not p:
        return 1
    f = 0
    if p["beam"]:
        f |= 2
    if p["px"]:
        f |= 4
    if p["pw"]:
        f |= 8
    if p["bounce"] > 0:
        f |= 16
    if p["grav"]:
        f |= 64
    if p["chain"]:
        f |= 32
    if p["icw"]:
        f |= 128
    return f


def self_check(heroes, P):
    pairs = {(num(r.get("Speed")), num(r.get("Radius"))) for r in P.values()}
    known = [(3100, 0), (4130, 50), (3261, 150), (5000, 150), (6000, 250),
             (1500, 200), (4000, 250), (3500, 300), (840, 0), (2853, 0)]
    hit = sum(1 for b in known if b in pairs)
    REPORT["checks"].append("projectile blacklist reproduced %d/%d" % (hit, len(known)))
    if hit != len(known):
        raise SystemExit("projectile table does not reproduce the known pairs, refusing to generate")
    names = [h["name"] for h in heroes]
    if len(names) != len(set(names)):
        raise SystemExit("duplicate hero names")
    if len(heroes) < 100:
        raise SystemExit("only %d heroes parsed" % len(heroes))
    say("data", "heroes=%d, hand pairs %d/%d" % (len(heroes), hit, len(known)))


# ---------------------------------------------------------------- generated code
CHARS_H = """#ifndef TNX_CHARS_DATA_H
#define TNX_CHARS_DATA_H

typedef struct {
    const char *name;
    const char *title;
    int hp;
    int speed;
    int radius;
    int wSpeed;
    int wRadius;
    int wCast;
    int wBullets;
    int wBetween;
    int wSpread;
    int wCd;
    int wRecharge;
    int wCharge;
    int uSpeed;
    int uRadius;
    int uBullets;
    int uSpread;
    int uRecharge;
    int flags;
} tnx_hero_t;

#define TNX_HERO_MAGIC 0x544e5833

#define TNX_HF_MELEE 1
#define TNX_HF_BEAM 2
#define TNX_HF_PIERCE_CHAR 4
#define TNX_HF_PIERCE_WALL 8
#define TNX_HF_BOUNCE 16
#define TNX_HF_CHAIN 32
#define TNX_HF_GRAVITY 64
#define TNX_HF_IGNORE_CLOSE_WALL 128

extern const tnx_hero_t g_heroes[];

extern const int g_hero_count;

int tnx_hero_find(const char *name);

const tnx_hero_t *tnx_hero_row(int index);

const tnx_hero_t *tnx_hero_by_hash(uint32_t hash);

int tnx_hero_speed(void);

int tnx_hero_radius(void);

int tnx_hero_hp_max(void);

int tnx_hero_inflated(int projectile_radius, int fallback);

int tnx_hero_melee(int index);

void tnx_hero_identify(int hp_max, int speed_units);

void tnx_hero_report(void);
"""

CHARS_MM_HEAD = """#include "titanox.h"

#include "data/chars_data.h"

const int g_hero_count = TNX_HERO_COUNT;

static int g_own_row = -1;

static uint32_t tnx_hero_hash32(const char *s) {
    uint32_t h = 2166136261u;
    int i = 0;

    if (!s) return 0;

    for (i = 0; s[i]; i++) {
        h = (h ^ (uint8_t)s[i]) * 16777619u;
    }

    return h;
}

int tnx_hero_find(const char *name) {
    int i = 0;

    if (!name || !name[0]) return -1;

    for (i = 0; i < TNX_HERO_COUNT; i++) {
        if (strcmp(g_heroes[i].name, name) == 0) return i;
    }

    return -1;
}

const tnx_hero_t *tnx_hero_row(int index) {
    if (index < 0 || index >= TNX_HERO_COUNT) return NULL;

    return &g_heroes[index];
}

const tnx_hero_t *tnx_hero_by_hash(uint32_t hash) {
    int i = 0;

    for (i = 0; i < TNX_HERO_COUNT; i++) {
        if (tnx_hero_hash32(g_heroes[i].name) == hash) return &g_heroes[i];
    }

    return NULL;
}

void tnx_hero_own(int index) {
    if (index < 0 || index >= TNX_HERO_COUNT) return;

    if (g_own_row == index) return;

    g_own_row = index;

    TNX_LOGX("hero own=%s hp=%d speed=%d radius=%d weaponSpeed=%d cast=%d bullets=%d spread=%d "
             "melee=%d - the character row was taken from the game tables and the own movement "
             "constants now come from it instead of one value shared by every brawler: the speed "
             "field alone ranges from a few hundred to a thousand across the roster, so a single "
             "constant made the arithmetic wrong for almost everyone",
             g_heroes[index].name, g_heroes[index].hp, g_heroes[index].speed, g_heroes[index].radius,
             g_heroes[index].wSpeed, g_heroes[index].wCast, g_heroes[index].wBullets,
             g_heroes[index].wSpread, (g_heroes[index].flags & TNX_HF_MELEE) ? 1 : 0);
}

int tnx_hero_speed(void) {
    if (g_own_row < 0) return (int)TNX_PLAYER_SPEED;
    if (g_heroes[g_own_row].speed <= 0) return (int)TNX_PLAYER_SPEED;

    return g_heroes[g_own_row].speed;
}

int tnx_hero_radius(void) {
    if (g_own_row < 0) return (int)TNX_PLAYER_RADIUS;
    if (g_heroes[g_own_row].radius <= 0) return (int)TNX_PLAYER_RADIUS;

    return g_heroes[g_own_row].radius;
}

int tnx_hero_hp_max(void) {
    if (g_own_row < 0) return 0;

    return g_heroes[g_own_row].hp;
}

int tnx_hero_inflated(int projectile_radius, int fallback) {
    int own = tnx_hero_radius();
    int r = projectile_radius + own;

    if (r <= 0) return fallback;
    if (r < fallback) return fallback;

    return r;
}

int tnx_hero_melee(int index) {
    if (index < 0 || index >= TNX_HERO_COUNT) return 0;

    return (g_heroes[index].flags & TNX_HF_MELEE) ? 1 : 0;
}


int g_own_cand = 0;

void tnx_hero_identify(int hp_max, int speed_units) {
    int i = 0;
    int cand = 0;
    int picked = -1;

    if (g_own_row >= 0) return;
    if (hp_max <= 0) return;

    for (i = 0; i < TNX_HERO_COUNT; i++) {
        if (g_heroes[i].hp != hp_max) continue;

        cand++;

        if (picked < 0) picked = i;
        if (speed_units > 0 && g_heroes[i].speed == speed_units) picked = i;
    }

    g_own_cand = cand;

    if (cand <= 0) return;

    tnx_hero_own(picked);

    TNX_LOGX("heroid hp=%d cand=%d picked=%s speed=%d - the own character is identified by matching "
             "the health the game reports against the table, which needs no new offsets: cand is how "
             "many characters share that health, so a candidate count of one is an identification "
             "and a large count means health alone cannot tell them apart and the observed speed is "
             "needed to break the tie",
             hp_max, cand, g_heroes[picked].title,
             (speed_units > 0) ? speed_units : g_heroes[picked].speed);
}

void tnx_hero_report(void) {
    int i = 0;
    int melee = 0;
    int speeds[8];
    int counts[8];
    int n = 0;

    for (i = 0; i < TNX_HERO_COUNT; i++) {
        int k = 0;
        int seen = -1;

        if (g_heroes[i].flags & TNX_HF_MELEE) melee++;

        for (k = 0; k < n; k++) {
            if (speeds[k] == g_heroes[i].speed) seen = k;
        }

        if (seen >= 0) counts[seen]++;
        else if (n < 8) {
            speeds[n] = g_heroes[i].speed;
            counts[n] = 1;
            n++;
        }
    }

    TNX_LOGX("hero table rows=%d melee=%d own=%d - rows is how many character records the table "
             "carries and melee is how many of them have no projectile at all, which is the group "
             "the shot model cannot see and that has to be dodged by body distance instead",
             TNX_HERO_COUNT, melee, g_own_row);
}
"""


def gen_chars(heroes, apply):
    body = ["", "const tnx_hero_t g_heroes[] = {"]
    for h in heroes:
        vals = [h[k] for k in ("hp", "speed", "radius", "wSpeed", "wRadius", "wCast", "wBullets",
                              "wBetween", "wSpread", "wCd", "wRecharge", "wCharge", "uSpeed",
                              "uRadius", "uBullets", "uSpread", "uRecharge", "flags")]
        f = '    { "%s", "%s", ' + ", ".join(["%d"] * len(vals)) + " },"
        body.append(f % tuple([h["name"], h["title"]] + vals))
    body += ["};", "",
             "#define TNX_HERO_COUNT ((int)(sizeof(g_heroes) / sizeof(g_heroes[0])))", "", "#endif", ""]
    write("src/data/chars_data.h", CHARS_H + "\n".join(body), apply)
    write("src/data/chars.mm", CHARS_MM_HEAD, apply)
    REPORT["generated"].append("src/data/chars_data.h rows=%d" % len(heroes))
    REPORT["generated"].append("src/data/chars.mm")
    say("chars", "generated table with %d rows" % len(heroes))


# ---------------------------------------------------------------- dead code
DEF_RE = re.compile(r"^(?:static\s+)?(?:const\s+)?[A-Za-z_][A-Za-z0-9_]*[ \*]*\b(tnx_[a-z0-9_]+)\s*\(")


def mm_files():
    out = []
    for dirpath, _, files in os.walk(os.path.join(ROOT, "src")):
        for f in files:
            if f.endswith((".mm", ".h")):
                out.append(os.path.relpath(os.path.join(dirpath, f), ROOT))
    return sorted(out)


def def_spans(text):
    spans = []
    lines = text.split("\n")
    for i, line in enumerate(lines):
        if line.startswith((" ", "\t")):
            continue
        m = DEF_RE.match(line)
        if not m:
            continue
        if line.rstrip().endswith(";"):
            continue
        depth = 0
        seen = False
        end = None
        for j in range(i, len(lines)):
            depth += lines[j].count("{") - lines[j].count("}")
            if "{" in lines[j]:
                seen = True
            if seen and depth <= 0:
                end = j
                break
        if end is None:
            continue
        spans.append((m.group(1), i, end))
    return spans


def call_sites(texts, name):
    pat = re.compile(r"\b" + re.escape(name) + r"\b")
    n = 0
    for path, t in texts.items():
        for i, line in enumerate(t.split("\n")):
            for _ in pat.finditer(line):
                if line.startswith((" ", "\t")) and not line.strip().startswith(("//", "/*")):
                    n += 1
                    continue
                if DEF_RE.match(line):
                    continue
                if line.rstrip().endswith(";"):
                    continue
                n += 1
    return n


GENERATED = ("src/data/chars_data.h", "src/data/chars.mm")

EXPLICIT = set(["tnx_write", "tnx_player_dump", "tnx_heap_dump", "tnx_walk", "tnx_trail",
                "tnx_test", "tnx_actuate", "tnx_probe", "tnx_witness", "tnx_witness_line",
                "tnx_frame_window", "tnx_window", "tnx_queue_line", "tnx_hop2", "tnx_snapshot_3",
                "tnx_sign", "tnx_probe_2", "tnx_probe_3", "tnx_drag", "tnx_setter", "tnx_elem_write"])


def dead_remove(roots, apply):
    texts = {p: read(p) for p in mm_files()}
    removed = []
    rounds = 0
    while rounds < 6:
        rounds += 1
        grew = False
        for path, t in list(texts.items()):
            for name, s, e in def_spans(t):
                if name in roots:
                    continue
                if call_sites(texts, name) == 0:
                    roots.add(name)
                    REPORT["removed_symbols"].append("%s (%s:%d)" % (name, path, s + 1))
                    grew = True
                    break
        if not grew:
            break
    for path in list(texts.keys()):
        if path in GENERATED:
            continue
        t = texts[path]
        spans = sorted([(s, e) for name, s, e in def_spans(t) if name in EXPLICIT], reverse=True)
        for s, e in spans:
            lines = t.split("\n")
            del lines[s:e + 1]
            while lines and s < len(lines) and lines[s].strip() == "":
                del lines[s]
            t = "\n".join(lines)
            removed.append((path, s))
            write(path, t, apply)
            texts[path] = t
    return removed, texts


def macro_refs(texts, name):
    pat = re.compile(r"\\b" + re.escape(name) + r"\\b")
    n = 0
    for path, t in texts.items():
        for line in t.split("\\n"):
            if re.match(r"^#define\\s+" + re.escape(name) + r"\\b", line):
                continue
            n += len(pat.findall(line))
    return n


def strip_defines(names, texts, apply):
    got = []
    kept = []
    for path in sorted(q for q in texts if q.endswith(".h")):
        t = texts[path]
        keep = []
        changed = False
        for line in t.split("\\n"):
            m = re.match(r"^#define\\s+(TNX_[A-Z0-9_]+)", line)
            if m and m.group(1) in names:
                left = macro_refs(texts, m.group(1))
                if left > 0:
                    kept.append("%s (%s, %d references left)" % (m.group(1), path, left))
                    keep.append(line)
                    continue
                got.append("%s (%s)" % (m.group(1), path))
                changed = True
                continue
            keep.append(line)
        if changed:
            write(path, "\\n".join(keep), apply)
    REPORT["removed_defines"] = got
    REPORT["kept_defines"] = kept
    return got


# ---------------------------------------------------------------- wiring
def wire(apply):
    mk = read("Makefile")
    if "src/data/*.mm" not in mk:
        mk = mk.replace(
            "Titanox_FILES += $(wildcard src/features/*.mm)",
            "Titanox_FILES += $(wildcard src/features/*.mm)\nTitanox_FILES += $(wildcard src/data/*.mm)")
        mk = mk.replace(COMMON_INCLUDES_ANCHOR, COMMON_INCLUDES_ANCHOR.replace("-Isrc \\", "-Isrc \\\n\t-Isrc/data \\"))
        write("Makefile", mk, apply)
        say("wire", "Makefile now compiles src/data and adds its include path")

    log = read("src/core/log.mm")
    m = re.search(r"drop=(\d+)", log)
    if m:
        old = int(m.group(1))
        new = old + 1
        log = log.replace("drop=%d" % old, "drop=%d" % new, 1)
        write("src/core/log.mm", log, apply)
        REPORT["checks"].append("drop stamp %d -> %d" % (old, new))
        say("wire", "drop stamp %d -> %d" % (old, new))

    for path, pairs in WIRE.items():
        patch_file(path, pairs, apply)

    allmm = "\n".join(read(q) for q in mm_files() if q.endswith(".mm"))
    if "tnx_hero_speed(" not in allmm:
        REPORT["skipped"].append("no own speed call site was wired, the table would be unused")
    else:
        REPORT["checks"].append("own speed is taken from the hero table")


COMMON_INCLUDES_ANCHOR = "COMMON_INCLUDES = \\\n\t-Isrc \\"

WIRE = {
    "src/features/autododge.mm": [
        ('#include "titanox.h"', '#include "titanox.h"\n#include "data/chars_data.h"'),
        ("dirX * TNX_PLAYER_SPEED", "dirX * (float)tnx_hero_speed()"),
        ("dirY * TNX_PLAYER_SPEED", "dirY * (float)tnx_hero_speed()"),
        ("travel / TNX_PLAYER_SPEED", "travel / (float)tnx_hero_speed()"),
        ("float speed = TNX_PLAYER_SPEED;", "float speed = (float)tnx_hero_speed();"),
    ],
    "src/features/report.mm": [
        ('#include "titanox.h"', '#include "titanox.h"\n#include "data/chars_data.h"'),
        ("    if (hpmax <= 0) return;\n", "    if (hpmax <= 0) return;\n\n    tnx_hero_identify(hpmax, 0);\n"),
    ],
}


def patch_file(path, pairs, apply):
    t = read(path)
    orig = t
    for old, new in pairs:
        if old not in t:
            REPORT["skipped"].append("%s: anchor not found: %s" % (path, old[:48]))
            continue
        t = t.replace(old, new, 1)
    if t != orig:
        write(path, t, apply)
        say("wire", "patched %s" % path)


def main():
    global VERSION

    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--version", default=VERSION)
    a = ap.parse_args()
    VERSION = a.version

    say("start", "version %s, mode %s" % (VERSION, "apply" if a.apply else "dry run"))
    fetch_tables(a.apply)
    heroes, P = build_heroes()
    self_check(heroes, P)
    gen_chars(heroes, a.apply)

    roots = set(["tnx_write", "tnx_player_dump", "tnx_heap_dump", "tnx_walk", "tnx_trail",
                 "tnx_test", "tnx_actuate", "tnx_probe", "tnx_witness", "tnx_witness_line",
                 "tnx_frame_window", "tnx_window", "tnx_queue_line", "tnx_hop2", "tnx_snapshot_3",
                 "tnx_sign", "tnx_probe_2", "tnx_probe_3", "tnx_drag"])
    wire(a.apply)

    cand = sorted(set(roots) - EXPLICIT)
    REPORT["candidates"] = cand

    removed, texts = dead_remove(roots, a.apply)
    say("deadcode", "removed %d definitions" % len(removed))
    strip_defines(set(["TNX_TEST_ENABLE", "TNX_TEST_X", "TNX_TEST_Y", "TNX_ACT_SETTER", "TNX_ACT_ELEM",
                       "TNX_ACT_LOGS", "TNX_PROBE_LOGS", "TNX_DRAG_MAG", "TNX_ENGAGE_2", "TNX_LOGS_7",
                       "TNX_MAX_LIFETIME_MS", "TNX_RAW_SWAP", "TNX_STAGE_MAX"]), texts, a.apply)

    gi = os.path.join(ROOT, ".gitignore")
    if a.apply:
        cur = io.open(gi, encoding="utf-8").read() if os.path.exists(gi) else ""
        add = ""
        for pat in ("tools/rework_report.md", "tools/rework_report.json"):
            if pat not in cur:
                add += pat + "\n"
        if add:
            with io.open(gi, "a", encoding="utf-8") as f:
                f.write(add)
            REPORT["changed"].append(".gitignore (report files are not committed)")

    with io.open(os.path.join(ROOT, "tools", "rework_report.json"), "w", encoding="utf-8") as f:
        f.write(json.dumps(REPORT, ensure_ascii=False, indent=1))
    with io.open(os.path.join(ROOT, "tools", "rework_report.md"), "w", encoding="utf-8") as f:
        f.write("# Titanox rework report\n\n")
        for k in ("stage", "generated", "removed_symbols", "removed_defines", "kept_defines", "candidates", "changed", "skipped", "checks"):
            f.write("## %s\n\n" % k)
            for x in REPORT[k]:
                f.write("- %s\n" % x)
            f.write("\n")
    say("done", "report written to tools/rework_report.md")
    return 0


if __name__ == "__main__":
    sys.exit(main())
