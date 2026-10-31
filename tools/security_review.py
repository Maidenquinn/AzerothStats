"""Offline source/package policy checks for the manual-approval candidate.

This scanner is a reproducible aid to human review, not a proof of safety or an
approval certificate. It evaluates no Lua and downloads nothing. Test harnesses
and Python developer tools are deliberately outside the runtime policy scope.
"""

from dataclasses import dataclass
from pathlib import Path
import argparse
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parent.parent
DATA_MODULES = {
    "Strings.lua": {"uiText"},
    "GameText.lua": {"gameText"},
    "Collection.lua": {"collectionAliases", "collectionSources", "abilityClasses"},
    "Icons.lua": {"gameSpellIcons"},
    "CreaturePortraits.lua": {"creaturePortraits"},
    "InsightsStrings.lua": {"uiText"},
}
FORBIDDEN = set(
    """load loadstring loadfile dofile require module setfenv getfenv
rawset setmetatable collectgarbage io os debug package ffi _G
SendAddonMessage SendChatMessage RunScript RunMacro RunMacroText ConsoleExec
SetCVar SetBinding SetBindingClick SaveBindings CastSpell CastSpellByName
UseAction UseItemByName TargetUnit AttackTarget MoveForwardStart MoveBackwardStart
TurnLeftStart TurnRightStart JumpOrAscendStart Screenshot Logout Quit ReloadUI
PickupInventoryItem DeleteCursorItem AcceptTrade SendMail SetItemRef""".split()
)


@dataclass(frozen=True)
class Token:
    kind: str
    text: str
    line: int


def tokens(source):
    """Lex strings/comments separately so text cannot masquerade as Lua code."""
    result = []
    offset, line = 0, 1
    while offset < len(source):
        start, current_line = offset, line
        char = source[offset]
        if char.isspace():
            offset += 1
        elif source.startswith("--", offset):
            long = re.match(r"--\[(=*)\[", source[offset:])
            if long:
                close = "]" + long[1] + "]"
                end = source.find(close, offset + long.end())
                assert end >= 0, (line, "unterminated comment")
                offset = end + len(close)
            else:
                end = source.find("\n", offset)
                offset = len(source) if end < 0 else end
        elif char in {chr(34), chr(39)}:
            quote = char
            offset += 1
            while offset < len(source):
                if source[offset] == "\\":
                    offset += 2
                elif source[offset] == quote:
                    offset += 1
                    break
                else:
                    offset += 1
            else:
                raise AssertionError((line, "unterminated string"))
            result.append(Token("string", source[start:offset], line))
        elif long := re.match(r"\[(=*)\[", source[offset:]):
            close = "]" + long[1] + "]"
            end = source.find(close, offset + long.end())
            assert end >= 0, (line, "unterminated long string")
            offset = end + len(close)
            result.append(Token("string", source[start:offset], line))
        elif identifier := re.match(r"[A-Za-z_][A-Za-z_0-9]*", source[offset:]):
            offset += identifier.end()
            result.append(Token("identifier", identifier[0], line))
        elif number := re.match(
            r"(?:0[xX][0-9a-fA-F]+|(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?)",
            source[offset:],
        ):
            offset += number.end()
            result.append(Token("number", number[0], line))
        else:
            offset += 1
            result.append(Token("symbol", char, line))
        line += source[start:offset].count("\n")
    return result


