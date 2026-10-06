#!/usr/bin/env python3
"""Check the installed generator's output without booting a simulator."""
import json
import subprocess
import tempfile
import unittest
from pathlib import Path


class XcodeGenPresetTests(unittest.TestCase):
    def test_generated_project_includes_build_presets(self):
        # Generate outside the repository and extracted archive so loose presets
        # cannot hide an incomplete installation.
        with tempfile.TemporaryDirectory(prefix='xcodegen-presets-') as directory:
            root = Path(directory)
            spec = {
                'name': 'PresetCheck',
                'targets': {
                    'App': {'type': 'application', 'platform': 'iOS'},
                    'AppUITests': {
                        'type': 'bundle.ui-testing',
                        'platform': 'iOS',
                        'dependencies': [{'target': 'App'}],
                    },
                },
            }
            (root / 'project.yml').write_text(json.dumps(spec))
            subprocess.run(['xcodegen', 'generate'], cwd=root, check=True)
            result = subprocess.run(
                ['plutil', '-convert', 'json', '-o', '-',
                 str(root / 'PresetCheck.xcodeproj/project.pbxproj')],
                check=True, capture_output=True, text=True,
            )
            project = json.loads(result.stdout)

        objects = project['objects']

        def configurations(owner):
            config_list = objects[owner['buildConfigurationList']]
            return {
                objects[ref]['name']: objects[ref]['buildSettings']
                for ref in config_list['buildConfigurations']
            }

        project_settings = configurations(objects[project['rootObject']])
        for name in ('Debug', 'Release'):
            with self.subTest(configuration=name):
                self.assertEqual(project_settings[name].get('PRODUCT_NAME'), '$(TARGET_NAME)')
        self.assertEqual(project_settings['Debug'].get('SWIFT_OPTIMIZATION_LEVEL'), '-Onone')
        self.assertEqual(project_settings['Debug'].get('ONLY_ACTIVE_ARCH'), 'YES')
        self.assertEqual(project_settings['Release'].get('SWIFT_COMPILATION_MODE'), 'wholemodule')

        targets = [obj for obj in objects.values() if obj['isa'] == 'PBXNativeTarget']
        self.assertEqual({target['name'] for target in targets}, {'App', 'AppUITests'})
        for target in targets:
            for name, settings in configurations(target).items():
                with self.subTest(target=target['name'], configuration=name):
                    self.assertEqual(settings.get('SDKROOT'), 'iphoneos')
                    if target['name'] == 'AppUITests':
                        self.assertIn('@loader_path/Frameworks', settings.get('LD_RUNPATH_SEARCH_PATHS', []))
                    else:
                        self.assertEqual(settings.get('ASSETCATALOG_COMPILER_APPICON_NAME'), 'AppIcon')


if __name__ == '__main__':
    unittest.main()
