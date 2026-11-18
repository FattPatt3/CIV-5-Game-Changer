-- =====================================================================
-- ASCENSION: ROGUELITE OVERHAUL -- World data
-- Era unit tables, Era Warlords (bosses), Quests, Ascension levels,
-- Legacy upgrades (meta-progression) and Origins.
-- =====================================================================

RL = RL or {}
local Fx = function() return RL.Fx end

-- ---------------------------------------------------------------------
-- Units by era and role. Missing types are skipped automatically, so
-- this also works if another mod removes a unit.
-- ---------------------------------------------------------------------
RL.EraUnits = {
	[0] = { MELEE = {"UNIT_SPEARMAN", "UNIT_WARRIOR"}, RANGED = {"UNIT_ARCHER"}, MOUNTED = {"UNIT_CHARIOT_ARCHER", "UNIT_SPEARMAN"}, SIEGE = {"UNIT_ARCHER"} },
	[1] = { MELEE = {"UNIT_SWORDSMAN"}, RANGED = {"UNIT_COMPOSITE_BOWMAN"}, MOUNTED = {"UNIT_HORSEMAN"}, SIEGE = {"UNIT_CATAPULT"} },
	[2] = { MELEE = {"UNIT_LONGSWORDSMAN", "UNIT_PIKEMAN"}, RANGED = {"UNIT_CROSSBOWMAN"}, MOUNTED = {"UNIT_KNIGHT"}, SIEGE = {"UNIT_TREBUCHET"} },
	[3] = { MELEE = {"UNIT_MUSKETMAN"}, RANGED = {"UNIT_CROSSBOWMAN"}, MOUNTED = {"UNIT_LANCER"}, SIEGE = {"UNIT_CANNON"} },
	[4] = { MELEE = {"UNIT_RIFLEMAN"}, RANGED = {"UNIT_GATLINGGUN"}, MOUNTED = {"UNIT_CAVALRY"}, SIEGE = {"UNIT_ARTILLERY"} },
	[5] = { MELEE = {"UNIT_GREAT_WAR_INFANTRY", "UNIT_RIFLEMAN"}, RANGED = {"UNIT_MACHINE_GUN", "UNIT_GATLINGGUN"}, MOUNTED = {"UNIT_LANDSHIP", "UNIT_CAVALRY"}, SIEGE = {"UNIT_ARTILLERY"} },
	[6] = { MELEE = {"UNIT_INFANTRY"}, RANGED = {"UNIT_MACHINE_GUN"}, MOUNTED = {"UNIT_TANK"}, SIEGE = {"UNIT_ROCKET_ARTILLERY", "UNIT_ARTILLERY"} },
	[7] = { MELEE = {"UNIT_MECHANIZED_INFANTRY"}, RANGED = {"UNIT_MACHINE_GUN"}, MOUNTED = {"UNIT_MODERN_ARMOR"}, SIEGE = {"UNIT_ROCKET_ARTILLERY"} },
}
-- Non-combat roles: first one the player can use
RL.RoleUnits = {
	WORKER  = {"UNIT_WORKER"},
	SETTLER = {"UNIT_SETTLER"},
	SCOUT   = {"UNIT_SCOUT"},
	NAVAL   = {"UNIT_DESTROYER", "UNIT_IRONCLAD", "UNIT_FRIGATE", "UNIT_GALLEASS", "UNIT_TRIREME"},
}

-- Champion tiers by era (unit types are defined in RL_Units.sql)
RL.ChampionTierByEra = { [0] = 1, [1] = 1, [2] = 2, [3] = 2, [4] = 3, [5] = 4, [6] = 4, [7] = 5 }
RL.ChampionRespawnTurns = 8

-- ---------------------------------------------------------------------
-- Era Warlords. Index 0 arrives on a timer; 1..7 arrive as your empire
-- enters each new era. Slaying index 6 (the Atomic-era Tyrant) wins the
-- run; index 7 is the optional "endless" warlord.
-- ---------------------------------------------------------------------
RL.FINAL_BOSS = 6
RL.FIRST_BOSS_TURN = 55   -- standard speed, scaled

