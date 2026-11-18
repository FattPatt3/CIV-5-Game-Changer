#!/usr/bin/env python3
"""
Validate the mod's SQL against a mock Civ V: Brave New World schema and
export the resulting tables as Lua for the offline simulator.

The mock schema only contains the tables/columns this mod touches. Every
column name was cross-checked against the columns the BNW game core reads
(CvBuildingClasses.cpp, CvPromotionClasses.cpp, CvUnitClasses.cpp,
CvInfos.cpp). If a mod file references a column that is not in this
schema, sqlite raises an error and this script fails - i.e. a typo in a
column name is caught here instead of silently breaking the mod in-game.

Usage: python3 tools/validate_db.py [--export tools/sim/gameinfo_gen.lua]
"""
import os
import re
import sqlite3
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MOD = os.path.join(ROOT, "Ascension Roguelite (v 1)")

SCHEMA = """
CREATE TABLE Buildings (ID INTEGER PRIMARY KEY AUTOINCREMENT, Type TEXT UNIQUE NOT NULL, BuildingClass TEXT,
  Description TEXT, Help TEXT, Cost INTEGER DEFAULT 0, FaithCost INTEGER DEFAULT 0, GreatWorkCount INTEGER DEFAULT 0,
  PrereqTech TEXT, NeverCapture INTEGER DEFAULT 0, NukeImmune INTEGER DEFAULT 0, ConquestProb INTEGER DEFAULT 0,
  HurryCostModifier INTEGER DEFAULT 0, IconAtlas TEXT, PortraitIndex INTEGER DEFAULT -1,
  MilitaryProductionModifier INTEGER DEFAULT 0, Defense INTEGER DEFAULT 0, ExtraCityHitPoints INTEGER DEFAULT 0,
  NumTradeRouteBonus INTEGER DEFAULT 0, GreatPeopleRateModifier INTEGER DEFAULT 0, FoodKept INTEGER DEFAULT 0,
  Happiness INTEGER DEFAULT 0, CultureRateModifier INTEGER DEFAULT 0, GoldenAgeModifier INTEGER DEFAULT 0,
  PlotCultureCostModifier INTEGER DEFAULT 0, PlotBuyCostModifier INTEGER DEFAULT 0,
  BuildingProductionModifier INTEGER DEFAULT 0, WonderProductionModifier INTEGER DEFAULT 0,
  GreatWorksTourismModifier INTEGER DEFAULT 0, ExtraSpies INTEGER DEFAULT 0, ReligiousPressureModifier INTEGER DEFAULT 0,
  TradeRouteRecipientBonus INTEGER DEFAULT 0, TradeRouteTargetBonus INTEGER DEFAULT 0);
CREATE TABLE BuildingClasses (ID INTEGER PRIMARY KEY AUTOINCREMENT, Type TEXT UNIQUE NOT NULL, DefaultBuilding TEXT,
  Description TEXT, MaxGlobalInstances INTEGER DEFAULT -1);
CREATE TABLE Building_YieldChanges (BuildingType TEXT, YieldType TEXT, Yield INTEGER);
CREATE TABLE Building_YieldModifiers (BuildingType TEXT, YieldType TEXT, Yield INTEGER);
CREATE TABLE Building_DomainFreeExperiences (BuildingType TEXT, DomainType TEXT, Experience INTEGER);
CREATE TABLE Building_DomainProductionModifiers (BuildingType TEXT, DomainType TEXT, Modifier INTEGER);
CREATE TABLE Building_SeaPlotYieldChanges (BuildingType TEXT, YieldType TEXT, Yield INTEGER);
CREATE TABLE Building_FeatureYieldChanges (BuildingType TEXT, FeatureType TEXT, YieldType TEXT, Yield INTEGER);
CREATE TABLE UnitPromotions (ID INTEGER PRIMARY KEY AUTOINCREMENT, Type TEXT UNIQUE NOT NULL, Description TEXT, Help TEXT,
  Sound TEXT, CannotBeChosen INTEGER DEFAULT 0, PortraitIndex INTEGER, IconAtlas TEXT, PediaType TEXT, PediaEntry TEXT,
  CombatPercent INTEGER DEFAULT 0, CityAttack INTEGER DEFAULT 0, MovesChange INTEGER DEFAULT 0,
  VisibilityChange INTEGER DEFAULT 0, AlwaysHeal INTEGER DEFAULT 0, RangeChange INTEGER DEFAULT 0,
  ExperiencePercent INTEGER DEFAULT 0);
CREATE TABLE UnitClasses (ID INTEGER PRIMARY KEY AUTOINCREMENT, Type TEXT UNIQUE NOT NULL, Description TEXT, DefaultUnit TEXT);
CREATE TABLE Units (ID INTEGER PRIMARY KEY AUTOINCREMENT, Type TEXT UNIQUE NOT NULL, Class TEXT, PrereqTech TEXT,
  ObsoleteTech TEXT, Cost INTEGER DEFAULT 0, FaithCost INTEGER DEFAULT 0, Combat INTEGER DEFAULT 0,
  RangedCombat INTEGER DEFAULT 0, Moves INTEGER DEFAULT 0, CombatClass TEXT, Domain TEXT, DefaultUnitAI TEXT,
  Description TEXT, Civilopedia TEXT, Strategy TEXT, Help TEXT, MilitarySupport INTEGER DEFAULT 0,
  MilitaryProduction INTEGER DEFAULT 0, Pillage INTEGER DEFAULT 0, NoMaintenance INTEGER DEFAULT 0,
  MoveRate TEXT, UnitArtInfo TEXT, UnitFlagIconOffset INTEGER DEFAULT 0, IconAtlas TEXT, PortraitIndex INTEGER DEFAULT 0,
  UnitFlagAtlas TEXT, XPValueAttack INTEGER DEFAULT 0, XPValueDefense INTEGER DEFAULT 0);
CREATE TABLE UnitGameplay2DScripts (UnitType TEXT, SelectionSound TEXT, FirstSelectionSound TEXT);
CREATE TABLE Unit_AITypes (UnitType TEXT, UnitAIType TEXT);
CREATE TABLE Unit_Flavors (UnitType TEXT, FlavorType TEXT, Flavor INTEGER);
CREATE TABLE Unit_FreePromotions (UnitType TEXT, PromotionType TEXT);
CREATE TABLE Language_en_US (Tag TEXT PRIMARY KEY, Text TEXT);
"""

