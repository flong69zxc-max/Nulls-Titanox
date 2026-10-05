#!/usr/bin/env python3
# Structural verification of the reworked source tree. Exits non zero on the first hard failure.
import io, json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FAIL = []
WARN = []
INFO = []


def fail(msg):
    FAIL.append(msg)
    print("FAIL  %s" % msg)


def warn(msg):
    WARN.append(msg)
    print("WARN  %s" % msg)


def ok(msg):
    INFO.append(msg)
    print("ok    %s" % msg)


def files(exts):
    out = []
    for dirpath, _, fs in os.walk(os.path.join(ROOT, "src")):
        for f in fs:
            if f.endswith(exts):
                out.append(os.path.relpath(os.path.join(dirpath, f), ROOT))
    return sorted(out)


def read(p):
    return io.open(os.path.join(ROOT, p), encoding="utf-8", errors="replace").read()


def code_only(t):
    out = []
    i = 0
    n = len(t)
    while i < n:
        c = t[i]
        if c == '"' or c == "'":
            q = c
            i += 1
            while i < n and t[i] != q:
                if t[i] == "\\":
                    i += 1
                i += 1
            i += 1
            continue
        out.append(c)
        i += 1
    return "".join(out)


ALL = files((".mm", ".h"))

for p in ALL:
    t = code_only(read(p))
    if t.count("{") != t.count("}"):
        fail("%s brace mismatch %d/%d" % (p, t.count("{"), t.count("}")))
    if t.count("(") != t.count(")"):
        fail("%s paren mismatch %d/%d" % (p, t.count("("), t.count(")")))
ok("braces and parens balanced in %d files" % len(ALL))

for p in ALL:
    t = read(p)
    for i, line in enumerate(t.split("\n"), 1):
        s = line.strip()
        if s.startswith("//") or s.startswith("/*"):
            fail("%s:%d carries a comment" % (p, i))
            break
for p in ALL:
    t = read(p)
    op = len(re.findall(r"^\s*#\s*(?:if|ifdef|ifndef)\b", t, re.M))
    cl = len(re.findall(r"^\s*#\s*endif\b", t, re.M))
    if op != cl:
        fail("%s has %d #if and %d #endif, the preprocessor nesting does not close" % (p, op, cl))
ok("no comment lines")

for p in ALL:
    t = read(p)
    for tagname in ("TNX_CHARS_DATA_H",):
        if t.startswith("#ifndef " + tagname) and t.rstrip().count("#endif") != 1:
            fail("%s opens a guard and closes it %d times, the table would sit outside the include guard" % (p, t.rstrip().count("#endif")))
ok("include guards close exactly once")

for p in ALL:
    for m in re.finditer(r'#include\s+"([^"]+)"', read(p)):
        inc = m.group(1)
        cands = [os.path.join(os.path.dirname(os.path.join(ROOT, p)), inc),
                 os.path.join(ROOT, "src", inc), os.path.join(ROOT, "include", inc),
                 os.path.join(ROOT, "src", "data", inc), os.path.join(ROOT, inc)]
        if not any(os.path.exists(c) for c in cands) and "deps/" not in inc:
            warn("%s includes %s, which is not in src/ - it must come from the theos include path" % (p, inc))
            break
ok("quoted includes resolve")

mk = io.open(os.path.join(ROOT, "Makefile"), encoding="utf-8", errors="replace").read()
for need in ("src/core/*.mm", "src/utils/*.mm", "src/helpers/*.mm", "src/features/*.mm", "src/*.mm"):
    if need not in mk:
        fail("Makefile stopped compiling %s" % need)
if os.path.isdir(os.path.join(ROOT, "src", "data")):
    if "src/data/*.mm" not in mk:
        fail("src/data exists but the Makefile does not compile it, so the hero table would be dead code")
    if "-Isrc/data" not in mk:
        warn("Makefile has no -Isrc/data include path")
ok("Makefile covers the source tree")

cd = os.path.join(ROOT, "src", "data", "chars_data.h")
if not os.path.exists(cd):
    fail("src/data/chars_data.h is missing")
else:
    t = read("src/data/chars_data.h")
    rows = [l for l in t.split("\n") if l.startswith('    { "')]
    if len(rows) < 100:
        fail("hero table has only %d rows" % len(rows))
    m = re.search(r"typedef struct \{(.*?)\} tnx_hero_t;", t, re.S)
    fields = 0
    if m:
        fields = len([x for x in m.group(1).split("\n") if x.strip() and x.strip().endswith(";")])
    if fields <= 0:
        fail("tnx_hero_t struct not found, cannot check the row shape")
    bad = [l for l in rows if l.count(",") != fields]
    if bad:
        fail("hero table has %d rows with a wrong field count, first: %s" % (len(bad), bad[0][:60]))
    names = re.findall(r'\{\s*"([^"]+)"', t)
    if len(names) != len(set(names)):
        fail("hero table has duplicate names")
    if "TNX_HERO_COUNT" not in t:
        fail("hero table has no TNX_HERO_COUNT")
    ok("hero table: %d rows" % len(rows))

log = read("src/core/log.mm")
if not re.search(r"drop=\d+", log):
    fail("src/core/log.mm lost its drop= stamp, the publish check would have nothing to verify")
else:
    ok("drop stamp present: %s" % re.search(r"drop=\d+", log).group(0))

rep = os.path.join(ROOT, "tools", "rework_report.json")
if os.path.exists(rep):
    r = json.load(io.open(rep, encoding="utf-8"))
    gone = [x.split(" ")[0] for x in r.get("removed_symbols", [])]
    allt = "\n".join(read(p) for p in ALL)
    for name in gone:
        left = 0
        pat = re.compile(r"\b" + re.escape(name) + r"\b")
        for p2 in ALL:
            for line in read(p2).split("\n"):
                if not pat.search(line):
                    continue
                if line.rstrip().endswith(";"):
                    continue
                if line and not line[0].isspace():
                    continue
                left += 1
        if left:
            fail("removed symbol %s still has %d references" % (name, left))
    ok("no dangling references to %d removed symbols" % len(gone))
    if r.get("skipped"):
        for s in r["skipped"]:
            warn("skipped patch: %s" % s)

print("\n%d checks failed, %d warnings" % (len(FAIL), len(WARN)))
sys.exit(1 if FAIL else 0)
