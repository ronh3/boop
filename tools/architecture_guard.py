"""Convention-based architecture guard for boop.

Boop deliberately requires direct, statically visible architectural
references. This module tokenizes enough Lua to enforce that repository
convention and to build the graph expressed through it. It is not a general
Lua parser, does not perform data-flow analysis, and does not claim to find a
dependency hidden behind unsupported indirection. Instead, such indirection
is rejected as a coding-convention violation. The only sanctioned string
dependency is the exact Mudlet event-handler registration shape documented in
ARCHITECTURE.md.
"""

from __future__ import annotations

import json
import re
from collections import Counter, defaultdict
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable, Mapping, Sequence


MODULE_MANIFEST = Path("src/scripts/boop/scripts.json")
MODULE_DIRECTORY = Path("src/scripts/boop")
COMPOSITION_ROOT = "boop_bootstrap"
BASELINE_PATH = Path(__file__).with_name("architecture_baseline.json")
PRE_DAG_STAGE = True

DECISION_ORCHESTRATION_PRESENTATION_MODULES = frozenset(
    {
        "boop_attacks", "boop_events", "boop_gag", "boop_ih", "boop_rage",
        "boop_safety", "boop_stats", "boop_targets", "boop_ui", "boop_walk",
    }
)


def _load_baseline() -> dict[str, object]:
    return json.loads(BASELINE_PATH.read_text())


BASELINE = _load_baseline()
EXPECTED_MODULES = frozenset(str(value) for value in BASELINE["expected_modules"])


def _edge_set(key: str) -> frozenset[tuple[str, str]]:
    return frozenset(
        (str(value[0]), str(value[1]))
        for value in BASELINE.get(key, [])
    )


REVIEWED_FORBIDDEN_EDGES = _edge_set("reviewed_forbidden_edges")
REVIEWED_MUTATION_EDGES = _edge_set("reviewed_mutation_edges")
SCHEMA_CUSTODY_EXCEPTIONS = frozenset(
    (
        str(value["kind"]), str(value["path"]),
        str(value["symbol"]), int(value["line"]),
    )
    for value in BASELINE.get("schema_custody_exceptions", [])
)

# Closed shared kernel. It is graph-exempt, not governance-exempt.
SHARED_KERNEL = frozenset({("config",), ("version",)})

# Explicit current semantic ownership. Direct references resolve by longest
# prefix. Physical table initialization never establishes ownership.
OWNED_DATA: dict[tuple[str, ...], str] = {
    ("defaults",): "boop_init",
    ("lists",): "boop_targets",
    ("lists", "separator"): "boop_util",
    ("handlers",): "boop_events",
    ("gmcp",): "boop_init",
    ("bootstrapped",): "boop_init",
    ("attacks", "registry"): "boop_attacks",
    ("attacks", "pendingRegistry"): "boop_attacks",
    ("skills",): "boop_skills",
    ("stats",): "boop_stats",
    ("db", "handle"): "boop_db",
    ("registry", "config"): "boop_ui_registry",
    ("registry", "ui"): "boop_ui_registry",
    ("ui", "modes"): "boop_ui_registry",
    ("ui", "presets"): "boop_ui_registry",
    ("ui", "helpTopics"): "boop_ui_registry",
    ("ui", "screens"): "boop_ui_registry",
    ("afflictions", "target"): "boop_afflictions",
    ("rage",): "boop_rage",
    ("perf",): "boop_perf",
    ("state",): "boop_runtime",
    ("state", "combat"): "boop_runtime",
    ("state", "combat", "openerUsedByClass"): "boop_attacks",
    ("state", "combat", "temporaryAttackPreferences"): "boop_attacks",
    ("state", "lifecycle"): "boop_runtime",
    ("state", "targeting"): "boop_targets",
    ("state", "targeting", "roomObservation"): "boop_runtime",
    ("state", "targeting", "movementIntent"): "boop_runtime",
    ("state", "gold"): "boop_events",
    ("state", "queue"): "boop_runtime",
    ("state", "walk"): "boop_walk",
    ("state", "diag"): "boop_runtime",
    ("state", "trace"): "boop_util",
    ("state", "ui"): "boop_ui",
    ("state", "rage"): "boop_rage",
    ("state", "inventory"): "boop_events",
    ("state", "ih"): "boop_ih",
    ("state", "gag"): "boop_gag",
}
STATE_DOMAIN_OWNERS = {
    prefix: owner
    for prefix, owner in OWNED_DATA.items()
    if prefix[:1] == ("state",) and len(prefix) > 1
}

# Data kept beneath executable namespaces. This is explicit so an unknown
# boop root never becomes valid merely because it appears in source.
MODULE_DATA_ROOTS: dict[tuple[str, ...], str] = {
    ("afflictions",): "boop_afflictions",
    ("attacks",): "boop_attacks",
    ("db",): "boop_db",
    ("events",): "boop_events",
    ("gag",): "boop_gag",
    ("ih",): "boop_ih",
    ("rage",): "boop_rage",
    ("registry",): "boop_ui_registry",
    ("runtime",): "boop_runtime",
    ("safety",): "boop_safety",
    ("skills",): "boop_skills",
    ("stats",): "boop_stats",
    ("targets",): "boop_targets",
    ("theme",): "boop_theme",
    ("trace",): "boop_util",
    ("triggers",): "boop_init",
    ("ui",): "boop_ui",
    ("util",): "boop_util",
    ("walk",): "boop_walk",
    ("perf",): "boop_perf",
}

