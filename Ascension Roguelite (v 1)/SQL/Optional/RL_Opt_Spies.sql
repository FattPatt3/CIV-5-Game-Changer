-- Optional effect. Verified by Lua before the Spymaster boon is offered.
UPDATE Buildings SET ExtraSpies = 1 WHERE Type = 'BUILDING_RL_SPYMASTER';
