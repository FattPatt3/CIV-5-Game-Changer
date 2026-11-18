-- Optional cosmetics/details for the Champion, copied from each tier's
-- source unit. Isolated: if any column is missing in your install, only
-- this file is skipped and the Champion still works.
UPDATE Units SET UnitFlagAtlas = (SELECT s.UnitFlagAtlas FROM Units s WHERE s.Type = 'UNIT_SWORDSMAN') WHERE Type = 'UNIT_RL_CHAMPION_1';
UPDATE Units SET UnitFlagAtlas = (SELECT s.UnitFlagAtlas FROM Units s WHERE s.Type = 'UNIT_LONGSWORDSMAN') WHERE Type = 'UNIT_RL_CHAMPION_2';
UPDATE Units SET UnitFlagAtlas = (SELECT s.UnitFlagAtlas FROM Units s WHERE s.Type = 'UNIT_RIFLEMAN') WHERE Type = 'UNIT_RL_CHAMPION_3';
UPDATE Units SET UnitFlagAtlas = (SELECT s.UnitFlagAtlas FROM Units s WHERE s.Type = 'UNIT_INFANTRY') WHERE Type = 'UNIT_RL_CHAMPION_4';
UPDATE Units SET UnitFlagAtlas = (SELECT s.UnitFlagAtlas FROM Units s WHERE s.Type = 'UNIT_MECHANIZED_INFANTRY') WHERE Type = 'UNIT_RL_CHAMPION_5';
UPDATE Units SET XPValueAttack = 3, XPValueDefense = 3 WHERE Class = 'UNITCLASS_RL_CHAMPION';
