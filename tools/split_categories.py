#!/usr/bin/env python3
"""Give the Titanox source tree one file per responsibility.

Run from the repo root:

    python3 tools/split_categories.py --plan      # what would move where, nothing written
    python3 tools/split_categories.py --apply     # rewrite src/ in place
    python3 tools/split_categories.py --apply --commit

Rules that keep both sides compiling:

  * every top level definition (function or global) is owned by exactly one module;
  * a definition that stays keeps its bytes; a definition that travels is cut out of its
    old file and appended to its new one, original relative order kept;
  * a `static` definition that another file now references loses `static` and gets a
    declaration in its own module header;
  * a `static` definition nothing outside touches stays private, and its new file gets a
    forward declaration so the order inside the file cannot break the build;
  * a block of preprocessor defaults that a moved function needs moves to
    src/core/tuning.h, which titanox.h includes before anything else;
  * every module header is generated from the definitions it exports, so no hand written
    prototype list can go stale.

Idempotent: the second run plans nothing.
"""

import argparse
import os
import re
import subprocess
import sys

ENTRY = "src/titanox.h"
TUNING = "src/core/tuning.h"

MODULES = {
    "players": ("src/players", "rosters, teams, and which object is the player"),
    "overlay": ("src/ui", "the on screen readout and the alerts"),
    "diag": ("src/diag", "dumps, probes and reports; nothing here decides anything"),
    "learn": ("src/learning", "tuning keys, learning rates and running statistics"),
    "drive": ("src/input", "the leg that actually moves the character"),
    "starts": ("src/core", "the branch target table: prologues, entries and terms"),
    "objc": ("src/core", "the Objective-C side of the hook set"),
}

EXPLICIT = {
    "players": """
        tnx_team_at tnx_roster tnx_own_ok tnx_enemy_blocked tnx_mate_blocked
        tnx_own_side_spawn tnx_side_near tnx_side_score tnx_side_pick
        tnx_clear_life tnx_respawn_event tnx_life
        tnx_own_latch tnx_take_own tnx_inject_own tnx_own_from_list
        tnx_own_by_min_gid tnx_own_scan tnx_resolve_own_2 tnx_own_probe
        tnx_own_verdict tnx_own_dump tnx_own tnx_own_obj
        tnx_resolve_own tnx_own_index_probe tnx_publish_own tnx_own_from_slot
        tnx_container_has
    """,
    "drive": """
        tnx_select tnx_drive tnx_write tnx_snap tnx_predict_2 tnx_precision
        tnx_speed tnx_stick tnx_route tnx_drag
        tnx_bs tnx_joy_read tnx_joy_angle
    """,
    "starts": """
        tnx_prologue_rule tnx_looks_like_start tnx_start_index tnx_start_word
        tnx_start_boundary tnx_load_function_starts tnx_word tnx_is_term
        tnx_is_prologue tnx_entry tnx_sc_string tnx_skip_compound
    """,
    "objc": """
        tnx_objc_arg_types tnx_class_owns_method tnx_owner_class tnx_objc_find
        tnx_objc_targets tnx_objc_rep0 tnx_objc_rep1 tnx_objc_rep1b tnx_objc_rep2
        tnx_objc_arm
    """,
    "overlay": """
        tnx_overlay_attach tnx_overlay_update tnx_render_watermark
        tnx_alert_menu tnx_battle_alert tnx_alert_battle_check
    """,
    "learn": """
        tnx_key_c tnx_key_t tnx_learn_rate tnx_blacklisted
        tnx_stat_tick tnx_stat_report
    """,
}
for _m in EXPLICIT:
    EXPLICIT[_m] = set(EXPLICIT[_m].split())

DIAG_EXACT = set("""
    tnx_dump tnx_core tnx_probe_2 tnx_drift tnx_candidates tnx_cand_name
    tnx_report_mode_hit tnx_vtcensus_top tnx_slot_diag tnx_diag_report tnx_report_manager
    tnx_trail_dump tnx_slot_table_dump tnx_object_detail tnx_engage_report
    tnx_players_dump tnx_hop_dump tnx_own_dump tnx_team_dump tnx_class_dump tnx_map_dump
    tnx_slot_line tnx_readback tnx_statics tnx_write_test tnx_audit_all tnx_pos_trace
    tnx_slot_probe tnx_gate_report
    tnx_witness tnx_witness_line tnx_fields tnx_fields_pair tnx_window tnx_frame_window
    tnx_queue_line tnx_test
    tnx_receiver_line tnx_receiver_probe tnx_hook_dispatches tnx_object_dispatches
    tnx_trail_verdict
""".split())

