#!/usr/bin/env python3

import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class PackageContractTest(unittest.TestCase):
    def test_package_and_asset_versions_are_independent(self):
        project_text = (ROOT / "dbt_project.yml").read_text()
        seed_loader = (ROOT / "macros" / "load_semantic_layer_seed.sql").read_text()

        project_version = re.search(
            r"(?m)^version: '((?:0|[1-9][0-9]*)\.[0-9]+\.[0-9]+"
            r"(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?)'$",
            project_text,
        )
        asset_version = re.search(
            r"(?m)^  semantic_layer_data_asset_version: '([^']+)'$",
            project_text,
        )

        self.assertIsNotNone(project_version)
        self.assertIsNotNone(asset_version)
        self.assertRegex(
            asset_version.group(1),
            r"^[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$",
        )
        self.assertIn(
            'require-dbt-version: ">=1.10.5,<3.0.0"',
            project_text,
        )
        packages_text = (ROOT / "packages.yml").read_text()
        self.assertIn('- ">=1.3.2"', packages_text)
        self.assertIn('- "<2.0.0"', packages_text)
        self.assertIn(
            "| `dbt_utils` | >=1.3.2,<2.0.0 | dbt Hub release range |",
            (ROOT / "README.md").read_text(),
        )

        configured_paths = set(
            re.findall(r"load_semantic_layer_seed\('([^']+)'\)", project_text)
        )
        header_paths = {
            f"{path.name}.gz" for path in (ROOT / "seeds").glob("*.csv")
        }
        self.assertEqual(configured_paths, header_paths)
        self.assertIn("'data-marts/semantic-layer',", seed_loader)
        self.assertIn("var('semantic_layer_data_asset_version'),", seed_loader)

        self.assertFalse((ROOT / "data_assets.yml").exists())
        self.assertFalse(
            (ROOT / "macros" / "get_semantic_layer_package_version.sql").exists()
        )

        workflow = (
            ROOT / ".github" / "workflows" / "package-contract.yml"
        ).read_text()
        self.assertIn(
            "run: python3 scripts/test_package_contract.py",
            workflow,
        )
        self.assertIn("- 'integration_tests/**'", workflow)
        self.assertIn("- 'seeds/**'", workflow)

    def test_ci_executes_the_locked_semantic_graph_for_model_changes(self):
        workflow = (
            ROOT / ".github" / "workflows" / "package-contract.yml"
        ).read_text()

        for watched_path in ("models/**", "tests/**", "integration_tests/**"):
            self.assertIn(f"- '{watched_path}'", workflow)
        self.assertIn("uses: actions/setup-python@", workflow)
        self.assertIn('"dbt-core==${DBT_CORE_VERSION}"', workflow)
        self.assertIn('"dbt-duckdb==${DBT_DUCKDB_VERSION}"', workflow)
        self.assertIn("run: scripts/dbt-local deps", workflow)
        self.assertIn(
            "scripts/dbt-local build --full-refresh --indirect-selection cautious",
            workflow,
        )
        self.assertIn("--select +package:semantic_layer", workflow)
        self.assertTrue((ROOT / ".github" / "profiles" / "profiles.yml").exists())

    def test_root_license_matches_the_preserved_apache_license(self):
        self.assertEqual(
            (ROOT / "LICENSE.txt").read_text(),
            (ROOT / "license" / "license-2.0.txt").read_text(),
        )

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
                r"\| `([^`]+)`(?: \(Tuva Core\))? \| "
                r"(?:0|[1-9][0-9]*)\.[0-9]+\.[0-9]+ \| `([0-9a-f]{40})` \|",
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

    def test_release_workflow_is_code_only(self):
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
        for forbidden in (
            "data_assets.yml",
            "PACKAGE_SLUG",
            "tuva-public-resources",
            "_release.json",
            "package_commit",
        ):
            self.assertNotIn(forbidden, workflow_text)

        action_refs = re.findall(r"uses:\s+[^@\s]+@([^\s]+)", workflow_text)
        self.assertTrue(action_refs)
        for action_ref in action_refs:
            self.assertRegex(action_ref, r"^[0-9a-f]{40}$")

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


if __name__ == "__main__":
    unittest.main()
