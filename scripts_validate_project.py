#!/usr/bin/env python3
from __future__ import annotations

import json
import plistlib
import re
import sys
from pathlib import Path

root = Path(__file__).resolve().parent
pbx_path = root / "MedVault.xcodeproj" / "project.pbxproj"
pbx = pbx_path.read_text(encoding="utf-8")
errors: list[str] = []
checks: list[str] = []

# Verify every app Swift source exists and is explicitly represented in the sources build phase.
swift_files = sorted((root / "MedVault").rglob("*.swift"))
source_paths = {path.name for path in swift_files}
for name in source_paths:
    if f"/* {name} in Sources */" not in pbx:
        errors.append(f"Swift source missing from target source phase: {name}")
checks.append(f"{len(swift_files)} Swift source files present and listed in the target sources phase")

# Verify expected target and build configuration keys.
required_project_tokens = [
    "productType = \"com.apple.product-type.application\"",
    "PRODUCT_BUNDLE_IDENTIFIER = com.medvault.app",
    "IPHONEOS_DEPLOYMENT_TARGET = 17.0",
    "SWIFT_VERSION = 5.0",
    "INFOPLIST_FILE = MedVault/Resources/Info.plist",
    "A1000000000000000000000F /* Assets.xcassets in Resources */",
]
for token in required_project_tokens:
    if token not in pbx:
        errors.append(f"Missing project configuration: {token}")
checks.append("Target, deployment target, bundle identifier, Swift version, plist, and assets are configured")

# Info.plist must be valid XML and declare the camera/photo permission strings used by the app.
plist_path = root / "MedVault" / "Resources" / "Info.plist"
try:
    info = plistlib.loads(plist_path.read_bytes())
    for key in ("NSCameraUsageDescription", "NSPhotoLibraryUsageDescription", "CFBundleDisplayName"):
        if not info.get(key):
            errors.append(f"Info.plist lacks a non-empty {key}")
    checks.append("Info.plist parses successfully and includes required privacy strings")
except Exception as exc:
    errors.append(f"Info.plist is invalid: {exc}")

# Asset catalog JSON files must be valid.
for asset_json in (root / "MedVault" / "Resources" / "Assets.xcassets").rglob("Contents.json"):
    try:
        json.loads(asset_json.read_text(encoding="utf-8"))
    except Exception as exc:
        errors.append(f"Invalid asset catalog JSON {asset_json.relative_to(root)}: {exc}")
checks.append("Asset catalog JSON files parse successfully")

# Confirm local-only implementation: no URLSession / server SDKs appear in source code.
source_text = "\n".join(path.read_text(encoding="utf-8") for path in swift_files)
for forbidden in ("URLSession", "Alamofire", "Firebase", "http://", "https://"):
    if forbidden in source_text:
        errors.append(f"Unexpected network-related token in app source: {forbidden}")
checks.append("No network client or third-party service token found in app source")

# Basic safety and feature guards.
feature_tokens = [
    "VNRecognizeTextRequest",
    "PDFDocument",
    "PhotosPicker",
    "fileImporter",
    "SafetyNotice",
    "MedicalProfile",
    "deleteDocument",
    "retryProcessing",
    "StorageService",
    "MedicalTimelineEvent",
    "HistoryRangePreset",
    "ClinicalAggregationService",
    "TimelineView",
    "AnalysesView",
    "AnalysisTrendView",
    "ClinicalOverviewView",
    "DocumentEditView",
    "saveEditedDocument",
    "HistoryPDFExportService",
    "ActivityShareSheet",
    "import Charts",
]
for token in feature_tokens:
    if token not in source_text:
        errors.append(f"Required feature token is absent from source: {token}")
checks.append("OCR, PDF, picker, safety notice, profile, deletion, retry, local storage, timeline, analyses, charts, manual editing, record links, and PDF export code are present")

# Guard against known SwiftUI syntax/API compatibility issues found during Xcode compilation.
if ".textContentType(.birthday)" in source_text:
    errors.append("Unsupported UITextContentType.birthday usage found")
invalid_section_footer = re.compile(r'Section\\s*\\(\\s*"[^"\\n]+"\\s*\\)\\s*\\{.*?\\}\\s*footer\\s*:', re.DOTALL)
for match in invalid_section_footer.finditer(source_text):
    line = source_text[:match.start()].count("\\n") + 1
    errors.append(f"Section(title) with a trailing footer closure found near combined source line {line}; use the explicit Section content/header/footer initializer")
checks.append("No unsupported birthday content type or Section(title) trailing-footer pattern found")

# Confirm all new source files are represented as both file references and target members.
new_source_names = [
    "ClinicalModels.swift",
    "ClinicalAggregationService.swift",
    "HistoryPDFExportService.swift",
    "TimelineView.swift",
    "AnalysesView.swift",
    "AnalysisTrendView.swift",
    "ClinicalOverviewView.swift",
    "DocumentEditView.swift",
]
for name in new_source_names:
    if f"/* {name} */ = {{isa = PBXFileReference" not in pbx:
        errors.append(f"New source is missing an Xcode file reference: {name}")
    if f"/* {name} in Sources */" not in pbx:
        errors.append(f"New source is missing target membership: {name}")
checks.append("All eight new Swift files have Xcode file references and target membership")

# Coarse lexical checks catch accidental merge markers / invalid unbalanced braces.
if "<<<<<<<" in source_text or ">>>>>>>" in source_text:
    errors.append("Unresolved merge marker found in Swift source")
for path in swift_files:
    content = path.read_text(encoding="utf-8")
    if content.count("{") != content.count("}"):
        errors.append(f"Potential unbalanced braces in {path.relative_to(root)}")
checks.append("No merge markers or coarse brace-balance issue found")

# Ensure repository documentation and ignore file are present.
for required_file in (root / "README.md", root / ".gitignore"):
    if not required_file.exists():
        errors.append(f"Required repository file is missing: {required_file.name}")
checks.append("README.md and .gitignore are present")

for check in checks:
    print(f"PASS: {check}")
if errors:
    for error in errors:
        print(f"FAIL: {error}", file=sys.stderr)
    sys.exit(1)
print("STATIC VALIDATION: PASS")
