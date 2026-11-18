-- =====================================================================
-- ASCENSION: ROGUELITE OVERHAUL  --  Dummy buildings
-- Every Boon, Curse, Ascension mutator and timed effect that changes
-- city yields is a hidden, unbuildable "dummy" building that the Lua
-- engine places (and stacks) in cities. Effects multiply with the
-- building count, which is how boon stacks work.
-- Only columns/tables that exist in vanilla Brave New World are used
-- here. Anything less certain lives in RL_Optional.sql so a failure
-- there can never take this file down with it.
-- =====================================================================

CREATE TABLE IF NOT EXISTS RL_Dummy (Type TEXT NOT NULL);

-- ---------------- Boons ----------------
INSERT INTO RL_Dummy (Type) VALUES ('BUILDING_RL_WARCAMPS');
INSERT INTO RL_Dummy (Type) VALUES ('BUILDING_RL_ARSENAL');
INSERT INTO RL_Dummy (Type) VALUES ('BUILDING_RL_ADMIRALTY');
INSERT INTO RL_Dummy (Type) VALUES ('BUILDING_RL_FORTRESS');
INSERT INTO RL_Dummy (Type) VALUES ('BUILDING_RL_MERCHANT_GUILDS');
INSERT INTO RL_Dummy (Type) VALUES ('BUILDING_RL_TAX_COLLECTORS');
INSERT INTO RL_Dummy (Type) VALUES ('BUILDING_RL_TRADE_WINDS');
INSERT INTO RL_Dummy (Type) VALUES ('BUILDING_RL_SILK_ROADS');
INSERT INTO RL_Dummy (Type) VALUES ('BUILDING_RL_LIBRARIES');
INSERT INTO RL_Dummy (Type) VALUES ('BUILDING_RL_BRAINSTORM');
INSERT INTO RL_Dummy (Type) VALUES ('BUILDING_RL_GREAT_MINDS');
INSERT INTO RL_Dummy (Type) VALUES ('BUILDING_RL_FERTILE');
INSERT INTO RL_Dummy (Type) VALUES ('BUILDING_RL_GRANARIES');
INSERT INTO RL_Dummy (Type) VALUES ('BUILDING_RL_SEAS');
INSERT INTO RL_Dummy (Type) VALUES ('BUILDING_RL_FOREST');
INSERT INTO RL_Dummy (Type) VALUES ('BUILDING_RL_HARVEST');
INSERT INTO RL_Dummy (Type) VALUES ('BUILDING_RL_ABUNDANCE');
INSERT INTO RL_Dummy (Type) VALUES ('BUILDING_RL_BARDS');
INSERT INTO RL_Dummy (Type) VALUES ('BUILDING_RL_RENAISSANCE');
INSERT INTO RL_Dummy (Type) VALUES ('BUILDING_RL_GOLDEN_PROPHECY');
INSERT INTO RL_Dummy (Type) VALUES ('BUILDING_RL_MUSEUM');
INSERT INTO RL_Dummy (Type) VALUES ('BUILDING_RL_BORDERS');
INSERT INTO RL_Dummy (Type) VALUES ('BUILDING_RL_SHRINES');
INSERT INTO RL_Dummy (Type) VALUES ('BUILDING_RL_ZEALOTS');
INSERT INTO RL_Dummy (Type) VALUES ('BUILDING_RL_TITHES');
INSERT INTO RL_Dummy (Type) VALUES ('BUILDING_RL_CIRCUSES');
INSERT INTO RL_Dummy (Type) VALUES ('BUILDING_RL_LOCAL_PRIDE');
INSERT INTO RL_Dummy (Type) VALUES ('BUILDING_RL_MASONS');
INSERT INTO RL_Dummy (Type) VALUES ('BUILDING_RL_ARCHITECTS');
INSERT INTO RL_Dummy (Type) VALUES ('BUILDING_RL_WONDERS');
INSERT INTO RL_Dummy (Type) VALUES ('BUILDING_RL_INDUSTRY');
INSERT INTO RL_Dummy (Type) VALUES ('BUILDING_RL_SPYMASTER');
INSERT INTO RL_Dummy (Type) VALUES ('BUILDING_RL_BULWARK');
INSERT INTO RL_Dummy (Type) VALUES ('BUILDING_RL_HEARTLAND');
INSERT INTO RL_Dummy (Type) VALUES ('BUILDING_RL_IMPERIAL_SEAT');
-- ---------------- Curses ----------------
INSERT INTO RL_Dummy (Type) VALUES ('BUILDING_RL_CURSE_FAMINE');
INSERT INTO RL_Dummy (Type) VALUES ('BUILDING_RL_CURSE_CORRUPTION');
INSERT INTO RL_Dummy (Type) VALUES ('BUILDING_RL_CURSE_UNREST');
INSERT INTO RL_Dummy (Type) VALUES ('BUILDING_RL_CURSE_DECAY');
INSERT INTO RL_Dummy (Type) VALUES ('BUILDING_RL_CURSE_DARK_AGES');
INSERT INTO RL_Dummy (Type) VALUES ('BUILDING_RL_CURSE_WEARY');
INSERT INTO RL_Dummy (Type) VALUES ('BUILDING_RL_CURSE_CURSED_GOLD');
INSERT INTO RL_Dummy (Type) VALUES ('BUILDING_RL_CURSE_HERESY');
-- ---------------- Timed effects (events) ----------------
INSERT INTO RL_Dummy (Type) VALUES ('BUILDING_RL_TEMP_HAPPY');
INSERT INTO RL_Dummy (Type) VALUES ('BUILDING_RL_TEMP_PRODUCTION');
INSERT INTO RL_Dummy (Type) VALUES ('BUILDING_RL_TEMP_GROWTH');
INSERT INTO RL_Dummy (Type) VALUES ('BUILDING_RL_TEMP_SCIENCE');
INSERT INTO RL_Dummy (Type) VALUES ('BUILDING_RL_TEMP_GOLD');
INSERT INTO RL_Dummy (Type) VALUES ('BUILDING_RL_TEMP_DEFENSE');
INSERT INTO RL_Dummy (Type) VALUES ('BUILDING_RL_TEMP_CULTURE');
INSERT INTO RL_Dummy (Type) VALUES ('BUILDING_RL_TEMP_PLAGUE');
-- ---------------- Ascension mutators ----------------
INSERT INTO RL_Dummy (Type) VALUES ('BUILDING_RL_ASC_LEAN');