WORD = re.compile(r"\b[A-Za-z_]\w*")
STRINGY = re.compile(r'"(?:[^"\\]|\\.)*"|\'(?:[^\'\\]|\\.)*\'')
KEYWORDS = set("""if else for while do switch case default break continue return sizeof struct union
enum class typedef static const void int char short long float double signed unsigned bool true
false NULL nullptr auto register volatile extern inline new delete public private protected
virtual typename template using namespace friend explicit mutable""".split())
DEFINE_RE = re.compile(r"^\s*#\s*define\s+([A-Za-z_]\w*)")


def strip_comments(text):
    out, i, n = [], 0, len(text)
    while i < n:
        c = text[i]
        if c in "\"'":
            q, out = c, out + [c]
            i += 1
            while i < n:
                if text[i] == "\\" and i + 1 < n:
                    out.append(text[i:i + 2])
                    i += 2
                    continue
                out.append(text[i])
                if text[i] == q:
                    i += 1
                    break
                i += 1
            continue
        if c == "/" and text[i:i + 2] == "//":
            while i < n and text[i] != "\n":
                i += 1
            continue
        if c == "/" and text[i:i + 2] == "/*":
            i += 2
            while i + 1 < n and text[i:i + 2] != "*/":
                i += 1
            i += 2
            continue
        out.append(c)
        i += 1
    return "".join(out)


def blank_strings(text):
    return STRINGY.sub(lambda m: '"' + " " * (len(m.group(0)) - 2) + '"', text)


def match_brace(t, i):
    d = 0
    while i < len(t):
        if t[i] == "{":
            d += 1
        elif t[i] == "}":
            d -= 1
            if d == 0:
                return i + 1
        i += 1
    return len(t)


def match_paren(t, i):
    d = 0
    while i < len(t):
        if t[i] == "(":
            d += 1
        elif t[i] == ")":
            d -= 1
            if d == 0:
                return i + 1
        i += 1
    return len(t)


FUNC_RE = re.compile(
    r"(?m)^(static\s+)?((?:const\s+)?(?:unsigned\s+)?[A-Za-z_][A-Za-z0-9_]*(?:\s*\*)?)\s*"
    r"([A-Za-z_][A-Za-z0-9_]*)\s*\(")
# the type is an atomic group: without it the identifier backtracks and the last
# letter of the name gets split off ("unsigned g_vt_text_rejects" -> "unsigned
# g_vt_text_reject" + "s")
GLOB_RE = re.compile(
    r"(?m)^(static\s+)?((?:const\s+)?(?:unsigned\s+)?(?>[A-Za-z_][A-Za-z0-9_]*)(?:\s*\*)?)\s*"
    r"([A-Za-z_][A-Za-z0-9_]*)\s*((?:\[[^\]]*\])*)\s*(=[^;]*)?;")


class Block(object):
    def __init__(self, name, kind, path, start, end, text, static, ret, dims, sane):
        self.name, self.kind, self.path = name, kind, path
        self.start, self.end, self.text = start, end, text
        self.static, self.ret, self.dims, self.sane = static, ret, dims, sane
        self.home = path
        self.assign = None


def scan_file(path):
    raw = open(path, encoding="utf-8", errors="replace").read()
    sane = blank_strings(strip_comments(raw))
    blocks, claimed = [], []

    for m in FUNC_RE.finditer(sane):
        if m.group(3) in KEYWORDS:
            continue
        p = sane.index("(", m.start())
        end = match_paren(sane, p)
        if not sane[end:end + 60].lstrip().startswith("{"):
            continue
        brace = sane.index("{", end)
        close = match_brace(sane, brace)
        blocks.append(Block(m.group(3), "function", path, m.start(), close,
                            raw[m.start():close], bool(m.group(1)), m.group(2), "",
                            sane[m.start():close]))
        claimed.append((m.start(), close))

    for m in GLOB_RE.finditer(sane):
        if m.group(3) in KEYWORDS or any(a <= m.start() < b for a, b in claimed):
            continue
        if "(" in sane[m.start():m.end()].split("=")[0]:
            continue
        blocks.append(Block(m.group(3), "global", path, m.start(), m.end(),
                            raw[m.start():m.end()], bool(m.group(1)), m.group(2),
                            m.group(4), sane[m.start():m.end()]))
    return raw, blocks


