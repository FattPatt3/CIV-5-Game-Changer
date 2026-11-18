#!/usr/bin/env python3
"""
Generate "Ascension Roguelite (v 1).modinfo" with correct MD5 checksums.
Run after changing any mod file:  python3 tools/build_modinfo.py
"""
import hashlib
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FOLDER = "Ascension Roguelite (v 1)"
MOD = os.path.join(ROOT, FOLDER)
MOD_ID = "8d1f6b2e-5c3a-4e79-9b1d-a4c27f0e6d35"
VERSION = "1"

# Database files, in load order. Optional files are isolated on purpose:
# if one fails on an unusual install, the rest of the mod is unaffected.
DB_FILES = [
    "SQL/RL_Buildings.sql",
    "SQL/RL_Promotions.sql",
    "SQL/RL_Units.sql",
    "SQL/Optional/RL_Opt_Tourism.sql",
    "SQL/Optional/RL_Opt_Spies.sql",
    "SQL/Optional/RL_Opt_Religion.sql",
    "SQL/Optional/RL_Opt_Trade.sql",
    "SQL/Optional/RL_Opt_Features.sql",
    "SQL/Optional/RL_Opt_UnitArt.sql",
]
VFS_FILES = [
    "Lua/RL_Util.lua",
    "Lua/RL_Data_Cards.lua",
    "Lua/RL_Data_World.lua",
    "Lua/RL_Data_Events.lua",
    "Lua/RL_Engine.lua",
    "UI/AscensionRoguelite.lua",
    "UI/AscensionRoguelite.xml",
]

DESCRIPTION = (
    "Turns every game of Civilization V into a roguelite run. Draft Boons from rarity-tiered cards, "
    "make FTL-style choices in 30 random events, survive escalating Horde raids, hunt eight Era Warlords "
    "with your ever-evolving Champion, chase Bounties and unlock Synergies. Earn Legacy that persists "
    "between games to buy permanent upgrades and Origins, then climb 10 Ascension difficulty levels. "
    "Requires Brave New World. Single player only."
)


def md5(path):
    h = hashlib.md5()
    with open(path, "rb") as f:
        h.update(f.read())
    return h.hexdigest().upper()


def main():
    for f in DB_FILES + VFS_FILES:
        assert os.path.exists(os.path.join(MOD, f)), "missing " + f
    files = []
    for f in DB_FILES:
        files.append('    <File md5="%s" import="0">%s</File>' % (md5(os.path.join(MOD, f)), f))
    for f in VFS_FILES:
        files.append('    <File md5="%s" import="1">%s</File>' % (md5(os.path.join(MOD, f)), f))
    actions = "\n".join("      <UpdateDatabase>%s</UpdateDatabase>" % f for f in DB_FILES)

    xml = """<?xml version="1.0" encoding="utf-8"?>
<Mod id="{id}" version="{ver}">
  <Properties>
    <Name>Ascension: Roguelite Overhaul</Name>
    <Stability>Beta</Stability>
    <Teaser>Every game becomes a roguelite run: drafts, events, Warlords, a Champion and permanent Legacy.</Teaser>
    <Description>{desc}</Description>
    <Authors>Ascension Roguelite contributors</Authors>
    <SpecialThanks>The Civ V modding community</SpecialThanks>
    <HideSetupGame>0</HideSetupGame>
    <AffectsSavedGames>1</AffectsSavedGames>
    <MinCompatibleSaveVersion>0</MinCompatibleSaveVersion>
    <SupportsSinglePlayer>1</SupportsSinglePlayer>
    <SupportsMultiplayer>0</SupportsMultiplayer>
    <SupportsHotSeat>0</SupportsHotSeat>
    <SupportsMac>1</SupportsMac>
    <ReloadAudioSystem>0</ReloadAudioSystem>
    <ReloadLandmarkSystem>0</ReloadLandmarkSystem>
    <ReloadStrategicViewSystem>0</ReloadStrategicViewSystem>
    <ReloadUnitSystem>0</ReloadUnitSystem>
  </Properties>
  <Dependencies />
  <References />
  <Blocks />
  <Files>
{files}
  </Files>
  <Actions>
    <OnModActivated>
{actions}
    </OnModActivated>
  </Actions>
  <EntryPoints>
    <EntryPoint type="InGameUIAddin" file="UI/AscensionRoguelite.xml">
      <Name>Ascension Roguelite</Name>
      <Description>Run engine and user interface for Ascension.</Description>
    </EntryPoint>
  </EntryPoints>
</Mod>
""".format(id=MOD_ID, ver=VERSION, desc=DESCRIPTION, files="\n".join(files), actions=actions)
    out = os.path.join(MOD, FOLDER + ".modinfo")
    with open(out, "w", encoding="utf-8", newline="\r\n") as f:
        f.write(xml)
    print("Wrote", out)


if __name__ == "__main__":
    main()