# Vanilla BNW units referenced by the mod: (Type, Class, PrereqTech, Combat, Ranged, Moves, Domain)
VANILLA_UNITS = [
    ("UNIT_WARRIOR", "UNITCLASS_WARRIOR", None, 8, 0, 2),
    ("UNIT_SPEARMAN", "UNITCLASS_SPEARMAN", "TECH_BRONZE_WORKING", 11, 0, 2),
    ("UNIT_ARCHER", "UNITCLASS_ARCHER", "TECH_ARCHERY", 5, 7, 2),
    ("UNIT_CHARIOT_ARCHER", "UNITCLASS_CHARIOT_ARCHER", "TECH_THE_WHEEL", 6, 10, 4),
    ("UNIT_SWORDSMAN", "UNITCLASS_SWORDSMAN", "TECH_IRON_WORKING", 14, 0, 2),
    ("UNIT_COMPOSITE_BOWMAN", "UNITCLASS_COMPOSITE_BOWMAN", "TECH_CONSTRUCTION", 7, 11, 2),
    ("UNIT_HORSEMAN", "UNITCLASS_HORSEMAN", "TECH_HORSEBACK_RIDING", 12, 0, 4),
    ("UNIT_CATAPULT", "UNITCLASS_CATAPULT", "TECH_MATHEMATICS", 7, 14, 2),
    ("UNIT_LONGSWORDSMAN", "UNITCLASS_LONGSWORDSMAN", "TECH_STEEL", 21, 0, 2),
    ("UNIT_PIKEMAN", "UNITCLASS_PIKEMAN", "TECH_CIVIL_SERVICE", 16, 0, 2),
    ("UNIT_CROSSBOWMAN", "UNITCLASS_CROSSBOWMAN", "TECH_MACHINERY", 13, 18, 2),
    ("UNIT_KNIGHT", "UNITCLASS_KNIGHT", "TECH_CHIVALRY", 20, 0, 4),
    ("UNIT_TREBUCHET", "UNITCLASS_TREBUCHET", "TECH_PHYSICS", 12, 20, 2),
    ("UNIT_MUSKETMAN", "UNITCLASS_MUSKETMAN", "TECH_GUNPOWDER", 24, 0, 2),
    ("UNIT_LANCER", "UNITCLASS_LANCER", "TECH_METALLURGY", 25, 0, 4),
    ("UNIT_CANNON", "UNITCLASS_CANNON", "TECH_CHEMISTRY", 14, 26, 2),
    ("UNIT_RIFLEMAN", "UNITCLASS_RIFLEMAN", "TECH_RIFLING", 34, 0, 2),
    ("UNIT_CAVALRY", "UNITCLASS_CAVALRY", "TECH_MILITARY_SCIENCE", 34, 0, 4),
    ("UNIT_ARTILLERY", "UNITCLASS_ARTILLERY", "TECH_DYNAMITE", 21, 32, 2),
    ("UNIT_GATLINGGUN", "UNITCLASS_GATLINGGUN", "TECH_INDUSTRIALIZATION", 30, 30, 2),
    ("UNIT_GREAT_WAR_INFANTRY", "UNITCLASS_GREAT_WAR_INFANTRY", "TECH_REPLACEABLE_PARTS", 50, 0, 2),
    ("UNIT_MACHINE_GUN", "UNITCLASS_MACHINE_GUN", "TECH_BALLISTICS", 60, 60, 2),
    ("UNIT_LANDSHIP", "UNITCLASS_WWI_TANK", "TECH_COMBUSTION", 60, 0, 4),
    ("UNIT_INFANTRY", "UNITCLASS_INFANTRY", "TECH_PLASTIC", 70, 0, 2),
    ("UNIT_TANK", "UNITCLASS_TANK", "TECH_COMBINED_ARMS", 70, 0, 5),
    ("UNIT_ROCKET_ARTILLERY", "UNITCLASS_ROCKET_ARTILLERY", "TECH_ROCKETRY", 45, 60, 3),
    ("UNIT_MECHANIZED_INFANTRY", "UNITCLASS_MECHANIZED_INFANTRY", "TECH_MOBILE_TACTICS", 90, 0, 3),
    ("UNIT_MODERN_ARMOR", "UNITCLASS_MODERN_ARMOR", "TECH_LASERS", 100, 0, 5),
    ("UNIT_WORKER", "UNITCLASS_WORKER", None, 0, 0, 2),
    ("UNIT_SETTLER", "UNITCLASS_SETTLER", None, 0, 0, 2),
    ("UNIT_SCOUT", "UNITCLASS_SCOUT", None, 4, 0, 2),
    ("UNIT_SCIENTIST", "UNITCLASS_SCIENTIST", None, 0, 0, 2),
    ("UNIT_ENGINEER", "UNITCLASS_ENGINEER", None, 0, 0, 2),
    ("UNIT_MERCHANT", "UNITCLASS_MERCHANT", None, 0, 0, 2),
    ("UNIT_TRIREME", "UNITCLASS_TRIREME", "TECH_SAILING", 10, 0, 4),
]


