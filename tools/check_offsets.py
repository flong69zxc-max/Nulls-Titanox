#!/usr/bin/env python3
"""Проверка правила: все адреса и смещения игры живут только в src/core/offsets.h.

Ловит три вещи вне offsets.h:
  1. собственный #define ..._OFF/_RVA/_ADDR/_SLOT/..._PTR;
  2. арифметику указателя с числовым литералом (obj + 0x1c);
  3. литерал, приведённый к указателю, и вызов с литералом-адресом.

Строки и комментарии вырезаются перед проверкой, поэтому упоминания вида
"+0x4c" внутри текста лога нарушением не считаются. Строку, которая законно
работает с числом, можно пометить комментарием offsets-ok.
"""

import os
import re
import sys

ROOT = "src"
OFFSETS = os.path.join(ROOT, "core", "offsets.h")
SUFFIXES = (".mm", ".m", ".h", ".c", ".cpp")

DEFINE_RE = re.compile(r"^\s*#\s*define\s+(TNX_[A-Z0-9_]*(?:_OFF|_RVA|_ADDR|_SLOT|_PTR))\b")
ARITH_RE = re.compile(r"\b[A-Za-z_][A-Za-z0-9_]*\s*[+\-]\s*0x[0-9a-fA-F]{2,}\b")
CAST_RE = re.compile(
    r"\(\s*(?:uintptr_t|intptr_t|uint32_t|void\s*\*|char\s*\*|[A-Za-z_][A-Za-z0-9_]*\s*\*)\s*\)\s*0x[0-9a-fA-F]{4,}"
)
CALL_RE = re.compile(r"\b[A-Za-z_][A-Za-z0-9_]*\s*\(\s*0x[0-9a-fA-F]{5,}")


def strip_code(text):
    """Убирает комментарии и содержимое строковых литералов, оставляя разметку строк."""
    out = []
    i = 0
    n = len(text)
    while i < n:
        c = text[i]
        two = text[i:i + 2]
        if two == "//":
            j = text.find("\n", i)
            i = n if j < 0 else j
            continue
        if two == "/*":
            j = text.find("*/", i + 2)
            i = n if j < 0 else j + 2
            continue
        if c == '"' or c == "'":
            quote = c
            i += 1
            while i < n and text[i] != quote:
                if text[i] == "\\":
                    i += 1
                i += 1
            i += 1
            out.append(quote + quote)
            continue
        out.append(c)
        i += 1
    return "".join(out)


def main():
    if not os.path.isfile(OFFSETS):
        print("нет %s" % OFFSETS)
        return 1

    bad = []
    for base, _, files in os.walk(ROOT):
        for name in files:
            path = os.path.join(base, name)
            if not name.endswith(SUFFIXES) or os.path.normpath(path) == os.path.normpath(OFFSETS):
                continue
            raw = open(path, encoding="utf-8", errors="replace").read()
            for lineno, line in enumerate(raw.split("\n"), 1):
                if "offsets-ok" in line:
                    continue
                m = DEFINE_RE.match(line)
                if m:
                    bad.append((path, lineno, "макрос смещения объявлен вне offsets.h", m.group(1)))
                    continue
            code = strip_code(raw)
            for lineno, line in enumerate(code.split("\n"), 1):
                for rx, why in ((ARITH_RE, "арифметика указателя с литералом"),
                                (CAST_RE, "литерал, приведённый к указателю"),
                                (CALL_RE, "вызов с литералом-адресом")):
                    m = rx.search(line)
                    if m:
                        bad.append((path, lineno, why, m.group(0).strip()))
                        break

    for path, lineno, why, what in bad:
        print("%s:%d: %s: %s" % (path, lineno, why, what))

    if bad:
        print("\n%d мест с числами вне offsets.h - перенеси их туда и дай имя"
              % len(bad))
        return 1
    print("адреса и смещения только в %s" % OFFSETS)
    return 0


if __name__ == "__main__":
    sys.exit(main())
