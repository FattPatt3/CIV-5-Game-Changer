-- =====================================================================
-- ASCENSION: ROGUELITE OVERHAUL  --  Promotions
-- None of these can be picked on level-up (CannotBeChosen = 1); the Lua
-- engine grants them to units that qualify for an owned boon, to the
-- Champion, and to Horde / Warlord units.
-- =====================================================================

INSERT INTO UnitPromotions (Type, Description, Help, Sound, CannotBeChosen, PortraitIndex, IconAtlas, PediaType, PediaEntry)
VALUES ('PROMOTION_RL_IRON_DISCIPLINE', 'TXT_KEY_PROMOTION_RL_IRON_DISCIPLINE', 'TXT_KEY_PROMOTION_RL_IRON_DISCIPLINE_HELP', 'AS2D_IF_LEVELUP', 1, 1, 'PROMOTION_ATLAS', 'PEDIA_ATTRIBUTES', 'TXT_KEY_PROMOTION_RL_IRON_DISCIPLINE');
INSERT INTO UnitPromotions (Type, Description, Help, Sound, CannotBeChosen, PortraitIndex, IconAtlas, PediaType, PediaEntry)
VALUES ('PROMOTION_RL_SIEGECRAFT', 'TXT_KEY_PROMOTION_RL_SIEGECRAFT', 'TXT_KEY_PROMOTION_RL_SIEGECRAFT_HELP', 'AS2D_IF_LEVELUP', 1, 13, 'PROMOTION_ATLAS', 'PEDIA_ATTRIBUTES', 'TXT_KEY_PROMOTION_RL_SIEGECRAFT');
INSERT INTO UnitPromotions (Type, Description, Help, Sound, CannotBeChosen, PortraitIndex, IconAtlas, PediaType, PediaEntry)
VALUES ('PROMOTION_RL_FORCED_MARCH', 'TXT_KEY_PROMOTION_RL_FORCED_MARCH', 'TXT_KEY_PROMOTION_RL_FORCED_MARCH_HELP', 'AS2D_IF_LEVELUP', 1, 22, 'PROMOTION_ATLAS', 'PEDIA_ATTRIBUTES', 'TXT_KEY_PROMOTION_RL_FORCED_MARCH');
INSERT INTO UnitPromotions (Type, Description, Help, Sound, CannotBeChosen, PortraitIndex, IconAtlas, PediaType, PediaEntry)
VALUES ('PROMOTION_RL_SEA_DOGS', 'TXT_KEY_PROMOTION_RL_SEA_DOGS', 'TXT_KEY_PROMOTION_RL_SEA_DOGS_HELP', 'AS2D_IF_LEVELUP', 1, 30, 'PROMOTION_ATLAS', 'PEDIA_ATTRIBUTES', 'TXT_KEY_PROMOTION_RL_SEA_DOGS');
INSERT INTO UnitPromotions (Type, Description, Help, Sound, CannotBeChosen, PortraitIndex, IconAtlas, PediaType, PediaEntry)
VALUES ('PROMOTION_RL_WARMASTER', 'TXT_KEY_PROMOTION_RL_WARMASTER', 'TXT_KEY_PROMOTION_RL_WARMASTER_HELP', 'AS2D_IF_LEVELUP', 1, 3, 'PROMOTION_ATLAS', 'PEDIA_ATTRIBUTES', 'TXT_KEY_PROMOTION_RL_WARMASTER');
INSERT INTO UnitPromotions (Type, Description, Help, Sound, CannotBeChosen, PortraitIndex, IconAtlas, PediaType, PediaEntry)
VALUES ('PROMOTION_RL_DRAGON_BANNER', 'TXT_KEY_PROMOTION_RL_DRAGON_BANNER', 'TXT_KEY_PROMOTION_RL_DRAGON_BANNER_HELP', 'AS2D_IF_LEVELUP', 1, 4, 'PROMOTION_ATLAS', 'PEDIA_ATTRIBUTES', 'TXT_KEY_PROMOTION_RL_DRAGON_BANNER');
INSERT INTO UnitPromotions (Type, Description, Help, Sound, CannotBeChosen, PortraitIndex, IconAtlas, PediaType, PediaEntry)
VALUES ('PROMOTION_RL_LONGBOW', 'TXT_KEY_PROMOTION_RL_LONGBOW', 'TXT_KEY_PROMOTION_RL_LONGBOW_HELP', 'AS2D_IF_LEVELUP', 1, 15, 'PROMOTION_ATLAS', 'PEDIA_ATTRIBUTES', 'TXT_KEY_PROMOTION_RL_LONGBOW');
INSERT INTO UnitPromotions (Type, Description, Help, Sound, CannotBeChosen, PortraitIndex, IconAtlas, PediaType, PediaEntry)
VALUES ('PROMOTION_RL_SCOUTS_EYE', 'TXT_KEY_PROMOTION_RL_SCOUTS_EYE', 'TXT_KEY_PROMOTION_RL_SCOUTS_EYE_HELP', 'AS2D_IF_LEVELUP', 1, 25, 'PROMOTION_ATLAS', 'PEDIA_ATTRIBUTES', 'TXT_KEY_PROMOTION_RL_SCOUTS_EYE');
INSERT INTO UnitPromotions (Type, Description, Help, Sound, CannotBeChosen, PortraitIndex, IconAtlas, PediaType, PediaEntry)
VALUES ('PROMOTION_RL_COLOSSAL_HERO', 'TXT_KEY_PROMOTION_RL_COLOSSAL_HERO', 'TXT_KEY_PROMOTION_RL_COLOSSAL_HERO_HELP', 'AS2D_IF_LEVELUP', 1, 5, 'PROMOTION_ATLAS', 'PEDIA_ATTRIBUTES', 'TXT_KEY_PROMOTION_RL_COLOSSAL_HERO');
INSERT INTO UnitPromotions (Type, Description, Help, Sound, CannotBeChosen, PortraitIndex, IconAtlas, PediaType, PediaEntry)
VALUES ('PROMOTION_RL_CHAMPION_ARMOR', 'TXT_KEY_PROMOTION_RL_CHAMPION_ARMOR', 'TXT_KEY_PROMOTION_RL_CHAMPION_ARMOR_HELP', 'AS2D_IF_LEVELUP', 1, 6, 'PROMOTION_ATLAS', 'PEDIA_ATTRIBUTES', 'TXT_KEY_PROMOTION_RL_CHAMPION_ARMOR');
INSERT INTO UnitPromotions (Type, Description, Help, Sound, CannotBeChosen, PortraitIndex, IconAtlas, PediaType, PediaEntry)
VALUES ('PROMOTION_RL_CHAMPION', 'TXT_KEY_PROMOTION_RL_CHAMPION', 'TXT_KEY_PROMOTION_RL_CHAMPION_HELP', 'AS2D_IF_LEVELUP', 1, 2, 'PROMOTION_ATLAS', 'PEDIA_ATTRIBUTES', 'TXT_KEY_PROMOTION_RL_CHAMPION');
INSERT INTO UnitPromotions (Type, Description, Help, Sound, CannotBeChosen, PortraitIndex, IconAtlas, PediaType, PediaEntry)
VALUES ('PROMOTION_RL_HORDE', 'TXT_KEY_PROMOTION_RL_HORDE', 'TXT_KEY_PROMOTION_RL_HORDE_HELP', 'AS2D_IF_LEVELUP', 1, 10, 'PROMOTION_ATLAS', 'PEDIA_ATTRIBUTES', 'TXT_KEY_PROMOTION_RL_HORDE');
INSERT INTO UnitPromotions (Type, Description, Help, Sound, CannotBeChosen, PortraitIndex, IconAtlas, PediaType, PediaEntry)
VALUES ('PROMOTION_RL_HORDE_VETERAN', 'TXT_KEY_PROMOTION_RL_HORDE_VETERAN', 'TXT_KEY_PROMOTION_RL_HORDE_VETERAN_HELP', 'AS2D_IF_LEVELUP', 1, 11, 'PROMOTION_ATLAS', 'PEDIA_ATTRIBUTES', 'TXT_KEY_PROMOTION_RL_HORDE_VETERAN');
INSERT INTO UnitPromotions (Type, Description, Help, Sound, CannotBeChosen, PortraitIndex, IconAtlas, PediaType, PediaEntry)
VALUES ('PROMOTION_RL_BOSS', 'TXT_KEY_PROMOTION_RL_BOSS', 'TXT_KEY_PROMOTION_RL_BOSS_HELP', 'AS2D_IF_LEVELUP', 1, 12, 'PROMOTION_ATLAS', 'PEDIA_ATTRIBUTES', 'TXT_KEY_PROMOTION_RL_BOSS');
INSERT INTO UnitPromotions (Type, Description, Help, Sound, CannotBeChosen, PortraitIndex, IconAtlas, PediaType, PediaEntry)
VALUES ('PROMOTION_RL_BOSS_EMPOWERED', 'TXT_KEY_PROMOTION_RL_BOSS_EMPOWERED', 'TXT_KEY_PROMOTION_RL_BOSS_EMPOWERED_HELP', 'AS2D_IF_LEVELUP', 1, 14, 'PROMOTION_ATLAS', 'PEDIA_ATTRIBUTES', 'TXT_KEY_PROMOTION_RL_BOSS_EMPOWERED');

