#!/usr/bin/env python3
"""Check the boundary between Nix tools and the host's Apple toolchain."""
import json
import os
import re
import shutil
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TOOLCHAIN = json.loads((ROOT / 'config/toolchain.json').read_text())


class NixShellTests(unittest.TestCase):
    def test_supporting_tools_come_from_nix(self):
        for tool in ('python3', 'git', 'xcodegen'):
            with self.subTest(tool=tool):
                path = shutil.which(tool)
                self.assertIsNotNone(path, f'{tool} is missing')
                self.assertTrue(str(Path(path).resolve()).startswith('/nix/store/'), path)
        version = TOOLCHAIN['xcodegen']['version']
        result = subprocess.run(['xcodegen', '--version'], check=True, capture_output=True, text=True)
        self.assertEqual(result.stdout.strip(), f'Version: {version}')

    def test_apple_tools_and_sdk_are_not_replaced_by_nix(self):
        for tool in ('swift', 'swiftc', 'xcrun', 'xcodebuild'):
            with self.subTest(tool=tool):
                self.assertEqual(shutil.which(tool), f'/usr/bin/{tool}')
        for variable in ('DEVELOPER_DIR', 'SDKROOT', 'TOOLCHAINS'):
            with self.subTest(variable=variable):
                self.assertNotIn('/nix/store/', os.environ.get(variable, ''))

    def test_xcode_has_the_required_compiler_and_simulator_sdk(self):
        result = subprocess.run(['swift', '--version'], check=True, capture_output=True, text=True)
        version = re.search(r'Apple Swift version (\d+)\.(\d+)', result.stdout)
        self.assertIsNotNone(version, result.stdout)
        minimum_swift = tuple(map(int, TOOLCHAIN['swiftLanguageVersion'].split('.')))
        self.assertGreaterEqual(tuple(map(int, version.groups())), minimum_swift)
        result = subprocess.run(
            ['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-version'],
            check=True, capture_output=True, text=True,
        )
        minimum_ios = tuple(map(int, TOOLCHAIN['minimumIOS'].split('.')))
        self.assertGreaterEqual(tuple(map(int, result.stdout.strip().split('.'))), minimum_ios)


if __name__ == '__main__':
    unittest.main()