INSERT INTO BuildingClasses (Type, DefaultBuilding, Description)
SELECT 'BUILDINGCLASS_' || substr(Type, 10), Type, 'TXT_KEY_' || Type FROM RL_Dummy;

INSERT INTO Buildings (Type, BuildingClass, Description, Help, Cost, FaithCost, GreatWorkCount,
                       PrereqTech, NeverCapture, NukeImmune, ConquestProb, HurryCostModifier,
                       IconAtlas, PortraitIndex)
SELECT Type, 'BUILDINGCLASS_' || substr(Type, 10), 'TXT_KEY_' || Type, 'TXT_KEY_' || Type || '_HELP',
       -1, -1, -1, NULL, 1, 1, 0, -1, 'BW_ATLAS_1', 19
FROM RL_Dummy;

DROP TABLE RL_Dummy;

-- ---------------------------------------------------------------------
-- Effects (core columns)
-- ---------------------------------------------------------------------
UPDATE Buildings SET MilitaryProductionModifier = 15            WHERE Type = 'BUILDING_RL_ARSENAL';
UPDATE Buildings SET Defense = 500, ExtraCityHitPoints = 50     WHERE Type = 'BUILDING_RL_FORTRESS';
UPDATE Buildings SET NumTradeRouteBonus = 1                     WHERE Type = 'BUILDING_RL_TRADE_WINDS';
UPDATE Buildings SET GreatPeopleRateModifier = 15               WHERE Type = 'BUILDING_RL_GREAT_MINDS';
UPDATE Buildings SET FoodKept = 20                              WHERE Type = 'BUILDING_RL_GRANARIES';
UPDATE Buildings SET Happiness = 1                              WHERE Type = 'BUILDING_RL_ABUNDANCE';
UPDATE Buildings SET CultureRateModifier = 15                   WHERE Type = 'BUILDING_RL_RENAISSANCE';
UPDATE Buildings SET GoldenAgeModifier = 25                     WHERE Type = 'BUILDING_RL_GOLDEN_PROPHECY';
UPDATE Buildings SET PlotCultureCostModifier = -33, PlotBuyCostModifier = -33 WHERE Type = 'BUILDING_RL_BORDERS';
UPDATE Buildings SET Happiness = 2                              WHERE Type = 'BUILDING_RL_CIRCUSES';
UPDATE Buildings SET Happiness = 1                              WHERE Type = 'BUILDING_RL_LOCAL_PRIDE';
UPDATE Buildings SET BuildingProductionModifier = 15            WHERE Type = 'BUILDING_RL_ARCHITECTS';
UPDATE Buildings SET WonderProductionModifier = 25              WHERE Type = 'BUILDING_RL_WONDERS';
UPDATE Buildings SET Defense = 800, ExtraCityHitPoints = 100    WHERE Type = 'BUILDING_RL_BULWARK';
UPDATE Buildings SET Happiness = 1                              WHERE Type = 'BUILDING_RL_HEARTLAND';
UPDATE Buildings SET Happiness = 2                              WHERE Type = 'BUILDING_RL_IMPERIAL_SEAT';
UPDATE Buildings SET CultureRateModifier = -15                  WHERE Type = 'BUILDING_RL_CURSE_WEARY';
UPDATE Buildings SET Happiness = -2                             WHERE Type = 'BUILDING_RL_CURSE_UNREST';
UPDATE Buildings SET Happiness = 1                              WHERE Type = 'BUILDING_RL_TEMP_HAPPY';
UPDATE Buildings SET Defense = 1000                             WHERE Type = 'BUILDING_RL_TEMP_DEFENSE';
UPDATE Buildings SET CultureRateModifier = 25                   WHERE Type = 'BUILDING_RL_TEMP_CULTURE';
UPDATE Buildings SET Happiness = -1                             WHERE Type = 'BUILDING_RL_TEMP_PLAGUE';

