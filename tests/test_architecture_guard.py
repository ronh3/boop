#!/usr/bin/env python3

from __future__ import annotations

from collections import Counter
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from tools.architecture_guard import (
    SCHEMA_CUSTODY_EXCEPTIONS,
    SHARED_KERNEL,
    ConventionViolation,
    SourceUnit,
    _scan_direct_calls,
    analyze_sources,
    analyze_units,
    check_repository_architecture,
    load_repository_graph,
    production_call_sites,
    scan_conventions,
    validate_graph,
    validate_production_calls,
)


EXPECTED_OUTBOUND = Counter({
    ("send", "src/aliases/boop/Targeting/IH.lua"): 1,
    ("send", "src/scripts/boop/boop_events.lua"): 2,
    ("send", "src/scripts/boop/boop_rage.lua"): 1,
    ("send", "src/scripts/boop/boop_runtime.lua"): 1,
    ("send", "src/scripts/boop/boop_safety.lua"): 1,
    ("send", "src/scripts/boop/boop_targets.lua"): 5,
    ("send", "src/scripts/boop/boop_ui.lua"): 4,
    ("send", "src/scripts/boop/boop_util.lua"): 1,
    ("sendGMCP", "src/scripts/boop/boop_events.lua"): 1,
    ("sendGMCP", "src/scripts/boop/boop_init.lua"): 4,
    ("sendGMCP", "src/scripts/boop/boop_skills.lua"): 3,
})