# Config is a shared-kernel map. These are its current direct writers: schema,
# persistence, and the modules that own the corresponding setting semantics.
CONFIG_WRITERS = frozenset(
    {"boop_db", "boop_gag", "boop_init", "boop_safety", "boop_ui", "boop_ui_registry"}
)


@dataclass(frozen=True)
class LuaToken:
    kind: str
    value: str
    line: int
    offset: int


@dataclass(frozen=True)
class SourceUnit:
    module: str
    path: str
    source: str


@dataclass(frozen=True)
class Definition:
    module: str
    symbol: str
    line: int
    path: str


@dataclass(frozen=True)
class Reference:
    module: str
    path: str
    symbol: str
    line: int
    kind: str
    owner: str | None = None
    write: bool = False


@dataclass(frozen=True)
class ConventionViolation:
    kind: str
    path: str
    symbol: str
    line: int

    @property
    def key(self) -> tuple[str, str, str]:
        return (self.kind, self.path, self.symbol)

    @property
    def exact_key(self) -> tuple[str, str, str, int]:
        return (self.kind, self.path, self.symbol, self.line)


@dataclass(frozen=True)
class CallSite:
    symbol: str
    path: str
    line: int

    @property
    def key(self) -> tuple[str, str]:
        return (self.symbol, self.path)


def _long_bracket_end(source: str, start: int) -> int | None:
    if start >= len(source) or source[start] != "[":
        return None
    cursor = start + 1
    while cursor < len(source) and source[cursor] == "=":
        cursor += 1
    if cursor >= len(source) or source[cursor] != "[":
        return None
    close = "]" + source[start + 1 : cursor] + "]"
    found = source.find(close, cursor + 1)
    return len(source) if found < 0 else found + len(close)


def lex_lua(source: str) -> list[LuaToken]:
    """Tokenize the direct-reference subset; comments and strings stay opaque."""

    tokens: list[LuaToken] = []
    index = 0
    line = 1
    while index < len(source):
        char = source[index]
        if char in " \t\r\f\v":
            index += 1
            continue
        if char == "\n":
            line += 1
            index += 1
            continue
        if source.startswith("--", index):
            long_end = _long_bracket_end(source, index + 2)
            if long_end is not None:
                line += source.count("\n", index, long_end)
                index = long_end
            else:
                end = source.find("\n", index + 2)
                index = len(source) if end < 0 else end
            continue
        if char in "'\"":
            start, start_line, quote = index, line, char
            index += 1
            while index < len(source):
                if source[index] == "\\":
                    if index + 1 < len(source) and source[index + 1] == "\n":
                        line += 1
                    index += 2
                elif source[index] == quote:
                    index += 1
                    break
                else:
                    if source[index] == "\n":
                        line += 1
                    index += 1
            tokens.append(LuaToken("string", source[start:index], start_line, start))
            continue
        long_end = _long_bracket_end(source, index)
        if long_end is not None:
            start, start_line = index, line
            line += source.count("\n", index, long_end)
            index = long_end
            tokens.append(LuaToken("string", source[start:index], start_line, start))
            continue
        if char.isalpha() or char == "_":
            start = index
            index += 1
            while index < len(source) and (
                source[index].isalnum() or source[index] == "_"
            ):
                index += 1
            tokens.append(LuaToken("ident", source[start:index], line, start))
            continue
        if char.isdigit():
            start = index
            index += 1
            while index < len(source) and (
                source[index].isalnum() or source[index] in ".xXpP+-"
            ):
                index += 1
            tokens.append(LuaToken("number", source[start:index], line, start))
            continue
        matched = False
        for symbol in ("...", "..", "==", "~=", "<=", ">=", "::", "//", "<<", ">>"):
            if source.startswith(symbol, index):
                tokens.append(LuaToken("symbol", symbol, line, index))
                index += len(symbol)
                matched = True
                break
        if not matched:
            tokens.append(LuaToken("symbol", char, line, index))
            index += 1
    return tokens


def _boop_path(
    tokens: Sequence[LuaToken], index: int
) -> tuple[tuple[str, ...], int] | None:
    if index >= len(tokens) or tokens[index].value != "boop":
        return None
    parts: list[str] = []
    cursor = index + 1
    while (
        cursor + 1 < len(tokens)
        and tokens[cursor].value == "."
        and tokens[cursor + 1].kind == "ident"
    ):
        parts.append(tokens[cursor + 1].value)
        cursor += 2
    if not parts:
        return None
    return tuple(parts), cursor


def _path_text(parts: Sequence[str]) -> str:
    return "boop." + ".".join(parts)


def _matching_owner(
    parts: tuple[str, ...], owners: Mapping[tuple[str, ...], str]
) -> tuple[tuple[str, ...], str] | None:
    matches = [
        (prefix, owner)
        for prefix, owner in owners.items()
        if parts[: len(prefix)] == prefix
    ]
    return max(matches, key=lambda item: len(item[0]), default=None)


def _matching_data_owner(
    parts: tuple[str, ...],
) -> tuple[tuple[str, ...], str] | None:
    """Resolve declared data without treating state schema custody as a domain owner."""

    if parts[:1] == ("state",) and len(parts) > 1:
        return _matching_owner(parts, STATE_DOMAIN_OWNERS)
    return _matching_owner(parts, OWNED_DATA)