def pp_regions(raw):
    """Maximal runs of macro preprocessor lines (blank lines allowed inside).

    A run never starts at an #include, and it always ends at the last directive of the
    run, so an #ifndef/#endif pair is never cut in half.
    """
    lines = raw.split("\n")
    is_pp = lambda l: l.lstrip().startswith("#") and not l.lstrip().startswith("#include")
    regions = []
    i, n = 0, len(lines)
    while i < n:
        if not is_pp(lines[i]):
            i += 1
            continue
        j, last = i, -1
        while j < n:
            if is_pp(lines[j]):
                if DEFINE_RE.match(lines[j].lstrip()):
                    last = j
                j += 1
            elif not lines[j].strip():
                j += 1
            else:
                break
        if last < i:
            i += 1
            continue
        end = j
        while end > i and not lines[end - 1].strip():
            end -= 1
        start = sum(len(x) + 1 for x in lines[:i])
        stop = sum(len(x) + 1 for x in lines[:end])
        text = "\n".join(lines[i:end]) + "\n"
        names = set()
        for l in lines[i:end]:
            d = DEFINE_RE.match(l.lstrip())
            if d:
                names.add(d.group(1))
        regions.append((start, stop, text, names))
        i = j
    return regions


def remove_spans(text, spans):
    """Delete spans, and the blank lines they leave behind, keeping every other byte."""
    if not spans:
        return text
    lines = text.split("\n")
    offs, pos = [], 0
    for l in lines:
        offs.append(pos)
        pos += len(l) + 1
    kill = [False] * len(lines)
    for s_, e_ in spans:
        for i, o in enumerate(offs):
            if o >= e_:
                break
            if o + len(lines[i]) + 1 > s_:
                kill[i] = True
    i = 0
    while i < len(lines):
        if not kill[i]:
            i += 1
            continue
        j = i
        while j + 1 < len(lines) and kill[j + 1]:
            j += 1
        while j + 1 < len(lines) and not lines[j + 1].strip():
            j += 1
            kill[j] = True
        i = j + 1
    return "\n".join(l for l, k in zip(lines, kill) if not k)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--plan", action="store_true")
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--commit", action="store_true")
    ap.add_argument("--root", default=".")
    a = ap.parse_args()

    root = os.path.abspath(a.root)
    src = os.path.join(root, "src")
    if not os.path.isdir(src):
        print("no src/ here - run from the repo root")
        return 2

    files = []
    for base, dirs, names in os.walk(src):
        dirs[:] = [d for d in dirs if d != ".git"]
        files += [os.path.join(base, f) for f in names if f.endswith(".mm")]
    files.sort()

    sources, blocks, regions = {}, [], {}
    for f in files:
        raw, bs = scan_file(f)
        sources[f] = raw
        blocks.extend(bs)
        regions[f] = pp_regions(raw)

    by_name = {}
    for b in blocks:
        by_name.setdefault(b.name, []).append(b)
    ambiguous = set(n for n, v in by_name.items() if len(v) > 1)

    # --- ownership ---------------------------------------------------------
    for b in blocks:
        if b.name in ambiguous:
            continue
        for mod, names in EXPLICIT.items():
            if b.name in names:
                b.assign = mod
                break
        if b.assign is None and b.kind == "function" and b.name in DIAG_EXACT:
            b.assign = "diag"
    for b in blocks:
        if b.name in ambiguous or b.assign or b.kind != "global":
            continue
        # a definition already filed under a module stays there, so a second run is a no-op
        here = None
        for mod, (d, _t) in MODULES.items():
            if b.path == os.path.join(root, d, mod + ".mm"):
                here = mod
        if here:
            b.assign = here
            continue
        votes = {}
        for o in blocks:
            if o.kind == "function" and re.search(r"\b%s\b" % re.escape(b.name), o.sane):
                m = o.assign
                if m is None and len(set(d for d, _t in MODULES.values())) == \
                        len(MODULES):
                    for mod, (d, _t) in MODULES.items():
                        if os.path.dirname(o.path) == os.path.join(root, d):
                            m = mod
                if m:
                    votes[m] = votes.get(m, 0) + 1
        if votes:
            best = max(votes.items(), key=lambda kv: kv[1])
            if best[1] >= 2:
                b.assign = best[0]

    for b in blocks:
        b.home = os.path.join(root, MODULES[b.assign][0], b.assign + ".mm") if b.assign \
            else b.path

    # --- reference graph ---------------------------------------------------
    refs = {}
    for b in blocks:
        for w in set(WORD.findall(b.sane)):
            refs.setdefault(w, []).append(b)

    def outside(b):
        pat = re.compile(r"\b%s\s*\(" % re.escape(b.name)) if b.kind == "function" \
            else re.compile(r"\b%s\b" % re.escape(b.name))
        for o in refs.get(b.name, []):
            if o is not b and o.home != b.home and pat.search(o.sane):
                return True
        return False

    exported = dict((b.name, b) for b in blocks
                    if b.name not in ambiguous and b.static and outside(b))

    header_text = {}
    for f in files:
        h = f[:-3] + ".h"
        if os.path.exists(h):
            header_text[h] = open(h, encoding="utf-8").read()
    extra_decls, new_headers = {}, []
    for b in blocks:
        if b.assign or b.name in ambiguous or not outside(b):
            continue
        if any(re.search(r"\b%s\b" % re.escape(b.name), t) for t in header_text.values()):
            continue
        if b.kind == "global":
            line = "extern %s %s%s;" % (re.sub(r"^static\s+", "", b.ret).strip(),
                                        b.name, b.dims or "")
        else:
            line = re.sub(r"^static\s+", "",
                          re.sub(r"\s+", " ", b.text.split("{", 1)[0]).strip()) + ";"
        extra_decls.setdefault(b.path[:-3] + ".h", []).append(line)

    # --- macro regions a moved definition depends on ------------------------
    move_regions = {}
    for f, rs in regions.items():
        keep = []
        for r in rs:
            needed = False
            for macro in r[3]:
                pat = re.compile(r"\b%s\b" % re.escape(macro))
                for b in blocks:
                    if b.home != f and pat.search(b.sane):
                        needed = True
                        break
                if needed:
                    break
            (move_regions.setdefault(f, []) if needed else keep).append(r)
        regions[f] = keep

    # --- report ------------------------------------------------------------
    moves = [b for b in blocks if b.assign and b.path != b.home]
    print("=== %d definitions in %d files, %d move" % (len(blocks), len(files), len(moves)))
    for mod in sorted(MODULES):
        mv = [b for b in moves if b.assign == mod]
        fn = sum(1 for b in mv if b.kind == "function")
        print("  %-8s -> %-28s %3d funcs %3d globals" %
              (mod, os.path.relpath(os.path.join(root, MODULES[mod][0], mod + ".mm"), root),
               fn, len(mv) - fn))
    left = {}
    for b in moves:
        left[b.path] = left.get(b.path, 0) + 1
    for p in sorted(left):
        print("  leaving  %-28s %3d" % (os.path.relpath(p, root), left[p]))
    if ambiguous:
        print("  untouched (defined twice): %s" % ", ".join(sorted(ambiguous)))
    print("  %d definition(s) stop being static, %d shared symbol(s) get a new declaration" %
          (len(exported), sum(len(v) for v in extra_decls.values())))
    for f, rs in sorted(move_regions.items()):
        if rs:
            print("  %s: %d macro block(s) -> %s" %
                  (os.path.relpath(f, root), len(rs), os.path.relpath(TUNING, root)))

    if not a.apply:
        print("\nnothing written. add --apply.")
        return 0

    # --- rewrite -----------------------------------------------------------
    written = []
    for tgt in sorted(set(b.home for b in blocks)):
        stays = [b for b in blocks if b.home == tgt]
        gone = [b for b in blocks if b.path == tgt and b.home != tgt]
        joined = [b for b in stays if b.path != tgt]
        existing = tgt in sources
        if existing and not gone and not joined and tgt not in move_regions:
            continue
        if existing:
            spans = [(b.start, b.end) for b in gone] + \
                    [(r[0], r[1]) for r in move_regions.get(tgt, [])]
            body = remove_spans(sources[tgt], spans).rstrip("\n") + "\n"
        else:
            body = '#include "titanox.h"\n'
        out = [body]
        for b in sorted(joined, key=lambda b: (b.path, b.start)):
            out.append("\n" + (re.sub(r"^static\s+", "", b.text) if b.name in exported
                               else b.text) + "\n")
        if not existing:
            priv = sorted([b for b in stays if b.static and b.name not in exported
                           and b.kind == "function"], key=lambda b: b.name)
            if priv:
                out.insert(1, "\n" + "\n".join(
                    "static " + re.sub(r"^static\s+", "",
                                       re.sub(r"\s+", " ", b.text.split("{", 1)[0]).strip()) + ";"
                    for b in priv) + "\n")
        written.append([tgt, "".join(out)])

    for rec in written:
        text = rec[1]
        for b in blocks:
            if b.path == rec[0] and b.name in exported:
                text = re.sub(r"(?m)^static\s+(?=[^\n]*\b%s\s*[=(])" % re.escape(b.name),
                              "", text, count=1)
        rec[1] = text
        os.makedirs(os.path.dirname(rec[0]), exist_ok=True)
        open(rec[0], "w", encoding="utf-8").write(rec[1])

    # --- headers -----------------------------------------------------------
    for hpath, lines in sorted(extra_decls.items()):
        os.makedirs(os.path.dirname(hpath), exist_ok=True)
        if os.path.exists(hpath):
            body = open(hpath, encoding="utf-8").read()
            body = body.replace("\n#endif", "\n" + "\n".join(sorted(lines)) + "\n\n#endif", 1)
        else:
            rel = os.path.relpath(hpath, root)
            guard = ("TITANOX_" + rel.replace("src/", "").replace("/", "_")
                     .replace(".", "_")).upper()
            body = "\n".join(["#ifndef %s" % guard, "#define %s" % guard, "",
                              '#include "core/types.h"', ""] + sorted(lines)
                             + ["", "#endif", ""])
            new_headers.append('#include "%s"' % os.path.relpath(hpath, src))
        open(hpath, "w", encoding="utf-8").write(body)

    for mod, (d, title) in MODULES.items():
        exports = [b for b in blocks if b.assign == mod
                   and (not b.static or b.name in exported)]
        lines = []
        for b in sorted(exports, key=lambda b: (b.kind != "global", b.name)):
            if b.kind == "global":
                lines.append("extern %s %s%s;" % (re.sub(r"^static\s+", "", b.ret).strip(),
                                                  b.name, b.dims or ""))
            else:
                lines.append(re.sub(r"^static\s+", "",
                                    re.sub(r"\s+", " ", b.text.split("{", 1)[0]).strip()) + ";")
        guard = ("TITANOX_" + d.replace("src/", "").replace("/", "_") + "_" + mod + "_H").upper()
        text = "\n".join(["#ifndef %s" % guard, "#define %s" % guard, "",
                          '#include "core/types.h"', "", "/* %s */" % title, ""]
                         + lines + ["", "#endif", ""])
        path = os.path.join(root, d, mod + ".h")
        os.makedirs(os.path.dirname(path), exist_ok=True)
        open(path, "w", encoding="utf-8").write(text)

    moved_pp = [r for _f, rs in move_regions.items() for r in rs]
    if moved_pp:
        text = "\n".join([
            "#ifndef TITANOX_CORE_TUNING_H", "#define TITANOX_CORE_TUNING_H", "",
            "/* Tuning defaults that used to sit inside a .mm. A translation unit only sees",
            "   its own file, so anything a moved function needs has to live up here. */", ""]
            + [r[2].strip() + "\n" for r in sorted(moved_pp, key=lambda r: r[0])]
            + ["#endif", ""])
        os.makedirs(os.path.join(root, "src/core"), exist_ok=True)
        open(os.path.join(root, TUNING), "w", encoding="utf-8").write(text)

    entry = os.path.join(root, ENTRY)
    body = open(entry, encoding="utf-8").read()
    if '#include "core/tuning.h"' not in body:
        body = body.replace('#include "core/config.h"',
                            '#include "core/config.h"\n#include "core/tuning.h"', 1)
    wanted = sorted(set([('#include "%s/%s.h"' % (d.replace("src/", ""), mod))
                         for mod, (d, _t) in MODULES.items()] + new_headers))
    fresh = [l for l in wanted if l not in body]
    if fresh:
        body = body.replace("\n#endif", "\n" + "\n".join(fresh) + "\n\n#endif", 1)
    open(entry, "w", encoding="utf-8").write(body)

    print("\nwrote %d source files, %d headers, %d macro blocks" %
          (len(written), len(MODULES) + len(new_headers), len(moved_pp)))
    if a.commit:
        run(["git", "add", "-A"], root)
        run(["git", "commit", "-m", "refactor: one file per responsibility"], root)
    return 0


def run(cmd, cwd):
    print("$ " + " ".join(cmd))
    return subprocess.run(cmd, cwd=cwd).returncode


if __name__ == "__main__":
    sys.exit(main())
