-- Optional effect. Verified by Lua before the Silk Roads boon is offered.
UPDATE Buildings SET TradeRouteRecipientBonus = 2, TradeRouteTargetBonus = 2 WHERE Type = 'BUILDING_RL_SILK_ROADS';
