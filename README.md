# Ascension: Roguelite Overhaul for Civilization V

**Ascension** turns every game of *Sid Meier's Civilization V* into a **roguelite run**. You draft boons from rarity-tiered cards and make tough choices in random events. Escalating Horde raids hit your borders, and eight Era Warlords come for your cities while your Champion grows with each era. You earn **Legacy** that carries over between games. You spend it on permanent upgrades and new Origins, then work your way up 10 **Ascension** difficulty levels.

> Requires **Brave New World** (the current Steam version, 1.0.3.279, with both expansions). Single player only.

---

## Features

| System | What it does |
|---|---|
| **Boon drafts** | Choose 1 of 3 cards (Common / Rare / Epic / Legendary) when you enter a new era, every 30 turns, after slaying Warlords, and as Bounty rewards. Many boons stack. You can reroll, or skip a draft for gold and a reroll. |
| **73 Boons** | Covers war, commerce, knowledge, growth, culture, faith, industry, seafaring, fate and your Champion. Effects include yields, promotions, gold for each kill, interest on your treasury, free techs, extra lives and more. |
| **Pacts** | Any draft card can roll as a *Pact*. Taking it gives a bonus Rare boon **and** a Curse. |
| **12 Curses** | Famine, Corruption, Dark Ages, Haunted, Bloodlust of the Horde and others. You get them from pacts, risky event choices and high Ascension. You can cleanse them. |
| **30 choice events** | FTL-style dilemmas such as the Wandering Merchant, the Stranger in Black, the Cursed Idol, a Grand Tournament for your Champion and the Lost Caravan. Outcomes are rolled when the event appears, so reloading a save won't change them. |
| **The Horde** | Barbarian raids every ~22 turns, announced 3 turns ahead with their target city. Raids grow with your era, your empire's size and the number of raids so far. |
| **8 Era Warlords** | Named boss units with Warlord promotions and escorts, one for each era. Slaying one earns gold, Legacy and an Epic-or-better draft. Slaying **General Null** (Atomic Era) **wins the run**. After that, Endless mode continues. |
| **The Champion** | A named hero who grows into a stronger form every era (5 tiers) and keeps all XP and promotions. If it falls, it returns after a few turns, unless you're playing at Ascension 5+. |
| **Bounties** | Timed objectives (slay N units, grow population, build a Wonder, research techs, and more). Each one rewards a Rare draft and Legacy. |
| **Synergies** | Own enough boons of one theme to unlock a set bonus. |
| **Rival boons** | AI empires draft boons too, and you can see which ones in the run overview. |
| **Legacy (meta-progression)** | Saved in your Civ V profile across **all** games. Spend it on 12 permanent upgrades and on unlocking Origins. Legacy can't be earned twice by reloading. |
| **9 Origins** | Starting kits that work like a starting relic: Warborn, Merchant Prince, Sage, Prophet, Builder, Heartland, Seafarer, Heroic Lineage and The Cursed One. |
| **10 Ascension levels** | Cumulative difficulty modifiers in the style of Slay the Spire. Each level adds +10% Legacy. |
| **Permadeath** | Losing your original capital ends the run, unless you have an extra life. |

See **[docs/CONTENT.md](docs/CONTENT.md)** for the full catalog of every card, event, Warlord, origin and upgrade.

---

## Installation (Windows, Steam)