def mod_sql_files():
    """SQL files in the order the .modinfo applies them."""
    order = ["SQL/RL_Buildings.sql", "SQL/RL_Promotions.sql", "SQL/RL_Units.sql"]
    opt = sorted(f for f in os.listdir(os.path.join(MOD, "SQL", "Optional")) if f.endswith(".sql"))
    return order + ["SQL/Optional/" + f for f in opt]


def build_db():
    db = sqlite3.connect(":memory:")
    db.executescript(SCHEMA)
    for t, cls, tech, combat, ranged, moves in VANILLA_UNITS:
        domain = "DOMAIN_SEA" if t == "UNIT_TRIREME" else "DOMAIN_LAND"
        db.execute(
            "INSERT INTO Units (Type, Class, PrereqTech, Combat, RangedCombat, Moves, CombatClass, Domain, DefaultUnitAI,"
            " Description, Cost, MoveRate, UnitArtInfo, UnitFlagIconOffset, IconAtlas, PortraitIndex, UnitFlagAtlas)"
            " VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
            (t, cls, tech, combat, ranged, moves, "UNITCOMBAT_MELEE", domain, "UNITAI_ATTACK",
             "TXT_KEY_" + t, 100, "BIPED", "ART_DEF_" + t, 1, "UNIT_ATLAS_1", 1, "UNIT_FLAG_ATLAS"))
        db.execute("INSERT INTO UnitClasses (Type, Description, DefaultUnit) VALUES (?,?,?)", (cls, "TXT_KEY_" + cls, t))
        db.execute("INSERT INTO UnitGameplay2DScripts VALUES (?,?,?)", (t, "AS2D_SELECT", "AS2D_FIRST"))
    # A couple of vanilla wonders so quest code has something to count
    db.execute("INSERT INTO BuildingClasses (Type, DefaultBuilding, MaxGlobalInstances) VALUES ('BUILDINGCLASS_PYRAMID','BUILDING_PYRAMID',1)")
    db.execute("INSERT INTO Buildings (Type, BuildingClass, Cost) VALUES ('BUILDING_PYRAMID','BUILDINGCLASS_PYRAMID',185)")
    return db


