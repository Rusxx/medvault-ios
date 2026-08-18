#!/usr/bin/env python3
from __future__ import annotations

import sys
from pathlib import Path

from tree_sitter import Language, Parser
import tree_sitter_swift

root = Path(__file__).resolve().parent / "MedVault"
language = Language(tree_sitter_swift.language())
parser = Parser(language)
errors: list[str] = []


def collect_errors(node, path: Path) -> None:
    if node.type == "ERROR" or node.is_missing:
        location = f"{path.relative_to(root.parent)}:{node.start_point[0] + 1}:{node.start_point[1] + 1}"
        errors.append(f"{location}: parser reported {node.type}")
    for child in node.children:
        collect_errors(child, path)


swift_files = sorted(root.rglob("*.swift"))
for swift_file in swift_files:
    tree = parser.parse(swift_file.read_bytes())
    collect_errors(tree.root_node, swift_file)

if errors:
    for error in errors:
        print(f"FAIL: {error}", file=sys.stderr)
    sys.exit(1)

print(f"SWIFT SYNTAX VALIDATION: PASS ({len(swift_files)} files)")
