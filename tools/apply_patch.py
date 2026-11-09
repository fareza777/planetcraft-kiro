"""Apply find/replace hunks to a file. Each hunk must match exactly once.

Patch format:
    <<<< FIND
    old text
    ==== REPLACE
    new text
    >>>>

Usage: python tools/apply_patch.py <target_file> <patch_file>
"""
import sys

target, patch = sys.argv[1], sys.argv[2]
src = open(target, encoding="utf-8").read().replace("\r\n", "\n")
text = open(patch, encoding="utf-8").read().replace("\r\n", "\n")
hunks = []
for block in text.split("<<<< FIND\n")[1:]:
    find, rest = block.split("\n==== REPLACE\n", 1)
    repl = rest.split("\n>>>>", 1)[0]
    hunks.append((find, repl))
for i, (find, repl) in enumerate(hunks):
    n = src.count(find)
    if n != 1:
        sys.exit(f"hunk {i + 1}: expected 1 match, found {n}:\n{find[:200]}")
    src = src.replace(find, repl)
open(target, "w", encoding="utf-8", newline="\n").write(src)
print(f"applied {len(hunks)} hunks to {target}")
