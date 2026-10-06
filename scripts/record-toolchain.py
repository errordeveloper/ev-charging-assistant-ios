#!/usr/bin/env python3
"""Write an unsigned in-toto Statement v1 describing the observed toolchain."""
import argparse
import hashlib
import json
import os
import platform
import shutil
import subprocess
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PREDICATE_TYPE = 'https://github.com/errordeveloper/ev-charging-assistant-ios/attestations/toolchain/v1'
SUBJECT_FILES = (
    'flake.nix', 'flake.lock', 'nix/xcodegen.nix', 'config/toolchain.json',
    '.github/workflows/ci.yml', 'scripts/record-toolchain.py',
)
COMMANDS = {
    'nix': ['nix', '--version'],
    'xcode': ['xcodebuild', '-version'],
    'swift': ['swift', '--version'],
    'python': ['python3', '--version'],
    'git': ['git', '--version'],
    'xcodegen': ['xcodegen', '--version'],
    'selectedSwift': ['xcrun', '--find', 'swift'],
    'simulatorSDK': ['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-version'],
    'simulatorRuntimes': ['xcrun', 'simctl', 'list', 'runtimes', '--json'],
    'gitRevision': ['git', 'rev-parse', 'HEAD'],
    'gitStatus': ['git', 'status', '--porcelain'],
}
ENVIRONMENT_KEYS = (
    'DEVELOPER_DIR', 'SDKROOT', 'TOOLCHAINS', 'GITHUB_REPOSITORY',
    'GITHUB_SHA', 'GITHUB_RUN_ID', 'GITHUB_RUN_ATTEMPT', 'RUNNER_OS', 'RUNNER_ARCH',
)


def run_command(command, root):
    observation = {'command': command, 'executable': shutil.which(command[0])}
    try:
        result = subprocess.run(command, cwd=root, capture_output=True, text=True, timeout=60)
        observation.update(exitCode=result.returncode, stdout=result.stdout, stderr=result.stderr)
    except subprocess.TimeoutExpired:
        observation.update(exitCode=124, stdout='', stderr='Toolchain probe timed out after 60 seconds.')
    except OSError as error:
        observation.update(exitCode=127, stdout='', stderr=str(error))
    return observation


def collect_statement(root, *, run=run_command, recorded_at=None, environ=None):
    environment = os.environ if environ is None else environ
    subjects = [
        {'name': name, 'digest': {'sha256': hashlib.sha256((root / name).read_bytes()).hexdigest()}}
        for name in SUBJECT_FILES
    ]
    observations = {name: run(command, root) for name, command in COMMANDS.items()}
    return {
        '_type': 'https://in-toto.io/Statement/v1',
        'subject': subjects,
        'predicateType': PREDICATE_TYPE,
        'predicate': {
            'recordedAt': recorded_at or datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z'),
            'host': {'os': platform.system(), 'architecture': platform.machine(),
                     'kernelRelease': platform.release()},
            'environment': {key: environment[key] for key in ENVIRONMENT_KEYS if key in environment},
            'observations': observations,
            'collectionSucceeded': all(item['exitCode'] == 0 for item in observations.values()),
        },
    }


def write_statement(statement, output):
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(statement, indent=2) + '\n')
    return 0 if statement['predicate']['collectionSucceeded'] else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT / 'artifacts/toolchain.intoto.json')
    args = parser.parse_args()
    status = write_statement(collect_statement(ROOT), args.output)
    print(f'Wrote unsigned toolchain statement to {args.output}')
    if status:
        print('Toolchain collection was incomplete; inspect the recorded command errors.')
    return status


if __name__ == '__main__':
    raise SystemExit(main())