UPDATE UnitPromotions SET CombatPercent = 10                    WHERE Type = 'PROMOTION_RL_IRON_DISCIPLINE';
UPDATE UnitPromotions SET CityAttack = 33                       WHERE Type = 'PROMOTION_RL_SIEGECRAFT';
UPDATE UnitPromotions SET MovesChange = 1                       WHERE Type = 'PROMOTION_RL_FORCED_MARCH';
UPDATE UnitPromotions SET CombatPercent = 15, VisibilityChange = 1 WHERE Type = 'PROMOTION_RL_SEA_DOGS';
UPDATE UnitPromotions SET CombatPercent = 15, AlwaysHeal = 1    WHERE Type = 'PROMOTION_RL_WARMASTER';
UPDATE UnitPromotions SET CombatPercent = 20                    WHERE Type = 'PROMOTION_RL_DRAGON_BANNER';
UPDATE UnitPromotions SET RangeChange = 1                       WHERE Type = 'PROMOTION_RL_LONGBOW';
UPDATE UnitPromotions SET VisibilityChange = 1                  WHERE Type = 'PROMOTION_RL_SCOUTS_EYE';
UPDATE UnitPromotions SET CombatPercent = 50, MovesChange = 1   WHERE Type = 'PROMOTION_RL_COLOSSAL_HERO';
UPDATE UnitPromotions SET CombatPercent = 25                    WHERE Type = 'PROMOTION_RL_CHAMPION_ARMOR';
UPDATE UnitPromotions SET AlwaysHeal = 1, VisibilityChange = 1, ExperiencePercent = 50 WHERE Type = 'PROMOTION_RL_CHAMPION';
UPDATE UnitPromotions SET CombatPercent = 15                    WHERE Type = 'PROMOTION_RL_HORDE_VETERAN';
UPDATE UnitPromotions SET CombatPercent = 50, AlwaysHeal = 1, VisibilityChange = 1 WHERE Type = 'PROMOTION_RL_BOSS';
UPDATE UnitPromotions SET CombatPercent = 25                    WHERE Type = 'PROMOTION_RL_BOSS_EMPOWERED';

INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_PROMOTION_RL_IRON_DISCIPLINE', 'Iron Discipline');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_PROMOTION_RL_IRON_DISCIPLINE_HELP', '+10% [ICON_STRENGTH] Combat Strength (Ascension boon).');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_PROMOTION_RL_SIEGECRAFT', 'Siegecraft');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_PROMOTION_RL_SIEGECRAFT_HELP', '+33% [ICON_STRENGTH] Combat Strength when attacking Cities (Ascension boon).');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_PROMOTION_RL_FORCED_MARCH', 'Forced March');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_PROMOTION_RL_FORCED_MARCH_HELP', '+1 [ICON_MOVES] Movement (Ascension boon).');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_PROMOTION_RL_SEA_DOGS', 'Sea Dogs');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_PROMOTION_RL_SEA_DOGS_HELP', '+15% [ICON_STRENGTH] Combat Strength and +1 Sight (Ascension boon).');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_PROMOTION_RL_WARMASTER', 'Warmaster');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_PROMOTION_RL_WARMASTER_HELP', '+15% [ICON_STRENGTH] Combat Strength. Heals even after moving or attacking (Ascension boon).');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_PROMOTION_RL_DRAGON_BANNER', 'Dragon Banner');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_PROMOTION_RL_DRAGON_BANNER_HELP', '+20% [ICON_STRENGTH] Combat Strength (Legendary Ascension boon).');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_PROMOTION_RL_LONGBOW', 'Longbow Doctrine');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_PROMOTION_RL_LONGBOW_HELP', '+1 Range (Ascension boon).');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_PROMOTION_RL_SCOUTS_EYE', 'Far Sight');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_PROMOTION_RL_SCOUTS_EYE_HELP', '+1 Sight (Ascension boon).');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_PROMOTION_RL_COLOSSAL_HERO', 'Colossus Reborn');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_PROMOTION_RL_COLOSSAL_HERO_HELP', '+50% [ICON_STRENGTH] Combat Strength and +1 [ICON_MOVES] Movement (Champion only).');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_PROMOTION_RL_CHAMPION_ARMOR', 'Mythril Plate');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_PROMOTION_RL_CHAMPION_ARMOR_HELP', '+25% [ICON_STRENGTH] Combat Strength (Champion only).');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_PROMOTION_RL_CHAMPION', 'Champion of the Realm');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_PROMOTION_RL_CHAMPION_HELP', 'Heals every turn even after acting, +1 Sight, +50% experience. Grows stronger every era.');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_PROMOTION_RL_HORDE', 'The Horde');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_PROMOTION_RL_HORDE_HELP', 'This unit belongs to the Horde that hunts your empire.');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_PROMOTION_RL_HORDE_VETERAN', 'Horde Veteran');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_PROMOTION_RL_HORDE_VETERAN_HELP', '+15% [ICON_STRENGTH] Combat Strength.');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_PROMOTION_RL_BOSS', 'Warlord');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_PROMOTION_RL_BOSS_HELP', 'An Era Warlord. +50% [ICON_STRENGTH] Combat Strength, heals every turn, +1 Sight. Slay it for great rewards.');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_PROMOTION_RL_BOSS_EMPOWERED', 'Ascendant Warlord');
INSERT INTO Language_en_US (Tag, Text) VALUES ('TXT_KEY_PROMOTION_RL_BOSS_EMPOWERED_HELP', '+25% [ICON_STRENGTH] Combat Strength (high Ascension).');
