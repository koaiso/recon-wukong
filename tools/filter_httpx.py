#!/usr/bin/env python3
"""Keep detailed httpx rows only for approved live URLs."""

import sys


with open(sys.argv[1], encoding="utf-8") as handle:
    allowed = {line.strip() for line in handle}
for line in sys.stdin:
    if line.split(None, 1) and line.split(None, 1)[0] in allowed:
        print(line.rstrip("\n"))
