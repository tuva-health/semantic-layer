#!/usr/bin/env python3

import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class PackageContractTest(unittest.TestCase):
    def test_package_version_and_asset_identity_are_aligned(self):
        project_text = (ROOT / "dbt_project.yml").read_text()
        version_macro = (
            ROOT / "macros" / "get_semantic_layer_package_version.sql"
        ).read_text()
        data_assets = (ROOT / "data_assets.yml").read_text()
        seed_loader = (ROOT / "macros" / "load_semantic_layer_seed.sql").read_text()

        project_version = re.search(
            r"(?m)^version: '([1-9][0-9]*\.[0-9]+\.[0-9]+"
            r"(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?)'$",
            project_text,
        )
        macro_version = re.search(
            r"return\('([1-9][0-9]*\.[0-9]+\.[0-9]+"
            r"(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?)'\)",
            version_macro,
        )

        self.assertIsNotNone(project_version)
        self.assertIsNotNone(macro_version)
        self.assertEqual(project_version.group(1), macro_version.group(1))
        self.assertIn(
            'require-dbt-version: ">=1.10.5,<3.0.0"',
            project_text,
        )
        self.assertIn(
            'version: "1.2.1"',
            (ROOT / "packages.yml").read_text(),
        )
        self.assertIn(
            "| `dbt_utils` | 1.2.1 | dbt Hub release |",
            (ROOT / "README.md").read_text(),
        )
        self.assertRegex(data_assets, r"(?m)^package: semantic-layer$")
        asset_paths = set(re.findall(r"(?m)^\s+path: (\S+)$", data_assets))
        configured_paths = set(
            re.findall(r"load_semantic_layer_seed\('([^']+)'\)", project_text)
        )
        self.assertEqual(asset_paths, configured_paths)
        self.assertIn(
            "'semantic-layer',\n"
            "      semantic_layer.get_semantic_layer_package_version(),",
            seed_loader,
        )
        workflow = (
            ROOT / ".github" / "workflows" / "package-contract.yml"
        ).read_text()
        self.assertIn(
            "run: python3 scripts/test_package_contract.py",
            workflow,
        )
        self.assertIn("- 'integration_tests/packages.yml'", workflow)

    def test_integration_pins_match_the_readme_compatibility_set(self):
        packages_text = (ROOT / "integration_tests" / "packages.yml").read_text()
        readme_text = (ROOT / "README.md").read_text()
        package_pins = dict(
            re.findall(
                r'- git: "https://github\.com/tuva-health/([^"/]+)\.git"\s+'
                r"revision: ([0-9a-f]{40})",
                packages_text,
            )
        )
        readme_pins = dict(
            re.findall(
                r"\| `([^`]+)`(?: \(Tuva Core\))? \| 1\.0\.0 \| `([0-9a-f]{40})` \|",
                readme_text,
            )
        )
        package_to_project = {
            "tuva-core": "the_tuva_project",
            "ahrq_quality_indicators": "ahrq_quality_indicators",
            "ccsr": "ccsr",
            "cms_hcc": "cms_hcc",
            "nyu_ed_classification": "nyu_ed_classification",
            "quality_measures": "quality_measures",
        }

        self.assertEqual(set(package_pins), set(package_to_project))
        for package_name, project_name in package_to_project.items():
            self.assertEqual(package_pins[package_name], readme_pins[project_name])


if __name__ == "__main__":
    unittest.main()