_LITERAL_BOOP_HANDLER = re.compile(
    r'^(?P<quote>["\'])(?P<symbol>boop(?:\.[A-Za-z_][A-Za-z0-9_]*)+)(?P=quote)$'
)
_MUDLET_HANDLER_PATH = "src/scripts/boop/boop_events.lua"


def _contains_token_sequence(tokens: Sequence[LuaToken], values: Sequence[str]) -> bool:
    width = len(values)
    return any(
        [token.value for token in tokens[index : index + width]] == list(values)
        for index in range(len(tokens) - width + 1)
    )


def _mudlet_handler_strings(
    unit: SourceUnit, tokens: Sequence[LuaToken]
) -> list[tuple[tuple[str, ...] | None, str, int]]:
    """Return only the sanctioned boop.events local-helper callback strings."""

    if unit.module != "boop_events" or unit.path != _MUDLET_HANDLER_PATH:
        return []
    if not _contains_token_sequence(
        tokens, ("local", "function", "add", "(", "event", ",", "fn", ")")
    ) or not _contains_token_sequence(
        tokens, ("registerAnonymousEventHandler", "(", "event", ",", "fn", ")")
    ):
        return []

    handlers: list[tuple[tuple[str, ...] | None, str, int]] = []
    for index, token in enumerate(tokens):
        if (
            token.value != "add" or index + 5 >= len(tokens)
            or tokens[index + 1].value != "("
            or tokens[index + 2].kind != "string"
            or tokens[index + 3].value != ","
            or tokens[index + 4].kind != "string"
            or tokens[index + 5].value != ")"
        ):
            continue
        handler = tokens[index + 4]
        if (
            len(handler.value) < 2
            or handler.value[0] not in {"'", '"'}
            or handler.value[-1] != handler.value[0]
        ):
            continue
        literal = handler.value[1:-1]
        if not literal.startswith("boop"):
            continue
        match = _LITERAL_BOOP_HANDLER.fullmatch(handler.value)
        if not match:
            handlers.append((None, literal, handler.line))
            continue
        symbol = match.group("symbol")
        handlers.append((tuple(symbol.removeprefix("boop.").split(".")), symbol, handler.line))
    return handlers


def _is_call(tokens: Sequence[LuaToken], end: int) -> bool:
    return end < len(tokens) and (
        tokens[end].value in {"(", "{"} or tokens[end].kind == "string"
    )


def _local_function_names(tokens: Sequence[LuaToken]) -> set[str]:
    names: set[str] = set()
    for index, token in enumerate(tokens):
        if (
            token.value == "function"
            and index > 0
            and tokens[index - 1].value == "local"
            and index + 1 < len(tokens)
            and tokens[index + 1].kind == "ident"
        ):
            names.add(tokens[index + 1].value)
        if (
            token.value == "local"
            and index + 3 < len(tokens)
            and tokens[index + 1].kind == "ident"
            and tokens[index + 2].value == "="
            and tokens[index + 3].value == "function"
        ):
            names.add(tokens[index + 1].value)
        if (
            token.kind == "ident"
            and index + 1 < len(tokens)
            and tokens[index + 1].value == "="
            and index + 2 < len(tokens)
            and tokens[index + 2].value == "function"
        ):
            names.add(token.value)
    return names


def _expression_ends(tokens: Sequence[LuaToken], end: int) -> bool:
    if end >= len(tokens):
        return True
    previous = tokens[end - 1]
    following = tokens[end]
    continuation = {"and", "or", ".", "[", "(", "{", ":", ","}
    return (
        following.line > previous.line and following.value not in continuation
    ) or following.value in {";", "end", "else", "elseif", "until"}


def _indexed_end(tokens: Sequence[LuaToken], start: int) -> int:
    if start >= len(tokens) or tokens[start].value != "[":
        return start
    depth = 0
    cursor = start
    while cursor < len(tokens):
        if tokens[cursor].value == "[":
            depth += 1
        elif tokens[cursor].value == "]":
            depth -= 1
            if depth == 0:
                return cursor + 1
        cursor += 1
    return cursor


def _reference_write(tokens: Sequence[LuaToken], start: int, end: int) -> bool:
    cursor = end
    while cursor < len(tokens) and tokens[cursor].value == "[":
        cursor = _indexed_end(tokens, cursor)
    if cursor < len(tokens) and tokens[cursor].value == "=":
        return True
    if start >= 4:
        before = [tokens[start - offset].value for offset in (4, 3, 2, 1)]
        if before[0:3] in (["table", ".", "insert"], ["table", ".", "remove"]):
            return before[3] == "("
    return False


def _defensive_indices(tokens: Sequence[LuaToken]) -> set[int]:
    ignored: set[int] = set()
    index = 0
    while index < len(tokens):
        parsed = _boop_path(tokens, index)
        if not parsed:
            index += 1
            continue
        lhs, end = parsed
        if end < len(tokens) and tokens[end].value == "=":
            rhs = _boop_path(tokens, end + 1)
            if rhs and rhs[0] == lhs and rhs[1] < len(tokens):
                after = rhs[1]
                if tokens[after].value == "or" and after + 1 < len(tokens):
                    if tokens[after + 1].value == "{":
                        ignored.update({index, end + 1})
        index = end
    return ignored


