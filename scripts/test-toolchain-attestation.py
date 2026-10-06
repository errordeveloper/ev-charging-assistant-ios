#!/usr/bin/env python3
"""Behavioral checks for unsigned toolchain evidence, using synthetic command results."""
import hashlib
import importlib.util
import json
import subprocess
import tempfile
import unittest
from unittest import mock
from pathlib import Path

spec = importlib.util.spec_from_file_location('record_toolchain', Path(__file__).with_name('record-toolchain.py'))
record_toolchain = importlib.util.module_from_spec(spec)
spec.loader.exec_module(record_toolchain)


class ToolchainAttestationTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        for name in record_toolchain.SUBJECT_FILES:
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(f'synthetic fixture for {name}\n')

    def collect(self, failed=False):
        def run(command, root):
            return {
                'command': command,
                'executable': f'/fixture/bin/{command[0]}',
                'exitCode': 1 if failed and command[0] == 'xcrun' else 0,
                'stdout': '',
                'stderr': 'SDK unavailable' if failed and command[0] == 'xcrun' else '',
            }

        return record_toolchain.collect_statement(
            self.root, run=run, recorded_at='2026-10-06T12:00:00Z',
            environ={'GITHUB_RUN_ID': '123', 'GITHUB_TOKEN': 'must-not-leak',
                     'DEVELOPER_DIR': '/Applications/Fixture Xcode.app/Contents/Developer'},
        )

    def test_statement_binds_observations_to_actual_input_bytes(self):
        statement = self.collect()
        self.assertEqual(statement['_type'], 'https://in-toto.io/Statement/v1')
        self.assertEqual(statement['predicateType'], record_toolchain.PREDICATE_TYPE)
        self.assertTrue(statement['predicate']['collectionSucceeded'])
        self.assertEqual({subject['name'] for subject in statement['subject']},
                         set(record_toolchain.SUBJECT_FILES))
        for subject in statement['subject']:
            expected = hashlib.sha256((self.root / subject['name']).read_bytes()).hexdigest()
            self.assertEqual(subject['digest'], {'sha256': expected})
        before = statement['subject']
        (self.root / 'flake.lock').write_text('changed locked inputs\n')
        self.assertNotEqual(self.collect()['subject'], before)
        self.assertNotIn('signatures', statement)
        output = self.root / 'artifacts/toolchain.intoto.json'
        self.assertEqual(record_toolchain.write_statement(statement, output), 0)
        self.assertEqual(json.loads(output.read_text()), statement)

    def test_only_allowlisted_environment_is_recorded(self):
        statement = self.collect()
        self.assertEqual(statement['predicate']['environment']['GITHUB_RUN_ID'], '123')
        self.assertNotIn('GITHUB_TOKEN', json.dumps(statement))
        self.assertNotIn('must-not-leak', json.dumps(statement))

    def test_failed_probe_is_preserved_and_reported_as_incomplete(self):
        statement = self.collect(failed=True)
        self.assertFalse(statement['predicate']['collectionSucceeded'])
        sdk = statement['predicate']['observations']['simulatorSDK']
        self.assertEqual(sdk['exitCode'], 1)
        self.assertEqual(sdk['stderr'], 'SDK unavailable')
        output = self.root / 'artifacts/toolchain.intoto.json'
        status = record_toolchain.write_statement(statement, output)
        self.assertEqual(status, 1)
        self.assertEqual(json.loads(output.read_text()), statement)

    def test_missing_command_is_recorded_as_a_failure(self):
        with mock.patch.object(record_toolchain.subprocess, 'run', side_effect=FileNotFoundError('missing tool')):
            observation = record_toolchain.run_command(['xcodegen', '--version'], self.root)
        self.assertEqual(observation['exitCode'], 127)
        self.assertEqual(observation['stderr'], 'missing tool')

    def test_timed_out_command_is_recorded_as_a_failure(self):
        error = subprocess.TimeoutExpired(['xcrun'], 60)
        with mock.patch.object(record_toolchain.subprocess, 'run', side_effect=error):
            observation = record_toolchain.run_command(['xcrun', '--find', 'swift'], self.root)
        self.assertEqual(observation['exitCode'], 124)
        self.assertIn('timed out', observation['stderr'])


if __name__ == '__main__':
    unittest.main()