class DirectDependencyTests(unittest.TestCase):
    def test_direct_api_and_owned_data_references_create_edges(self) -> None:
        graph = analyze_sources(
            {
                "module_a": """
                    boop.targets.choose()
                    return boop.state.targeting.currentTargetId
                """,
                "boop_targets": "function boop.targets.choose() return true end",
            },
            ["module_a", "boop_targets"],
        )
        self.assertEqual({("module_a", "boop_targets")}, graph.executable_edges)
        self.assertEqual({("module_a", "boop_targets")}, graph.data_edges)
        self.assertEqual([], graph.unresolved_references)

    def test_comments_and_strings_do_not_create_references(self) -> None:
        graph = analyze_sources(
            {
                "module_a": "function boop.alpha.work() return true end",
                "module_b": r'''
                    -- boop.alpha.work()
                    --[=[ boop.unknown.value ]=]
                    local one = "boop.alpha.work()"
                    local two = [[send("hidden")]]
                ''',
            },
            ["module_a", "module_b"],
        )
        self.assertEqual(set(), graph.edges)
        self.assertEqual([], graph.unresolved_references)

    def test_unknown_direct_namespace_fails_closed(self) -> None:
        graph = analyze_sources({"module_a": "boop.unknown.service()"}, ["module_a"])
        errors, _ = validate_graph(graph, require_composition_root=False)
        self.assertTrue(any("unresolved boop reference" in error for error in errors))

    def test_unknown_first_level_state_domain_fails_closed(self) -> None:
        graph = analyze_sources(
            {"module_a": "return boop.state.fictitiousDomain.value"},
            ["module_a"],
        )
        errors, _ = validate_graph(graph, require_composition_root=False)
        self.assertTrue(any(
            "unresolved boop reference boop.state.fictitiousDomain.value" in error
            for error in errors
        ))

    def test_defaults_is_owned_and_kernel_is_closed(self) -> None:
        self.assertEqual({("config",), ("version",)}, set(SHARED_KERNEL))
        graph = analyze_sources(
            {
                "boop_init": "boop.defaults.enabled = true; boop.version = 'test'",
                "boop_db": "return boop.defaults.enabled, boop.config.enabled",
            },
            ["boop_init", "boop_db"],
        )
        self.assertEqual({("boop_db", "boop_init")}, graph.data_edges)

    def test_foreign_direct_owned_data_write_fails(self) -> None:
        graph = analyze_sources(
            {
                "boop_targets": "boop.lists.whitelist = {}",
                "module_a": "boop.state.targeting.currentTargetId = '42'",
            },
            ["boop_targets", "module_a"],
        )
        errors, _ = validate_graph(graph, require_composition_root=False)
        self.assertTrue(any("foreign owned-data write" in error for error in errors))

    def test_attack_opener_and_temporary_preferences_have_specific_ownership(self) -> None:
        graph = analyze_sources(
            {
                "boop_attacks": """
                    boop.state.combat.openerUsedByClass.occultist = '42'
                    boop.state.combat.temporaryAttackPreferences.occultist = 'horripilation'
                """,
                "module_a": "return boop.state.combat.openerUsedByClass",
            },
            ["boop_attacks", "module_a"],
        )
        self.assertEqual({("module_a", "boop_attacks")}, graph.data_edges)
        self.assertEqual([], graph.mutation_violations)

    def test_literal_mudlet_handler_registration_creates_dependency_edge(self) -> None:
        graph = analyze_units(
            [
                SourceUnit(
                    "boop_events",
                    "src/scripts/boop/boop_events.lua",
                    """
                    function boop.events.register()
                      local function add(event, fn)
                        registerAnonymousEventHandler(event, fn)
                      end
                      add('test.event', 'boop.targets.choose')
                    end
                    """,
                ),
                SourceUnit(
                    "boop_targets",
                    "src/scripts/boop/boop_targets.lua",
                    "function boop.targets.choose() return true end",
                ),
            ],
            ["boop_events", "boop_targets"],
        )
        self.assertIn(("boop_events", "boop_targets"), graph.executable_edges)
        self.assertEqual([], graph.unresolved_references)

    def test_unknown_literal_mudlet_handler_fails_closed(self) -> None:
        graph = analyze_units(
            [
                SourceUnit(
                    "boop_events",
                    "src/scripts/boop/boop_events.lua",
                    """
                    function boop.events.register()
                      local function add(event, fn)
                        registerAnonymousEventHandler(event, fn)
                      end
                      add('test.event', 'boop.unknownHandler')
                    end
                    """,
                ),
            ],
            ["boop_events"],
        )
        errors, _ = validate_graph(graph, require_composition_root=False)
        self.assertTrue(any(
            "unresolved boop reference boop.unknownHandler" in error
            for error in errors
        ))

    def test_duplicate_direct_exports_fail(self) -> None:
        graph = analyze_sources(
            {
                "module_a": "function boop.same() end",
                "module_b": "boop.same = function() end",
            },
            ["module_a", "module_b"],
        )
        errors, _ = validate_graph(graph, require_composition_root=False)
        self.assertTrue(any("duplicate executable export boop.same" in error for error in errors))

    def test_attack_registration_exception_is_exact(self) -> None:
        real = load_repository_graph(ROOT)
        attack_units = [unit for unit in real.units if "/attacks/" in unit.path]
        self.assertGreater(len(attack_units), 1)
        self.assertTrue(all(unit.module == "boop_attacks" for unit in attack_units))
        self.assertNotIn("boop.attacks.register", real.duplicate_exports)

        graph = analyze_units(
            [
                SourceUnit("boop_attacks", "src/scripts/boop/boop_attacks.lua", "function boop.attacks.register() end"),
                SourceUnit("boop_attacks", "src/scripts/boop/attacks/attack_profile_bootstrap.lua", "function boop.attacks.register() end"),
                SourceUnit("boop_attacks", "src/scripts/boop/attacks/rogue.lua", "function boop.attacks.register() end"),
            ],
            ["boop_attacks"],
        )
        self.assertIn("boop.attacks.register", graph.duplicate_exports)

    def test_direct_forbidden_edge_fails(self) -> None:
        graph = analyze_sources(
            {
                "boop_runtime": "boop.rage.decide()",
                "boop_rage": "function boop.rage.decide() end",
            },
            ["boop_runtime", "boop_rage"],
        )
        errors, _ = validate_graph(graph, require_composition_root=False)
        self.assertTrue(any("hard-forbidden dependency edge" in error for error in errors))