@dataclass
class ArchitectureGraph:
    modules: tuple[str, ...]
    units: tuple[SourceUnit, ...]
    executable_owners: dict[tuple[str, ...], str]
    namespace_owners: dict[str, str]
    executable_edges: set[tuple[str, str]]
    data_edges: set[tuple[str, str]]
    duplicate_exports: dict[str, list[Definition]]
    unresolved_references: list[Reference]
    mutation_violations: list[Reference]
    kernel_writes: list[Reference]
    edges: set[tuple[str, str]] = field(init=False)

    def __post_init__(self) -> None:
        self.edges = self.executable_edges | self.data_edges

    def incoming(self, module: str) -> set[str]:
        return {source for source, target in self.edges if target == module}

    def composition_roots(self) -> list[str]:
        return sorted(module for module in self.modules if not self.incoming(module))

    def reciprocal_pairs(self) -> set[tuple[str, str]]:
        return {
            tuple(sorted((source, target)))
            for source, target in self.edges
            if source != target and (target, source) in self.edges
        }

    def strongly_connected_components(self) -> list[set[str]]:
        adjacency = {module: set() for module in self.modules}
        for source, target in self.edges:
            adjacency[source].add(target)
        index = 0
        indices: dict[str, int] = {}
        low: dict[str, int] = {}
        stack: list[str] = []
        on_stack: set[str] = set()
        result: list[set[str]] = []

        def visit(node: str) -> None:
            nonlocal index
            indices[node] = low[node] = index
            index += 1
            stack.append(node)
            on_stack.add(node)
            for target in sorted(adjacency[node]):
                if target not in indices:
                    visit(target)
                    low[node] = min(low[node], low[target])
                elif target in on_stack:
                    low[node] = min(low[node], indices[target])
            if low[node] != indices[node]:
                return
            component: set[str] = set()
            while stack:
                member = stack.pop()
                on_stack.remove(member)
                component.add(member)
                if member == node:
                    break
            result.append(component)

        for module in self.modules:
            if module not in indices:
                visit(module)
        return result

    def nontrivial_sccs(self) -> list[set[str]]:
        return [value for value in self.strongly_connected_components() if len(value) > 1]


def _definition_at(
    tokens: Sequence[LuaToken], index: int, local_functions: set[str]
) -> tuple[tuple[str, ...], int] | None:
    """Return a directly visible executable definition beginning at index."""

    if tokens[index].value == "function":
        return _boop_path(tokens, index + 1)
    parsed = _boop_path(tokens, index)
    if not parsed:
        return None
    parts, end = parsed
    if end >= len(tokens) or tokens[end].value != "=" or end + 1 >= len(tokens):
        return None
    rhs = tokens[end + 1]
    if rhs.value == "function" or (
        rhs.kind == "ident" and rhs.value in local_functions and _expression_ends(tokens, end + 2)
    ) or (
        rhs.value == "boop" and end + 3 < len(tokens)
        and tokens[end + 2].value == "."
        and tokens[end + 3].kind == "ident"
        and end + 5 < len(tokens)
        and tokens[end + 4].value == "or"
        and tokens[end + 5].value == "function"
    ):
        return parts, end
    return None