class LiteralCatalog:
    """Accept only own-namespace assignments to primitive/table literals.

    Unlike a keyword search, this rejects function calls hidden in constructors,
    arithmetic/concatenation expressions, computed keys and unexpected writes.
    """

    def __init__(self, stream, namespaces):
        self.stream = stream
        self.namespaces = namespaces
        self.offset = 0
        self.alias = False

    def take(self, text=None):
        assert self.offset < len(self.stream), "unexpected end of catalog"
        token = self.stream[self.offset]
        self.offset += 1
        assert text is None or token.text == text, (token.line, text, token.text)
        return token

    def value(self):
        token = self.take()
        if token.kind in {"string", "number"} or token.text in {"nil", "true", "false"}:
            return
        if token.text == "-":
            assert self.take().kind == "number"
            return
        assert token.text == "{", (token.line, "non-literal catalog value", token.text)
        while self.stream[self.offset].text != "}":
            if self.stream[self.offset].text == "[":
                self.take("[")
                assert self.take().kind in {"string", "number"}
                self.take("]")
                self.take("=")
            self.value()
            if self.stream[self.offset].text in {",", ";"}:
                self.take()
            else:
                assert self.stream[self.offset].text == "}"
        self.take("}")

    def check(self):
        while self.offset < len(self.stream):
            if self.stream[self.offset].text == ";":
                self.take()
                continue
            if self.stream[self.offset].text == "local":
                for text in ["local", "A", "=", "AzerothStats"]:
                    self.take(text)
                assert not self.alias
                self.alias = True
                continue
            root = self.take()
            assert root.text == "AzerothStats" or (root.text == "A" and self.alias)
            self.take(".")
            namespace = self.take()
            assert namespace.text in self.namespaces, (
                namespace.line,
                "unexpected namespace",
                namespace.text,
            )
            while self.stream[self.offset].text in {".", "["}:
                if self.take().text == ".":
                    assert self.take().kind == "identifier"
                else:
                    assert self.take().kind in {"string", "number"}
                    self.take("]")
            self.take("=")
            self.value()


def inspect(root=ROOT):
    addon = root / "AzerothStats"
    toc = (addon / "AzerothStats.toc").read_text(encoding="utf-8")
    modules = [
        line.strip()
        for line in toc.splitlines()
        if line.strip() and not line.startswith("#")
    ]
    assert len(modules) == len(set(modules))
    assert set(modules) == {file.name for file in addon.glob("*.lua")}
    assert all(re.fullmatch(r"[A-Za-z][A-Za-z0-9_]*\.lua", name) for name in modules)
    assert "## Interface: 11200" in toc and "## SavedVariables: AzerothStatsDB" in toc
    manifest, methods, calls = {}, set(), set()
    for name in modules:
        source = (addon / name).read_text(encoding="utf-8")
        stream = tokens(source)
        if name in DATA_MODULES:
            LiteralCatalog(stream, DATA_MODULES[name]).check()
        else:
            for index, token in enumerate(stream):
                assert token.kind != "identifier" or token.text not in FORBIDDEN, (
                    name,
                    token.line,
                    token.text,
                )
                assert token.kind != "string" or token.text[1:-1] not in (
                    FORBIDDEN - {"io", "os", "debug", "package", "ffi", "_G"}
                ), (name, token.line, "forbidden dynamic lookup")
                if (
                    index + 1 < len(stream)
                    and stream[index + 1].text == "("
                    and token.kind == "identifier"
                ):
                    previous = stream[index - 1].text if index else ""
                    if previous == ":":
                        methods.add(token.text)
                    elif previous != ".":
                        calls.add(token.text)
        manifest[name] = hashlib.sha256((addon / name).read_bytes()).hexdigest()
    return {
        "scope": "All and only Lua modules listed in AzerothStats.toc",
        "runtimeModules": len(modules),
        "literalDataModules": sorted(DATA_MODULES),
        "forbiddenCapabilitiesFound": [],
        "sourceSha256": manifest,
        "callNamesForHumanReview": sorted(calls),
        "widgetMethodsForHumanReview": sorted(methods),
        "limitations": [
            "Static policy checks complement human review; they are not a formal proof.",
            "Native client implementation and other addons are outside this source audit.",
            "No game-developer approval is asserted.",
        ],
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    result = inspect()
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(
        "Runtime policy:",
        result["runtimeModules"],
        "modules;",
        len(DATA_MODULES),
        "literal-only catalogs; no forbidden capability found",
    )