-- Flat yields per city (multiplied by stack count)
INSERT INTO Building_YieldChanges (BuildingType, YieldType, Yield) VALUES ('BUILDING_RL_MERCHANT_GUILDS', 'YIELD_GOLD', 2);
INSERT INTO Building_YieldChanges (BuildingType, YieldType, Yield) VALUES ('BUILDING_RL_LIBRARIES', 'YIELD_SCIENCE', 2);
INSERT INTO Building_YieldChanges (BuildingType, YieldType, Yield) VALUES ('BUILDING_RL_FERTILE', 'YIELD_FOOD', 2);
INSERT INTO Building_YieldChanges (BuildingType, YieldType, Yield) VALUES ('BUILDING_RL_ABUNDANCE', 'YIELD_FOOD', 1);
INSERT INTO Building_YieldChanges (BuildingType, YieldType, Yield) VALUES ('BUILDING_RL_BARDS', 'YIELD_CULTURE', 2);
INSERT INTO Building_YieldChanges (BuildingType, YieldType, Yield) VALUES ('BUILDING_RL_MUSEUM', 'YIELD_CULTURE', 1);
INSERT INTO Building_YieldChanges (BuildingType, YieldType, Yield) VALUES ('BUILDING_RL_SHRINES', 'YIELD_FAITH', 2);
INSERT INTO Building_YieldChanges (BuildingType, YieldType, Yield) VALUES ('BUILDING_RL_TITHES', 'YIELD_FAITH', 1);
INSERT INTO Building_YieldChanges (BuildingType, YieldType, Yield) VALUES ('BUILDING_RL_TITHES', 'YIELD_GOLD', 1);
INSERT INTO Building_YieldChanges (BuildingType, YieldType, Yield) VALUES ('BUILDING_RL_MASONS', 'YIELD_PRODUCTION', 2);
INSERT INTO Building_YieldChanges (BuildingType, YieldType, Yield) VALUES ('BUILDING_RL_HEARTLAND', 'YIELD_FOOD', 1);
INSERT INTO Building_YieldChanges (BuildingType, YieldType, Yield) VALUES ('BUILDING_RL_HEARTLAND', 'YIELD_PRODUCTION', 1);
INSERT INTO Building_YieldChanges (BuildingType, YieldType, Yield) VALUES ('BUILDING_RL_IMPERIAL_SEAT', 'YIELD_PRODUCTION', 3);
INSERT INTO Building_YieldChanges (BuildingType, YieldType, Yield) VALUES ('BUILDING_RL_IMPERIAL_SEAT', 'YIELD_SCIENCE', 3);
INSERT INTO Building_YieldChanges (BuildingType, YieldType, Yield) VALUES ('BUILDING_RL_IMPERIAL_SEAT', 'YIELD_GOLD', 3);
INSERT INTO Building_YieldChanges (BuildingType, YieldType, Yield) VALUES ('BUILDING_RL_IMPERIAL_SEAT', 'YIELD_CULTURE', 2);
INSERT INTO Building_YieldChanges (BuildingType, YieldType, Yield) VALUES ('BUILDING_RL_CURSE_FAMINE', 'YIELD_FOOD', -1);
INSERT INTO Building_YieldChanges (BuildingType, YieldType, Yield) VALUES ('BUILDING_RL_CURSE_CURSED_GOLD', 'YIELD_GOLD', -2);
INSERT INTO Building_YieldChanges (BuildingType, YieldType, Yield) VALUES ('BUILDING_RL_CURSE_HERESY', 'YIELD_FAITH', -1);

