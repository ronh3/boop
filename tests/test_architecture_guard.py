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
    ("send", "src/scripts/boop/boop_events.lua"): 1,
    ("send", "src/scripts/boop/boop_rage.lua"): 1,
    ("send", "src/scripts/boop/boop_room.lua"): 1,
    ("send", "src/scripts/boop/boop_runtime.lua"): 1,
    ("send", "src/scripts/boop/boop_safety.lua"): 1,
    ("send", "src/scripts/boop/boop_targets.lua"): 5,
    ("send", "src/scripts/boop/boop_ui.lua"): 4,
    ("send", "src/scripts/boop/boop_wire.lua"): 1,
    ("sendGMCP", "src/scripts/boop/boop_init.lua"): 4,
    ("sendGMCP", "src/scripts/boop/boop_room.lua"): 1,
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

    def test_attack_decision_layer_cannot_depend_on_combat(self) -> None:
        graph = analyze_sources(
            {
                "boop_attacks": "boop.combat.evaluateGates({})",
                "boop_combat": "function boop.combat.evaluateGates() end",
            },
            ["boop_attacks", "boop_combat"],
        )
        errors, _ = validate_graph(
            graph,
            require_composition_root=False,
        )
        self.assertTrue(any(
            "hard-forbidden dependency edge" in error
            for error in errors
        ))

    def test_phase_five_closed_directions_are_hard_forbidden(self) -> None:
        cases = (
            (
                "boop_runtime", "boop_targets",
                "boop.targets.resetGameTargetSync()",
                "function boop.targets.resetGameTargetSync() end",
            ),
            (
                "boop_walk", "boop_events",
                "boop.events.requestRoomItemsOnce()",
                "function boop.events.requestRoomItemsOnce() end",
            ),
            (
                "boop_room", "boop_runtime",
                "boop.runtime.state()",
                "function boop.runtime.state() end",
            ),
            (
                "boop_locks", "boop_combat",
                "boop.combat.step()",
                "function boop.combat.step() end",
            ),
            (
                "boop_room", "boop_ui",
                "boop.ui.render()",
                "function boop.ui.render() end",
            ),
            (
                "boop_room", "boop_targets",
                "boop.targets.choose()",
                "function boop.targets.choose() end",
            ),
            (
                "boop_locks", "boop_wire",
                "boop.wire.executeAction()",
                "function boop.wire.executeAction() end",
            ),
        )
        for source, target, call, definition in cases:
            with self.subTest(source=source, target=target):
                graph = analyze_sources(
                    {source: call, target: definition},
                    [source, target],
                )
                errors, _ = validate_graph(
                    graph,
                    require_composition_root=False,
                )
                self.assertTrue(any(
                    "hard-forbidden dependency edge" in error
                    for error in errors
                ))


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
            "rawset", "src/scripts/boop/boop_runtime.lua", "rawset", 276
        )
        shifted = ConventionViolation(
            "rawset", "src/scripts/boop/boop_runtime.lua", "rawset", 277
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
        self.assertEqual(0, sum(site.symbol == "boop.executeAction" for site in forwarders))

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
        self.assertEqual(25, len(graph.modules))
        self.assertEqual(141, len(graph.edges))
        self.assertEqual(133, len(graph.executable_edges))
        self.assertEqual(42, len(graph.data_edges))
        self.assertEqual(34, len(graph.executable_edges & graph.data_edges))
        self.assertEqual(7, len(graph.reciprocal_pairs()))
        self.assertEqual([22], sorted(len(value) for value in graph.nontrivial_sccs()))
        self.assertEqual(["boop_bootstrap"], graph.composition_roots())
        self.assertEqual([], graph.unresolved_references)
        self.assertEqual({}, graph.duplicate_exports)

        errors, summary = check_repository_architecture(ROOT)
        self.assertEqual([], errors)
        self.assertEqual(141, summary["edges"])
        self.assertEqual(4, summary["legacy_indirection_exceptions"])
        self.assertEqual(1, summary["schema_custody_exceptions"])

    def test_phase_five_ownership_and_closed_pair_invariants(self) -> None:
        graph = load_repository_graph(ROOT)
        self.assertEqual(
            "boop_runtime",
            graph.executable_owners[("runtime", "context")],
        )
        for symbol in (
            "tickStep", "promptStep", "step", "applyEffects",
            "execute", "canAct", "canUseRage",
        ):
            self.assertEqual(
                "boop_combat",
                graph.executable_owners[("combat", symbol)],
            )
        self.assertNotIn(("attacks", "execute"), graph.executable_owners)
        for symbol in (
            "startRoomObservation", "observeRoomInfo", "beginRoomResponseFence",
            "observeRoomItemsList", "claimRoomApplication",
            "validateRoomSourceAuthority", "currentRoomSourceAuthority",
            "movementIntentSnapshot", "requestRoomItemsOnce",
        ):
            self.assertEqual(
                "boop_room",
                graph.executable_owners[("room", symbol)],
            )
        for symbol in (
            "blockersSnapshot", "blockerSnapshot", "setBlocker", "clearBlocker",
            "shouldHold", "operationLocksSnapshot", "operationLockSnapshot",
            "operationHolds", "interruptAdmission", "notePromptObserved",
            "noteGmcpObserved",
        ):
            self.assertEqual(
                "boop_locks",
                graph.executable_owners[("locks", symbol)],
            )

        runtime = (
            ROOT / "src/scripts/boop/boop_runtime.lua"
        ).read_text()
        for symbol in (
            "boop.attacks", "boop.safety", "boop.walk", "boop.gag",
            "boop.targets",
        ):
            self.assertNotIn(symbol, runtime)

        room = (ROOT / "src/scripts/boop/boop_room.lua").read_text()
        locks = (ROOT / "src/scripts/boop/boop_locks.lua").read_text()
        for source in (room, locks):
            for symbol in (
                "boop.runtime", "boop.combat", "boop.events", "boop.gag",
                "boop.render", "boop.stats", "boop.ui",
            ):
                self.assertNotIn(symbol, source)

        walk = (ROOT / "src/scripts/boop/boop_walk.lua").read_text()
        self.assertIn("boop.room.requestRoomItemsOnce", walk)
        self.assertNotIn("boop.events", walk)

        for path in (
            ROOT / "src/scripts/boop/boop_attacks.lua",
            ROOT / "src/scripts/boop/boop_ui.lua",
        ):
            self.assertNotIn("boop.combat", path.read_text())

        closed_pairs = {
            tuple(sorted(pair))
            for pair in (
                ("boop_init", "boop_ui"),
                ("boop_events", "boop_init"),
                ("boop_db", "boop_init"),
                ("boop_ui", "boop_ui_registry"),
                ("boop_gag", "boop_ui"),
                ("boop_stats", "boop_ui"),
                ("boop_runtime", "boop_util"),
                ("boop_rage", "boop_util"),
                ("boop_gag", "boop_util"),
                ("boop_targets", "boop_util"),
                ("boop_db", "boop_stats"),
                ("boop_db", "boop_targets"),
                ("boop_runtime", "boop_targets"),
                ("boop_events", "boop_walk"),
            )
        }
        self.assertTrue(closed_pairs.isdisjoint(graph.reciprocal_pairs()))
        self.assertEqual(set(), {
            edge for edge in graph.edges if edge[0] == "boop_ui_registry"
        })
        self.assertNotIn(("boop_wire", "boop_targets"), graph.edges)
        self.assertIn(("boop_runtime", "boop_room"), graph.edges)
        self.assertIn(("boop_runtime", "boop_locks"), graph.edges)
        self.assertNotIn(("boop_room", "boop_runtime"), graph.edges)
        self.assertNotIn(("boop_locks", "boop_runtime"), graph.edges)
        self.assertNotIn(("boop_runtime", "boop_targets"), graph.edges)
        self.assertNotIn(("boop_walk", "boop_events"), graph.edges)

        self.assertEqual({
            "boop_afflictions", "boop_attacks", "boop_combat", "boop_db",
            "boop_events", "boop_gag", "boop_ih", "boop_init", "boop_locks",
            "boop_rage", "boop_render", "boop_room", "boop_runtime",
            "boop_safety", "boop_skills", "boop_stats", "boop_targets",
            "boop_theme", "boop_ui", "boop_util", "boop_walk", "boop_wire",
        }, graph.nontrivial_sccs()[0])

        wire = (ROOT / "src/scripts/boop/boop_wire.lua").read_text()
        self.assertNotIn("boop.state.targeting", wire)
        self.assertNotIn("boop.targets", wire)
        self.assertFalse((ROOT / "src/scripts/boop/boop_state.lua").exists())


if __name__ == "__main__":
    unittest.main()