def run_sql(db, rel):
    path = os.path.join(MOD, rel)
    sql = open(path, encoding="utf-8").read()
    # Civ V's SQLite predates multi-row VALUES; flag it
    if re.search(r"VALUES\s*\([^;]*\)\s*,\s*\(", sql):
        raise RuntimeError(rel + ": multi-row VALUES is not supported by Civ V's SQLite")
    db.executescript(sql)


def lua_val(v):
    if v is None:
        return "nil"
    if isinstance(v, (int, float)):
        return repr(v)
    return '"' + str(v).replace("\\", "\\\\").replace('"', '\\"') + '"'


def export(db, out):
    tables = ["Buildings", "BuildingClasses", "Building_YieldChanges", "Building_YieldModifiers",
              "Building_FeatureYieldChanges", "UnitPromotions", "UnitClasses", "Units", "Unit_FreePromotions"]
    lines = ["-- generated by tools/validate_db.py - do not edit", "GEN = {}"]
    for t in tables:
        cur = db.execute("SELECT * FROM " + t)
        cols = [c[0] for c in cur.description]
        lines.append("GEN.%s = {" % t)
        for row in cur.fetchall():
            fields = ", ".join("%s = %s" % (c, lua_val(v)) for c, v in zip(cols, row) if v is not None)
            lines.append("  { %s }," % fields)
        lines.append("}")
    with open(out, "w") as f:
        f.write("\n".join(lines) + "\n")


def main():
    db = build_db()
    ok = True
    for rel in mod_sql_files():
        try:
            run_sql(db, rel)
            print("OK    ", rel)
        except Exception as e:  # noqa
            ok = False
            print("FAIL  ", rel, "->", e)
    if not ok:
        sys.exit(1)

    # Integrity checks
    n_dummy = db.execute("SELECT COUNT(*) FROM Buildings WHERE Type LIKE 'BUILDING_RL_%'").fetchone()[0]
    n_cls = db.execute("SELECT COUNT(*) FROM BuildingClasses WHERE Type LIKE 'BUILDINGCLASS_RL_%'").fetchone()[0]
    assert n_dummy == n_cls, "building/class mismatch"
    missing_text = db.execute(
        "SELECT Description FROM Buildings WHERE Type LIKE 'BUILDING_RL_%' AND Description NOT IN (SELECT Tag FROM Language_en_US)").fetchall()
    missing_text += db.execute(
        "SELECT Help FROM Buildings WHERE Type LIKE 'BUILDING_RL_%' AND Help NOT IN (SELECT Tag FROM Language_en_US)").fetchall()
    missing_text += db.execute(
        "SELECT Description FROM UnitPromotions WHERE Type LIKE 'PROMOTION_RL_%' AND Description NOT IN (SELECT Tag FROM Language_en_US)").fetchall()
    missing_text += db.execute(
        "SELECT Help FROM UnitPromotions WHERE Type LIKE 'PROMOTION_RL_%' AND Help NOT IN (SELECT Tag FROM Language_en_US)").fetchall()
    assert not missing_text, "missing text keys: %s" % missing_text
    champs = db.execute("SELECT Type, Combat FROM Units WHERE Class='UNITCLASS_RL_CHAMPION' ORDER BY Type").fetchall()
    assert len(champs) == 5, champs
    for t, _ in champs:
        assert db.execute("SELECT COUNT(*) FROM UnitGameplay2DScripts WHERE UnitType=?", (t,)).fetchone()[0] == 1, t
    print("Dummy buildings: %d, promotions: %d, champion tiers: %s" % (
        n_dummy, db.execute("SELECT COUNT(*) FROM UnitPromotions").fetchone()[0], champs))

    # Cross-check Lua references
    lua_src = ""
    for d in ("Lua", "UI"):
        for f in os.listdir(os.path.join(MOD, d)):
            if f.endswith(".lua"):
                lua_src += open(os.path.join(MOD, d, f), encoding="utf-8").read()
    for kind, table in (("BUILDING_RL_", "Buildings"), ("PROMOTION_RL_", "UnitPromotions"), ("UNIT_RL_", "Units")):
        refs = set(re.findall(r'"(%s[A-Z0-9_]+)"' % kind, lua_src))
        refs = {r for r in refs if not r.endswith("_")}
        known = {r[0] for r in db.execute("SELECT Type FROM " + table)}
        bad = refs - known
        assert not bad, "Lua references unknown %s: %s" % (table, bad)
        print("Lua -> %-15s %d references, all defined" % (table, len(refs)))

    if "--export" in sys.argv:
        out = sys.argv[sys.argv.index("--export") + 1]
        export(db, out)
        print("Exported", out)
    print("DATABASE VALIDATION PASSED")


if __name__ == "__main__":
    main()
