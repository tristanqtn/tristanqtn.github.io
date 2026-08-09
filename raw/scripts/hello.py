#!/usr/bin/env python3
"""An example of a hosted script.

Fetch it with:

    curl -fsSL https://tristanqtn.github.io/raw/scripts/hello.py

Replace this with something you actually use.
"""

import argparse
import platform
import sys


def describe_host() -> dict[str, str]:
    """Return a few harmless facts about the machine we're running on."""
    return {
        "python": platform.python_version(),
        "system": platform.system(),
        "release": platform.release(),
        "machine": platform.machine(),
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("name", nargs="?", default="world", help="who to greet")
    parser.add_argument("-v", "--verbose", action="store_true", help="also describe the host")
    args = parser.parse_args(argv)

    print(f"hello, {args.name}")

    if args.verbose:
        for key, value in describe_host().items():
            print(f"  {key:<8} {value}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
