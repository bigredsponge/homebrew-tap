#!/usr/bin/env python3
"""Print this tap's formulae whose bottles need rebuilding, one per line, as
"<formula>\t<dependency> [<dependency> ...]".

Homebrew/core raises a formula's `compatibility_version` when its new version
needs its dependents rebuilt, and its audit refuses a dependent's revision bump
without one, so this is the signal core uses to rebuild its own bottles. Each
bottle's INSTALL_RECEIPT.json records the `compatibility_version` of every
runtime dependency it was built against, so a bottle is stale when any of them
has gone up since.

Usage: stale-bottles.py <tap>
"""

import json
import subprocess
import sys
import tarfile
import urllib.request


def brew_json(*args):
    return json.loads(subprocess.run(["brew", *args], check=True, capture_output=True, text=True).stdout)


def receipt(url):
    # Stream the bottle and stop at the receipt instead of downloading all of it.
    with urllib.request.urlopen(url) as response, tarfile.open(fileobj=response, mode="r|gz") as bottle:
        for member in bottle:
            # <name>/<version>/INSTALL_RECEIPT.json
            if member.name.count("/") == 2 and member.name.endswith("/INSTALL_RECEIPT.json"):
                return json.load(bottle.extractfile(member))
    raise RuntimeError(f"{url} has no INSTALL_RECEIPT.json")


def main(tap):
    names = brew_json("tap-info", "--json", tap)[0]["formula_names"]
    built_against = {}
    for formula in brew_json("info", "--json=v2", "--formula", *names)["formulae"]:
        for file in ((formula["bottle"].get("stable") or {}).get("files") or {}).values():
            for dep in receipt(file["url"])["runtime_dependencies"]:
                if dep.get("compatibility_version") is not None:
                    built_against.setdefault(formula["full_name"], {})[dep["full_name"]] = dep["compatibility_version"]

    deps = sorted({dep for recorded in built_against.values() for dep in recorded})
    if not deps:
        return
    current = {f["full_name"]: f.get("compatibility_version")
               for f in brew_json("info", "--json=v2", "--formula", *deps)["formulae"]}

    for formula, recorded in built_against.items():
        changed = [dep for dep, version in recorded.items() if (current.get(dep) or 0) > version]
        if changed:
            print(formula, " ".join(changed), sep="\t")


if __name__ == "__main__":
    main(sys.argv[1])