1. Copy the folder **`Ascension Roguelite (v 1)`** (the whole folder, not just its contents) into:
   ```
   Documents\My Games\Sid Meier's Civilization 5\MODS\
   ```
   (Create `MODS` if it doesn't exist.)
2. Start Civilization V and choose **Mods** from the main menu. Accept the EULA if asked.
3. Tick **Ascension: Roguelite Overhaul**, click **Next**, then set up your game under **Single Player**.

To update the mod, replace the folder. To uninstall, delete it. Your Legacy is kept in the game's mod user-data cache, so it survives updates.

## How to play

1. **On turn 0 the Ascension screen opens.** Pick an Ascension level and an Origin, buy Legacy upgrades if you have Legacy to spend, then click **Begin the Run**. Your Champion appears next to your settler.
2. **The ASCENSION button** at the top centre of the screen shows your Ascension level, Warlords slain, banked Legacy and how many choices are waiting. Hover over it for the next raid, the current Warlord and your Bounty. Click it to open the run overview, which lists your boons, curses, synergies, rivals' boons and the run log.
3. Drafts, events and Warlord announcements open automatically at the start of your turn. Choose **Decide Later** to leave one for later, or turn auto-open off in the overview.
4. **To win the run**, slay the Atomic-era Warlord or win the game normally. Winning (or slaying 5 Warlords in one run) unlocks the next Ascension level.
5. **You lose the run** if your original capital falls. At Ascension 5+, you also lose if your Champion dies. After a loss you can keep playing, but the roguelite systems pause.

### Tips
- Raids target frontier cities most often, so garrison them and keep an eye on the "raid incoming" notification.
- Your Champion levels up quickly and heals every turn. Use it to break up raids and finish off Warlords.
- Pacts are strongest early, when you have time to deal with the curse they bring.
- Legacy upgrades like *Fortune's Favor* (rerolls) and *Keen Eye* (luck) make every future draft better.

---

## How it works (for modders)

```
Ascension Roguelite (v 1)/
  Ascension Roguelite (v 1).modinfo   generated by tools/build_modinfo.py (MD5s)
  SQL/RL_Buildings.sql                52 hidden "dummy" buildings: every boon/curse/timed yield effect
  SQL/RL_Promotions.sql               15 promotions (boons, Champion, Horde, Warlords)
  SQL/RL_Units.sql                    the 5 Champion tiers (copied from vanilla units)
  SQL/Optional/*.sql                  less-certain columns, isolated so a failure can't break the core
  Lua/RL_Util.lua                     serializer, seeded RNG, text helpers
  Lua/RL_Data_Cards.lua               boons, curses, synergies (data + effect hooks)
  Lua/RL_Data_World.lua               era units, Warlords, bounties, ascension, legacy, origins
  Lua/RL_Data_Events.lua              the 30 events
  Lua/RL_Engine.lua                   state, persistence, all gameplay systems
  UI/AscensionRoguelite.xml/.lua      InGameUIAddin: every panel + game-event wiring
```

- **Effects** are applied through stackable dummy buildings (`City:SetNumRealBuilding`), promotions, and Lua hooks on `PlayerDoTurn`, `UnitKilledInCombat`, `PlayerCityFounded`, `CityCaptureComplete` and `CityTrained`. Every hook runs inside `pcall`, so one failing effect can't break turn processing.
- **Run state** is serialized into the savegame with `Modding.OpenSaveData`. **Meta-progression** is stored in `Modding.OpenUserData("AscensionRoguelite", 1)`.
- **Adding content** only takes data. Append a `Card{...}` to `RL_Data_Cards.lua` or an `Event{...}` to `RL_Data_Events.lua`. If a new boon changes yields, add a dummy building in `RL_Buildings.sql`.
- Boons that depend on optional columns check their own data with `requires`, so they're never offered if their effect didn't load.

### Testing

The mod can't be launched in-game from this repository, so it's verified in three layers:

```bash
./tools/run_tests.sh     # needs lua5.1, python3, xmllint
```

1. **Static checks.** Lua 5.1 syntax (the version Civ V uses) and XML well-formedness.
2. **Database validation** (`tools/validate_db.py`). Runs every SQL file against a mock BNW schema, using column names checked against the game core's C++ source, then checks text keys and cross-references every building, promotion and unit the Lua uses.
3. **Offline simulation** (`tools/sim/`). A mock of the Civ V Lua API loads the real mod files and plays 40 complete runs: standard, Ascension 10, Ascension 5 with an extra life, both save-data binding styles, Quick and Marathon speed, and capital-loss defeats. The runs click the real UI callbacks and fire game events, and they round-trip the save every turn. Any Lua error fails the suite.

The Lua API calls, GameEvent argument orders, DB columns, UI styles and markup tags were checked against the Civ V game-core source and the stock UI files in the [Community Patch DLL](https://github.com/LoneGazebo/Community-Patch-DLL) repository. **In-game balance and visual layout still need real playtesting.** Please report anything that looks off.

After editing any mod file, regenerate the modinfo checksums and the content catalog:

```bash
python3 tools/build_modinfo.py
lua5.1 tools/gen_docs.lua > docs/CONTENT.md
```

## Troubleshooting

- **No Ascension button or screen.** Make sure you started the game from the **Mods** menu, not the normal Single Player menu, and that Brave New World is enabled.
- **Errors.** Set `LoggingEnabled = 1` in `Documents\My Games\Sid Meier's Civilization 5\config.ini`, then look for lines starting with `[Ascension]` in `Logs\Lua.log`. Database problems show up in `Logs\Database.log`.
- **Other mods.** Ascension adds content without overriding any vanilla file, and its UI lives in its own addin context, so it should work alongside most mods, including UI replacements like EUI. That hasn't been tested in-game, though, and gameplay mods that rework barbarians or eras may interact unpredictably.
