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

    def test_release_workflow_runs_package_contract(self):
        workflow_text = (
            ROOT / ".github" / "workflows" / "create-release.yml"
        ).read_text()
        checkout_position = workflow_text.index("uses: actions/checkout@")
        contract_position = workflow_text.index(
            "run: python3 scripts/test_package_contract.py"
        )
        version_check_position = workflow_text.index("- name: Check version change")

        self.assertLess(checkout_position, contract_position)
        self.assertLess(contract_position, version_check_position)

    def test_release_workflow_finds_exactly_one_package_version(self):
        workflow_text = (
            ROOT / ".github" / "workflows" / "create-release.yml"
        ).read_text()
        project_text = (ROOT / "dbt_project.yml").read_text()

        pattern_source = re.search(
            r'VERSION_LINE_PATTERN = re\.compile\(\s*'
            r'r"((?:[^"\\]|\\.)*)",\s*re\.MULTILINE,\s*\)',
            workflow_text,
        )
        self.assertIsNotNone(pattern_source)

        version_line_pattern = re.compile(pattern_source.group(1), re.MULTILINE)
        matches = version_line_pattern.findall(project_text)
        project_version = re.search(r"(?m)^version: '([^']+)'$", project_text)

        self.assertEqual(len(matches), 1)
        self.assertEqual(matches[0][1], project_version.group(1))

    def test_release_workflow_checks_declared_files_before_tagging(self):
        workflow_text = (
            ROOT / ".github" / "workflows" / "create-release.yml"
        ).read_text()

        self.assertIn("PACKAGE_SLUG: semantic-layer", workflow_text)
        asset_check_position = workflow_text.index(
            "- name: Verify data asset files exist"
        )
        tag_position = workflow_text.index("- name: Create tag")
        self.assertLess(asset_check_position, tag_position)
        self.assertIn("data_assets.yml", workflow_text)
        self.assertIn(
            'url="${public_root}/${PACKAGE_SLUG}/${PACKAGE_VERSION}/${asset_path}"',
            workflow_text,
        )
        self.assertIn("--head", workflow_text)
        for host in (
            "https://tuva-public-resources.s3.amazonaws.com",
            "https://storage.googleapis.com/tuva-public-resources",
            "https://tuvapublicresources.blob.core.windows.net/tuva-public-resources",
        ):
            self.assertIn(host, workflow_text)

        action_refs = re.findall(r"uses:\s+[^@\s]+@([^\s]+)", workflow_text)
        self.assertTrue(action_refs)
        for action_ref in action_refs:
            self.assertRegex(action_ref, r"^[0-9a-f]{40}$")


if __name__ == "__main__":
    unittest.main()
