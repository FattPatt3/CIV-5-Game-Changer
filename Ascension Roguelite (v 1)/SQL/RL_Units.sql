-- =====================================================================
-- ASCENSION: ROGUELITE OVERHAUL  --  The Champion
-- One hero unit per run. It cannot be trained (Cost -1); the Lua engine
-- spawns it, and swaps it for the next tier every time your era advances,
-- keeping all experience and promotions.
-- Each tier copies the art / sounds / combat class of a vanilla unit.
-- Only columns read by the BNW game core are used here; cosmetic extras
-- (unit flag atlas, XP values) are copied in Optional/RL_Opt_UnitArt.sql.
-- =====================================================================

INSERT INTO UnitClasses (Type, Description, DefaultUnit)
VALUES ('UNITCLASS_RL_CHAMPION', 'TXT_KEY_UNIT_RL_CHAMPION', 'UNIT_RL_CHAMPION_1');

CREATE TABLE IF NOT EXISTS RL_ChampionTiers (Type TEXT, Source TEXT, Combat INTEGER, Moves INTEGER);
INSERT INTO RL_ChampionTiers VALUES ('UNIT_RL_CHAMPION_1', 'UNIT_SWORDSMAN', 20, 2);
INSERT INTO RL_ChampionTiers VALUES ('UNIT_RL_CHAMPION_2', 'UNIT_LONGSWORDSMAN', 32, 2);
INSERT INTO RL_ChampionTiers VALUES ('UNIT_RL_CHAMPION_3', 'UNIT_RIFLEMAN', 48, 2);
INSERT INTO RL_ChampionTiers VALUES ('UNIT_RL_CHAMPION_4', 'UNIT_INFANTRY', 80, 2);
INSERT INTO RL_ChampionTiers VALUES ('UNIT_RL_CHAMPION_5', 'UNIT_MECHANIZED_INFANTRY', 105, 3);

INSERT INTO Units (Type, Class, PrereqTech, ObsoleteTech, Cost, FaithCost, Combat, Moves,
                   CombatClass, Domain, DefaultUnitAI, Description, Civilopedia, Strategy, Help,
                   MilitarySupport, MilitaryProduction, Pillage, NoMaintenance, MoveRate,
                   UnitArtInfo, UnitFlagIconOffset, IconAtlas, PortraitIndex)
SELECT t.Type, 'UNITCLASS_RL_CHAMPION', NULL, NULL, -1, -1, t.Combat, t.Moves,
       u.CombatClass, u.Domain, u.DefaultUnitAI, 'TXT_KEY_UNIT_RL_CHAMPION', 'TXT_KEY_UNIT_RL_CHAMPION_PEDIA',
       'TXT_KEY_UNIT_RL_CHAMPION_STRATEGY', 'TXT_KEY_UNIT_RL_CHAMPION_HELP',
       1, 1, 1, 1, u.MoveRate,
       u.UnitArtInfo, u.UnitFlagIconOffset, u.IconAtlas, u.PortraitIndex
FROM RL_ChampionTiers t, Units u WHERE u.Type = t.Source;

INSERT INTO UnitGameplay2DScripts (UnitType, SelectionSound, FirstSelectionSound)
SELECT t.Type, s.SelectionSound, s.FirstSelectionSound
FROM RL_ChampionTiers t, UnitGameplay2DScripts s WHERE s.UnitType = t.Source;

INSERT INTO Unit_AITypes (UnitType, UnitAIType) SELECT Type, 'UNITAI_ATTACK' FROM RL_ChampionTiers;
INSERT INTO Unit_AITypes (UnitType, UnitAIType) SELECT Type, 'UNITAI_DEFENSE' FROM RL_ChampionTiers;
INSERT INTO Unit_Flavors (UnitType, FlavorType, Flavor) SELECT Type, 'FLAVOR_OFFENSE', 1 FROM RL_ChampionTiers;
INSERT INTO Unit_FreePromotions (UnitType, PromotionType) SELECT Type, 'PROMOTION_RL_CHAMPION' FROM RL_ChampionTiers;

DROP TABLE RL_ChampionTiers;

INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_UNIT_RL_CHAMPION', 'Champion');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_UNIT_RL_CHAMPION_HELP', 'Your run''s hero. Cannot be built. Grows into a stronger form every era, keeping all experience and promotions. If it falls it returns after a few turns - unless your Ascension forbids it.');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_UNIT_RL_CHAMPION_STRATEGY', 'Use the Champion to break Horde raids and hunt Era Warlords. Keep it alive: on high Ascension levels its death ends the run.');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_UNIT_RL_CHAMPION_PEDIA', 'Every age has its legends. The Champion is yours: a single warrior whose deeds echo from one era to the next, reforged by each new age of the world.');
