-- =====================================================================
-- ASCENSION: ROGUELITE OVERHAUL -- Engine
--
-- Owns the run state (saved inside the savegame), the meta-progression
-- store (saved in the user's profile, shared by all games), and every
-- gameplay system: boons, curses, drafts, events, the Horde, Era
-- Warlords, quests, the Champion and the run's win/lose conditions.
--
-- The UI layer (UI/AscensionRoguelite.lua) registers RL.UI callbacks.
-- =====================================================================

RL = RL or {}
RL.Fx = RL.Fx or {}
RL.UI = RL.UI or {}
local Fx = RL.Fx

RL.VERSION = 1
RL.SAVE_KEY = "ASCENSION_RL_STATE"
RL.META_NAME = "AscensionRoguelite"

-- ---------------------------------------------------------------------
-- Key/value stores (save data & user data). The binding style of
-- GetValue/SetValue (dot vs colon) is probed so either works.
-- ---------------------------------------------------------------------
local function MakeStore(obj)
	if not obj then return nil end
	local colon = false
	local ok = pcall(function() return obj.GetValue("__rl_probe") end)
	if not ok then colon = true end
	local store = {}
	function store.Get(k)
		local okk, v
		if colon then okk, v = pcall(function() return obj:GetValue(k) end)
		else okk, v = pcall(function() return obj.GetValue(k) end) end
		if okk then return v end
		return nil
	end
	function store.Set(k, v)
		if colon then pcall(function() obj:SetValue(k, v) end)
		else pcall(function() obj.SetValue(k, v) end) end
	end
	return store
end

local saveStore, metaStore

function RL.OpenStores()
	if not saveStore then
		local ok, obj = pcall(function() return Modding.OpenSaveData() end)
		if ok then saveStore = MakeStore(obj) end
	end
	if not metaStore then
		local ok, obj = pcall(function() return Modding.OpenUserData(RL.META_NAME, 1) end)
		if ok then metaStore = MakeStore(obj) end
	end
end

-- ---------------------------------------------------------------------
-- Meta progression (persists across every game you play)
-- ---------------------------------------------------------------------
RL.Meta = {}
local metaCache = {}

function RL.Meta.Get(k, default)
	if metaCache[k] ~= nil then return metaCache[k] end
	local v = metaStore and metaStore.Get(k)
	if v == nil then v = default end
	metaCache[k] = v
	return v
end

function RL.Meta.Set(k, v)
	metaCache[k] = v
	if metaStore then metaStore.Set(k, v) end
end

function RL.Meta.Num(k) return tonumber(RL.Meta.Get(k, 0)) or 0 end
function RL.Meta.Add(k, n) RL.Meta.Set(k, RL.Meta.Num(k) + n) end
function RL.Meta.Rank(id) return RL.Meta.Num("up_" .. id) end
function RL.Meta.Legacy() return RL.Meta.Num("legacy") end
function RL.Meta.AscUnlocked() return RL.Meta.Num("ascUnlocked") end
function RL.Meta.OriginUnlocked(id)
	local o = RL.OriginById[id]
	if not o then return false end
	return o.cost == 0 or RL.Meta.Num("origin_" .. id) > 0
end

function RL.Meta.BuyUpgrade(id)
	local u = RL.LegacyById[id]
	if not u then return false end
	local rank = RL.Meta.Rank(id)
	local cost = u.costs[rank + 1]
	if not cost or RL.Meta.Legacy() < cost then return false end
	RL.Meta.Add("legacy", -cost)
	RL.Meta.Set("up_" .. id, rank + 1)
	return true
end

function RL.Meta.BuyOrigin(id)
	local o = RL.OriginById[id]
	if not o or RL.Meta.OriginUnlocked(id) then return false end
	if RL.Meta.Legacy() < o.cost then return false end
	RL.Meta.Add("legacy", -o.cost)
	RL.Meta.Set("origin_" .. id, 1)
	return true
end

-- Legacy awards are keyed by run id + milestone and recorded in the
-- profile, so reloading a save can never award the same milestone twice.
function RL.AwardLegacy(key, base, reason)
	local S = RL.State
	if not S or not S.started or S.noLegacy then return 0 end
	local flag = "aw_" .. S.runId .. "_" .. key
	if RL.Meta.Num(flag) > 0 then return 0 end
	local mult = 100 + 10 * (S.ascension or 0) + (S.legacyBonus or 0)
	local amount = math.max(base, math.floor(base * mult / 100 + 0.5))
	RL.Meta.Set(flag, 1)
	RL.Meta.Add("legacy", amount)
	RL.Meta.Add("legacyTotal", amount)
	S.stats.legacy = (S.stats.legacy or 0) + amount
	RL.LogRun("+" .. amount .. " Legacy: " .. tostring(reason))
	RL.Notify(S.human, "+" .. amount .. " Legacy", "[ICON_GOLDEN_AGE] Legacy earned: " .. tostring(reason) .. " (+" .. amount .. ")")
	return amount
end

function RL.UnlockAscension(level)
	level = math.min(RL.MAX_ASCENSION, level)
	if level > RL.Meta.AscUnlocked() then
		RL.Meta.Set("ascUnlocked", level)
		RL.Notify(RL.State.human, "Ascension " .. level .. " unlocked", "[ICON_TROPHY_GOLD] You have unlocked Ascension " .. level .. " for future runs!")
	end
end

-- ---------------------------------------------------------------------
-- Run state (saved in the savegame)
-- ---------------------------------------------------------------------
RL.State = nil

local function NewState()
	return {
		v = RL.VERSION, started = false, over = false, won = false,
		runId = "", seed = 0, rng = 1, ascension = 0, origin = "",
		human = Game.GetActivePlayer(),
		players = {},
		rerolls = 0, luck = 0, extraChoices = 0, lives = 0, legacyBonus = 0,
		drafts = {}, pending = {}, infos = {},
		temps = {},
		wave = { next = 0, warned = false, bonus = 0, count = 0 },
		boss = { active = false },
		bossesSpawned = {}, bossesSlain = 0,
		quest = nil, nextQuestTurn = 0,
		nextEventTurn = 0, nextMilestone = 0, eventHistory = {},
		champion = { id = -1, tier = 0, deadTurn = -1, xp = 0, level = 1, promos = {}, name = "" },
		capX = -1, capY = -1,
		focus = nil, synergies = {},
		stats = { kills = 0, losses = 0, drafts = 0, events = 0, quests = 0, legacy = 0, cards = 0 },
		log = {},
	}
end

function RL.Save()
	if not RL.State then return end
	RL.State.rng = RL.rngState
	if saveStore then saveStore.Set(RL.SAVE_KEY, RL.Serialize(RL.State)) end
end

function RL.Load()
	RL.OpenStores()
	local s = saveStore and saveStore.Get(RL.SAVE_KEY)
	local st = s and RL.Deserialize(s)
	if type(st) == "table" and st.v then
		RL.State = st
		-- forward-compatible defaults
		local d = NewState()
		for k, v in pairs(d) do if RL.State[k] == nil then RL.State[k] = v end end
		for k, v in pairs(d.stats) do if RL.State.stats[k] == nil then RL.State.stats[k] = v end end
		RL.SeedRNG(RL.State.rng or 1)
	else
		RL.State = NewState()
	end
	return RL.State
end

function RL.LogRun(msg)
	local S = RL.State
	if not S then return end
	table.insert(S.log, 1, "T" .. Game.GetGameTurn() .. ": " .. msg)
	while #S.log > 80 do table.remove(S.log) end
end

function RL.PD(pid)
	local S = RL.State
	local key = pid
	if not S.players[key] then
		S.players[key] = { cards = {}, curses = {}, order = {}, era = 0 }
		local p = Players[pid]
		if p and p:IsAlive() then S.players[key].era = p:GetCurrentEra() end
	end
	return S.players[key]
end

local function IsTracked(pid)
	local p = Players[pid]
	return p and p:IsAlive() and not p:IsMinorCiv() and not p:IsBarbarian()
end
RL.IsTracked = IsTracked

-- ---------------------------------------------------------------------
-- Game-speed scaling
-- ---------------------------------------------------------------------
local speedPct
function RL.Speed()
	if not speedPct then
		speedPct = 1
		local ok, v = pcall(function() return GameInfo.GameSpeeds[Game.GetGameSpeedType()].TrainPercent end)
		if ok and tonumber(v) then speedPct = tonumber(v) / 100 end
	end
	return speedPct
end

function RL.Interval(n) return math.max(1, math.floor(n * RL.Speed() + 0.5)) end

function RL.EraName(e)
	local row = GameInfo.Eras and GameInfo.Eras[e]
	if row then
		local ok, s = pcall(Locale.ConvertTextKey, row.Description)
		if ok and s then return s end
	end
	return "Era " .. tostring(e)
end

-- ---------------------------------------------------------------------
-- Notifications
-- ---------------------------------------------------------------------
function RL.Notify(pid, title, text, x, y)
	local p = Players[pid]
	if not p or not p:IsHuman() then return end
	pcall(function() p:AddNotification(NotificationTypes.NOTIFICATION_GENERIC, text, title, x or -1, y or -1) end)
end

-- =====================================================================
-- EFFECT HELPERS (used by data files)
-- =====================================================================
local function Era(pid) local p = Players[pid]; return (p and p:GetCurrentEra()) or 0 end

function Fx.Amt(pid, base, perEra) return math.floor((base + perEra * Era(pid)) * RL.Speed() + 0.5) end
function Fx.Cost(pid, base, perEra)
	local v = Fx.Amt(pid, base, perEra)
	if RL.Meta.Rank("HAGGLER") > 0 then v = math.floor(v * 0.75) end
	return v
end
function Fx.Every(turn, n) local k = RL.Interval(n); return turn > 0 and turn % k == 0 end

function Fx.Gold(pid, n, msg)
	if n == 0 then return end
	Players[pid]:ChangeGold(n)
	if msg then RL.Notify(pid, msg, msg .. ": " .. (n > 0 and "+" or "") .. n .. " [ICON_GOLD] Gold") end
end
function Fx.Culture(pid, n) if n ~= 0 then Players[pid]:ChangeJONSCulture(n) end end
function Fx.Faith(pid, n, msg)
	if n == 0 then return end
	Players[pid]:ChangeFaith(n)
	if msg then RL.Notify(pid, msg, msg .. ": +" .. n .. " [ICON_PEACE] Faith") end
end
function Fx.GoldenAge(pid, turns) Players[pid]:ChangeGoldenAgeTurns(turns) end

local function CurrentOrAnyTech(p)
	local t = p:GetCurrentResearch()
	if t and t >= 0 then return t end
	for row in GameInfo.Technologies() do
		local ok, can = pcall(function() return p:CanResearch(row.ID) end)
		if ok and can then return row.ID end
	end
	return nil
end

function Fx.Science(pid, n)
	local p = Players[pid]
	local tech = CurrentOrAnyTech(p)
	if not tech or n <= 0 then return end
	local team = Teams[p:GetTeam()]
	RL.Try("Science", function() team:GetTeamTechs():ChangeResearchProgress(tech, n, pid) end)
end

function Fx.ResearchFraction(pid, f)
	local p = Players[pid]
	local tech = CurrentOrAnyTech(p)
	if not tech then return end
	local cost = 100
	pcall(function() cost = p:GetResearchCost(tech) end)
	Fx.Science(pid, math.floor(cost * f))
end

function Fx.FreeTech(pid)
	local p = Players[pid]
	local team = Teams[p:GetTeam()]
	local options = {}
	for row in GameInfo.Technologies() do
		local ok, can = pcall(function() return p:CanResearch(row.ID) and not team:IsHasTech(row.ID) end)
		if ok and can then options[#options + 1] = row end
	end
	local pick = RL.Pick(options)
	if not pick then return nil end
	-- args: tech, value, player credited (defaults to 0 if omitted!), first-to-discover, announce
	pcall(function() team:SetHasTech(pick.ID, true, pid, false, false) end)
	if not team:IsHasTech(pick.ID) then
		local cost = 200
		pcall(function() cost = p:GetResearchCost(pick.ID) end)
		pcall(function() team:GetTeamTechs():ChangeResearchProgress(pick.ID, cost, pid) end)
	end
	RL.Notify(pid, "Free technology", "[ICON_RESEARCH] You learned " .. Locale.ConvertTextKey(pick.Description) .. "!")
	return pick
end

function Fx.PolicyCulture(pid, f)
	local p = Players[pid]
	local cost = 100
	pcall(function() cost = p:GetNextPolicyCost() end)
	Fx.Culture(pid, math.floor(cost * f))
end

-- ---------------- Units ----------------
local function CivType(pid)
	local row = GameInfo.Civilizations[Players[pid]:GetCivilizationType()]
	return row and row.Type
end

-- Swap in the civ's unique unit for a unit's class, if it has one.
function Fx.ResolveForCiv(pid, unitType)
	local u = GameInfo.Units[unitType]
	if not u then return nil end
	local civ = CivType(pid)
	if civ and GameInfo.Civilization_UnitClassOverrides then
		for row in GameInfo.Civilization_UnitClassOverrides{ CivilizationType = civ, UnitClassType = u.Class } do
			if row.UnitType and GameInfo.Units[row.UnitType] then return GameInfo.Units[row.UnitType] end
		end
	end
	return u
end

local function HasTechFor(pid, u)
	if not u.PrereqTech then return true end
	local t = GameInfoTypes[u.PrereqTech]
	if not t then return true end
	return Teams[Players[pid]:GetTeam()]:IsHasTech(t)
end

-- Best unit of a role the player has the tech for (era table, newest first).
function Fx.BestRoleUnit(pid, role, eraCap)
	if RL.RoleUnits[role] then
		for _, t in ipairs(RL.RoleUnits[role]) do
			local u = GameInfo.Units[t]
			if u and HasTechFor(pid, u) then return Fx.ResolveForCiv(pid, t) end
		end
		return nil
	end
	local top = eraCap or 7
	for e = top, 0, -1 do
		local set = RL.EraUnits[e] and RL.EraUnits[e][role]
		if set then
			for _, t in ipairs(set) do
				local u = GameInfo.Units[t]
				if u and (eraCap or HasTechFor(pid, u)) then
					if eraCap then return u end
					return Fx.ResolveForCiv(pid, t)
				end
			end
		end
	end
	return GameInfo.Units["UNIT_WARRIOR"]
end

local function HomePlot(pid)
	local p = Players[pid]
	local cap = p:GetCapitalCity()
	if cap then return cap:Plot() end
	for u in p:Units() do return u:Plot() end
	return p:GetStartingPlot()
end

local function PlaceUnit(pid, unitRow, plot, ai)
	if not unitRow or not plot then return nil end
	local p = Players[pid]
	local unit
	if ai then unit = p:InitUnit(unitRow.ID, plot:GetX(), plot:GetY(), ai)
	else unit = p:InitUnit(unitRow.ID, plot:GetX(), plot:GetY()) end
	if unit and unit:IsCombatUnit() and plot:GetNumUnits() > 1 then
		pcall(function() unit:JumpToNearestValidPlot() end)
	end
	return unit
end

function Fx.SpawnUnitType(pid, unitType, n, plot)
	local row = Fx.ResolveForCiv(pid, unitType)
	plot = plot or HomePlot(pid)
	local last
	for i = 1, (n or 1) do last = PlaceUnit(pid, row, plot) end
	return last
end

function Fx.SpawnRole(pid, role, n)
	local row = Fx.BestRoleUnit(pid, role)
	local plot = HomePlot(pid)
	if not plot or not row then return end
	for i = 1, (n or 1) do PlaceUnit(pid, row, plot) end
	if row then RL.Notify(pid, "Reinforcements", "[ICON_WAR] " .. (n or 1) .. "x " .. Locale.ConvertTextKey(row.Description) .. " joined your army.", plot:GetX(), plot:GetY()) end
end

local championClass
local function IsChampion(unit)
	championClass = championClass or GameInfoTypes.UNITCLASS_RL_CHAMPION
	return championClass and unit:GetUnitClassType() == championClass
end
RL.IsChampion = IsChampion

function Fx.UnitsXP(pid, xp)
	for u in Players[pid]:Units() do
		if u:IsCombatUnit() then
			local ok = pcall(function() u:ChangeExperience(xp) end)
			if not ok then pcall(function() u:SetExperience(u:GetExperience() + xp) end) end
		end
	end
end

local function Heal(u, hp)
	local d = u:GetDamage()
	if d > 0 then pcall(function() u:SetDamage(math.max(0, d - hp)) end) end
end

function Fx.HealUnits(pid, hp)
	for u in Players[pid]:Units() do if u:IsCombatUnit() then Heal(u, hp) end end
end

function Fx.HealUnitsNear(pid, x, y, r, hp)
	for u in Players[pid]:Units() do
		if u:IsCombatUnit() and Map.PlotDistance(x, y, u:GetX(), u:GetY()) <= r then Heal(u, hp) end
	end
end

function Fx.CountMilitary(pid)
	local n = 0
	for u in Players[pid]:Units() do if u:IsCombatUnit() and not IsChampion(u) then n = n + 1 end end
	return n
end

function Fx.KillRandomMilitary(pid)
	local list = {}
	for u in Players[pid]:Units() do if u:IsCombatUnit() and not IsChampion(u) then list[#list + 1] = u end end
	local u = RL.Pick(list)
	if not u then return nil end
	local name = Locale.ConvertTextKey(GameInfo.Units[u:GetUnitType()].Description)
	u:Kill(true, -1)
	return name
end

-- ---------------- Cities ----------------
function Fx.CityPop(city, n)
	if not city then return end
	local target = math.max(1, city:GetPopulation() + n)
	pcall(function() city:ChangePopulation(target - city:GetPopulation(), true) end)
end

function Fx.CapitalPop(pid, n) Fx.CityPop(Players[pid]:GetCapitalCity(), n) end

function Fx.AddPopulation(pid, n, capitalBonus)
	local p = Players[pid]
	for city in p:Cities() do
		Fx.CityPop(city, n)
		if capitalBonus and city:IsCapital() then Fx.CityPop(city, 1) end
	end
end

function Fx.ProductionBurst(pid, n)
	for city in Players[pid]:Cities() do pcall(function() city:ChangeProduction(n) end) end
end

function Fx.DamageCapital(pid, dmg)
	local cap = Players[pid]:GetCapitalCity()
	if not cap then return end
	pcall(function()
		local maxHP = cap:GetMaxHitPoints()
		cap:SetDamage(math.min(maxHP - 1, cap:GetDamage() + dmg))
	end)
end

function Fx.CountCoastal(pid)
	local n = 0
	for city in Players[pid]:Cities() do
		local ok, c = pcall(function() return city:IsCoastal(10) end)
		if ok and c then n = n + 1 end
	end
	return n
end

function Fx.RevealAround(pid, r)
	local p = Players[pid]
	local plot = HomePlot(pid)
	if not plot then return end
	local team = p:GetTeam()
	local x, y = plot:GetX(), plot:GetY()
	for dx = -r, r do
		for dy = -r, r do
			local pl = Map.PlotXYWithRangeCheck(x, y, dx, dy, r)
			if pl then pcall(function() pl:SetRevealed(team, true) end) end
		end
	end
	pcall(function() Game.UpdateFOW(true) end)
	pcall(function() UI.RequestMinimapBroadcast() end)
end

function Fx.PlaceResource(pid, resType)
	local res = GameInfoTypes[resType]
	if not res then return false end
	local cands = {}
	for city in Players[pid]:Cities() do
		for dx = -3, 3 do
			for dy = -3, 3 do
				local pl = Map.PlotXYWithRangeCheck(city:GetX(), city:GetY(), dx, dy, 3)
				if pl and not pl:IsWater() and not pl:IsMountain() and not pl:IsCity()
					and pl:GetResourceType(-1) == -1 and pl:GetImprovementType() == -1
					and (pl:GetOwner() == pid or pl:GetOwner() == -1) then
					cands[#cands + 1] = pl
				end
			end
		end
	end
	local pl = RL.Pick(cands)
	if not pl then return false end
	pl:SetResourceType(res, 1)
	RL.Notify(pid, "Gold Rush", "A vein of gold has been found!", pl:GetX(), pl:GetY())
	return true
end

function Fx.Treasure(pid)
	local k = RL.Rand(4)
	if k == 0 then local g = Fx.Amt(pid, 40, 25); Fx.Gold(pid, g); return "Treasure: +" .. g .. " [ICON_GOLD] Gold."
	elseif k == 1 then local c = Fx.Amt(pid, 20, 15); Fx.Culture(pid, c); return "Treasure: +" .. c .. " [ICON_CULTURE] Culture."
	elseif k == 2 then local f = Fx.Amt(pid, 20, 15); Fx.Faith(pid, f); return "Treasure: +" .. f .. " [ICON_PEACE] Faith."
	else local s = Fx.Amt(pid, 30, 30); Fx.Science(pid, s); return "Treasure: +" .. s .. " [ICON_RESEARCH] Science." end
end

-- ---------------- Timed effects ----------------
function Fx.AddTemp(pid, building, count, turns, label)
	if not GameInfoTypes[building] then return end
	local S = RL.State
	S.temps[#S.temps + 1] = { pid = pid, b = building, n = count or 1, untilTurn = Game.GetGameTurn() + RL.Interval(turns), label = label or "" }
	RL.SyncPlayer(pid)
end

-- ---------------- Run-level knobs ----------------
function Fx.Rerolls(n) RL.State.rerolls = math.max(0, RL.State.rerolls + n) end
function Fx.Luck(n) RL.State.luck = RL.State.luck + n end
function Fx.ExtraChoice(n) RL.State.extraChoices = RL.State.extraChoices + n end
function Fx.ExtraLife(n) RL.State.lives = RL.State.lives + n end
function Fx.DelayWave(t) RL.State.wave.next = RL.State.wave.next + RL.Interval(t); RL.State.wave.warned = false end
function Fx.WaveBonus(n) RL.State.wave.bonus = (RL.State.wave.bonus or 0) + n end
function Fx.SetFocus(tag) RL.State.focus = tag end

-- =====================================================================
-- CARDS
-- =====================================================================
local function CardOK(card, pid)
	if card.building and not GameInfoTypes[card.building] then return false end
	if card.promo and not GameInfoTypes[card.promo] then return false end
	local req = card.requires
	if type(req) == "function" then
		local ok, v = pcall(req, pid)
		return ok and v
	elseif type(req) == "table" then
		if req.column then
			local ok, v = pcall(function() return GameInfo.Buildings[req.building][req.column] end)
			return ok and v == req.value
		elseif req.table then
			local ok, found = pcall(function()
				local tbl = GameInfo[req.table]
				if not tbl then return false end
				for _ in tbl{ BuildingType = req.building } do return true end
				return false
			end)
			return ok and found
		end
	end
	return true
end
RL.CardOK = CardOK

function Fx.Stacks(pid, id)
	local pd = RL.PD(pid)
	return pd.cards[id] or pd.curses[id] or 0
end

function Fx.CanGain(pid, id)
	local c = RL.CardById[id]
	if not c then return false end
	return Fx.Stacks(pid, id) < (c.max or 1) and CardOK(c, pid)
end

local function RunHook(card, hook, pid, ...)
	local f = card[hook]
	if not f then return end
	RL.Try(card.id .. "." .. hook, f, pid, ...)
end

function Fx.GrantCard(pid, id, silent)
	local c = RL.CardById[id]
	if not c or c.curse then return nil end
	local pd = RL.PD(pid)
	local cur = pd.cards[id] or 0
	if cur >= (c.max or 1) then
		-- At max stacks: convert into a consolation treasure instead
		if Players[pid]:IsHuman() then Fx.Treasure(pid) end
		return c
	end
	pd.cards[id] = cur + 1
	if cur == 0 then pd.order[#pd.order + 1] = id end
	if pid == RL.State.human and not c.hidden then
		RL.State.stats.cards = RL.State.stats.cards + 1
		RL.LogRun("Boon: " .. c.name .. (cur > 0 and (" (x" .. (cur + 1) .. ")") or ""))
	end
	RunHook(c, "onAcquire", pid, cur + 1, 1)
	RL.SyncPlayer(pid)
	RL.CheckSynergies(pid)
	if not silent and pid ~= RL.State.human and not c.hidden then
		-- Let the human know what rivals are getting (keeps the AI legible)
		local p = Players[pid]
		local hp = Players[RL.State.human]
		if hp and Teams[hp:GetTeam()]:IsHasMet(p:GetTeam()) then
			RL.Notify(RL.State.human, "Rival boon", Locale.ConvertTextKey(p:GetCivilizationShortDescription()) .. " gained the boon " .. RL.RarityText(c.rarity) .. " " .. c.name .. ".")
		end
	end
	return c
end

function Fx.CurseCount(pid)
	local n = 0
	for _, s in pairs(RL.PD(pid).curses) do n = n + s end
	return n
end

function Fx.AddCurse(pid, id)
	local pd = RL.PD(pid)
	local c
	if id then c = RL.CardById[id] end
	if not c then
		local opts = {}
		for _, cu in ipairs(RL.Curses) do
			if (pd.curses[cu.id] or 0) < cu.max and CardOK(cu, pid) then opts[#opts + 1] = cu end
		end
		c = RL.Pick(opts)
	end
	if not c then return nil end
	pd.curses[c.id] = math.min(c.max, (pd.curses[c.id] or 0) + 1)
	if pid == RL.State.human then
		RL.LogRun("Curse: " .. c.name)
		RL.Notify(pid, "Cursed!", "[COLOR_NEGATIVE_TEXT]Curse: " .. c.name .. "[ENDCOLOR] - " .. c.desc)
	end
	RL.SyncPlayer(pid)
	return c
end

function Fx.CleanseCurses(pid, n)
	local pd = RL.PD(pid)
	local removed = 0
	for id, s in pairs(pd.curses) do
		while s > 0 and removed < n do s = s - 1; removed = removed + 1 end
		pd.curses[id] = (s > 0) and s or nil
		if removed >= n then break end
	end
	if removed > 0 and pid == RL.State.human then RL.LogRun("Cleansed " .. removed .. " curse(s)") end
	RL.SyncPlayer(pid)
	return removed
end

-- Rarity-weighted card pool for a player.
local function Pool(pid, opts)
	opts = opts or {}
	local isHuman = (pid == RL.State.human)
	local out = {}
	for _, c in ipairs(RL.Cards) do
		if not c.hidden
			and (isHuman or (not c.humanOnly and not RL.Contains(c.tags, "HERO")))
			and (not opts.minR or c.rarity >= opts.minR)
			and (not opts.maxR or c.rarity <= opts.maxR)
			and (not opts.exclude or not opts.exclude[c.id])
			and (not opts.tag or RL.Contains(c.tags, opts.tag))
			and Fx.CanGain(pid, c.id) then
			out[#out + 1] = c
		end
	end
	return out
end
RL.Pool = Pool

local function RollRarity(minR, maxR, luck)
	luck = luck or 0
	local entries = {}
	for r, def in ipairs(RL.RARITY) do
		if r >= minR and r <= maxR then
			local w = def.weight
			if r == 1 then w = w - luck elseif r == 2 then w = w + luck * 0.6 elseif r == 3 then w = w + luck * 0.3 else w = w + luck * 0.1 end
			entries[#entries + 1] = { item = r, w = math.max(1, math.floor(w * 10)) }
		end
	end
	return RL.WeightedPick(entries) or minR
end

-- Pick one card from the pool honoring a rarity roll, falling back to
-- neighbouring rarities when a tier is exhausted.
local function PickCard(pid, minR, maxR, exclude, tag)
	local r = RollRarity(minR, maxR, (pid == RL.State.human) and RL.State.luck or 0)
	local order = { r }
	for d = 1, 3 do
		if r - d >= minR then order[#order + 1] = r - d end
		if r + d <= maxR then order[#order + 1] = r + d end
	end
	for _, rr in ipairs(order) do
		local pool = Pool(pid, { minR = rr, maxR = rr, exclude = exclude, tag = tag })
		if #pool > 0 then return RL.Pick(pool) end
	end
	return nil
end

function Fx.GrantRandomCard(pid, minR, maxR)
	local c = PickCard(pid, minR or 1, maxR or 4, nil, nil)
	if c then Fx.GrantCard(pid, c.id) end
	return c
end

-- ---------------- Synergies ----------------
local function TagCounts(pid)
	local counts = {}
	local pd = RL.PD(pid)
	for id, s in pairs(pd.cards) do
		local c = RL.CardById[id]
		if c and not c.hidden then
			for _, t in ipairs(c.tags or {}) do counts[t] = (counts[t] or 0) + s end
		end
	end
	return counts
end
RL.TagCounts = TagCounts

function RL.ActiveSynergies(pid)
	local counts = TagCounts(pid)
	local out = {}
	for _, syn in ipairs(RL.Synergies) do
		if (counts[syn.tag] or 0) >= syn.need then out[#out + 1] = syn end
	end
	return out
end

function RL.CheckSynergies(pid)
	local S = RL.State
	if pid ~= S.human then return end
	for _, syn in ipairs(RL.ActiveSynergies(pid)) do
		if not S.synergies[syn.tag] then
			S.synergies[syn.tag] = true
			RL.LogRun("Synergy: " .. syn.name)
			RL.QueueInfo("Synergy Unlocked: " .. syn.name,
				"Your " .. RL.TAGS[syn.tag].name .. " boons resonate together.\n\n[COLOR_POSITIVE_TEXT]" .. syn.desc .. "[ENDCOLOR]")
		end
	end
end

-- =====================================================================
-- SYNC: dummy buildings & promotions
-- =====================================================================
local rlBuildings
local function AllRLBuildings()
	if rlBuildings then return rlBuildings end
	rlBuildings = {}
	for b in GameInfo.Buildings() do
		if string.sub(b.Type, 1, 12) == "BUILDING_RL_" then rlBuildings[#rlBuildings + 1] = b end
	end
	return rlBuildings
end

local rangedCache = {}
local function IsRangedType(t)
	if rangedCache[t] == nil then
		local u = GameInfo.Units[t]
		rangedCache[t] = (u and (u.RangedCombat or 0) > 0) and true or false
	end
	return rangedCache[t]
end

local function MatchFilter(u, filter)
	if filter == "CHAMPION" then return IsChampion(u) end
	if not u:IsCombatUnit() then return false end
	if filter == "MILITARY" then return true end
	local dom = u:GetDomainType()
	if filter == "LAND" then return dom == DomainTypes.DOMAIN_LAND end
	if filter == "SEA" then return dom == DomainTypes.DOMAIN_SEA end
	if filter == "RANGED" then return dom == DomainTypes.DOMAIN_LAND and IsRangedType(u:GetUnitType()) end
	return false
end

function RL.PromoList(pid)
	local list = {}
	local pd = RL.PD(pid)
	for id, s in pairs(pd.cards) do
		local c = RL.CardById[id]
		if c and c.promo and s > 0 and GameInfoTypes[c.promo] then list[#list + 1] = { id = GameInfoTypes[c.promo], filter = c.filter } end
	end
	if pid == RL.State.human then
		for _, syn in ipairs(RL.ActiveSynergies(pid)) do
			if syn.promo and GameInfoTypes[syn.promo] then list[#list + 1] = { id = GameInfoTypes[syn.promo], filter = syn.filter } end
		end
	end
	return list
end

function RL.ApplyPromotions(pid, onlyUnit)
	local list = RL.PromoList(pid)
	if #list == 0 then return end
	local function apply(u)
		for _, pr in ipairs(list) do
			if not u:IsHasPromotion(pr.id) and MatchFilter(u, pr.filter) then u:SetHasPromotion(pr.id, true) end
		end
	end
	if onlyUnit then apply(onlyUnit) return end
	for u in Players[pid]:Units() do apply(u) end
end

function RL.SyncPlayer(pid)
	if not RL.State or not IsTracked(pid) then return end
	local want = {}  -- type -> {all=, cap=}
	local function add(b, scope, n)
		if not b or not GameInfoTypes[b] or n <= 0 then return end
		want[b] = want[b] or { all = 0, cap = 0 }
		if scope == "capital" then want[b].cap = want[b].cap + n else want[b].all = want[b].all + n end
	end
	local pd = RL.PD(pid)
	for id, s in pairs(pd.cards) do local c = RL.CardById[id]; if c and c.building then add(c.building, c.scope, s) end end
	for id, s in pairs(pd.curses) do local c = RL.CardById[id]; if c and c.building then add(c.building, c.scope, s) end end
	if pid == RL.State.human then
		for _, syn in ipairs(RL.ActiveSynergies(pid)) do if syn.building then add(syn.building, syn.scope, 1) end end
	end
	for _, t in ipairs(RL.State.temps) do if t.pid == pid then add(t.b, "all", t.n) end end

	local blist = AllRLBuildings()
	for city in Players[pid]:Cities() do
		local isCap = city:IsCapital()
		for _, b in ipairs(blist) do
			local w = want[b.Type]
			local n = 0
			if w then n = w.all + (isCap and w.cap or 0) end
			if city:GetNumRealBuilding(b.ID) ~= n then city:SetNumRealBuilding(b.ID, n) end
		end
	end
	RL.ApplyPromotions(pid)
end

local function ExpireTemps()
	local S = RL.State
	local turn = Game.GetGameTurn()
	local keep, touched = {}, {}
	for _, t in ipairs(S.temps) do
		if t.untilTurn > turn then keep[#keep + 1] = t
		else
			touched[t.pid] = true
			if t.pid == S.human and t.label ~= "" then RL.Notify(t.pid, "Effect ended", "The effect '" .. t.label .. "' has ended.") end
		end
	end
	S.temps = keep
	return touched
end

-- =====================================================================
-- DRAFTS
-- =====================================================================
local function DraftSize()
	local S = RL.State
	local n = 3 + S.extraChoices + RL.Meta.Rank("WIDER")
	if S.ascension >= 9 then n = n - 1 end
	n = n - Fx.Stacks(S.human, "BAD_OMENS")
	return RL.Clamp(n, 2, 5)
end

function RL.RollDraftCards(d)
	local S = RL.State
	local pid = S.human
	local n = DraftSize()
	local maxR = 4
	if d.floor < 3 and RL.Meta.Rank("LEGENDS") == 0 then maxR = 3 end
	local minR = math.min(d.floor or 1, maxR)
	local exclude, cards, pacts = {}, {}, {}
	local focus = d.focus
	for i = 1, n do
		local c
		if focus and i <= 2 then c = PickCard(pid, 1, maxR, exclude, focus) end
		c = c or PickCard(pid, minR, maxR, exclude, nil)
		if c then
			exclude[c.id] = true
			cards[#cards + 1] = c.id
			-- Pact roll: the card comes with a bonus Rare boon AND a curse
			local pactChance = 10 + 2 * S.ascension
			pacts[#pacts + 1] = (c.rarity < 4 and RL.Chance(pactChance)) and true or false
		end
	end
	d.cards, d.pacts = cards, pacts
end

-- Queue a draft for the human. floor = minimum rarity.
function Fx.QueueDraft(title, floor)
	local S = RL.State
	if not S or S.over and not S.won then return end
	local d = { title = title, floor = floor or 1, turn = Game.GetGameTurn() }
	if S.focus then d.focus = S.focus; S.focus = nil end
	RL.RollDraftCards(d)
	if #d.cards == 0 then
		Fx.Gold(S.human, Fx.Amt(S.human, 50, 30), "Nothing left to draft - you receive gold instead")
		return
	end
	S.drafts[#S.drafts + 1] = d
	RL.Notify(S.human, "Draft available", "[ICON_TROPHY_GOLD] " .. title .. ": choose a Boon! (Open the Ascension panel at the top of the screen.)")
end

function RL.ChooseDraft(index)
	local S = RL.State
	local d = S.drafts[1]
	if not d then return end
	local id = d.cards[index]
	if not id then return end
	table.remove(S.drafts, 1)
	S.stats.drafts = S.stats.drafts + 1
	Fx.GrantCard(S.human, id)
	if d.pacts and d.pacts[index] then
		local bonus = Fx.GrantRandomCard(S.human, 2, 2)
		local curse = Fx.AddCurse(S.human)
		RL.LogRun("Pact sealed: +" .. (bonus and bonus.name or "?") .. ", curse " .. (curse and curse.name or "?"))
	end
	RL.Save()
end

function RL.RerollDraft()
	local S = RL.State
	local d = S.drafts[1]
	if not d or S.rerolls <= 0 then return false end
	S.rerolls = S.rerolls - 1
	RL.RollDraftCards(d)
	RL.Save()
	return true
end

function RL.SkipDraft()
	local S = RL.State
	local d = S.drafts[1]
	if not d then return end
	table.remove(S.drafts, 1)
	local g = Fx.Amt(S.human, 30, 20)
	Fx.Gold(S.human, g)
	S.rerolls = S.rerolls + 1
	RL.LogRun("Skipped draft (+" .. g .. " gold, +1 reroll)")
	RL.Save()
end

-- AI rivals draft automatically: prefer the highest rarity offered.
function RL.AIDraft(pid, floor)
	local best
	local exclude = {}
	for i = 1, 3 do
		local c = PickCard(pid, floor or 1, 3, exclude, nil)
		if c then
			exclude[c.id] = true
			if not best or c.rarity > best.rarity then best = c end
		end
	end
	if best then Fx.GrantCard(pid, best.id) end
end

-- =====================================================================
-- INFO POPUPS & EVENTS
-- =====================================================================
function RL.QueueInfo(title, text, x, y)
	local S = RL.State
	S.infos[#S.infos + 1] = { title = title, text = text, x = x or -1, y = y or -1 }
end

function RL.PopInfo() table.remove(RL.State.infos, 1); RL.Save() end

function RL.RollEvent()
	local S = RL.State
	local pid = S.human
	local turn = Game.GetGameTurn()
	local era = Era(pid)
	local entries = {}
	for _, ev in ipairs(RL.Events) do
		local ok = turn >= RL.Interval(ev.minTurn)
			and (not ev.minEra or era >= ev.minEra)
			and (not ev.maxEra or era <= ev.maxEra)
		if ok and ev.cond then local okc, v = pcall(ev.cond, pid); ok = okc and v end
		if ok then
			-- recently seen events are much less likely
			local w = ev.weight
			local last = S.eventHistory[ev.id]
			if last and turn - last < RL.Interval(60) then w = math.max(1, math.floor(w / 4)) end
			entries[#entries + 1] = { item = ev, w = w }
		end
	end
	local ev = RL.WeightedPick(entries)
	if not ev then return end
	local params = {}
	if ev.roll then params = RL.Try(ev.id .. ".roll", ev.roll, pid) or {} end
	S.pending[#S.pending + 1] = { id = ev.id, p = params, turn = turn }
	S.eventHistory[ev.id] = turn
	RL.Notify(pid, "Event", "[ICON_HAPPINESS_1] " .. ev.title .. " - a decision awaits you.")
end

-- Render the current pending event for the UI.
function RL.DescribeEvent()
	local S = RL.State
	local pe = S.pending[1]
	if not pe then return nil end
	local ev = RL.EventById[pe.id]
	if not ev then table.remove(S.pending, 1); return nil end
	local pid = S.human
	local out = { title = ev.title, options = {} }
	out.text = (type(ev.text) == "function") and (RL.Try(ev.id .. ".text", ev.text, pid, pe.p) or "") or ev.text
	for i, o in ipairs(ev.options) do
		local label = o.label
		if type(label) == "function" then label = RL.Try(ev.id .. ".label", label, pid, pe.p) or "?" end
		local ok, reason = true, nil
		if o.avail then
			local good, a, b = pcall(o.avail, pid, pe.p)
			if good then ok, reason = a, b else ok = false end
		end
		out.options[i] = { label = label, ok = ok and true or false, reason = reason }
	end
	return out
end

function RL.ResolveEvent(index)
	local S = RL.State
	local pe = S.pending[1]
	if not pe then return nil end
	local ev = RL.EventById[pe.id]
	local o = ev and ev.options[index]
	if not o then return nil end
	if o.avail then
		local good, a = pcall(o.avail, S.human, pe.p)
		if not (good and a) then return nil end
	end
	table.remove(S.pending, 1)
	S.stats.events = S.stats.events + 1
	local result = RL.Try(ev.id .. ".run", o.run, S.human, pe.p) or ""
	RL.LogRun(ev.title)
	RL.SyncPlayer(S.human)
	RL.Save()
	return result
end

-- =====================================================================
-- THE HORDE (barbarian raids) & ERA WARLORDS
-- =====================================================================
local barbId
local function Barb()
	if barbId then return Players[barbId] end
	for i = GameDefines.MAX_PLAYERS - 1, 0, -1 do
		local p = Players[i]
		if p and p:IsBarbarian() then barbId = i; return p end
	end
	barbId = GameDefines.MAX_PLAYERS - 1
	return Players[barbId]
end

local function GoodSpawnPlot(pl, area)
	return pl and not pl:IsWater() and not pl:IsMountain() and not pl:IsImpassable()
		and not pl:IsCity() and pl:GetNumUnits() == 0 and pl:GetArea() == area
end

-- Find up to n land plots clustered 4-7 tiles from (cx, cy).
local function FindSpawnPlots(cx, cy, n)
	local center = Map.GetPlot(cx, cy)
	if not center then return {} end
	local area = center:GetArea()
	local ring = {}
	for dx = -7, 7 do
		for dy = -7, 7 do
			local pl = Map.PlotXYWithRangeCheck(cx, cy, dx, dy, 7)
			if pl and Map.PlotDistance(cx, cy, pl:GetX(), pl:GetY()) >= 4 and GoodSpawnPlot(pl, area) then ring[#ring + 1] = pl end
		end
	end
	if #ring == 0 then return {} end
	local anchor = RL.Pick(ring)
	table.sort(ring, function(a, b)
		return Map.PlotDistance(anchor:GetX(), anchor:GetY(), a:GetX(), a:GetY()) < Map.PlotDistance(anchor:GetX(), anchor:GetY(), b:GetX(), b:GetY())
	end)
	local out = {}
	for i = 1, math.min(n, #ring) do out[i] = ring[i] end
	return out
end

local function TargetCity(pid)
	local list = {}
	for city in Players[pid]:Cities() do list[#list + 1] = city end
	if #list == 0 then return nil end
	-- prefer the frontier: cities furthest from the capital
	local cap = Players[pid]:GetCapitalCity()
	if cap and #list > 1 and RL.Chance(60) then
		table.sort(list, function(a, b)
			return Map.PlotDistance(cap:GetX(), cap:GetY(), a:GetX(), a:GetY()) > Map.PlotDistance(cap:GetX(), cap:GetY(), b:GetX(), b:GetY())
		end)
		return list[RL.Rand(math.min(3, #list)) + 1]
	end
	return RL.Pick(list)
end

local HORDE_MIX = { "MELEE", "MELEE", "RANGED", "MOUNTED", "MELEE", "SIEGE", "RANGED", "MOUNTED" }

local function SpawnHordeUnit(role, era, plot, extraPromos)
	local row = Fx.BestRoleUnit(Barb():GetID(), role, RL.Clamp(era, 0, 7))
	if not row or not plot then return nil end
	-- NOTE: there is no UnitAITypes global in Civ V; unit AI ids come from the
	-- UnitAIInfos table via GameInfoTypes. Without one the unit uses its default AI.
	local ai = GameInfoTypes.UNITAI_ATTACK
	local u
	if ai then u = Barb():InitUnit(row.ID, plot:GetX(), plot:GetY(), ai)
	else u = Barb():InitUnit(row.ID, plot:GetX(), plot:GetY()) end
	if not u then return nil end
	if GameInfoTypes.PROMOTION_RL_HORDE then u:SetHasPromotion(GameInfoTypes.PROMOTION_RL_HORDE, true) end
	for _, pr in ipairs(extraPromos or {}) do if GameInfoTypes[pr] then u:SetHasPromotion(GameInfoTypes[pr], true) end end
	return u
end

local function HordePromos()
	if RL.State.ascension >= 3 then return { "PROMOTION_RL_HORDE_VETERAN" } end
	return {}
end

-- Spawn n hostile units near one of pid's cities.
function Fx.SpawnHostilesNear(pid, n, msg, eraOffset, city)
	city = city or TargetCity(pid)
	if not city then return 0 end
	local plots = FindSpawnPlots(city:GetX(), city:GetY(), n)
	local era = Era(pid) + (eraOffset or 0)
	local spawned = 0
	for i, pl in ipairs(plots) do
		if SpawnHordeUnit(HORDE_MIX[((i - 1) % #HORDE_MIX) + 1], era, pl, HordePromos()) then spawned = spawned + 1 end
	end
	if spawned > 0 and msg then
		RL.Notify(pid, "Hostiles!", "[ICON_WAR] " .. msg .. " (" .. spawned .. " units near " .. city:GetName() .. ")", plots[1]:GetX(), plots[1]:GetY())
	end
	return spawned
end

local function WaveInterval()
	local S = RL.State
	local base = 22
	if S.ascension >= 1 then base = base * 0.8 end
	return RL.Interval(base)
end

local function WaveSize()
	local S = RL.State
	local pid = S.human
	local growth = (S.ascension >= 10) and 2 or 1
	local n = 2 + math.floor(Era(pid) * 0.75) + math.floor(S.wave.count / 3) * growth
	if S.ascension >= 2 then n = n + 1 end
	n = n + Fx.Stacks(pid, "BLOODLUST") + (S.wave.bonus or 0)
	n = n + math.floor(Players[pid]:GetNumCities() / 5)
	return RL.Clamp(n, 2, 14)
end
RL.WaveSize = WaveSize

local function ProcessWaves(turn)
	local S = RL.State
	local W = S.wave
	if W.next <= 0 then
		W.next = RL.Interval(38) - ((S.ascension >= 10) and RL.Interval(10) or 0)
	end
	if not W.warned and turn >= W.next - 3 then
		local city = TargetCity(S.human)
		if city then
			W.warned, W.tx, W.ty = true, city:GetX(), city:GetY()
			RL.Notify(S.human, "Horde raid incoming!", "[ICON_WAR] Scouts report a Horde war-band (~" .. WaveSize() .. " units) closing on " .. city:GetName() .. ". It will arrive in about 3 turns.", W.tx, W.ty)
		end
	end
	if turn >= W.next then
		local target
		if W.tx then local pl = Map.GetPlot(W.tx, W.ty); if pl and pl:IsCity() and pl:GetPlotCity():GetOwner() == S.human then target = pl:GetPlotCity() end end
		local n = WaveSize()
		W.next = turn + WaveInterval()
		W.warned, W.tx, W.ty = false, nil, nil
		local spawned = RL.Try("HordeSpawn", Fx.SpawnHostilesNear, S.human, n, "The Horde attacks!", 0, target) or 0
		W.count = W.count + 1
		W.bonus = 0
		if spawned > 0 then RL.LogRun("Horde raid #" .. W.count .. " (" .. spawned .. " units)") end
	end
end

-- ---------------- Warlords ----------------
function RL.SpawnBoss(idx)
	local S = RL.State
	local def = RL.Bosses[idx]
	if not def or S.bossesSpawned[idx] then return end
	if S.over and not S.won then return end   -- a lost run spawns no more Warlords
	if S.boss.active then
		-- One Warlord at a time; the next one waits until this one falls.
		S.boss.queue = S.boss.queue or {}
		if not RL.Contains(S.boss.queue, idx) then S.boss.queue[#S.boss.queue + 1] = idx end
		return
	end
	local pid = S.human
	local function retry()
		S.boss.queue = S.boss.queue or {}
		if not RL.Contains(S.boss.queue, idx) then S.boss.queue[#S.boss.queue + 1] = idx end
	end
	local city = TargetCity(pid)
	if not city then retry(); return end
	local escorts = {}
	for _, r in ipairs(def.escorts) do escorts[#escorts + 1] = r end
	local extra = Fx.Stacks(pid, "HUBRIS") + ((S.ascension >= 8) and 2 or 0)
	for i = 1, extra do escorts[#escorts + 1] = HORDE_MIX[RL.Rand(#HORDE_MIX) + 1] end
	local plots = FindSpawnPlots(city:GetX(), city:GetY(), #escorts + 1)
	if #plots == 0 then retry(); return end
	local era = math.max(Era(pid), idx)
	local bossPromos = { "PROMOTION_RL_BOSS", "PROMOTION_RL_HORDE_VETERAN" }
	if S.ascension >= 8 then bossPromos[#bossPromos + 1] = "PROMOTION_RL_BOSS_EMPOWERED" end
	local leader = SpawnHordeUnit(def.role, era, plots[1], bossPromos)
	if not leader then retry(); return end
	pcall(function() leader:SetName(def.name) end)
	for i = 2, #plots do SpawnHordeUnit(escorts[i - 1], era, plots[i], HordePromos()) end
	S.bossesSpawned[idx] = true
	S.boss = { active = true, idx = idx, unitId = leader:GetID(), turn = Game.GetGameTurn(), name = def.name, queue = S.boss.queue }
	RL.LogRun("Warlord appeared: " .. def.name)
	RL.QueueInfo("A Warlord Rises: " .. def.name,
		def.flavor .. "\n\n[COLOR_NEGATIVE_TEXT]" .. def.name .. " and " .. (#plots - 1) .. " escorts march on " .. city:GetName() .. ".[ENDCOLOR]\n\nSlay the Warlord to earn an [COLOR_MAGENTA]Epic draft[ENDCOLOR], gold and Legacy." ..
		((idx == RL.FINAL_BOSS) and "\n\n[COLOR_YIELD_GOLD]This is the FINAL WARLORD. Slay it to win your run![ENDCOLOR]" or ""),
		plots[1]:GetX(), plots[1]:GetY())
	RL.Notify(pid, "Warlord: " .. def.name, "[ICON_WAR] " .. def.name .. " leads a war-host toward " .. city:GetName() .. "!", plots[1]:GetX(), plots[1]:GetY())
end

function RL.CheckBoss()
	local S = RL.State
	if not S.boss.active then return end
	local u = Barb():GetUnitByID(S.boss.unitId)
	local alive = u and not u:IsDead()
	if alive then
		local ok, dd = pcall(function() return u:IsDelayedDeath() end)
		if ok and dd then alive = false end
	end
	if alive then return end
	local idx = S.boss.idx
	local name = S.boss.name or "the Warlord"
	local queue = S.boss.queue
	S.boss = { active = false, queue = queue }
	S.bossesSlain = S.bossesSlain + 1
	local pid = S.human
	RL.LogRun("Warlord slain: " .. name)
	Fx.Gold(pid, Fx.Amt(pid, 100, 50))
	Fx.ChampionXP(25)
	RL.AwardLegacy("boss" .. idx, RL.LegacyAwards.BOSS, "Slew " .. name)
	Fx.QueueDraft("Spoils of " .. name, 3)
	for id, s in pairs(RL.PD(pid).cards) do local c = RL.CardById[id]; if c and c.onBoss then RunHook(c, "onBoss", pid, s) end end
	RL.QueueInfo("Warlord Slain!", "[COLOR_POSITIVE_TEXT]" .. name .. " has fallen![ENDCOLOR]\n\nThe war-host scatters. Your people sing your name. Claim your spoils: gold, Legacy, and an Epic-or-better draft.")
	if S.bossesSlain >= 5 then RL.UnlockAscension(S.ascension + 1) end
	if idx == RL.FINAL_BOSS then RL.RunWon("Slew the Final Warlord") end
end

-- One queued Warlord (waiting or failed to find room) per turn.
local function ProcessBossQueue(turn)
	local S = RL.State
	S.boss.queue = S.boss.queue or {}
	local q = S.boss.queue
	-- Catch-up: any Warlord whose arrival time has passed but never spawned
	-- (e.g. a save from a version where spawning failed) joins the queue.
	local era = Players[S.human]:GetCurrentEra()
	for idx = 0, 7 do
		local due = (idx == 0 and turn >= RL.Interval(RL.FIRST_BOSS_TURN)) or (idx > 0 and era >= idx)
		if due and not S.bossesSpawned[idx] and not RL.Contains(q, idx) and S.boss.idx ~= idx then q[#q + 1] = idx end
	end
	table.sort(q)
	if S.boss.active or #q == 0 then return end
	local idx = table.remove(q, 1)
	RL.SpawnBoss(idx)
	if not S.bossesSpawned[idx] and not RL.Contains(q, idx) then table.insert(q, 1, idx) end
end

-- =====================================================================
-- QUESTS
-- =====================================================================
local function QuestMetric(q) local ok, v = pcall(q.metric, RL.State.human); return ok and tonumber(v) or 0 end

local function OfferQuest(turn)
	local S = RL.State
	local pid = S.human
	local opts = {}
	for _, q in ipairs(RL.Quests) do
		local ok = true
		if q.cond then local g, v = pcall(q.cond, pid); ok = g and v end
		if ok then opts[#opts + 1] = q end
	end
	local q = RL.Pick(opts)
	if not q then return end
	local target = RL.Try(q.id .. ".target", q.target, pid, Era(pid)) or 1
	S.quest = { id = q.id, base = q.relative and QuestMetric(q) or 0, target = target,
		deadline = turn + RL.Interval(q.duration), desc = string.format(q.desc, target), name = q.name }
	RL.Notify(pid, "New Bounty: " .. q.name, "[ICON_TROPHY_SILVER] " .. S.quest.desc .. " (" .. RL.Interval(q.duration) .. " turns). Reward: a Rare draft and Legacy.")
	RL.LogRun("Bounty: " .. q.name)
end

function RL.QuestProgress()
	local S = RL.State
	if not S.quest then return 0, 0 end
	local def
	for _, q in ipairs(RL.Quests) do if q.id == S.quest.id then def = q end end
	if not def then return 0, 0 end
	return QuestMetric(def) - S.quest.base, S.quest.target
end

local function ProcessQuest(turn)
	local S = RL.State
	if S.quest then
		local prog, target = RL.QuestProgress()
		if prog >= target then
			S.stats.quests = S.stats.quests + 1
			RL.Notify(S.human, "Bounty complete!", "[ICON_TROPHY_GOLD] " .. S.quest.name .. " complete!")
			RL.LogRun("Bounty complete: " .. S.quest.name)
			RL.AwardLegacy("quest" .. S.stats.quests .. "_" .. S.quest.id .. "_" .. turn, RL.LegacyAwards.QUEST, "Bounty: " .. S.quest.name)
			Fx.QueueDraft("Bounty: " .. S.quest.name, 2)
			S.quest = nil
			S.nextQuestTurn = turn + RL.Interval(12)
		elseif turn > S.quest.deadline then
			RL.Notify(S.human, "Bounty failed", "The bounty '" .. S.quest.name .. "' has expired.")
			RL.LogRun("Bounty failed: " .. S.quest.name)
			S.quest = nil
			S.nextQuestTurn = turn + RL.Interval(10)
		end
	elseif turn >= S.nextQuestTurn then
		OfferQuest(turn)
	end
end

-- =====================================================================
-- THE CHAMPION
-- =====================================================================
local HERO_NAMES = { "Aldric the Bold", "Seraphine Ironheart", "Kaelen Stormborn", "Brannoc the Unbroken", "Ysolde of the Ash",
	"Tamsin Wolfsbane", "Orrin Duskblade", "Valka the Red", "Cassius Thorne", "Mireille Dawnspear", "Ragnvald Oakshield", "Ilyana Starfall" }

local function ChampionUnit()
	local S = RL.State
	if not S or not S.champion or S.champion.id < 0 then return nil end
	local u = Players[S.human]:GetUnitByID(S.champion.id)
	if u and not u:IsDead() and IsChampion(u) then return u end
	return nil
end
RL.ChampionUnit = ChampionUnit

function Fx.ChampionAlive() return ChampionUnit() ~= nil end
function Fx.ChampionLevel() local u = ChampionUnit(); return u and u:GetLevel() or 0 end
function Fx.TourneyChance() return RL.Clamp(40 + 10 * Fx.ChampionLevel(), 0, 90) end
function Fx.ChampionXP(xp)
	local u = ChampionUnit()
	if not u then return end
	local ok = pcall(function() u:ChangeExperience(xp) end)
	if not ok then pcall(function() u:SetExperience(u:GetExperience() + xp) end) end
end
function Fx.ChampionHeal() local u = ChampionUnit(); if u then pcall(function() u:SetDamage(0) end) end end
function Fx.ChampionDamage(d)
	local u = ChampionUnit()
	if u then pcall(function() u:SetDamage(math.min(u:GetDamage() + d, 90)) end) end
end

local function SnapshotChampion(u)
	local C = RL.State.champion
	C.xp = u:GetExperience()
	C.level = u:GetLevel()
	C.promos = {}
	for pr in GameInfo.UnitPromotions() do
		if u:IsHasPromotion(pr.ID) then C.promos[#C.promos + 1] = pr.Type end
	end
end

local function SpawnChampion(plot, restore)
	local S = RL.State
	local pid = S.human
	local era = Era(pid)
	local tier = RL.ChampionTierByEra[era] or 1
	local row = GameInfo.Units["UNIT_RL_CHAMPION_" .. tier]
	if not row then return nil end
	plot = plot or HomePlot(pid)
	if not plot then return nil end
	local u = Players[pid]:InitUnit(row.ID, plot:GetX(), plot:GetY())
	if not u then return nil end
	pcall(function() u:JumpToNearestValidPlot() end)
	local C = S.champion
	if C.name == "" then C.name = RL.Pick(HERO_NAMES) end
	pcall(function() u:SetName(C.name) end)
	if restore then
		pcall(function() u:SetExperience(restore.xp or 0) end)
		pcall(function() u:SetLevel(restore.level or 1) end)
		for _, t in ipairs(restore.promos or {}) do
			local id = GameInfoTypes[t]
			if id then pcall(function() u:SetHasPromotion(id, true) end) end
		end
	end
	C.id, C.tier, C.deadTurn, C.spawned, C.respawnNow = u:GetID(), tier, -1, true, nil
	RL.ApplyPromotions(pid, u)
	SnapshotChampion(u)
	return u
end

local function UpgradeChampion()
	local S = RL.State
	local u = ChampionUnit()
	if not u then return end
	local tier = RL.ChampionTierByEra[Era(S.human)] or 1
	if tier <= S.champion.tier then return end
	SnapshotChampion(u)
	local plot, dmg = u:Plot(), u:GetDamage()
	local restore = { xp = S.champion.xp, level = S.champion.level, promos = S.champion.promos }
	S.champion.id = -1
	u:Kill(false, -1)
	local nu = SpawnChampion(plot, restore)
	if nu then
		pcall(function() nu:SetDamage(dmg) end)
		RL.Notify(S.human, "Champion ascends", "[ICON_GREAT_GENERAL] " .. S.champion.name .. " is reforged for a new era (" .. Locale.ConvertTextKey(GameInfo.Units[nu:GetUnitType()].Description) .. ", tier " .. S.champion.tier .. ").", nu:GetX(), nu:GetY())
	end
end

function RL.OnChampionDeath()
	local S = RL.State
	local C = S.champion
	if C.deadTurn >= 0 or not C.spawned then return end
	C.id = -1
	C.deadTurn = Game.GetGameTurn()
	RL.LogRun("Champion " .. C.name .. " fell")
	if S.ascension >= 5 then
		RL.RunLost("Your Champion fell (Ascension 5: Last Stand)")
	else
		local wait = RL.ChampionRespawnTurns - ((Fx.Stacks(S.human, "BLOOD_OATH") > 0) and 4 or 0)
		RL.Notify(S.human, "Champion fallen", "[ICON_WAR] " .. C.name .. " has fallen! They will return in " .. RL.Interval(wait) .. " turns.")
	end
end

local function ProcessChampion(turn)
	local S = RL.State
	local C = S.champion
	local u = ChampionUnit()
	if u then
		SnapshotChampion(u)
		UpgradeChampion()
		return
	end
	if C.deadTurn < 0 then RL.OnChampionDeath() end
	if S.over and not S.won then return end
	local wait = RL.ChampionRespawnTurns - ((Fx.Stacks(S.human, "BLOOD_OATH") > 0) and 4 or 0)
	local due = C.respawnNow or not C.spawned or turn >= C.deadTurn + RL.Interval(wait)
	if due and Players[S.human]:GetCapitalCity() then
		local restore = { xp = math.floor((C.xp or 0) / 2), level = C.level, promos = C.promos }
		local nu = SpawnChampion(nil, restore)
		if nu then RL.Notify(S.human, "Champion returns", "[ICON_GREAT_GENERAL] " .. C.name .. " returns to fight again!", nu:GetX(), nu:GetY()) end
	end
end

-- =====================================================================
-- RUN LIFECYCLE
-- =====================================================================
function RL.RunWon(reason)
	local S = RL.State
	if S.won or S.over then return end   -- a lost run can never become a win
	S.won = true
	S.over = true
	RL.LogRun("RUN WON: " .. reason)
	RL.AwardLegacy("runwon", RL.LegacyAwards.RUN_WON, "Run victory")
	RL.UnlockAscension(S.ascension + 1)
	RL.Meta.Add("wins", 1)
	if S.ascension > RL.Meta.Num("bestAsc") then RL.Meta.Set("bestAsc", S.ascension) end
	RL.Save()
	if RL.UI.ShowRunOver then RL.UI.ShowRunOver(true, reason) end
end

function RL.RunLost(reason)
	local S = RL.State
	if S.over then return end
	if S.lives > 0 then
		S.lives = S.lives - 1
		local pid = S.human
		RL.LogRun("Extra life consumed: " .. reason)
		Fx.GoldenAge(pid, 5)
		Fx.SpawnRole(pid, "MELEE", 2)
		Fx.SpawnRole(pid, "RANGED", 1)
		S.champion.respawnNow = true
		RL.QueueInfo("Rise from the Ashes", "[COLOR_YIELD_GOLD]" .. reason .. "[ENDCOLOR]\n\n...but this is not your end. An extra life is spent: your people rally with a Golden Age and fresh troops. (" .. S.lives .. " extra lives left.)")
		RL.Save()
		return
	end
	S.over = true
	RL.LogRun("RUN LOST: " .. reason)
	RL.AwardLegacy("defeat", RL.LegacyAwards.DEFEAT, "Run ended")
	S.noLegacy = true   -- nothing more can be earned in this game
	RL.Meta.Add("losses", 1)
	RL.Save()
	if RL.UI.ShowRunOver then RL.UI.ShowRunOver(false, reason) end
end

local function CheckDefeat()
	local S = RL.State
	if S.over then return end
	local p = Players[S.human]
	if not p:IsAlive() then RL.RunLost("Your civilization was destroyed"); return end
	if S.capX >= 0 then
		local pl = Map.GetPlot(S.capX, S.capY)
		local owner = pl and pl:IsCity() and pl:GetPlotCity():GetOwner()
		if pl and owner ~= S.human then
			RL.RunLost("Your original capital has fallen")
			-- a spent extra life moves the "heart of the empire" to the current capital
			if not S.over then
				local cap = p:GetCapitalCity()
				if cap then S.capX, S.capY = cap:GetX(), cap:GetY() else S.capX, S.capY = -1, -1 end
			end
		end
	elseif p:GetCapitalCity() then
		local cap = p:GetCapitalCity()
		S.capX, S.capY = cap:GetX(), cap:GetY()
	end
end

-- Begin a new run (called from the start screen).
function RL.BeginRun(ascension, originId)
	local S = RL.State
	if S.started then return end
	local pid = S.human
	S.started = true
	S.ascension = RL.Clamp(ascension or 0, 0, math.min(RL.MAX_ASCENSION, RL.Meta.AscUnlocked()))
	S.origin = originId or "WARBORN"
	S.seed = Game.GetGameTurn() * 7919 + pid * 104729
	pcall(function() S.seed = S.seed + os.time() end)
	pcall(function() S.seed = S.seed + Game.Rand(100000, "Ascension seed") end)
	RL.SeedRNG(S.seed)
	S.runId = tostring(S.seed) .. "_" .. tostring(RL.Rand(1000000))
	RL.Meta.Add("runs", 1)

	local turn = Game.GetGameTurn()
	S.nextEventTurn = turn + RL.Interval(10)
	S.nextQuestTurn = turn + RL.Interval(18)
	S.nextMilestone = turn + RL.Interval(30)
	S.wave = { next = turn + RL.Interval(38) - ((S.ascension >= 10) and RL.Interval(10) or 0), warned = false, bonus = 0, count = 0 }

	-- Legacy upgrades
	local r
	r = RL.Meta.Rank("INHERITANCE"); if r > 0 then Fx.Gold(pid, 75 * r) end
	r = RL.Meta.Rank("FORTUNE"); S.rerolls = 1 + r
	r = RL.Meta.Rank("KEEN_EYE"); S.luck = 8 * r
	r = RL.Meta.Rank("SECOND_WIND"); S.lives = r
	r = RL.Meta.Rank("BULWARK"); if r > 0 then Fx.GrantCard(pid, "LEGACY_BULWARK", true) end
	r = RL.Meta.Rank("SCHOLAR"); for i = 1, r do Fx.FreeTech(pid) end
	r = RL.Meta.Rank("PIONEER"); if r > 0 then Fx.SpawnUnitType(pid, "UNIT_SETTLER", 1) end

	-- Champion
	local restore = { xp = 20 * RL.Meta.Rank("VETERAN"), level = 1, promos = {} }
	SpawnChampion(nil, restore)

	-- Origin
	local o = RL.OriginById[S.origin]
	if o then
		S.legacyBonus = o.legacyBonus or 0
		RL.Try("origin", o.apply, pid)
		RL.LogRun("Origin: " .. o.name)
	end

	-- Ascension mutators
	if S.ascension >= 6 then Fx.GrantCard(pid, "ASC_LEAN", true) end
	if S.ascension >= 7 then Fx.AddCurse(pid) end

	if RL.Meta.Rank("GAMBIT") > 0 then Fx.QueueDraft("Opening Gambit", 2) end
	Fx.QueueDraft("A New Dawn", 1)

	-- Every AI rival starts with one boon too.
	for i = 0, GameDefines.MAX_MAJOR_CIVS - 1 do
		if i ~= pid and IsTracked(i) then
			RL.PD(i)
			RL.AIDraft(i, 1)
		end
	end

	local cap = Players[pid]:GetCapitalCity()
	if cap then S.capX, S.capY = cap:GetX(), cap:GetY() end
	RL.LogRun("Run begun at Ascension " .. S.ascension)
	RL.SyncPlayer(pid)
	RL.Save()
end

-- =====================================================================
-- TURN PROCESSING
-- =====================================================================
local function CardsHook(pid, hook, ...)
	local pd = RL.PD(pid)
	for _, id in ipairs(pd.order) do
		local c = RL.CardById[id]
		local s = pd.cards[id]
		if c and s and s > 0 and c[hook] then RunHook(c, hook, pid, s, ...) end
	end
	for id, s in pairs(pd.curses) do
		local c = RL.CardById[id]
		if c and c[hook] and s > 0 then RunHook(c, hook, pid, s, ...) end
	end
end
RL.CardsHook = CardsHook

local function ProcessEra(pid)
	local S = RL.State
	local pd = RL.PD(pid)
	local era = Players[pid]:GetCurrentEra()
	if era <= pd.era then return end
	for e = pd.era + 1, era do
		CardsHook(pid, "onEra", e)
		if pid == S.human then
			RL.AwardLegacy("era" .. e, RL.LegacyAwards.ERA, "Reached the " .. RL.EraName(e))
			Fx.QueueDraft("Dawn of the " .. RL.EraName(e), 1)
			if RL.Meta.Rank("FORTUNE") >= 3 then Fx.Rerolls(1) end
			-- Warlord e is queued by ProcessBossQueue on the human's turn
		else
			RL.AIDraft(pid, 1)
			if S.ascension >= 4 then RL.AIDraft(pid, 1) end
		end
	end
	pd.era = era
	if pid == S.human then UpgradeChampion() end
end

function RL.OnPlayerDoTurn(pid)
	local S = RL.State
	if not S or not S.started or not IsTracked(pid) then return end
	local turn = Game.GetGameTurn()
	if pid == S.human then
		local touched = ExpireTemps()
		for tp in pairs(touched) do if tp ~= pid then RL.SyncPlayer(tp) end end
	end
	-- Every subsystem runs in its own protected call: one failure is logged
	-- to Lua.log and can never stop the others from running this turn.
	RL.Try("Sync", RL.SyncPlayer, pid)
	RL.Try("onTurn", CardsHook, pid, "onTurn", turn)
	RL.Try("Era", ProcessEra, pid)

	if pid == S.human then
		local active = not S.over or S.won
		RL.Try("Champion", ProcessChampion, turn)
		RL.Try("CheckBoss", RL.CheckBoss)
		if active then
			RL.Try("BossQueue", ProcessBossQueue, turn)
			RL.Try("Waves", ProcessWaves, turn)
			RL.Try("Milestone", function()
				if turn >= S.nextMilestone then
					S.nextMilestone = turn + RL.Interval(30)
					Fx.QueueDraft("Milestone: Turn " .. turn, 1)
				end
			end)
			RL.Try("Events", function()
				if turn >= S.nextEventTurn and #S.pending == 0 then
					S.nextEventTurn = turn + RL.Interval(RL.RandRange(12, 18))
					RL.RollEvent()
				end
			end)
			RL.Try("Quest", ProcessQuest, turn)
		end
		RL.Try("Defeat", CheckDefeat)
		-- SaveData writes are slow; AI-turn changes are flushed here, at the
		-- start of the human's turn, before any autosave is written.
		RL.Save()
	end
end

function RL.OnUnitKilled(killer, killed, unitType)
	local S = RL.State
	if not S or not S.started then return end
	if killer and killer >= 0 and IsTracked(killer) and killer ~= killed then
		if killer == S.human then S.stats.kills = S.stats.kills + 1 end
		CardsHook(killer, "onKill", killed, unitType)
	end
	if killed and killed >= 0 and IsTracked(killed) then
		if killed == S.human then
			S.stats.losses = S.stats.losses + 1
			local row = GameInfo.Units[unitType]
			if row and row.Class == "UNITCLASS_RL_CHAMPION" and not ChampionUnit() then RL.OnChampionDeath() end
		end
		CardsHook(killed, "onLoss", killer, unitType)
	end
	if S.boss.active then RL.CheckBoss() end
	if killer == S.human or killed == S.human then RL.Save() end
end

function RL.OnCityFounded(pid, x, y)
	local S = RL.State
	if not S or not S.started or not IsTracked(pid) then return end
	local pl = Map.GetPlot(x, y)
	local city = pl and pl:GetPlotCity()
	if not city then return end
	if pid == S.human and S.capX < 0 then S.capX, S.capY = x, y end
	CardsHook(pid, "onCityFounded", city)
	RL.SyncPlayer(pid)
	RL.Save()
end

function RL.OnCityCaptured(oldOwner, isCapital, x, y, newOwner)
	local S = RL.State
	if not S or not S.started then return end
	local pl = Map.GetPlot(x, y)
	local city = pl and pl:GetPlotCity()
	if city and IsTracked(newOwner) then
		CardsHook(newOwner, "onCityCaptured", city, oldOwner)
		RL.SyncPlayer(newOwner)
	end
	if IsTracked(oldOwner) then RL.SyncPlayer(oldOwner) end
	if oldOwner == S.human then CheckDefeat() end
	RL.Save()
end

function RL.OnUnitTrained(pid, cityId, unitId)
	local S = RL.State
	if not S or not S.started or not IsTracked(pid) then return end
	local u = Players[pid]:GetUnitByID(unitId)
	if u then RL.ApplyPromotions(pid, u) end
end

function RL.OnGameEnd()
	local S = RL.State
	if not S or not S.started then return end
	local ok, winner = pcall(function() return Game.GetWinner() end)
	local myTeam = Players[S.human]:GetTeam()
	if ok and winner == myTeam then
		RL.AwardLegacy("civwin", RL.LegacyAwards.CIV_WIN, "Won the game")
		if not S.won then RL.RunWon("Achieved a standard victory") end
		RL.UnlockAscension(S.ascension + 1)
	elseif not S.over then
		RL.RunLost("The game has ended")
	end
	RL.Save()
end

-- Score shown in the run summary
function RL.RunScore()
	local S = RL.State
	return S.bossesSlain * 100 + S.stats.kills * 2 + S.stats.cards * 10 + S.stats.quests * 25
		+ (Players[S.human]:GetCurrentEra() * 50) + (S.won and 500 or 0) + S.ascension * 100
end