-- Percentage yields per city
INSERT INTO Building_YieldModifiers (BuildingType, YieldType, Yield) VALUES ('BUILDING_RL_TAX_COLLECTORS', 'YIELD_GOLD', 10);
INSERT INTO Building_YieldModifiers (BuildingType, YieldType, Yield) VALUES ('BUILDING_RL_BRAINSTORM', 'YIELD_SCIENCE', 10);
INSERT INTO Building_YieldModifiers (BuildingType, YieldType, Yield) VALUES ('BUILDING_RL_HARVEST', 'YIELD_FOOD', 10);
INSERT INTO Building_YieldModifiers (BuildingType, YieldType, Yield) VALUES ('BUILDING_RL_INDUSTRY', 'YIELD_PRODUCTION', 10);
INSERT INTO Building_YieldModifiers (BuildingType, YieldType, Yield) VALUES ('BUILDING_RL_CURSE_CORRUPTION', 'YIELD_GOLD', -10);
INSERT INTO Building_YieldModifiers (BuildingType, YieldType, Yield) VALUES ('BUILDING_RL_CURSE_DECAY', 'YIELD_PRODUCTION', -10);
INSERT INTO Building_YieldModifiers (BuildingType, YieldType, Yield) VALUES ('BUILDING_RL_CURSE_DARK_AGES', 'YIELD_SCIENCE', -10);
INSERT INTO Building_YieldModifiers (BuildingType, YieldType, Yield) VALUES ('BUILDING_RL_TEMP_PRODUCTION', 'YIELD_PRODUCTION', 10);
INSERT INTO Building_YieldModifiers (BuildingType, YieldType, Yield) VALUES ('BUILDING_RL_TEMP_GROWTH', 'YIELD_FOOD', 10);
INSERT INTO Building_YieldModifiers (BuildingType, YieldType, Yield) VALUES ('BUILDING_RL_TEMP_SCIENCE', 'YIELD_SCIENCE', 10);
INSERT INTO Building_YieldModifiers (BuildingType, YieldType, Yield) VALUES ('BUILDING_RL_TEMP_GOLD', 'YIELD_GOLD', 10);
INSERT INTO Building_YieldModifiers (BuildingType, YieldType, Yield) VALUES ('BUILDING_RL_ASC_LEAN', 'YIELD_GOLD', -10);
INSERT INTO Building_YieldModifiers (BuildingType, YieldType, Yield) VALUES ('BUILDING_RL_ASC_LEAN', 'YIELD_PRODUCTION', -10);

-- Free experience & domain production
INSERT INTO Building_DomainFreeExperiences (BuildingType, DomainType, Experience) VALUES ('BUILDING_RL_WARCAMPS', 'DOMAIN_LAND', 15);
INSERT INTO Building_DomainFreeExperiences (BuildingType, DomainType, Experience) VALUES ('BUILDING_RL_ADMIRALTY', 'DOMAIN_SEA', 20);
INSERT INTO Building_DomainProductionModifiers (BuildingType, DomainType, Modifier) VALUES ('BUILDING_RL_ADMIRALTY', 'DOMAIN_SEA', 25);

-- Ocean tiles (same table the Lighthouse uses)
INSERT INTO Building_SeaPlotYieldChanges (BuildingType, YieldType, Yield) VALUES ('BUILDING_RL_SEAS', 'YIELD_FOOD', 1);
INSERT INTO Building_SeaPlotYieldChanges (BuildingType, YieldType, Yield) VALUES ('BUILDING_RL_SEAS', 'YIELD_GOLD', 1);