def analyze_units(units: Iterable[SourceUnit], modules: Iterable[str]) -> ArchitectureGraph:
    unit_list = tuple(units)
    module_list = tuple(modules)
    tokens_by_path = {unit.path: lex_lua(unit.source) for unit in unit_list}
    definitions: dict[str, list[Definition]] = defaultdict(list)
    definition_indices: dict[str, set[int]] = defaultdict(set)

    for unit in unit_list:
        tokens = tokens_by_path[unit.path]
        local_functions = _local_function_names(tokens)
        for index in range(len(tokens)):
            parsed = _definition_at(tokens, index, local_functions)
            if not parsed:
                continue
            parts, end = parsed
            symbol = _path_text(parts)
            definitions[symbol].append(
                Definition(unit.module, symbol, tokens[index].line, unit.path)
            )
            definition_indices[unit.path].add(index + 1 if tokens[index].value == "function" else index)

    executable_owners: dict[tuple[str, ...], str] = {}
    duplicate_exports: dict[str, list[Definition]] = {}
    for symbol, values in sorted(definitions.items()):
        owners = {value.module for value in values}
        exact_attack_exception = (
            symbol == "boop.attacks.register"
            and len(values) == 2
            and {value.path for value in values} == {
                "src/scripts/boop/boop_attacks.lua",
                "src/scripts/boop/attacks/attack_profile_bootstrap.lua",
            }
            and owners == {"boop_attacks"}
        )
        if len(values) > 1 and not exact_attack_exception:
            duplicate_exports[symbol] = values
        executable_owners[tuple(symbol.removeprefix("boop.").split("."))] = values[0].module

    namespace_owners: dict[str, str] = {}
    for parts, owner in {**MODULE_DATA_ROOTS, **executable_owners}.items():
        namespace_owners.setdefault(parts[0], owner)
    for parts, owner in OWNED_DATA.items():
        namespace_owners.setdefault(parts[0], owner)

    executable_edges: set[tuple[str, str]] = set()
    data_edges: set[tuple[str, str]] = set()
    unresolved: list[Reference] = []
    mutations: list[Reference] = []
    kernel_writes: list[Reference] = []

    for unit in unit_list:
        tokens = tokens_by_path[unit.path]
        ignored = _defensive_indices(tokens)
        index = 0
        while index < len(tokens):
            parsed = _boop_path(tokens, index)
            if not parsed:
                index += 1
                continue
            parts, end = parsed
            if index in definition_indices[unit.path] or index in ignored:
                index = end
                continue
            # A namespace existence guard is not a second data access. The
            # longer direct reference carries the architectural meaning.
            if end < len(tokens) and tokens[end].value in {"and", "or"}:
                guarded = _boop_path(tokens, end + 1)
                if guarded and guarded[0][: len(parts)] == parts:
                    index = end
                    continue
            symbol = _path_text(parts)
            write = _reference_write(tokens, index, end)
            call = _is_call(tokens, end)
            if parts[:1] in SHARED_KERNEL:
                if write:
                    kernel_writes.append(
                        Reference(unit.module, unit.path, symbol, tokens[index].line, "kernel", write=True)
                    )
                index = end
                continue

            exact_owner = executable_owners.get(parts)
            if call:
                if exact_owner is None:
                    unresolved.append(
                        Reference(
                            unit.module, unit.path, symbol, tokens[index].line,
                            "unresolved-call", write=write,
                        )
                    )
                elif exact_owner != unit.module:
                    executable_edges.add((unit.module, exact_owner))
                index = end
                continue
            if exact_owner is not None:
                if exact_owner != unit.module:
                    executable_edges.add((unit.module, exact_owner))
                index = end
                continue

            data_owner = _matching_data_owner(parts)
            if data_owner is None:
                data_owner = _matching_owner(parts, MODULE_DATA_ROOTS)
            if data_owner:
                _, owner = data_owner
                reference = Reference(
                    unit.module, unit.path, symbol, tokens[index].line, "data", owner, write
                )
                if owner != unit.module:
                    data_edges.add((unit.module, owner))
                    if write:
                        mutations.append(reference)
                index = end
                continue

            if len(parts) == 1 and parts[0] in namespace_owners:
                owner = namespace_owners[parts[0]]
                if owner != unit.module:
                    executable_edges.add((unit.module, owner))
                index = end
                continue

            unresolved.append(
                Reference(unit.module, unit.path, symbol, tokens[index].line, "unresolved", write=write)
            )
            index = end

        for parts, symbol, line in _mudlet_handler_strings(unit, tokens):
            owner = executable_owners.get(parts) if parts is not None else None
            if owner is None:
                unresolved.append(
                    Reference(
                        unit.module, unit.path, symbol, line,
                        "unresolved-handler-string",
                    )
                )
            elif owner != unit.module:
                executable_edges.add((unit.module, owner))

    return ArchitectureGraph(
        modules=module_list,
        units=unit_list,
        executable_owners=executable_owners,
        namespace_owners=namespace_owners,
        executable_edges=executable_edges,
        data_edges=data_edges,
        duplicate_exports=duplicate_exports,
        unresolved_references=unresolved,
        mutation_violations=mutations,
        kernel_writes=kernel_writes,
    )


def analyze_sources(
    sources: Mapping[str, str], modules: Iterable[str] | None = None
) -> ArchitectureGraph:
    module_list = tuple(modules or sources.keys())
    return analyze_units(
        (
            SourceUnit(module, f"{module}.lua", sources.get(module, ""))
            for module in module_list
        ),
        module_list,
    )


def repository_units(root: Path) -> tuple[tuple[SourceUnit, ...], tuple[str, ...]]:
    manifest = json.loads((root / MODULE_MANIFEST).read_text())
    modules = tuple(
        str(entry["name"])
        for entry in manifest
        if str(entry.get("isFolder", "no")) != "yes"
    )
    units: list[SourceUnit] = []
    for module in modules:
        path = root / MODULE_DIRECTORY / f"{module}.lua"
        units.append(SourceUnit(module, path.relative_to(root).as_posix(), path.read_text()))
    attack_root = root / MODULE_DIRECTORY / "attacks"
    for path in sorted(attack_root.rglob("*.lua")):
        units.append(
            SourceUnit("boop_attacks", path.relative_to(root).as_posix(), path.read_text())
        )
    return tuple(units), modules


def load_repository_graph(root: Path) -> ArchitectureGraph:
    units, modules = repository_units(root)
    return analyze_units(units, modules)


def all_production_units(root: Path) -> tuple[SourceUnit, ...]:
    units: list[SourceUnit] = []
    for path in sorted((root / "src").rglob("*.lua")):
        relative = path.relative_to(root).as_posix()
        module = path.stem if "/scripts/boop/" in relative else "<adapter>"
        if "/scripts/boop/attacks/" in relative:
            module = "boop_attacks"
        units.append(SourceUnit(module, relative, path.read_text()))
    return tuple(units)


def is_hard_forbidden(source: str, target: str) -> bool:
    if target == COMPOSITION_ROOT:
        return True
    if source == "boop_runtime" and target in DECISION_ORCHESTRATION_PRESENTATION_MODULES:
        return True
    if (source, target) in {
        ("boop_db", "boop_stats"),
        ("boop_stats", "boop_ui"),
        ("boop_gag", "boop_ui"),
    }:
        return True
    if source == "boop_ui_registry" and target != "boop_ui_registry":
        return True
    if source == "boop_util" and target not in {"boop_theme", "boop_util"}:
        return True
    return False


