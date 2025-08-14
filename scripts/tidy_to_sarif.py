#!/usr/bin/env python3
import json
import os
import re
import sys
from datetime import datetime, timezone

# Very simple parser for lines like:
# path/to/file.cpp:12:34: warning: message [checkname]
LINE_RE = re.compile(r"^(?P<file>.*?):(?P<line>\d+):(?P<col>\d+):\s+(?P<severity>warning|error|note):\s+(?P<message>.*?)\s*\[(?P<rule>[^\]]+)\]\s*$")


def parse_diagnostics(text):
    diags = []
    for line in text.splitlines():
        m = LINE_RE.match(line)
        if m:
            d = m.groupdict()
            d["line"] = int(d["line"]) - 1  # SARIF uses 0-based
            d["col"] = int(d["col"]) - 1
            diags.append(d)
    return diags


def to_sarif(diags):
    rules = {}
    results = []
    for d in diags:
        rule_id = d["rule"]
        if rule_id not in rules:
            rules[rule_id] = {
                "id": rule_id,
                "name": rule_id,
                "shortDescription": {"text": rule_id},
                "fullDescription": {"text": f"Diagnostic emitted by clang-tidy rule {rule_id}"},
                "help": {"text": "See clang-tidy docs."},
                "defaultConfiguration": {"level": "warning"},
            }
        results.append({
            "ruleId": rule_id,
            "level": "warning" if d["severity"] == "warning" else "error",
            "message": {"text": d["message"]},
            "locations": [{
                "physicalLocation": {
                    "artifactLocation": {"uri": os.path.abspath(d["file"])},
                    "region": {
                        "startLine": d["line"] + 1,
                        "startColumn": d["col"] + 1,
                    },
                }
            }],
        })

    sarif = {
        "$schema": "https://json.schemastore.org/sarif-2.1.0.json",
        "version": "2.1.0",
        "runs": [
            {
                "tool": {
                    "driver": {
                        "name": "clang-tidy",
                        "informationUri": "https://clang.llvm.org/extra/clang-tidy/",
                        "rules": list(rules.values()),
                    }
                },
                "results": results,
                "columnKind": "utf16CodeUnits",
            }
        ],
    }
    return sarif


def main():
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <clang-tidy-output.txt> <out.sarif>", file=sys.stderr)
        sys.exit(2)
    with open(sys.argv[1], "r", encoding="utf-8") as f:
        text = f.read()
    diags = parse_diagnostics(text)
    sarif = to_sarif(diags)
    with open(sys.argv[2], "w", encoding="utf-8") as f:
        json.dump(sarif, f, indent=2)


if __name__ == "__main__":
    main() 