-- ---------------------------------------------------------------------
-- Text
-- ---------------------------------------------------------------------
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_BUILDING_RL_WARCAMPS', 'Boon: Warcamps');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_BUILDING_RL_ARSENAL', 'Boon: Arsenal');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_BUILDING_RL_ADMIRALTY', 'Boon: Admiralty');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_BUILDING_RL_FORTRESS', 'Boon: Fortress Cities');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_BUILDING_RL_MERCHANT_GUILDS', 'Boon: Merchant Guilds');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_BUILDING_RL_TAX_COLLECTORS', 'Boon: Tax Collectors');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_BUILDING_RL_TRADE_WINDS', 'Boon: Trade Winds');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_BUILDING_RL_SILK_ROADS', 'Boon: Silk Roads');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_BUILDING_RL_LIBRARIES', 'Boon: Libraries of Old');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_BUILDING_RL_BRAINSTORM', 'Boon: Brainstorm');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_BUILDING_RL_GREAT_MINDS', 'Boon: Great Minds');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_BUILDING_RL_FERTILE', 'Boon: Fertile Lands');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_BUILDING_RL_GRANARIES', 'Boon: Royal Granaries');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_BUILDING_RL_SEAS', 'Boon: Bountiful Seas');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_BUILDING_RL_FOREST', 'Boon: Forest Wardens');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_BUILDING_RL_HARVEST', 'Boon: Harvest Festival');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_BUILDING_RL_ABUNDANCE', 'Boon: Abundance');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_BUILDING_RL_BARDS', 'Boon: Wandering Bards');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_BUILDING_RL_RENAISSANCE', 'Boon: Renaissance Spirit');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_BUILDING_RL_GOLDEN_PROPHECY', 'Boon: Golden Prophecy');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_BUILDING_RL_MUSEUM', 'Boon: Grand Museum');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_BUILDING_RL_BORDERS', 'Boon: Manifest Destiny');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_BUILDING_RL_SHRINES', 'Boon: Wayside Shrines');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_BUILDING_RL_ZEALOTS', 'Boon: Zealots');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_BUILDING_RL_TITHES', 'Boon: Tithes');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_BUILDING_RL_CIRCUSES', 'Boon: Bread and Circuses');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_BUILDING_RL_LOCAL_PRIDE', 'Boon: Local Pride');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_BUILDING_RL_MASONS', 'Boon: Master Masons');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_BUILDING_RL_ARCHITECTS', 'Boon: Royal Architects');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_BUILDING_RL_WONDERS', 'Boon: Wonder Architects');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_BUILDING_RL_INDUSTRY', 'Boon: Industrious');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_BUILDING_RL_SPYMASTER', 'Boon: Spymaster');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_BUILDING_RL_BULWARK', 'Legacy: Ancestral Bulwark');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_BUILDING_RL_HEARTLAND', 'Origin: Heartland');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_BUILDING_RL_IMPERIAL_SEAT', 'Boon: Imperial Seat');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_BUILDING_RL_CURSE_FAMINE', 'Curse: Famine');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_BUILDING_RL_CURSE_CORRUPTION', 'Curse: Corruption');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_BUILDING_RL_CURSE_UNREST', 'Curse: Unrest');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_BUILDING_RL_CURSE_DECAY', 'Curse: Decay');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_BUILDING_RL_CURSE_DARK_AGES', 'Curse: Dark Ages');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_BUILDING_RL_CURSE_WEARY', 'Curse: Weariness');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_BUILDING_RL_CURSE_CURSED_GOLD', 'Curse: Cursed Gold');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_BUILDING_RL_CURSE_HERESY', 'Curse: Heresy');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_BUILDING_RL_TEMP_HAPPY', 'Event: Jubilation');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_BUILDING_RL_TEMP_PRODUCTION', 'Event: Work Song');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_BUILDING_RL_TEMP_GROWTH', 'Event: Fair Seasons');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_BUILDING_RL_TEMP_SCIENCE', 'Event: Inspiration');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_BUILDING_RL_TEMP_GOLD', 'Event: Boom Times');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_BUILDING_RL_TEMP_DEFENSE', 'Event: Mustered Militia');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_BUILDING_RL_TEMP_CULTURE', 'Event: Festival of Arts');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_BUILDING_RL_TEMP_PLAGUE', 'Event: Sickness');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_BUILDING_RL_ASC_LEAN', 'Ascension: Lean Times');

INSERT INTO Language_en_US (Tag, Text)
SELECT Help, 'An effect of the Ascension roguelite run. Open the Ascension Run panel (button at the top of the screen) for details.'
FROM Buildings WHERE Type LIKE 'BUILDING_RL_%';