def scan_conventions(
    unit: SourceUnit,
    executable_owners: Mapping[tuple[str, ...], str],
) -> list[ConventionViolation]:
    """Reject dependency-hiding syntax; approved legacy instances are filtered later."""

    tokens = lex_lua(unit.source)
    violations: list[ConventionViolation] = []
    aliases: dict[str, tuple[str, str]] = {}
    shadowed_outbound = _shadowed_call_indices(tokens, {"send", "sendGMCP"})

    def add(kind: str, token: LuaToken, symbol: str) -> None:
        violations.append(ConventionViolation(kind, unit.path, symbol, token.line))

    index = 0
    while index < len(tokens):
        token = tokens[index]

        if token.value == "boop" and index + 1 < len(tokens) and tokens[index + 1].value == "[":
            add("dynamic-boop-root", token, "boop[]")
        if (
            token.value == "(" and index + 2 < len(tokens)
            and tokens[index + 1].value == "boop" and tokens[index + 2].value == ")"
        ):
            add("parenthesized-boop", tokens[index + 1], "(boop)")
        if token.value == "rawset" and _is_call(tokens, index + 1):
            add("rawset", token, "rawset")
        if (
            token.value == "_G" and index + 2 < len(tokens)
            and tokens[index + 1].value == "."
            and tokens[index + 2].value in {"send", "sendGMCP"}
        ):
            add("global-outbound-indirection", token, f"_G.{tokens[index + 2].value}")
        if (
            token.value == "(" and index + 3 < len(tokens)
            and tokens[index + 1].value in {"send", "sendGMCP"}
            and tokens[index + 2].value == ")"
            and (tokens[index + 3].value in {"(", "{"} or tokens[index + 3].kind == "string")
        ):
            add("parenthesized-outbound", tokens[index + 1], f"({tokens[index + 1].value})")
        if (
            token.value in {"send", "sendGMCP"}
            and index not in shadowed_outbound
            and index > 0 and index + 1 < len(tokens)
            and tokens[index - 1].value in {"(", ","}
            and tokens[index + 1].value in {",", ")"}
        ):
            add("outbound-capture", token, token.value)

        parsed_forwarder = _boop_path(tokens, index)
        if (
            parsed_forwarder
            and _path_text(parsed_forwarder[0]) in {"boop.tick", "boop.executeAction"}
            and index > 0 and parsed_forwarder[1] < len(tokens)
            and tokens[index - 1].value in {"(", ","}
            and tokens[parsed_forwarder[1]].value in {",", ")"}
        ):
            add("forwarder-capture", token, _path_text(parsed_forwarder[0]))

        parsed_owned = _boop_path(tokens, index)
        if parsed_owned and parsed_owned[1] < len(tokens) and tokens[parsed_owned[1]].value == "[":
            indexed_end = _indexed_end(tokens, parsed_owned[1])
            owner = _matching_data_owner(parsed_owned[0])
            if (
                owner and owner[1] != unit.module
                and indexed_end < len(tokens) and tokens[indexed_end].value == "="
            ):
                add("dynamic-owned-write", token, _path_text(parsed_owned[0]))

        # Only simple local aliases are tracked. More elaborate indirection is
        # rejected at its boop[]/(boop)/rawset boundary or is outside the stated subset.
        if (
            token.value == "local" and index + 3 < len(tokens)
            and tokens[index + 1].kind == "ident" and tokens[index + 2].value == "="
        ):
            alias = tokens[index + 1].value
            rhs = index + 3
            if tokens[rhs].value == "boop" and _expression_ends(tokens, rhs + 1):
                add("boop-root-alias", tokens[rhs], f"local {alias} = boop")
            if tokens[rhs].value in {"send", "sendGMCP"} and _expression_ends(tokens, rhs + 1):
                add("outbound-alias", tokens[rhs], f"local {alias} = {tokens[rhs].value}")
            if (
                tokens[rhs].value == "_G" and rhs + 2 < len(tokens)
                and tokens[rhs + 1].value == "."
                and tokens[rhs + 2].value in {"send", "sendGMCP"}
                and _expression_ends(tokens, rhs + 3)
            ):
                add("outbound-alias", tokens[rhs], f"local {alias} = _G.{tokens[rhs + 2].value}")
            parsed = _boop_path(tokens, rhs)
            if parsed and _expression_ends(tokens, parsed[1]):
                parts, _ = parsed
                owner_match = _matching_owner(parts, executable_owners)
                if owner_match and len(owner_match[0]) == len(parts) and owner_match[1] != unit.module:
                    add("function-capture", tokens[rhs], _path_text(parts))
                data_match = _matching_data_owner(parts)
                if data_match and data_match[1] != unit.module:
                    aliases[alias] = (_path_text(parts), data_match[1])

        if token.kind == "ident" and token.value in aliases:
            if index + 2 < len(tokens) and tokens[index + 1].value in {".", "["}:
                cursor = index + 1
                while cursor < len(tokens) and tokens[cursor].value in {".", "["}:
                    if tokens[cursor].value == "." and cursor + 1 < len(tokens):
                        cursor += 2
                    else:
                        cursor = _indexed_end(tokens, cursor)
                if cursor < len(tokens) and tokens[cursor].value == "=":
                    add("foreign-data-alias-write", token, aliases[token.value][0])
        if (
            token.value == "table" and index + 4 < len(tokens)
            and tokens[index + 1].value == "."
            and tokens[index + 2].value in {"insert", "remove"}
            and tokens[index + 3].value == "("
            and tokens[index + 4].value in aliases
        ):
            alias = tokens[index + 4].value
            add("foreign-data-alias-write", tokens[index + 4], aliases[alias][0])
        index += 1
    return violations