RL.Bosses = {
	[0] = { name = "Grak, the Bandit King", role = "MELEE", escorts = {"MELEE", "RANGED", "MELEE"},
		flavor = "The hill-tribes have rallied behind a brute who has never lost a fight. Grak's war-band marches on your lands, eager for loot and slaves." },
	[1] = { name = "Temujar, the Iron Khan", role = "MOUNTED", escorts = {"MOUNTED", "MOUNTED", "RANGED"},
		flavor = "A storm of hooves rolls over the steppe. The Iron Khan has united the riders of the plains and swears your cities will burn before winter." },
	[2] = { name = "The Black Abbot", role = "MELEE", escorts = {"MELEE", "SIEGE", "RANGED", "MELEE"},
		flavor = "A fallen monastery has become a fortress of heretics. Its Abbot preaches that your empire is the beast of the end times - and his zealots believe him." },
	[3] = { name = "Captain Vexx, Corsair Lord", role = "MELEE", escorts = {"MELEE", "SIEGE", "MOUNTED", "RANGED"},
		flavor = "Corsairs have come ashore with stolen cannon. Captain Vexx has a price on every head in your capital, and a crew that collects." },
	[4] = { name = "Colonel Ashgrave", role = "MOUNTED", escorts = {"MELEE", "SIEGE", "MOUNTED", "RANGED", "MELEE"},
		flavor = "A deserter colonel and his rogue regiment have turned to warlordism. Ashgrave fights with modern rifles and an old grudge." },
	[5] = { name = "The Iron Behemoth", role = "MOUNTED", escorts = {"MELEE", "SIEGE", "RANGED", "MELEE", "MOUNTED"},
		flavor = "Something vast crawls out of the mud of the last war - a land-ironclad crewed by men who never stopped fighting it." },
	[6] = { name = "General Null, the Tyrant", role = "MOUNTED", escorts = {"MOUNTED", "MELEE", "SIEGE", "RANGED", "MELEE", "MOUNTED"},
		flavor = "The final Warlord. General Null commands an army without a nation and a doctrine without mercy. Defeat it and your Ascension is complete." },
	[7] = { name = "The Ascended", role = "MOUNTED", escorts = {"MOUNTED", "MOUNTED", "MELEE", "SIEGE", "SIEGE", "RANGED", "MELEE"},
		flavor = "Beyond the end of history waits a power that feeds on victory itself. It has watched your entire run. Now it wants your crown." },
}

-- ---------------------------------------------------------------------
-- Quests (Bounties). metric(pid) returns a number; `relative` quests
-- measure growth from the moment the quest is accepted.
-- ---------------------------------------------------------------------
local function CountWonders(p)
	local n = 0
	for city in p:Cities() do
		for b in GameInfo.Buildings() do
			local cls = GameInfo.BuildingClasses[b.BuildingClass]
			if cls and cls.MaxGlobalInstances == 1 and city:IsHasBuilding(b.ID) then n = n + 1 end
		end
	end
	return n
end

local function TotalPop(p)
	local n = 0
	for city in p:Cities() do n = n + city:GetPopulation() end
	return n
end

local function TechCount(p)
	local team = Teams[p:GetTeam()]
	local n = 0
	for t in GameInfo.Technologies() do if team:IsHasTech(t.ID) then n = n + 1 end end
	return n
end

RL.Quests = {
	{ id = "SLAYER", name = "Slayer", relative = true, duration = 20,
		metric = function(pid) return RL.State and RL.State.stats.kills or 0 end,
		target = function(pid, era) return 3 + era end,
		desc = "Destroy %d enemy units." },
	{ id = "SCHOLAR", name = "Scholar", relative = true, duration = 25,
		metric = function(pid) return TechCount(Players[pid]) end,
		target = function(pid, era) return 3 end,
		desc = "Research %d technologies." },
	{ id = "GROWTH", name = "Population Boom", relative = true, duration = 25,
		metric = function(pid) return TotalPop(Players[pid]) end,
		target = function(pid, era) return 4 + math.floor(Players[pid]:GetNumCities() / 2) end,
		desc = "Grow your total population by %d." },
	{ id = "HOARD", name = "Dragon's Hoard", relative = false, duration = 20,
		metric = function(pid) return Players[pid]:GetGold() end,
		target = function(pid, era) return math.max(Players[pid]:GetGold() + 150, RL.Fx.Amt(pid, 300, 200)) end,
		desc = "Hold at least %d [ICON_GOLD] Gold in your treasury." },
	{ id = "WONDER", name = "Monument to Ages", relative = true, duration = 30,
		metric = function(pid) return CountWonders(Players[pid]) end,
		target = function() return 1 end,
		desc = "Complete %d World Wonder." },
	{ id = "SETTLE", name = "New Horizons", relative = false, duration = 30,
		metric = function(pid) return Players[pid]:GetNumCities() end,
		target = function(pid) return Players[pid]:GetNumCities() + 1 end,
		cond = function(pid) return Players[pid]:GetNumCities() < 8 end,
		desc = "Control %d cities." },
	{ id = "POLICY", name = "Philosopher", relative = true, duration = 25,
		metric = function(pid) return Players[pid]:GetNumPolicies() end,
		target = function() return 2 end,
		desc = "Adopt %d Social Policies." },
	{ id = "CHAMPION", name = "Trial of the Champion", relative = false, duration = 25,
		metric = function(pid) return RL.Fx.ChampionLevel() end,
		target = function() return RL.Fx.ChampionLevel() + 1 end,
		cond = function(pid) return RL.Fx.ChampionLevel() > 0 end,
		desc = "Raise your Champion to level %d." },
	{ id = "FAITH", name = "Devotion", relative = false, duration = 20,
		metric = function(pid) return Players[pid]:GetFaith() end,
		target = function(pid, era) return Players[pid]:GetFaith() + RL.Fx.Amt(pid, 60, 40) end,
		desc = "Accumulate %d [ICON_PEACE] Faith." },
}