class ConventionTests(unittest.TestCase):
    def violations(self, source: str) -> list[str]:
        definitions = analyze_sources(
            {
                "owner": "function boop.targets.choose() end; function boop.tick() end",
                "consumer": source,
            },
            ["owner", "consumer"],
        )
        unit = SourceUnit("consumer", "consumer.lua", source)
        return [value.kind for value in scan_conventions(unit, definitions.executable_owners)]

    def test_allowed_direct_forms_pass(self) -> None:
        self.assertEqual([], self.violations(
            "boop.targets.choose(); return boop.state.targeting.currentTargetId"
        ))

    def test_boop_indirection_is_rejected(self) -> None:
        cases = {
            "local b = boop\nb.targets.choose()": "boop-root-alias",
            "(boop).targets.choose()": "parenthesized-boop",
            'boop["targets"].choose()': "dynamic-boop-root",
            "local f = boop.targets.choose\nf()": "function-capture",
            "local f = boop.tick\nf()": "function-capture",
        }
        for source, expected in cases.items():
            with self.subTest(source=source):
                self.assertIn(expected, self.violations(source))

    def test_outbound_indirection_is_rejected(self) -> None:
        cases = {
            "local emit = send\nemit('foo')": "outbound-alias",
            "(send)('foo')": "parenthesized-outbound",
            "_G.send('foo')": "global-outbound-indirection",
            "local emit = _G.send\nemit('foo')": "outbound-alias",
            "consume(send)": "outbound-capture",
        }
        for source, expected in cases.items():
            with self.subTest(source=source):
                self.assertIn(expected, self.violations(source))

    def test_compatibility_forwarder_capture_is_rejected(self) -> None:
        self.assertIn("forwarder-capture", self.violations("pcall(boop.tick)"))

    def test_hidden_owned_data_mutation_is_rejected(self) -> None:
        kinds = self.violations(
            "local target = boop.state.targeting\ntarget.currentTargetId = '42'"
        )
        self.assertIn("foreign-data-alias-write", kinds)
        self.assertIn(
            "dynamic-owned-write",
            self.violations("boop.state.targeting[key] = '42'"),
        )

    def test_runtime_schema_rawset_exception_is_exactly_site_scoped(self) -> None:
        exact = ConventionViolation(
            "rawset", "src/scripts/boop/boop_runtime.lua", "rawset", 283
        )
        shifted = ConventionViolation(
            "rawset", "src/scripts/boop/boop_runtime.lua", "rawset", 284
        )
        self.assertIn(exact.exact_key, SCHEMA_CUSTODY_EXCEPTIONS)
        self.assertNotIn(shifted.exact_key, SCHEMA_CUSTODY_EXCEPTIONS)


class ProductionGuardTests(unittest.TestCase):
    def test_direct_call_scanner_handles_parenthesis_free_and_shadowed_calls(self) -> None:
        unit = SourceUnit("test", "test.lua", r'''
            send "global"
            sendGMCP [[Core.Supports.Set]]
            do
              local send = function(_) end
              send "shadowed"
            end
            local function nested(sendGMCP)
              sendGMCP "shadowed parameter"
            end
        ''')
        sites = _scan_direct_calls(unit, {"send", "sendGMCP"}, set())
        self.assertEqual(Counter({"send": 1, "sendGMCP": 1}), Counter(site.symbol for site in sites))

    def test_current_outbound_and_forwarder_sites_are_reported(self) -> None:
        outbound, forwarders = production_call_sites(ROOT)
        self.assertEqual(EXPECTED_OUTBOUND, Counter(site.key for site in outbound))
        self.assertEqual(16, sum(site.symbol == "send" for site in outbound))
        self.assertEqual(8, sum(site.symbol == "sendGMCP" for site in outbound))
        self.assertEqual(17, sum(site.symbol == "boop.tick" for site in forwarders))
        self.assertEqual(6, sum(site.symbol == "boop.executeAction" for site in forwarders))

    def test_new_direct_outbound_and_forwarder_sites_fail(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source_root = root / "src/scripts/boop"
            source_root.mkdir(parents=True)
            (source_root / "boop_new.lua").write_text(
                "send 'new'\nboop.tick()\n", encoding="utf-8"
            )
            errors = validate_production_calls(root)
        self.assertTrue(any("new outbound location" in error for error in errors))
        self.assertTrue(any("new forwarder location" in error for error in errors))

    def test_repository_graph_and_complete_check_match_accepted_facts(self) -> None:
        graph = load_repository_graph(ROOT)
        self.assertEqual(21, len(graph.modules))
        self.assertEqual(118, len(graph.edges))
        self.assertEqual(108, len(graph.executable_edges))
        self.assertEqual(46, len(graph.data_edges))
        self.assertEqual(36, len(graph.executable_edges & graph.data_edges))
        self.assertEqual(23, len(graph.reciprocal_pairs()))
        self.assertEqual([19], sorted(len(value) for value in graph.nontrivial_sccs()))
        self.assertEqual(["boop_bootstrap"], graph.composition_roots())
        self.assertEqual([], graph.unresolved_references)
        self.assertEqual({}, graph.duplicate_exports)

        errors, summary = check_repository_architecture(ROOT)
        self.assertEqual([], errors)
        self.assertEqual(118, summary["edges"])
        self.assertEqual(14, summary["legacy_indirection_exceptions"])
        self.assertEqual(1, summary["schema_custody_exceptions"])


if __name__ == "__main__":
    unittest.main()