def _shadowed_call_indices(tokens: Sequence[LuaToken], symbols: set[str]) -> set[int]:
    """Mark direct call tokens hidden by ordinary local Lua bindings."""

    shadowed: set[int] = set()
    scopes: list[set[str]] = [set()]
    pending_for: set[str] = set()
    index = 0
    while index < len(tokens):
        token = tokens[index]
        if token.value in {"end", "until"} and len(scopes) > 1:
            scopes.pop()
        if token.value in {"else", "elseif"} and len(scopes) > 1:
            scopes.pop()
        if token.kind == "ident" and token.value in symbols:
            if any(token.value in scope for scope in scopes):
                shadowed.add(index)
        if token.value == "local":
            cursor = index + 1
            if cursor < len(tokens) and tokens[cursor].value == "function":
                cursor += 1
            while cursor < len(tokens) and tokens[cursor].kind == "ident":
                scopes[-1].add(tokens[cursor].value)
                cursor += 1
                if cursor >= len(tokens) or tokens[cursor].value != ",":
                    break
                cursor += 1
        if token.value == "for":
            cursor = index + 1
            pending_for = set()
            while cursor < len(tokens) and tokens[cursor].kind == "ident":
                pending_for.add(tokens[cursor].value)
                cursor += 1
                if cursor >= len(tokens) or tokens[cursor].value != ",":
                    break
                cursor += 1
        if token.value == "function":
            parameters: set[str] = set()
            cursor = index + 1
            while cursor < len(tokens) and tokens[cursor].value != "(":
                cursor += 1
            cursor += 1
            while cursor < len(tokens) and tokens[cursor].value != ")":
                if tokens[cursor].kind == "ident":
                    parameters.add(tokens[cursor].value)
                cursor += 1
            scopes.append(parameters)
        elif token.value in {"then", "repeat"}:
            scopes.append(set())
        elif token.value == "do":
            scopes.append(pending_for)
            pending_for = set()
        index += 1
    return shadowed


def _scan_direct_calls(
    unit: SourceUnit, plain_symbols: set[str], boop_symbols: set[str]
) -> list[CallSite]:
    tokens = lex_lua(unit.source)
    shadowed = _shadowed_call_indices(tokens, plain_symbols)
    sites: list[CallSite] = []
    for index, token in enumerate(tokens):
        if token.value in plain_symbols and index not in shadowed:
            preceded = index > 0 and tokens[index - 1].value in {".", ":"}
            if not preceded and _is_call(tokens, index + 1):
                sites.append(CallSite(token.value, unit.path, token.line))
        parsed = _boop_path(tokens, index)
        if parsed:
            parts, end = parsed
            symbol = _path_text(parts)
            is_definition = index > 0 and tokens[index - 1].value == "function"
            if symbol in boop_symbols and not is_definition and _is_call(tokens, end):
                sites.append(CallSite(symbol, unit.path, token.line))
    return sites


def production_call_sites(root: Path) -> tuple[list[CallSite], list[CallSite]]:
    outbound: list[CallSite] = []
    forwarders: list[CallSite] = []
    for unit in all_production_units(root):
        outbound.extend(_scan_direct_calls(unit, {"send", "sendGMCP"}, set()))
        forwarders.extend(
            _scan_direct_calls(unit, set(), {"boop.tick", "boop.executeAction"})
        )
    return outbound, forwarders


def _site_counter(key: str) -> Counter[tuple[str, str]]:
    return Counter(
        {
            (str(item["symbol"]), str(item["path"])): int(item["count"])
            for item in BASELINE.get(key, [])
        }
    )


def _validate_sites(
    actual: Iterable[CallSite], expected: Counter[tuple[str, str]], label: str
) -> list[str]:
    errors: list[str] = []
    counts = Counter(site.key for site in actual)
    for key, count in sorted(counts.items()):
        ceiling = expected.get(key, 0)
        if ceiling == 0:
            errors.append(f"new {label} location: {key[0]} in {key[1]}")
        elif count > ceiling:
            errors.append(
                f"{label} location grew: {key[0]} in {key[1]} ({count} > {ceiling})"
            )
    return errors


def validate_production_calls(root: Path) -> list[str]:
    outbound, forwarders = production_call_sites(root)
    errors = _validate_sites(outbound, _site_counter("outbound_sites"), "outbound")
    errors.extend(
        _validate_sites(forwarders, _site_counter("forwarder_sites"), "forwarder")
    )
    return errors