-- ---------------------------------------------------------------------
-- Ascension levels (cumulative difficulty, Slay-the-Spire style)
-- ---------------------------------------------------------------------
RL.MAX_ASCENSION = 10
RL.Ascensions = {
	[1]  = { name = "Restless Horde",      desc = "Horde raids come 20% more often." },
	[2]  = { name = "Swelling Ranks",      desc = "Horde raids bring +1 unit." },
	[3]  = { name = "Veteran Raiders",     desc = "Horde units are Veterans (+15% Combat Strength)." },
	[4]  = { name = "Envious Rivals",      desc = "AI empires receive an extra Boon every era." },
	[5]  = { name = "Last Stand",          desc = "If your Champion dies, the run ends." },
	[6]  = { name = "Lean Times",          desc = "All cities -10% Gold and -10% Production." },
	[7]  = { name = "Marked",              desc = "Begin the run with a random Curse." },
	[8]  = { name = "Warlords Ascendant",  desc = "Era Warlords are Ascendant (+25%) and bring 2 more escorts." },
	[9]  = { name = "Scarcity",            desc = "Drafts offer one fewer card." },
	[10] = { name = "The Long Night",      desc = "Horde raids begin 10 turns earlier and grow twice as fast." },
}

-- ---------------------------------------------------------------------
-- Legacy upgrades (permanent, bought with Legacy between/at runs)
-- ---------------------------------------------------------------------
RL.LegacyUpgrades = {
	{ id = "INHERITANCE", name = "Inheritance", costs = {4, 10, 20},
		desc = "Start each run with +75 [ICON_GOLD] Gold per rank." },
	{ id = "VETERAN", name = "Veteran Champion", costs = {5, 12, 25},
		desc = "Your Champion starts with +20 XP per rank." },
	{ id = "FORTUNE", name = "Fortune's Favor", costs = {4, 10, 20},
		desc = "Start with +1 Reroll per rank, and gain +1 Reroll every era at rank 3." },
	{ id = "KEEN_EYE", name = "Keen Eye", costs = {8, 20},
		desc = "Better odds of Rare, Epic and Legendary cards (+8 luck per rank)." },
	{ id = "GAMBIT", name = "Opening Gambit", costs = {12},
		desc = "Begin each run with a bonus draft of Rare-or-better cards." },
	{ id = "SCHOLAR", name = "Ancestral Lore", costs = {10, 25},
		desc = "Begin each run knowing 1 random extra technology per rank." },
	{ id = "PIONEER", name = "Pioneer Spirit", costs = {30},
		desc = "Begin each run with an extra Settler." },
	{ id = "BULWARK", name = "Ancestral Bulwark", costs = {8},
		desc = "Your capital gains +8 Defense and +100 HP." },
	{ id = "LEGENDS", name = "Book of Legends", costs = {12},
		desc = "Legendary cards can appear in ordinary drafts (otherwise only from Warlords)." },
	{ id = "WIDER", name = "Wider Horizons", costs = {40},
		desc = "All drafts offer +1 card." },
	{ id = "HAGGLER", name = "Silver Tongue", costs = {15},
		desc = "Event costs in Gold are 25% cheaper." },
	{ id = "SECOND_WIND", name = "Second Wind", costs = {50},
		desc = "Start each run with an extra life." },
}
RL.LegacyById = {}
for _, u in ipairs(RL.LegacyUpgrades) do RL.LegacyById[u.id] = u end

