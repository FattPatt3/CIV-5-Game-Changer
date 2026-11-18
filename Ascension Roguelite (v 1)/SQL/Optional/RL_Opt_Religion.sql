-- Optional effect. Verified by Lua before the Zealots boon is offered.
UPDATE Buildings SET ReligiousPressureModifier = 50 WHERE Type = 'BUILDING_RL_ZEALOTS';
