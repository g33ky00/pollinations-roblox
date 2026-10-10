#!/usr/bin/env python3
"""Generate a Roblox place file (.rbxlx) embedding the Pollinations NPC module.

Produces a Studio-importable place containing:
  - Workspace: Baseplate + SpawnLocation
  - ServerScriptService: ExampleNPCScript + Modules/PollinationsNPC
  - Lighting, ReplicatedStorage, StarterGui scaffolding

The Lua sources are embedded verbatim in CDATA sections, so the place is
self-contained: opening it in Studio gives a runnable demo with no manual
file copying.
"""

import html
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
MODULE_SRC = ROOT / "src" / "PollinationsNPC.lua"
EXAMPLE_SRC = ROOT / "src" / "ExampleNPCScript.lua"
OUT = ROOT / "PollinationsNPC.rbxlx"


def cdata(path: pathlib.Path) -> str:
    text = path.read_text(encoding="utf-8")
    if "]]>" in text:
        raise SystemExit(f"ERROR: {path} contains ']]>' which breaks CDATA")
    # Roblox expects LF newlines in embedded sources.
    return text.replace("\r\n", "\n")


def cframe(x: float, y: float, z: float) -> str:
    return (
        "<CoordinateFrame name=\"CFrame\">"
        f"<X>{x}</X><Y>{y}</Y><Z>{z}</Z>"
        "<R00>1</R00><R01>0</R01><R02>0</R02>"
        "<R10>0</R10><R11>1</R11><R12>0</R12>"
        "<R20>0</R20><R21>0</R21><R22>1</R22>"
        "</CoordinateFrame>"
    )


def part(name: str, referent: str, size, pos, color, anchored=True) -> str:
    sx, sy, sz = size
    return f"""    <Item class="Part" referent="{referent}">
      <Properties>
        <bool name="Anchored">{str(anchored).lower()}</bool>
        <Color3uint8 name="Color3uint8">{color}</Color3uint8>
        <string name="Name">{html.escape(name)}</string>
        <Vector3 name="size"><X>{sx}</X><Y>{sy}</Y><Z>{sz}</Z></Vector3>
        {cframe(*pos)}
      </Properties>
    </Item>"""


def spawn_location(referent: str) -> str:
    return f"""    <Item class="SpawnLocation" referent="{referent}">
      <Properties>
        <bool name="Anchored">true</bool>
        <Color3uint8 name="Color3uint8">4288914085</Color3uint8>
        <string name="Name">SpawnLocation</string>
        <bool name="Neutral">true</bool>
        <Vector3 name="size"><X>12</X><Y>1</Y><Z>12</Z></Vector3>
        {cframe(0, 0.5, -20)}
      </Properties>
    </Item>"""


def script_item(cls: str, name: str, referent: str, source: str, extra: str = "") -> str:
    return f"""      <Item class="{cls}" referent="{referent}">
        <Properties>
          <string name="Name">{html.escape(name)}</string>
          <ProtectedString name="Source"><![CDATA[{source}]]></ProtectedString>
{extra}        </Properties>
      </Item>"""


def build() -> str:
    module = cdata(MODULE_SRC)
    example = cdata(EXAMPLE_SRC)

    workspace = f"""  <Item class="Workspace" referent="RBX0">
    <Properties>
      <string name="Name">Workspace</string>
      <bool name="FilteringEnabled">true</bool>
    </Properties>
{part("Baseplate", "RBX1", (512, 20, 512), (0, -10, 0), 4288914085)}
{spawn_location("RBX2")}
  </Item>"""

    lighting = """  <Item class="Lighting" referent="RBX3">
    <Properties>
      <string name="Name">Lighting</string>
      <Color3 name="Ambient"><R>0.5</R><G>0.5</G><B>0.5</B></Color3>
      <Color3 name="OutdoorAmbient"><R>0.5</R><G>0.5</G><B>0.5</B></Color3>
      <double name="Brightness">2</double>
      <bool name="GlobalShadows">true</bool>
    </Properties>
  </Item>"""

    replicated = """  <Item class="ReplicatedStorage" referent="RBX4">
    <Properties>
      <string name="Name">ReplicatedStorage</string>
    </Properties>
  </Item>"""

    sss = f"""  <Item class="ServerScriptService" referent="RBX5">
    <Properties>
      <string name="Name">ServerScriptService</string>
    </Properties>
    <Item class="Folder" referent="RBX6">
      <Properties>
        <string name="Name">Modules</string>
      </Properties>
{script_item("ModuleScript", "PollinationsNPC", "RBX7", module)}
    </Item>
{script_item("Script", "ExampleNPCScript", "RBX8", example)}
  </Item>"""

    starter_gui = """  <Item class="StarterGui" referent="RBX9">
    <Properties>
      <string name="Name">StarterGui</string>
    </Properties>
  </Item>"""

    players = """  <Item class="Players" referent="RBX10">
    <Properties>
      <string name="Name">Players</string>
      <bool name="CharacterAutoLoads">true</bool>
    </Properties>
  </Item>"""

    return (
        '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
        'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">\n'
        + workspace
        + "\n"
        + lighting
        + "\n"
        + replicated
        + "\n"
        + sss
        + "\n"
        + starter_gui
        + "\n"
        + players
        + "\n</roblox>\n"
    )


def main() -> int:
    if not MODULE_SRC.exists() or not EXAMPLE_SRC.exists():
        print(f"ERROR: missing sources under {ROOT / 'src'}", file=sys.stderr)
        return 1
    xml = build()
    OUT.write_text(xml, encoding="utf-8")
    print(f"wrote {OUT} ({len(xml)} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