-- ---------------------------------------------------------------------
-- Origins (pick one per run, StS-style starting relic)
-- ---------------------------------------------------------------------
RL.Origins = {
	{ id = "WARBORN", name = "Warborn", cost = 0,
		desc = "Start with [COLOR_POSITIVE_TEXT]Iron Discipline[ENDCOLOR] and an extra Warrior.",
		apply = function(pid) Fx().GrantCard(pid, "IRON_DISCIPLINE", true); Fx().SpawnUnitType(pid, "UNIT_WARRIOR", 1) end },
	{ id = "MERCHANT", name = "Merchant Prince", cost = 0,
		desc = "Start with [COLOR_POSITIVE_TEXT]Merchant Guilds[ENDCOLOR] and +100 [ICON_GOLD] Gold.",
		apply = function(pid) Fx().GrantCard(pid, "MERCHANT_GUILDS", true); Fx().Gold(pid, 100) end },
	{ id = "SAGE", name = "Sage", cost = 0,
		desc = "Start with [COLOR_POSITIVE_TEXT]Libraries of Old[ENDCOLOR] and 1 free technology.",
		apply = function(pid) Fx().GrantCard(pid, "LIBRARIES", true); Fx().FreeTech(pid) end },
	{ id = "PROPHET", name = "Prophet", cost = 8,
		desc = "Start with [COLOR_POSITIVE_TEXT]Wayside Shrines[ENDCOLOR] and 25 [ICON_PEACE] Faith.",
		apply = function(pid) Fx().GrantCard(pid, "SHRINES", true); Fx().Faith(pid, 25) end },
	{ id = "BUILDER", name = "Builder", cost = 8,
		desc = "Start with [COLOR_POSITIVE_TEXT]Master Masons[ENDCOLOR] and an extra Worker.",
		apply = function(pid) Fx().GrantCard(pid, "MASONS", true); Fx().SpawnUnitType(pid, "UNIT_WORKER", 1) end },
	{ id = "HEARTLAND", name = "Heartland", cost = 10,
		desc = "Every city gets [COLOR_POSITIVE_TEXT]+1 Food, +1 Production and +1 Happiness[ENDCOLOR] for the whole run.",
		apply = function(pid) Fx().GrantCard(pid, "ORIGIN_HEARTLAND", true) end },
	{ id = "SEAFARER", name = "Seafarer", cost = 10,
		desc = "Start with [COLOR_POSITIVE_TEXT]Bountiful Seas[ENDCOLOR] and [COLOR_POSITIVE_TEXT]Cartographers[ENDCOLOR].",
		apply = function(pid) Fx().GrantCard(pid, "BOUNTIFUL_SEAS", true); Fx().GrantCard(pid, "CARTOGRAPHY", true) end },
	{ id = "HEROIC", name = "Heroic Lineage", cost = 15,
		desc = "Start with [COLOR_POSITIVE_TEXT]Mythril Plate[ENDCOLOR] and your Champion begins with +30 XP.",
		apply = function(pid) Fx().GrantCard(pid, "CHAMPION_ARMOR", true); Fx().ChampionXP(30) end },
	{ id = "CURSED", name = "The Cursed One", cost = 25,
		desc = "Start with [COLOR_NEGATIVE_TEXT]2 random Curses[ENDCOLOR] and a [COLOR_YIELD_GOLD]Legendary draft[ENDCOLOR]. Earn +50% Legacy.",
		legacyBonus = 50,
		apply = function(pid) Fx().AddCurse(pid); Fx().AddCurse(pid); Fx().QueueDraft("The Cursed One", 4) end },
}
RL.OriginById = {}
for _, o in ipairs(RL.Origins) do RL.OriginById[o.id] = o end

-- Hidden card used by the Heartland origin (never drafted)
RL.Cards[#RL.Cards + 1] = { id = "ORIGIN_HEARTLAND", name = "Heartland", rarity = 1, tags = {"GROWTH"}, max = 1, hidden = true,
	desc = "Origin: every city +1 Food, +1 Production, +1 Happiness.", building = "BUILDING_RL_HEARTLAND", scope = "all" }
RL.Cards[#RL.Cards + 1] = { id = "LEGACY_BULWARK", name = "Ancestral Bulwark", rarity = 1, tags = {"WAR"}, max = 1, hidden = true,
	desc = "Legacy: capital +8 Defense and +100 HP.", building = "BUILDING_RL_BULWARK", scope = "capital" }
RL.Cards[#RL.Cards + 1] = { id = "ASC_LEAN", name = "Lean Times", rarity = 1, tags = {}, max = 1, hidden = true,
	desc = "Ascension: all cities -10% Gold and Production.", building = "BUILDING_RL_ASC_LEAN", scope = "all" }
for _, c in ipairs(RL.Cards) do RL.CardById[c.id] = c end

-- ---------------------------------------------------------------------
-- Legacy (meta-currency) awards
-- ---------------------------------------------------------------------
RL.LegacyAwards = {
	ERA      = 1,   -- per new era reached
	BOSS     = 3,   -- per Era Warlord slain
	QUEST    = 1,   -- per quest completed
	RUN_WON  = 10,  -- Final Warlord slain
	CIV_WIN  = 10,  -- any standard victory
	DEFEAT   = 1,   -- consolation
}
