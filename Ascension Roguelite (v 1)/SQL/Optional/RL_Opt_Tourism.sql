-- Optional effect (isolated so an unexpected schema difference cannot break the core mod).
-- The Lua engine verifies the value landed before offering the Grand Museum boon.
UPDATE Buildings SET GreatWorksTourismModifier = 25 WHERE Type = 'BUILDING_RL_MUSEUM';