def validate_graph(
    graph: ArchitectureGraph,
    *,
    expected_modules: frozenset[str] | None = None,
    require_composition_root: bool = True,
) -> tuple[list[str], dict[str, object]]:
    errors: list[str] = []
    if expected_modules is not None and set(graph.modules) != set(expected_modules):
        added = sorted(set(graph.modules) - set(expected_modules))
        removed = sorted(set(expected_modules) - set(graph.modules))
        errors.append(f"module manifest changed without architecture review: added={added}, removed={removed}")
    for symbol, values in sorted(graph.duplicate_exports.items()):
        locations = ", ".join(f"{value.path}:{value.line}" for value in values)
        errors.append(f"duplicate executable export {symbol}: {locations}")
    for reference in graph.unresolved_references:
        errors.append(
            f"unresolved boop reference {reference.symbol} at {reference.path}:{reference.line}"
        )
    for reference in graph.mutation_violations:
        edge = (reference.module, str(reference.owner))
        if edge not in REVIEWED_MUTATION_EDGES:
            errors.append(
                f"foreign owned-data write {reference.symbol} by {reference.module} "
                f"at {reference.path}:{reference.line}; owner={reference.owner}"
            )
    for reference in graph.kernel_writes:
        root = reference.symbol.split(".", 2)[1]
        allowed = (
            root == "config" and reference.module in CONFIG_WRITERS
        ) or (root == "version" and reference.module == "boop_init")
        if not allowed:
            errors.append(
                f"unauthorized shared-kernel write {reference.symbol} by {reference.module} "
                f"at {reference.path}:{reference.line}"
            )
    for edge in sorted(graph.edges):
        if is_hard_forbidden(*edge) and edge not in REVIEWED_FORBIDDEN_EDGES:
            errors.append(f"hard-forbidden dependency edge {edge[0]} -> {edge[1]}")
    roots = graph.composition_roots()
    if require_composition_root and roots != [COMPOSITION_ROOT]:
        errors.append(f"composition root must be {COMPOSITION_ROOT}; found {roots}")
    sccs = sorted((sorted(value) for value in graph.nontrivial_sccs()), key=lambda value: (-len(value), value))
    if not PRE_DAG_STAGE and sccs:
        errors.append(f"dependency graph is cyclic: {sccs}")
    summary: dict[str, object] = {
        "modules": len(graph.modules),
        "edges": len(graph.edges),
        "executable_edges": len(graph.executable_edges),
        "owned_data_edges": len(graph.data_edges),
        "overlapping_edge_directions": len(graph.executable_edges & graph.data_edges),
        "reciprocal_pairs": len(graph.reciprocal_pairs()),
        "composition_roots": roots,
        "nontrivial_sccs": sccs,
        "unresolved_references": len(graph.unresolved_references),
        "duplicate_exports": len(graph.duplicate_exports),
    }
    return errors, summary


def check_repository_architecture(root: Path) -> tuple[list[str], dict[str, object]]:
    graph = load_repository_graph(root)
    errors, summary = validate_graph(graph, expected_modules=EXPECTED_MODULES)
    approved = {
        (str(item["kind"]), str(item["path"]), str(item["symbol"]))
        for item in BASELINE.get("legacy_indirection_exceptions", [])
    }
    violations: list[ConventionViolation] = []
    for unit in all_production_units(root):
        violations.extend(scan_conventions(unit, graph.executable_owners))
    unapproved = sorted(
        (
            value for value in violations
            if value.key not in approved
            and value.exact_key not in SCHEMA_CUSTODY_EXCEPTIONS
        ),
        key=lambda value: (value.path, value.line, value.kind, value.symbol),
    )
    for value in unapproved:
        errors.append(
            f"unsupported architectural indirection {value.kind} ({value.symbol}) "
            f"at {value.path}:{value.line}"
        )
    errors.extend(validate_production_calls(root))
    outbound, forwarders = production_call_sites(root)
    summary["legacy_indirection_exceptions"] = len(approved)
    summary["schema_custody_exceptions"] = len(SCHEMA_CUSTODY_EXCEPTIONS)
    summary["outbound_send_calls"] = sum(site.symbol == "send" for site in outbound)
    summary["outbound_sendgmcp_calls"] = sum(site.symbol == "sendGMCP" for site in outbound)
    summary["tick_forwarders"] = sum(site.symbol == "boop.tick" for site in forwarders)
    summary["execute_action_forwarders"] = sum(
        site.symbol == "boop.executeAction" for site in forwarders
    )
    return errors, summary


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    errors, summary = check_repository_architecture(root)
    print(
        "Architecture graph: "
        f"{summary['modules']} modules, {summary['edges']} unique edges "
        f"({summary['executable_edges']} executable/API, "
        f"{summary['owned_data_edges']} owned-data, "
        f"{summary['overlapping_edge_directions']} overlapping), "
        f"{summary['reciprocal_pairs']} reciprocal pairs"
    )
    sizes = [len(value) for value in summary["nontrivial_sccs"]]
    print(
        f"Composition roots: {summary['composition_roots']}; "
        f"non-trivial SCC sizes: {sizes or 'none'}"
    )
    print(
        "Convention scope: direct/static boop references plus Mudlet literal handlers; "
        f"reviewed legacy indirections={summary['legacy_indirection_exceptions']}; "
        f"schema-custody exceptions={summary['schema_custody_exceptions']}"
    )
    print(
        f"Outbound calls: send={summary['outbound_send_calls']}, "
        f"sendGMCP={summary['outbound_sendgmcp_calls']}; "
        f"forwarders: tick={summary['tick_forwarders']}, "
        f"executeAction={summary['execute_action_forwarders']}"
    )
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1
    print("Architecture convention guard passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
