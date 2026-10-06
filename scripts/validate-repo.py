#!/usr/bin/env python3
"""Structural/source policy checks, not a substitute for Swift or Xcode tests."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
required = [
    'Package.swift', 'project.yml', 'README.md', 'AGENTS.md',
    'docs/DEVELOPMENT_PLAN.md', 'docs/ARCHITECTURE.md', 'docs/BLUETOOTH.md',
    'docs/TEST_STRATEGY.md', 'docs/SECURITY_AND_PRIVACY.md', 'docs/BACKLOG.md',
    'docs/BOOTSTRAP_VALIDATION.md', '.github/workflows/ci.yml',
    'Apps/EVChargingAssistant/EVChargingAssistantApp.swift',
    'Apps/EVChargingAssistant/BluetoothScanner.swift',
    'UITests/DashboardUITests.swift', 'config/compatibility.json',
    'flake.nix', 'flake.lock', 'nix/xcodegen.nix', 'scripts/test-nix-shell.py',
    'scripts/record-toolchain.py', 'scripts/test-toolchain-attestation.py',
]
for name in required:
    assert (ROOT / name).is_file(), f'Missing {name}'

for script in (ROOT / 'scripts').iterdir():
    if script.is_file():
        assert re.fullmatch(r'[a-z0-9]+(?:-[a-z0-9]+)*\.(py|sh)', script.name), \
            f'Script filenames must use kebab-case: {script.name}'

for path in ROOT.rglob('*.md'):
    if '.git' in path.parts:
        continue
    for target in re.findall(r'(?<!!)\[[^\]]+\]\(([^)]+)\)', path.read_text()):
        if '://' in target or target.startswith('#') or target.startswith('mailto:'):
            continue
        target_path = (path.parent / target.split('#', 1)[0]).resolve()
        assert target_path.exists(), f'Broken link in {path.relative_to(ROOT)}: {target}'

compat = json.loads((ROOT / 'config/compatibility.json').read_text())
assert compat['schemaVersion'] == 1
for profile in compat['profiles']:
    assert profile['status'] in ['unverified', 'verified', 'unsupported']
    if profile['status'] == 'verified':
        report = profile['evidenceReport']
        assert report and (ROOT / report).is_file(), 'Verified profile needs a report'
        assert profile['readCommands'], 'Verified profile needs reviewed request definitions'
    else:
        assert not profile['readCommands'], 'Unverified profile cannot enable commands'

project = (ROOT / 'project.yml').read_text()
assert 'NSBluetoothAlwaysUsageDescription:' in project
assert 'UIBackgroundModes:' not in project, 'Background support is not implemented yet'
scanner = (ROOT / 'Apps/EVChargingAssistant/BluetoothScanner.swift').read_text()
assert 'writeValue(' not in scanner and '.connect(' not in scanner

workflow = (ROOT / '.github/workflows/ci.yml').read_text()
toolchain = json.loads((ROOT / 'config/toolchain.json').read_text())
assert toolchain['actions']['checkout'] in workflow
assert toolchain['actions']['uploadArtifact'] in workflow
assert toolchain['actions']['installNix'] in workflow
assert f'nix-{toolchain["nixVersion"]}/install' in workflow
assert toolchain['xcodegen']['version'] in project
assert re.fullmatch(r'[0-9a-f]{64}', toolchain['xcodegen']['sha256'])
assert 'pull_request_target' not in workflow
assert 'contents: read' in workflow
for action in re.findall(r'uses:\s+([^\s#]+)', workflow):
    assert re.fullmatch(r'[^@]+@[0-9a-f]{40}', action), f'Unpinned action: {action}'

flake_lock = json.loads((ROOT / 'flake.lock').read_text())
locked_nixpkgs = flake_lock['nodes']['nixpkgs']['locked']
assert re.fullmatch(r'[0-9a-f]{40}', locked_nixpkgs['rev']), 'Nixpkgs must be commit-pinned'
assert locked_nixpkgs['narHash'].startswith('sha256-'), 'Nixpkgs must be content-hashed'

issues = json.loads((ROOT / '.github/backlog.json').read_text())
ids = {issue['id'] for issue in issues}
assert len(ids) == len(issues), 'Duplicate issue identifiers'
for issue in issues:
    assert issue['title'] and issue['body'] and issue['acceptanceCriteria']
    assert all(dependency in ids for dependency in issue['dependsOn'])
    assert issue['id'] not in issue['dependsOn']
visited, active = set(), set()
by_id = {issue['id']: issue for issue in issues}
def visit(issue_id):
    assert issue_id not in active, f'Cyclic backlog dependency at {issue_id}'
    if issue_id in visited:
        return
    active.add(issue_id)
    for dependency in by_id[issue_id]['dependsOn']:
        visit(dependency)
    active.remove(issue_id)
    visited.add(issue_id)
for issue_id in ids:
    visit(issue_id)

print(f'Structural checks passed: {len(required)} required files, Markdown links, '
      f'{len(compat["profiles"])} compatibility candidate, {len(issues)} acyclic backlog items, '
      'SHA-pinned Actions and foreground-only scanner policy.')
print('Swift compilation, behavioral tests, UI tests and hardware tests are separate checks.')
