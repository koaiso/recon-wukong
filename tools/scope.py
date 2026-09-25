#!/usr/bin/env python3
"""Validate target scope and filter discovery output without external packages."""

import argparse
import collections
import ipaddress
import re
import sys
from urllib.parse import parse_qsl, urlsplit, urlunsplit


LABEL = re.compile(r"^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$")


def domain(value):
    value = value.strip().lower().rstrip(".")
    if not 4 <= len(value) <= 253 or "." not in value:
        raise ValueError("use a domain such as example.com")
    if any(not LABEL.fullmatch(part) for part in value.split(".")):
        raise ValueError("invalid domain label")
    try:
        ipaddress.ip_address(value)
    except ValueError:
        return value
    raise ValueError("IP addresses are not supported")


def within(host, root):
    try:
        host = domain(host)
    except ValueError:
        return False
    return host == root or host.endswith("." + root)


def clean_url(value, root):
    try:
        parts = urlsplit(value.strip())
        if parts.scheme.lower() not in ("http", "https") or not parts.hostname:
            return None
        if parts.username is not None or parts.password is not None:
            return None
        if not within(parts.hostname, root):
            return None
        port = parts.port  # Reject invalid ports.
        hostname = parts.hostname.lower().rstrip(".")
        netloc = hostname + (f":{port}" if port is not None else "")
        return urlunsplit((parts.scheme.lower(), netloc, parts.path or "/", parts.query, ""))
    except (ValueError, UnicodeError):
        return None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("validate", "hosts", "urls", "live", "params", "js", "api", "keys"))
    parser.add_argument("target")
    args = parser.parse_args()
    try:
        root = domain(args.target)
    except ValueError as exc:
        parser.error(str(exc))
    if args.action == "validate":
        print(root)
        return

    keys = collections.Counter()
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        if args.action == "hosts":
            host = line.lower().rstrip(".")
            if within(host, root):
                print(host)
            continue
        # httpx -status-code adds metadata after the URL.
        value = line.split(None, 1)[0] if args.action == "live" else line
        url = clean_url(value, root)
        if not url:
            continue
        parsed = urlsplit(url)
        if args.action in ("urls", "live"):
            print(url)
        elif args.action == "params" and parsed.query:
            if parse_qsl(parsed.query, keep_blank_values=True):
                print(url)
        elif args.action == "js" and parsed.path.lower().endswith(".js"):
            print(url)
        elif args.action == "api" and ("/api/" in parsed.path.lower() or parsed.path.lower().endswith("/graphql")):
            print(url)
        elif args.action == "keys":
            keys.update(key for key, _ in parse_qsl(parsed.query, keep_blank_values=True))
    if args.action == "keys":
        for key, count in sorted(keys.items(), key=lambda item: (-item[1], item[0])):
            print(f"{count}\t{key}")


if __name__ == "__main__":
    main()
