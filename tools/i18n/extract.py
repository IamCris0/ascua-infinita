"""Collects the player-facing Spanish texts of the game and keeps
locale/en.json in step with them.

Run from the project root:  python tools/i18n/extract.py [--report]

Every string literal in scripts/*.gd that reads as text (not a path, a colour,
an id or a key) becomes an entry of locale/en.json. Existing translations are
kept; new texts arrive with an empty value to fill in; texts no longer found
are listed and removed. Entries under "templates" are written by hand for texts
the code builds by joining pieces, and are never removed.

--report lists the texts still missing a translation and exits with 1 if any.
"""
import glob
import json
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
TARGET = os.path.join(ROOT, "locale", "en.json")
SKIP_FILES = {"i18n.gd", "build_check.gd", "audio_director.gd", "art_library.gd", "actor.gd", "fly_layer.gd", "stone_panel.gd", "ui_kit.gd", "title_art.gd"}
# Lowercase single words that are shown to the player (everything else that
# looks like an identifier is treated as one).
SHOWN_WORDS = {"esquirlas", "ascuas", "oro", "ascuas disponibles", "en la hoguera", "sin juramento"}
ID = re.compile(r"^[a-z][a-z0-9_]*$")
HEX = re.compile(r"^#?[0-9a-fA-F]{6,8}$")


def literals(line):
    """String literals of one line of GDScript, skipping comments."""
    out = []
    i = 0
    n = len(line)
    while i < n:
        ch = line[i]
        if ch == "#":
            break
        if ch == '"':
            j = i + 1
            buf = []
            while j < n and line[j] != '"':
                if line[j] == "\\" and j + 1 < n:
                    buf.append({"n": "\n", "t": "\t", '"': '"', "\\": "\\"}.get(line[j + 1], line[j + 1]))
                    j += 2
                    continue
                buf.append(line[j])
                j += 1
            out.append("".join(buf))
            i = j + 1
            continue
        i += 1
    return out


def shown(text):
    if not re.search(r"[A-Za-zÁÉÍÓÚÑáéíóúñü]", text):
        return False
    if text.startswith(("res://", "user://", "--")) or HEX.match(text):
        return False
    if ID.match(text) and text not in SHOWN_WORDS:
        return False
    if text in ("Godot", "%s", "v", "E", "[Q]", "ASCUA", "ASCUA INFINITA", "I N F I N I T A", "  ·  Godot 4.7", "CAPTURE_OK ") or text.startswith("."):
        return False
    # Number formats such as "%.1fk" or "%.2fe%d".
    if re.fullmatch(r"(%[.\d]*[dfs]|[BMTke])+", text):
        return False
    # Paths, property paths and collection id prefixes.
    if "/" in text and " " not in text or re.fullmatch(r"[a-z_]+:[a-z_]*", text):
        return False
    return True


def collect():
    found = {}
    for path in sorted(glob.glob(os.path.join(ROOT, "scripts", "*.gd"))):
        name = os.path.basename(path)
        if name in SKIP_FILES:
            continue
        for number, line in enumerate(open(path, encoding="utf-8"), 1):
            stripped = line.strip()
            if stripped.startswith("#") or stripped.startswith("##"):
                continue
            # Node, signal and input names are not text.
            if "get_node(" in line or "has_meta(" in line or "set_meta(" in line or "remove_meta(" in line:
                continue
            # Console output is for developers.
            if "print(" in line or "printerr(" in line or "push_error(" in line or "push_warning(" in line:
                continue
            for text in literals(line):
                if shown(text):
                    found.setdefault(text, "%s:%d" % (name, number))
    return found


def main():
    found = collect()
    data = {"texts": {}, "templates": {}}
    if os.path.exists(TARGET):
        data = json.load(open(TARGET, encoding="utf-8"))
    texts = data.get("texts", {})
    # A text written by hand as a template stays there.
    found = {k: v for k, v in found.items() if k not in data.get("templates", {})}
    removed = [k for k in texts if k not in found]
    merged = {k: texts.get(k, "") for k in sorted(found)}
    data = {"texts": merged, "templates": dict(sorted(data.get("templates", {}).items()))}
    os.makedirs(os.path.dirname(TARGET), exist_ok=True)
    with open(TARGET, "w", encoding="utf-8", newline="\n") as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
        f.write("\n")
    missing = [k for k, v in merged.items() if not v]
    print("textos: %d  ·  sin traducir: %d  ·  retirados: %d  ·  plantillas: %d" % (len(merged), len(missing), len(removed), len(data["templates"])))
    if "--report" in sys.argv:
        for k in missing:
            print("  %-28s %s" % (found[k], k))
        sys.exit(1 if missing else 0)


if __name__ == "__main__":
    main()
