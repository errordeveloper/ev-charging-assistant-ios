#!/usr/bin/env python3
"""Preview by default; create GitHub issues only with explicit --apply."""
import argparse
import json
import re
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--repository', help='Existing GitHub owner/repo')
parser.add_argument('--apply', action='store_true', help='Create missing issues using authenticated gh')
args = parser.parse_args()
issues = json.loads((root / '.github/backlog.json').read_text())

if not args.apply:
    for issue in issues:
        print(f'{issue["title"]} | dependencies: {", ".join(issue["dependsOn"]) or "none"}')
    print('Preview only. Use --repository OWNER/REPO --apply to create issues.')
    raise SystemExit(0)

if not args.repository or not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', args.repository):
    parser.error('--apply requires --repository OWNER/REPO')

existing = json.loads(subprocess.check_output([
    'gh', 'issue', 'list', '--repo', args.repository, '--state', 'all',
    '--limit', '1000', '--json', 'title,number'
], text=True))
titles = {issue['title'] for issue in existing}
for issue in issues:
    if issue['title'] in titles:
        print(f'Skipping existing: {issue["title"]}')
        continue
    body = '\n\n'.join([
        issue['body'],
        'Dependencies: ' + (', '.join(issue['dependsOn']) or 'None'),
        'Acceptance criteria:\n\n' + '\n'.join('- [ ] ' + c for c in issue['acceptanceCriteria']),
        'Follow AGENTS.md and attach exact software/hardware evidence. See docs/DEVELOPMENT_PLAN.md.'
    ])
    subprocess.run([
        'gh', 'issue', 'create', '--repo', args.repository,
        '--title', issue['title'], '--body-file', '-'
    ], input=body, text=True, check=True)
    titles.add(issue['title'])
