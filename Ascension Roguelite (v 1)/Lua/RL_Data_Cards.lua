-- =====================================================================
-- ASCENSION: ROGUELITE OVERHAUL -- Boons & Curses
--
-- Card fields
--   id, name, rarity (1 Common .. 4 Legendary), tags = {..}
--   max        : max stacks (default 1)
--   desc       : string or function(stacks) -> string
--   building   : dummy building placed per stack ("all" cities or "capital")
--   promo      : promotion granted to units matching `filter`
--                filters: LAND, SEA, MILITARY, RANGED, CHAMPION
--   humanOnly  : never given to AI rivals
--   requires   : {building=, column=, value=} DB check, or function(pid)
--   hooks      : onAcquire(pid, stacks, gained), onTurn(pid, stacks, turn),
--                onKill(pid, stacks, victimPlayer, unitType),
--                onLoss(pid, stacks, killerPlayer, unitType),
--                onCityFounded(pid, stacks, city),
--                onCityCaptured(pid, stacks, city, oldOwner),
--                onEra(pid, stacks, era), onBoss(pid, stacks)
-- RL.Fx.* helpers live in RL_Engine.lua.
-- =====================================================================

RL = RL or {}
local Fx = function() return RL.Fx end   -- late-bound (engine loads after data)

RL.Cards = {}
RL.Curses = {}

local function Card(t) t.max = t.max or 1; t.rarity = t.rarity or 1; RL.Cards[#RL.Cards + 1] = t; return t end
local function Curse(t) t.max = t.max or 3; t.curse = true; RL.Curses[#RL.Curses + 1] = t; return t end

-- =========================== WAR ===========================
Card{ id = "IRON_DISCIPLINE", name = "Iron Discipline", rarity = 1, tags = {"WAR"},
	desc = "All land military units gain [COLOR_POSITIVE_TEXT]+10%[ENDCOLOR] [ICON_STRENGTH] Combat Strength.",
	promo = "PROMOTION_RL_IRON_DISCIPLINE", filter = "LAND" }

Card{ id = "WARCAMPS", name = "Warcamps", rarity = 1, tags = {"WAR"}, max = 3,
	desc = "Land units trained in any city start with [COLOR_POSITIVE_TEXT]+15 XP[ENDCOLOR] per stack.",
	building = "BUILDING_RL_WARCAMPS", scope = "all" }

Card{ id = "BLOOD_BOUNTY", name = "Blood Bounty", rarity = 1, tags = {"WAR", "GOLD"}, max = 3,
	desc = function(s) return "Every enemy unit you destroy pays [ICON_GOLD] Gold (8 + 4 per era, x" .. s .. " stacks)." end,
	onKill = function(pid, s) Fx().Gold(pid, Fx().Amt(pid, 8, 4) * s) end }

Card{ id = "FORTRESS", name = "Fortress Cities", rarity = 1, tags = {"WAR", "BUILD"}, max = 3,
	desc = "All cities gain [COLOR_POSITIVE_TEXT]+5[ENDCOLOR] [ICON_STRENGTH] Defense and +50 HP per stack.",
	building = "BUILDING_RL_FORTRESS", scope = "all" }

Card{ id = "VETERANS", name = "Veterans' Return", rarity = 1, tags = {"WAR"}, max = 2,
	desc = "All your current military units immediately gain [COLOR_POSITIVE_TEXT]20 XP[ENDCOLOR].",
	onAcquire = function(pid, s, gained) Fx().UnitsXP(pid, 20 * gained) end }

Card{ id = "ARSENAL", name = "Arsenal", rarity = 2, tags = {"WAR", "BUILD"}, max = 2,
	desc = "[COLOR_POSITIVE_TEXT]+15%[ENDCOLOR] [ICON_PRODUCTION] Production toward military units in all cities per stack.",
	building = "BUILDING_RL_ARSENAL", scope = "all" }

Card{ id = "SIEGECRAFT", name = "Siegecraft", rarity = 2, tags = {"WAR"},
	desc = "Land military units gain [COLOR_POSITIVE_TEXT]+33%[ENDCOLOR] [ICON_STRENGTH] when attacking cities.",
	promo = "PROMOTION_RL_SIEGECRAFT", filter = "LAND" }

Card{ id = "FORCED_MARCH", name = "Forced March", rarity = 2, tags = {"WAR"},
	desc = "Land military units gain [COLOR_POSITIVE_TEXT]+1[ENDCOLOR] [ICON_MOVES] Movement.",
	promo = "PROMOTION_RL_FORCED_MARCH", filter = "LAND" }

Card{ id = "LONGBOW", name = "Longbow Doctrine", rarity = 2, tags = {"WAR"},
	desc = "Land ranged units gain [COLOR_POSITIVE_TEXT]+1 Range[ENDCOLOR].",
	promo = "PROMOTION_RL_LONGBOW", filter = "RANGED" }

Card{ id = "TROPHY_HALL", name = "Trophy Hall", rarity = 2, tags = {"WAR", "CULTURE"},
	desc = "Every enemy unit you destroy grants [ICON_CULTURE] Culture (4 + 2 per era).",
	onKill = function(pid, s) Fx().Culture(pid, Fx().Amt(pid, 4, 2) * s) end }

Card{ id = "BATTLE_HYMNS", name = "Battle Hymns", rarity = 2, tags = {"WAR", "FAITH"},
	desc = "Every enemy unit you destroy grants [ICON_PEACE] Faith (4 + 2 per era).",
	onKill = function(pid, s) Fx().Faith(pid, Fx().Amt(pid, 4, 2) * s) end }

Card{ id = "PLUNDERERS", name = "Plunderers", rarity = 2, tags = {"WAR", "GOLD"},
	desc = "Capturing a city loots [ICON_GOLD] Gold (80 + 40 per era) and instantly heals all your units near it.",
	onCityCaptured = function(pid, s, city)
		Fx().Gold(pid, Fx().Amt(pid, 80, 40) * s)
		Fx().HealUnitsNear(pid, city:GetX(), city:GetY(), 3, 100)
	end }

Card{ id = "MERCENARIES", name = "Mercenary Contract", rarity = 2, tags = {"WAR", "GOLD"}, max = 2,
	desc = "Immediately recruit your best available melee and ranged units in the capital.",
	onAcquire = function(pid, s, gained)
		for i = 1, gained do Fx().SpawnRole(pid, "MELEE", 1); Fx().SpawnRole(pid, "RANGED", 1) end
	end }

Card{ id = "REGENERATION", name = "Troll Blood", rarity = 3, tags = {"WAR"},
	desc = "At the start of each turn all your military units heal [COLOR_POSITIVE_TEXT]10 HP[ENDCOLOR] wherever they are.",
	onTurn = function(pid, s) Fx().HealUnits(pid, 10 * s) end }

Card{ id = "CONSCRIPTION", name = "Levee en Masse", rarity = 3, tags = {"WAR"},
	desc = "Every 12 turns (scaled by game speed) a free unit of your best melee type musters in your capital.",
	onTurn = function(pid, s, turn) if Fx().Every(turn, 12) then Fx().SpawnRole(pid, "MELEE", s) end end }

Card{ id = "WARMASTER", name = "Warmaster", rarity = 3, tags = {"WAR"},
	desc = "Land military units gain [COLOR_POSITIVE_TEXT]+15%[ENDCOLOR] [ICON_STRENGTH] and heal even after moving or attacking.",
	promo = "PROMOTION_RL_WARMASTER", filter = "LAND" }

Card{ id = "DRAGON_BANNER", name = "The Dragon Banner", rarity = 4, tags = {"WAR"},
	desc = "ALL military units (land, sea, air) gain [COLOR_POSITIVE_TEXT]+20%[ENDCOLOR] [ICON_STRENGTH] and heal 5 HP every turn.",
	promo = "PROMOTION_RL_DRAGON_BANNER", filter = "MILITARY",
	onTurn = function(pid, s) Fx().HealUnits(pid, 5) end }

-- =========================== SEA ===========================
Card{ id = "SEA_DOGS", name = "Sea Dogs", rarity = 1, tags = {"SEA", "WAR"},
	desc = "Naval units gain [COLOR_POSITIVE_TEXT]+15%[ENDCOLOR] [ICON_STRENGTH] and +1 Sight.",
	promo = "PROMOTION_RL_SEA_DOGS", filter = "SEA" }

Card{ id = "BOUNTIFUL_SEAS", name = "Bountiful Seas", rarity = 1, tags = {"SEA", "GROWTH"}, max = 3,
	desc = "Ocean and coast tiles worked by your cities yield [COLOR_POSITIVE_TEXT]+1[ENDCOLOR] [ICON_FOOD] and +1 [ICON_GOLD] per stack.",
	building = "BUILDING_RL_SEAS", scope = "all" }

Card{ id = "ADMIRALTY", name = "Admiralty", rarity = 2, tags = {"SEA", "WAR"}, max = 2,
	desc = "Naval units are built [COLOR_POSITIVE_TEXT]25%[ENDCOLOR] faster and start with +20 XP per stack.",
	building = "BUILDING_RL_ADMIRALTY", scope = "all" }

Card{ id = "TRADE_WINDS", name = "Trade Winds", rarity = 2, tags = {"SEA", "GOLD"}, max = 2,
	desc = "[COLOR_POSITIVE_TEXT]+1[ENDCOLOR] [ICON_INTERNATIONAL_TRADE] Trade Route slot per stack.",
	building = "BUILDING_RL_TRADE_WINDS", scope = "capital" }

Card{ id = "PRIVATEERS", name = "Privateer Charters", rarity = 2, tags = {"SEA", "GOLD"},
	desc = "Every 10 turns, collect [ICON_GOLD] Gold for each of your coastal cities (15 + 10 per era each).",
	onTurn = function(pid, s, turn)
		if Fx().Every(turn, 10) then
			local n = Fx().CountCoastal(pid)
			if n > 0 then Fx().Gold(pid, Fx().Amt(pid, 15, 10) * n * s, "Privateers return with plunder") end
		end
	end }

-- =========================== COMMERCE ===========================
Card{ id = "MERCHANT_GUILDS", name = "Merchant Guilds", rarity = 1, tags = {"GOLD"}, max = 3,
	desc = "All cities [COLOR_POSITIVE_TEXT]+2[ENDCOLOR] [ICON_GOLD] Gold per stack.",
	building = "BUILDING_RL_MERCHANT_GUILDS", scope = "all" }

Card{ id = "MARKET_DAY", name = "Market Day", rarity = 1, tags = {"GOLD"}, max = 2,
	desc = "Every 10 turns gain [ICON_GOLD] Gold (30 + 20 per era) per stack.",
	onTurn = function(pid, s, turn) if Fx().Every(turn, 10) then Fx().Gold(pid, Fx().Amt(pid, 30, 20) * s, "Market Day") end end }

Card{ id = "TAX_COLLECTORS", name = "Tax Collectors", rarity = 2, tags = {"GOLD"}, max = 2,
	desc = "All cities [COLOR_POSITIVE_TEXT]+10%[ENDCOLOR] [ICON_GOLD] Gold per stack.",
	building = "BUILDING_RL_TAX_COLLECTORS", scope = "all" }

Card{ id = "SILK_ROADS", name = "Silk Roads", rarity = 2, tags = {"GOLD"},
	desc = "Trade routes to or from your cities earn [COLOR_POSITIVE_TEXT]+2[ENDCOLOR] [ICON_GOLD] Gold for both sides.",
	building = "BUILDING_RL_SILK_ROADS", scope = "all",
	requires = { building = "BUILDING_RL_SILK_ROADS", column = "TradeRouteRecipientBonus", value = 2 } }

Card{ id = "GOLDEN_GOOSE", name = "The Golden Goose", rarity = 3, tags = {"GOLD"},
	desc = "Each turn earn 3% interest on your treasury (max 30 + 15 per era).",
	onTurn = function(pid, s)
		local p = Players[pid]
		local cap = Fx().Amt(pid, 30, 15)
		local v = math.min(cap, math.floor(p:GetGold() * 0.03))
		if v > 0 then Fx().Gold(pid, v) end
	end }

Card{ id = "MIDAS", name = "Midas Touch", rarity = 4, tags = {"GOLD", "WAR"},
	desc = "Immediately gain [ICON_GOLD] Gold (200 + 100 per era). Every enemy unit destroyed pays 20 + 10 per era.",
	onAcquire = function(pid) Fx().Gold(pid, Fx().Amt(pid, 200, 100)) end,
	onKill = function(pid) Fx().Gold(pid, Fx().Amt(pid, 20, 10)) end }

-- =========================== KNOWLEDGE ===========================
Card{ id = "LIBRARIES", name = "Libraries of Old", rarity = 1, tags = {"SCIENCE"}, max = 3,
	desc = "All cities [COLOR_POSITIVE_TEXT]+2[ENDCOLOR] [ICON_RESEARCH] Science per stack.",
	building = "BUILDING_RL_LIBRARIES", scope = "all" }

Card{ id = "STARGAZERS", name = "Stargazers", rarity = 1, tags = {"SCIENCE"}, max = 2,
	desc = "Immediately gain [ICON_RESEARCH] Science toward your current research (40 + 40 per era).",
	onAcquire = function(pid, s, gained) Fx().Science(pid, Fx().Amt(pid, 40, 40) * gained) end }

Card{ id = "BRAINSTORM", name = "Brainstorm", rarity = 2, tags = {"SCIENCE"}, max = 2,
	desc = "All cities [COLOR_POSITIVE_TEXT]+10%[ENDCOLOR] [ICON_RESEARCH] Science per stack.",
	building = "BUILDING_RL_BRAINSTORM", scope = "all" }

Card{ id = "GREAT_MINDS", name = "Great Minds", rarity = 2, tags = {"SCIENCE", "CULTURE"}, max = 2,
	desc = "All cities [COLOR_POSITIVE_TEXT]+15%[ENDCOLOR] [ICON_GREAT_PEOPLE] Great Person generation per stack.",
	building = "BUILDING_RL_GREAT_MINDS", scope = "all" }

Card{ id = "EUREKA", name = "Eureka!", rarity = 3, tags = {"SCIENCE"},
	desc = "Every 15 turns your current research receives a burst worth one third of its cost.",
	onTurn = function(pid, s, turn) if Fx().Every(turn, 15) then Fx().ResearchFraction(pid, 0.33 * s) end end }

Card{ id = "FORBIDDEN_TOME", name = "The Forbidden Tome", rarity = 4, tags = {"SCIENCE"},
	desc = "Immediately learn [COLOR_POSITIVE_TEXT]2 random technologies[ENDCOLOR] you could research.",
	onAcquire = function(pid) Fx().FreeTech(pid); Fx().FreeTech(pid) end }

-- =========================== GROWTH ===========================
Card{ id = "FERTILE", name = "Fertile Lands", rarity = 1, tags = {"GROWTH"}, max = 3,
	desc = "All cities [COLOR_POSITIVE_TEXT]+2[ENDCOLOR] [ICON_FOOD] Food per stack.",
	building = "BUILDING_RL_FERTILE", scope = "all" }

Card{ id = "MANIFEST_DESTINY", name = "Manifest Destiny", rarity = 1, tags = {"GROWTH", "CULTURE"},
	desc = "Tiles cost [COLOR_POSITIVE_TEXT]33% less[ENDCOLOR] [ICON_CULTURE] Culture and [ICON_GOLD] Gold to acquire.",
	building = "BUILDING_RL_BORDERS", scope = "all" }

Card{ id = "FOREST", name = "Forest Wardens", rarity = 1, tags = {"GROWTH", "BUILD"},
	desc = "Worked Forests yield +1 [ICON_PRODUCTION] and +1 [ICON_GOLD]; worked Jungles +1 [ICON_FOOD].",
	building = "BUILDING_RL_FOREST", scope = "all",
	requires = { table = "Building_FeatureYieldChanges", building = "BUILDING_RL_FOREST" } }

Card{ id = "GRANARIES", name = "Royal Granaries", rarity = 2, tags = {"GROWTH"}, max = 2,
	desc = "Cities keep [COLOR_POSITIVE_TEXT]20%[ENDCOLOR] of their [ICON_FOOD] Food after growing, per stack.",
	building = "BUILDING_RL_GRANARIES", scope = "all" }

Card{ id = "HARVEST", name = "Harvest Festival", rarity = 2, tags = {"GROWTH"}, max = 2,
	desc = "All cities [COLOR_POSITIVE_TEXT]+10%[ENDCOLOR] [ICON_FOOD] Food per stack.",
	building = "BUILDING_RL_HARVEST", scope = "all" }

Card{ id = "BABY_BOOM", name = "Baby Boom", rarity = 2, tags = {"GROWTH"}, max = 2,
	desc = "Immediately: [COLOR_POSITIVE_TEXT]+1[ENDCOLOR] [ICON_CITIZEN] Population in every city and +1 more in your capital.",
	onAcquire = function(pid, s, gained) for i = 1, gained do Fx().AddPopulation(pid, 1, true) end end }

Card{ id = "ABUNDANCE", name = "Abundance", rarity = 3, tags = {"GROWTH", "FATE"}, max = 2,
	desc = "All cities [COLOR_POSITIVE_TEXT]+1[ENDCOLOR] [ICON_HAPPINESS_1] Happiness and +1 [ICON_FOOD] Food per stack.",
	building = "BUILDING_RL_ABUNDANCE", scope = "all" }

Card{ id = "HIVE_MIND", name = "Hive Mind", rarity = 3, tags = {"GROWTH", "WAR"},
	desc = "Every city you found or capture immediately gains [COLOR_POSITIVE_TEXT]+2[ENDCOLOR] [ICON_CITIZEN] Population.",
	onCityFounded = function(pid, s, city) Fx().CityPop(city, 2) end,
	onCityCaptured = function(pid, s, city) Fx().CityPop(city, 2) end }

-- =========================== CULTURE ===========================
Card{ id = "BARDS", name = "Wandering Bards", rarity = 1, tags = {"CULTURE"}, max = 3,
	desc = "All cities [COLOR_POSITIVE_TEXT]+2[ENDCOLOR] [ICON_CULTURE] Culture per stack.",
	building = "BUILDING_RL_BARDS", scope = "all" }

Card{ id = "RENAISSANCE", name = "Renaissance Spirit", rarity = 2, tags = {"CULTURE"}, max = 2,
	desc = "All cities [COLOR_POSITIVE_TEXT]+15%[ENDCOLOR] [ICON_CULTURE] Culture per stack.",
	building = "BUILDING_RL_RENAISSANCE", scope = "all" }

Card{ id = "GOLDEN_PROPHECY", name = "Golden Prophecy", rarity = 2, tags = {"CULTURE", "FATE"},
	desc = "Immediately begin a [ICON_GOLDEN_AGE] Golden Age (10 turns). Golden Ages last 25% longer.",
	building = "BUILDING_RL_GOLDEN_PROPHECY", scope = "capital",
	onAcquire = function(pid) Fx().GoldenAge(pid, 10) end }

Card{ id = "SPYMASTER", name = "Spymaster", rarity = 2, tags = {"CULTURE", "SCIENCE"},
	desc = "Gain [COLOR_POSITIVE_TEXT]+1[ENDCOLOR] [ICON_SPY] Spy.",
	building = "BUILDING_RL_SPYMASTER", scope = "capital",
	requires = { building = "BUILDING_RL_SPYMASTER", column = "ExtraSpies", value = 1 } }

Card{ id = "MUSEUM", name = "Grand Museum", rarity = 3, tags = {"CULTURE"},
	desc = "Great Works produce [COLOR_POSITIVE_TEXT]+25%[ENDCOLOR] [ICON_TOURISM] Tourism; all cities +1 [ICON_CULTURE].",
	building = "BUILDING_RL_MUSEUM", scope = "all",
	requires = { building = "BUILDING_RL_MUSEUM", column = "GreatWorksTourismModifier", value = 25 } }

Card{ id = "PHILOSOPHER_KINGS", name = "Philosopher Kings", rarity = 4, tags = {"CULTURE"},
	desc = "Immediately gain [ICON_CULTURE] Culture equal to your next Social Policy, and again every time you enter a new era.",
	onAcquire = function(pid) Fx().PolicyCulture(pid, 1.0) end,
	onEra = function(pid) Fx().PolicyCulture(pid, 1.0) end }

-- =========================== FAITH ===========================
Card{ id = "SHRINES", name = "Wayside Shrines", rarity = 1, tags = {"FAITH"}, max = 3,
	desc = "All cities [COLOR_POSITIVE_TEXT]+2[ENDCOLOR] [ICON_PEACE] Faith per stack.",
	building = "BUILDING_RL_SHRINES", scope = "all" }

Card{ id = "TITHES", name = "Tithes", rarity = 1, tags = {"FAITH", "GOLD"}, max = 3,
	desc = "All cities [COLOR_POSITIVE_TEXT]+1[ENDCOLOR] [ICON_PEACE] Faith and +1 [ICON_GOLD] Gold per stack.",
	building = "BUILDING_RL_TITHES", scope = "all" }

Card{ id = "ZEALOTS", name = "Zealots", rarity = 2, tags = {"FAITH"},
	desc = "Your cities exert [COLOR_POSITIVE_TEXT]+50%[ENDCOLOR] religious pressure.",
	building = "BUILDING_RL_ZEALOTS", scope = "all",
	requires = { building = "BUILDING_RL_ZEALOTS", column = "ReligiousPressureModifier", value = 50 } }

Card{ id = "MARTYRDOM", name = "Martyrdom", rarity = 2, tags = {"FAITH", "WAR"},
	desc = "Whenever one of your units is destroyed, gain [ICON_PEACE] Faith (10 + 5 per era).",
	onLoss = function(pid, s) Fx().Faith(pid, Fx().Amt(pid, 10, 5) * s) end }

Card{ id = "PILGRIMAGE", name = "Great Pilgrimage", rarity = 3, tags = {"FAITH"},
	desc = "Every 10 turns pilgrims bring [ICON_PEACE] Faith (30 + 20 per era) and [ICON_GOLD] Gold (20 + 10 per era).",
	onTurn = function(pid, s, turn)
		if Fx().Every(turn, 10) then
			Fx().Faith(pid, Fx().Amt(pid, 30, 20) * s, "Pilgrims arrive")
			Fx().Gold(pid, Fx().Amt(pid, 20, 10) * s)
		end
	end }

Card{ id = "ABSOLUTION", name = "Absolution", rarity = 3, tags = {"FAITH", "FATE"}, max = 3,
	desc = "Cleanse [COLOR_POSITIVE_TEXT]all Curses[ENDCOLOR] currently afflicting your empire.",
	requires = function(pid) return RL.Fx.CurseCount(pid) > 0 end,
	onAcquire = function(pid) Fx().CleanseCurses(pid, 99) end }

-- =========================== INDUSTRY ===========================
Card{ id = "MASONS", name = "Master Masons", rarity = 1, tags = {"BUILD"}, max = 3,
	desc = "All cities [COLOR_POSITIVE_TEXT]+2[ENDCOLOR] [ICON_PRODUCTION] Production per stack.",
	building = "BUILDING_RL_MASONS", scope = "all" }

Card{ id = "WORKERS_UNION", name = "Workers' Union", rarity = 1, tags = {"BUILD"}, max = 2,
	desc = "Immediately gain [COLOR_POSITIVE_TEXT]2 Workers[ENDCOLOR] in your capital.",
	onAcquire = function(pid, s, gained) Fx().SpawnRole(pid, "WORKER", 2 * gained) end }

Card{ id = "ARCHITECTS", name = "Royal Architects", rarity = 2, tags = {"BUILD"}, max = 2,
	desc = "[COLOR_POSITIVE_TEXT]+15%[ENDCOLOR] [ICON_PRODUCTION] Production toward buildings in all cities per stack.",
	building = "BUILDING_RL_ARCHITECTS", scope = "all" }

Card{ id = "WONDERS", name = "Wonder Architects", rarity = 2, tags = {"BUILD", "CULTURE"}, max = 2,
	desc = "[COLOR_POSITIVE_TEXT]+25%[ENDCOLOR] [ICON_PRODUCTION] Production toward Wonders in all cities per stack.",
	building = "BUILDING_RL_WONDERS", scope = "all" }

Card{ id = "INDUSTRY", name = "Industrious", rarity = 3, tags = {"BUILD"}, max = 2,
	desc = "All cities [COLOR_POSITIVE_TEXT]+10%[ENDCOLOR] [ICON_PRODUCTION] Production per stack.",
	building = "BUILDING_RL_INDUSTRY", scope = "all" }

Card{ id = "IMPERIAL_SEAT", name = "Imperial Seat", rarity = 3, tags = {"BUILD", "GOLD", "SCIENCE"}, max = 2,
	desc = "Capital: [COLOR_POSITIVE_TEXT]+3[ENDCOLOR] [ICON_PRODUCTION], +3 [ICON_RESEARCH], +3 [ICON_GOLD], +2 [ICON_CULTURE], +2 [ICON_HAPPINESS_1] per stack.",
	building = "BUILDING_RL_IMPERIAL_SEAT", scope = "capital" }

-- =========================== FATE ===========================
Card{ id = "CIRCUSES", name = "Bread and Circuses", rarity = 1, tags = {"FATE"}, max = 3,
	desc = "[COLOR_POSITIVE_TEXT]+2[ENDCOLOR] [ICON_HAPPINESS_1] Happiness per stack.",
	building = "BUILDING_RL_CIRCUSES", scope = "capital" }

Card{ id = "TREASURE_MAP", name = "Treasure Map", rarity = 1, tags = {"FATE", "GOLD"}, max = 3,
	desc = "Dig up [COLOR_POSITIVE_TEXT]3 random treasures[ENDCOLOR] ([ICON_GOLD], [ICON_CULTURE], [ICON_PEACE] or [ICON_RESEARCH]).",
	onAcquire = function(pid, s, gained) for i = 1, 3 * gained do Fx().Treasure(pid) end end }

Card{ id = "CARTOGRAPHY", name = "Cartographers", rarity = 1, tags = {"FATE", "SEA"},
	desc = "Reveal the land within 12 tiles of your capital. Land units gain +1 Sight.",
	promo = "PROMOTION_RL_SCOUTS_EYE", filter = "LAND",
	onAcquire = function(pid) Fx().RevealAround(pid, 12) end }

Card{ id = "LOCAL_PRIDE", name = "Local Pride", rarity = 2, tags = {"FATE"}, max = 2,
	desc = "All cities [COLOR_POSITIVE_TEXT]+1[ENDCOLOR] [ICON_HAPPINESS_1] Happiness per stack.",
	building = "BUILDING_RL_LOCAL_PRIDE", scope = "all" }

Card{ id = "LUCKY_COIN", name = "Lucky Coin", rarity = 2, tags = {"FATE"}, max = 3, humanOnly = true,
	desc = "[COLOR_POSITIVE_TEXT]+2 Rerolls[ENDCOLOR] and better odds of rare cards in future drafts.",
	onAcquire = function(pid, s, gained) Fx().Rerolls(2 * gained); Fx().Luck(8 * gained) end }

Card{ id = "ECHOES", name = "Echoing Victories", rarity = 3, tags = {"FATE", "WAR"}, humanOnly = true,
	desc = "Every Era Warlord you slay grants an [COLOR_POSITIVE_TEXT]additional draft[ENDCOLOR].",
	onBoss = function(pid, s) Fx().QueueDraft("Echoing Victory", 2) end }

Card{ id = "TIME_DILATION", name = "Time Dilation", rarity = 4, tags = {"FATE"}, humanOnly = true,
	desc = "All future drafts offer [COLOR_POSITIVE_TEXT]+1 card[ENDCOLOR]. Gain 2 Rerolls.",
	onAcquire = function(pid) Fx().ExtraChoice(1); Fx().Rerolls(2) end }

Card{ id = "PHOENIX", name = "Phoenix Feather", rarity = 4, tags = {"FATE"}, humanOnly = true, max = 2,
	desc = "[COLOR_POSITIVE_TEXT]Extra life.[ENDCOLOR] The next time your run would end, rise from the ashes instead.",
	onAcquire = function(pid, s, gained) Fx().ExtraLife(gained) end }

-- =========================== CHAMPION ===========================
Card{ id = "HERO_TRAINING", name = "Hero's Training", rarity = 1, tags = {"HERO"}, max = 3, humanOnly = true,
	desc = "Your Champion gains [COLOR_POSITIVE_TEXT]30 XP[ENDCOLOR] and is fully healed.",
	onAcquire = function(pid, s, gained) Fx().ChampionXP(30 * gained); Fx().ChampionHeal() end }

Card{ id = "CHAMPION_ARMOR", name = "Mythril Plate", rarity = 2, tags = {"HERO"}, humanOnly = true,
	desc = "Your Champion gains [COLOR_POSITIVE_TEXT]+25%[ENDCOLOR] [ICON_STRENGTH] Combat Strength.",
	promo = "PROMOTION_RL_CHAMPION_ARMOR", filter = "CHAMPION" }

Card{ id = "SAGAS", name = "Sagas of the Hero", rarity = 2, tags = {"HERO", "CULTURE"}, humanOnly = true,
	desc = "Each new era your Champion gains 40 XP and you gain [ICON_CULTURE] Culture (25 + 25 per era).",
	onEra = function(pid, s) Fx().ChampionXP(40 * s); Fx().Culture(pid, Fx().Amt(pid, 25, 25) * s) end }

Card{ id = "BLOOD_OATH", name = "Blood Oath", rarity = 3, tags = {"HERO"}, humanOnly = true,
	desc = "Your Champion fully heals every turn and returns from death 4 turns sooner.",
	onTurn = function(pid) Fx().ChampionHeal() end }

Card{ id = "COLOSSAL_HERO", name = "Colossus Reborn", rarity = 4, tags = {"HERO", "WAR"}, humanOnly = true,
	desc = "Your Champion gains [COLOR_POSITIVE_TEXT]+50%[ENDCOLOR] [ICON_STRENGTH] and +1 [ICON_MOVES] Movement.",
	promo = "PROMOTION_RL_COLOSSAL_HERO", filter = "CHAMPION" }

-- =========================== CURSES ===========================
Curse{ id = "FAMINE", name = "Famine", desc = "All cities -1 [ICON_FOOD] Food per stack.",
	building = "BUILDING_RL_CURSE_FAMINE", scope = "all" }
Curse{ id = "CORRUPTION", name = "Corruption", desc = "All cities -10% [ICON_GOLD] Gold per stack.",
	building = "BUILDING_RL_CURSE_CORRUPTION", scope = "all" }
Curse{ id = "UNREST", name = "Unrest", desc = "-2 [ICON_HAPPINESS_4] Happiness per stack.",
	building = "BUILDING_RL_CURSE_UNREST", scope = "capital" }
Curse{ id = "DECAY", name = "Decay", desc = "All cities -10% [ICON_PRODUCTION] Production per stack.",
	building = "BUILDING_RL_CURSE_DECAY", scope = "all" }
Curse{ id = "DARK_AGES", name = "Dark Ages", desc = "All cities -10% [ICON_RESEARCH] Science per stack.",
	building = "BUILDING_RL_CURSE_DARK_AGES", scope = "all" }
Curse{ id = "WEARY", name = "Weariness", desc = "All cities -15% [ICON_CULTURE] Culture per stack.",
	building = "BUILDING_RL_CURSE_WEARY", scope = "all" }
Curse{ id = "CURSED_GOLD", name = "Cursed Gold", desc = "All cities -2 [ICON_GOLD] Gold per stack.",
	building = "BUILDING_RL_CURSE_CURSED_GOLD", scope = "all" }
Curse{ id = "HERESY", name = "Heresy", desc = "All cities -1 [ICON_PEACE] Faith per stack.",
	building = "BUILDING_RL_CURSE_HERESY", scope = "all" }
Curse{ id = "BLOODLUST", name = "Bloodlust of the Horde", desc = "Horde raids bring +1 extra unit per stack." }
Curse{ id = "HUBRIS", name = "Hubris", desc = "Era Warlords bring +1 extra escort per stack." }
Curse{ id = "HAUNTED", name = "Haunted", desc = "Every 20 turns, restless dead (2 hostile units per stack) rise near one of your cities.",
	onTurn = function(pid, s, turn) if Fx().Every(turn, 20) then Fx().SpawnHostilesNear(pid, 2 * s, "The restless dead rise!") end end }
Curse{ id = "BAD_OMENS", name = "Bad Omens", max = 1, desc = "Drafts offer one fewer card (minimum 2)." }

-- Index by id
RL.CardById = {}
for _, c in ipairs(RL.Cards) do RL.CardById[c.id] = c end
for _, c in ipairs(RL.Curses) do RL.CardById[c.id] = c end

-- Synergy sets: owning N cards (counting stacks) with a tag unlocks a bonus.
RL.Synergies = {
	{ tag = "WAR",     need = 5, name = "Warborn",      desc = "+15 XP to all newly trained units (via an extra Warcamps stack).", building = "BUILDING_RL_WARCAMPS", scope = "all" },
	{ tag = "GOLD",    need = 5, name = "Tycoon",       desc = "+10% Gold in all cities.", building = "BUILDING_RL_TAX_COLLECTORS", scope = "all" },
	{ tag = "SCIENCE", need = 5, name = "Enlightened",  desc = "+10% Science in all cities.", building = "BUILDING_RL_BRAINSTORM", scope = "all" },
	{ tag = "GROWTH",  need = 5, name = "Cornucopia",   desc = "+10% Food in all cities.", building = "BUILDING_RL_HARVEST", scope = "all" },
	{ tag = "CULTURE", need = 5, name = "Patron of Arts", desc = "+15% Culture in all cities.", building = "BUILDING_RL_RENAISSANCE", scope = "all" },
	{ tag = "FAITH",   need = 5, name = "Theocrat",     desc = "+2 Faith in all cities.", building = "BUILDING_RL_SHRINES", scope = "all" },
	{ tag = "BUILD",   need = 5, name = "Engineer-King", desc = "+10% Production in all cities.", building = "BUILDING_RL_INDUSTRY", scope = "all" },
	{ tag = "SEA",     need = 4, name = "Thalassocracy", desc = "+1 Trade Route.", building = "BUILDING_RL_TRADE_WINDS", scope = "capital" },
	{ tag = "FATE",    need = 5, name = "Fortune's Child", desc = "+1 Happiness in all cities.", building = "BUILDING_RL_LOCAL_PRIDE", scope = "all" },
	{ tag = "HERO",    need = 3, name = "Living Legend", desc = "Champion gains Warmaster (+15% Combat Strength, heals after acting).", promo = "PROMOTION_RL_WARMASTER", filter = "CHAMPION" },
}
