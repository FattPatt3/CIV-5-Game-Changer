-- =====================================================================
-- Minimal mock of the Civilization V (BNW) Lua environment, sufficient to
-- load and exercise the Ascension mod outside the game.
-- Only the API surface the mod uses is implemented; every method follows
-- the argument conventions of the real game core (CvLua*.cpp).
-- =====================================================================

MOCK = { logs = {}, errors = {}, notifications = {}, storeStyle = "dot" }

local realprint = print
function print(...)
	local parts = {}
	for i = 1, select("#", ...) do parts[#parts + 1] = tostring(select(i, ...)) end
	local s = table.concat(parts, " ")
	MOCK.logs[#MOCK.logs + 1] = s
	if s:find("ERROR") then MOCK.errors[#MOCK.errors + 1] = s end
	if MOCK.verbose then realprint(s) end
end
MOCK.realprint = realprint

-- ---------------------------------------------------------------------
-- GameInfo
-- ---------------------------------------------------------------------
dofile(MOCK_DIR .. "/gameinfo_gen.lua")

GEN.Eras = {}
local eraNames = { "ERA_ANCIENT", "ERA_CLASSICAL", "ERA_MEDIEVAL", "ERA_RENAISSANCE", "ERA_INDUSTRIAL", "ERA_MODERN", "ERA_POSTMODERN", "ERA_FUTURE" }
for i, n in ipairs(eraNames) do GEN.Eras[i] = { ID = i - 1, Type = n, Description = "TXT_KEY_" .. n } end
GEN.GameSpeeds = { { ID = 0, Type = "GAMESPEED_MARATHON", TrainPercent = 300 }, { ID = 1, Type = "GAMESPEED_STANDARD", TrainPercent = 100 }, { ID = 2, Type = "GAMESPEED_QUICK", TrainPercent = 67 } }
GEN.Technologies = {}
for i = 1, 80 do GEN.Technologies[i] = { ID = i - 1, Type = "TECH_" .. i, Description = "TXT_KEY_TECH_" .. i } end
-- techs that the unit table references
local unitTechs = {}
for _, u in ipairs(GEN.Units) do if u.PrereqTech then unitTechs[u.PrereqTech] = true end end
for t in pairs(unitTechs) do GEN.Technologies[#GEN.Technologies + 1] = { ID = #GEN.Technologies, Type = t, Description = "TXT_KEY_" .. t } end
GEN.Civilizations = { { ID = 0, Type = "CIVILIZATION_ROME" }, { ID = 1, Type = "CIVILIZATION_GREECE" } }
GEN.Civilization_UnitClassOverrides = { { CivilizationType = "CIVILIZATION_ROME", UnitClassType = "UNITCLASS_SWORDSMAN", UnitType = "UNIT_SWORDSMAN" } }
GEN.Building_FeatureYieldChanges = GEN.Building_FeatureYieldChanges or {}
GEN.UnitAIInfos = { { ID = 0, Type = "UNITAI_UNKNOWN" }, { ID = 1, Type = "UNITAI_SETTLE" }, { ID = 2, Type = "UNITAI_WORKER" }, { ID = 3, Type = "UNITAI_ATTACK" }, { ID = 4, Type = "UNITAI_DEFENSE" } }

local function MakeTable(rows, hasId)
	local byKey = {}
	for i, r in ipairs(rows) do
		if hasId and r.ID == nil then r.ID = i - 1 end
		if r.ID then byKey[r.ID] = r end
		if r.Type then byKey[r.Type] = r end
	end
	local t = {}
	setmetatable(t, {
		__index = function(_, k) return byKey[k] end,
		__call = function(_, filter)
			local i = 0
			return function()
				while true do
					i = i + 1
					local r = rows[i]
					if not r then return nil end
					local ok = true
					if filter then for fk, fv in pairs(filter) do if r[fk] ~= fv then ok = false end end end
					if ok then return r end
				end
			end
		end,
	})
	return t
end

GameInfo = {}
GameInfoTypes = {}
for name, rows in pairs(GEN) do
	-- generated IDs from sqlite are 1-based; Civ5 IDs are 0-based - normalise
	local hasType = rows[1] and rows[1].Type
	if hasType and rows[1].ID then for i, r in ipairs(rows) do r.ID = i - 1 end end
	GameInfo[name] = MakeTable(rows, hasType and true)
	if hasType then for _, r in ipairs(rows) do GameInfoTypes[r.Type] = r.ID end end
end

-- ---------------------------------------------------------------------
-- Enums & misc globals
-- ---------------------------------------------------------------------
GameDefines = { MAX_PLAYERS = 64, MAX_MAJOR_CIVS = 22, MAX_CIV_PLAYERS = 63 }
DomainTypes = { DOMAIN_LAND = 0, DOMAIN_SEA = 1, DOMAIN_AIR = 2 }
-- NOTE: Civ V does NOT register a UnitAITypes global (see CvLuaEnums.cpp);
-- unit AI ids live in GameInfoTypes (UnitAIInfos table). Don't add one here.
NotificationTypes = { NOTIFICATION_GENERIC = 0 }
Mouse = { eLClick = 1 }
KeyEvents = { KeyDown = 1 }
Keys = { VK_ESCAPE = 27 }
Locale = { ConvertTextKey = function(k) return tostring(k) end }
UI = { LookAt = function() end, RequestMinimapBroadcast = function() end }

-- ---------------------------------------------------------------------
-- Map
-- ---------------------------------------------------------------------
MOCK.W, MOCK.H = 50, 36
local plots = {}
local Plot = {}
Plot.__index = Plot
function Plot:GetX() return self.x end
function Plot:GetY() return self.y end
function Plot:IsWater() return self.water end
function Plot:IsMountain() return self.mountain end
function Plot:IsImpassable() return self.mountain end
function Plot:IsCity() return self.city ~= nil end
function Plot:GetPlotCity() return self.city end
function Plot:GetNumUnits() local n = 0; for _ in pairs(self.units) do n = n + 1 end; return n end
function Plot:GetArea() return self.water and 2 or 1 end
function Plot:GetOwner() return self.owner end
function Plot:GetResourceType(team) return self.resource end
function Plot:SetResourceType(r, n) assert(type(r) == "number"); self.resource = r end
function Plot:GetImprovementType() return -1 end
function Plot:SetRevealed(team, b) assert(type(team) == "number"); self.revealed = b end

for y = 0, MOCK.H - 1 do
	for x = 0, MOCK.W - 1 do
		local p = setmetatable({ x = x, y = y, units = {}, owner = -1, resource = -1,
			water = (x < 2 or x > MOCK.W - 3), mountain = ((x * 7 + y * 13) % 23 == 0) }, Plot)
		plots[y * MOCK.W + x] = p
	end
end

Map = {}
function Map.GetPlot(x, y)
	if x < 0 or y < 0 or x >= MOCK.W or y >= MOCK.H then return nil end
	return plots[y * MOCK.W + x]
end
function Map.PlotDistance(x1, y1, x2, y2) return math.max(math.abs(x1 - x2), math.abs(y1 - y2)) end
function Map.PlotXYWithRangeCheck(x, y, dx, dy, r)
	if math.max(math.abs(dx), math.abs(dy)) > r then return nil end
	return Map.GetPlot(x + dx, y + dy)
end

-- ---------------------------------------------------------------------
-- Units
-- ---------------------------------------------------------------------
local Unit = {}
Unit.__index = Unit
local nextUnitId = 1
function Unit:GetID() return self.id end
function Unit:GetX() return self.x end
function Unit:GetY() return self.y end
function Unit:Plot() return Map.GetPlot(self.x, self.y) end
function Unit:GetUnitType() return self.type end
function Unit:GetUnitClassType() return GameInfoTypes[GameInfo.Units[self.type].Class] end
function Unit:IsCombatUnit() return (GameInfo.Units[self.type].Combat or 0) > 0 end
function Unit:GetDomainType() return GameInfo.Units[self.type].Domain == "DOMAIN_SEA" and 1 or 0 end
function Unit:GetDamage() return self.damage end
function Unit:SetDamage(v, ePlayer) assert(type(v) == "number"); self.damage = math.max(0, math.min(100, v)) end
function Unit:GetExperience() return self.xp end
function Unit:SetExperience(v) self.xp = v end
function Unit:ChangeExperience(v, iMax) assert(type(v) == "number"); self.xp = self.xp + v end
function Unit:GetLevel() return self.level end
function Unit:SetLevel(v) self.level = v end
function Unit:IsHasPromotion(id) assert(type(id) == "number"); return self.promos[id] == true end
function Unit:SetHasPromotion(id, b) assert(type(id) == "number" and GameInfo.UnitPromotions[id], "bad promo " .. tostring(id)); self.promos[id] = b or nil end
function Unit:SetName(n) self.name = n end
function Unit:IsDead() return self.dead end
function Unit:IsDelayedDeath() return false end
function Unit:JumpToNearestValidPlot() return true end
function Unit:Kill(bDelay, ePlayer)
	self.dead = true
	local p = Players[self.owner]
	p.units[self.id] = nil
	local pl = self:Plot(); if pl then pl.units[self.id] = nil end
end

-- ---------------------------------------------------------------------
-- Cities
-- ---------------------------------------------------------------------
local City = {}
City.__index = City
local nextCityId = 1
function City:GetID() return self.id end
function City:GetX() return self.x end
function City:GetY() return self.y end
function City:Plot() return Map.GetPlot(self.x, self.y) end
function City:GetName() return self.name end
function City:GetOwner() return self.owner end
function City:IsCapital() return Players[self.owner].capital == self end
function City:GetPopulation() return self.pop end
function City:ChangePopulation(n, b) self.pop = math.max(1, self.pop + n) end
function City:GetNumRealBuilding(id) assert(type(id) == "number"); return self.buildings[id] or 0 end
function City:SetNumRealBuilding(id, n)
	assert(type(id) == "number" and GameInfo.Buildings[id], "bad building id"); assert(n >= 0, "negative count")
	self.buildings[id] = (n > 0) and n or nil
end
function City:IsHasBuilding(id) return (self.buildings[id] or 0) > 0 end
function City:ChangeProduction(n) self.production = (self.production or 0) + n end
function City:GetMaxHitPoints() return 200 end
function City:GetDamage() return self.damage end
function City:SetDamage(v) assert(v < 200); self.damage = v end
function City:IsCoastal(n) return self.x < 5 end

-- ---------------------------------------------------------------------
-- Teams & players
-- ---------------------------------------------------------------------
local TeamTechs = {}
TeamTechs.__index = TeamTechs
function TeamTechs:ChangeResearchProgress(tech, n, pid)
	assert(type(tech) == "number" and type(n) == "number" and type(pid) == "number")
	self.team.progress[tech] = (self.team.progress[tech] or 0) + n
end

local Team = {}
Team.__index = Team
function Team:IsHasTech(t) return self.techs[t] == true end
function Team:SetHasTech(t, b, pid, first, announce)
	assert(type(pid) == "number", "SetHasTech needs the player id")
	self.techs[t] = b or nil
end
function Team:GetTeamTechs() return setmetatable({ team = self }, TeamTechs) end
function Team:IsHasMet(t) return true end

local Player = {}
Player.__index = Player
function Player:GetID() return self.id end
function Player:IsAlive() return self.alive end
function Player:IsHuman() return self.human end
function Player:IsMinorCiv() return false end
function Player:IsBarbarian() return self.barbarian end
function Player:GetTeam() return self.id end
function Player:GetCivilizationType() return self.human and 0 or 1 end
function Player:GetCivilizationShortDescription() return "Civ" .. self.id end
function Player:GetCurrentEra() return self.era end
function Player:GetGold() return self.gold end
function Player:ChangeGold(n) self.gold = math.max(0, self.gold + n) end
function Player:GetFaith() return self.faith end
function Player:ChangeFaith(n) self.faith = math.max(0, self.faith + n) end
function Player:ChangeJONSCulture(n) self.culture = self.culture + n end
function Player:ChangeGoldenAgeTurns(n) self.ga = (self.ga or 0) + n end
function Player:GetNextPolicyCost() return 50 + 20 * self.policies end
function Player:GetNumPolicies() return self.policies end
function Player:GetCurrentResearch() return 3 end
function Player:GetResearchCost(t) return 300 end
function Player:CanResearch(t) return not Teams[self.id].techs[t] and t < 40 end
function Player:GetNumCities() local n = 0; for _ in pairs(self.cities) do n = n + 1 end; return n end
function Player:GetCapitalCity() return self.capital end
function Player:GetStartingPlot() return Map.GetPlot(self.sx, self.sy) end
function Player:AddNotification(t, text, title, x, y)
	assert(type(text) == "string" and type(title) == "string")
	MOCK.notifications[#MOCK.notifications + 1] = title .. ": " .. text
end
function Player:Cities()
	local list = {}
	for _, c in pairs(self.cities) do list[#list + 1] = c end
	table.sort(list, function(a, b) return a.id < b.id end)
	local i = 0
	return function() i = i + 1; return list[i] end
end
function Player:Units()
	local list = {}
	for _, u in pairs(self.units) do list[#list + 1] = u end
	table.sort(list, function(a, b) return a.id < b.id end)
	local i = 0
	return function() i = i + 1; return list[i] end
end
function Player:GetUnitByID(id) return self.units[id] end
function Player:InitUnit(typeId, x, y, ai, dir)
	assert(type(typeId) == "number" and GameInfo.Units[typeId], "InitUnit bad type " .. tostring(typeId))
	local u = setmetatable({ id = nextUnitId, type = typeId, x = x, y = y, damage = 0, xp = 0, level = 1, promos = {}, owner = self.id, dead = false }, Unit)
	nextUnitId = nextUnitId + 1
	local row = GameInfo.Units[typeId]
	for fp in GameInfo.Unit_FreePromotions{ UnitType = row.Type } do u.promos[GameInfoTypes[fp.PromotionType]] = true end
	self.units[u.id] = u
	Map.GetPlot(x, y).units[u.id] = u
	MOCK.spawned = (MOCK.spawned or 0) + 1
	return u
end

function MOCK.FoundCity(pid, x, y, name)
	local p = Players[pid]
	local c = setmetatable({ id = nextCityId, x = x, y = y, owner = pid, pop = 3, buildings = {}, damage = 0, name = name or ("City" .. nextCityId) }, City)
	nextCityId = nextCityId + 1
	p.cities[c.id] = c
	if not p.capital then p.capital = c end
	Map.GetPlot(x, y).city = c
	Map.GetPlot(x, y).owner = pid
	return c
end

function MOCK.TransferCity(c, newOwner)
	local old = Players[c.owner]
	old.cities[c.id] = nil
	if old.capital == c then
		old.capital = nil
		for _, oc in pairs(old.cities) do old.capital = oc; break end
	end
	c.owner = newOwner
	Players[newOwner].cities[c.id] = c
	c.buildings = {}
end

Players, Teams = {}, {}
function MOCK.MakePlayer(id, human, barbarian)
	Players[id] = setmetatable({ id = id, human = human, barbarian = barbarian or false, alive = true, era = 0, gold = 100, faith = 0,
		culture = 0, policies = 0, cities = {}, units = {}, sx = 6 + id * 8, sy = 10 }, Player)
	Teams[id] = setmetatable({ id = id, techs = {}, progress = {} }, Team)
end

-- ---------------------------------------------------------------------
-- Game, events, persistence
-- ---------------------------------------------------------------------
MOCK.turn = 0
MOCK.speed = 1
Game = {}
function Game.GetGameTurn() return MOCK.turn end
function Game.GetActivePlayer() return 0 end
function Game.GetGameSpeedType() return MOCK.speed end
function Game.Rand(n, s) assert(type(s) == "string"); return math.random(0, n - 1) end
function Game.GetWinner() return MOCK.winner or -1 end
function Game.UpdateFOW() end

local function EventSlot()
	local fns = {}
	return { Add = function(f) fns[#fns + 1] = f end, Fire = function(...) for _, f in ipairs(fns) do f(...) end end, count = function() return #fns end }
end
GameEvents = setmetatable({}, { __index = function(t, k) local s = EventSlot(); rawset(t, k, s); return s end })
Events = setmetatable({}, { __index = function(t, k) local s = EventSlot(); rawset(t, k, s); return s end })
Events.AudioPlay2DSound = function() end

local function MakeStore(data)
	if MOCK.storeStyle == "dot" then
		return { GetValue = function(k) assert(type(k) == "string", "dot-style store got non-string key"); return data[k] end,
		         SetValue = function(k, v) assert(type(k) == "string"); data[k] = v end }
	end
	local o = {}
	function o:GetValue(k) assert(type(k) == "string", "colon-style store got non-string key"); return data[k] end
	function o:SetValue(k, v) assert(type(k) == "string"); data[k] = v end
	return o
end
MOCK.saveData, MOCK.userData = {}, {}
Modding = {
	OpenSaveData = function() return MakeStore(MOCK.saveData) end,
	OpenUserData = function(name, v) return MakeStore(MOCK.userData) end,
}

-- ---------------------------------------------------------------------
-- UI stubs: every control records callbacks, text and visibility.
-- ---------------------------------------------------------------------
local function NewControl(name)
	local c = { name = name, hidden = false, text = "", callbacks = {}, disabled = false }
	return setmetatable(c, { __index = function(t, k)
		if k == "SetHide" then return function(self, b) self.hidden = b end end
		if k == "IsHidden" then return function(self) return self.hidden end end
		if k == "SetText" then return function(self, s) assert(type(s) == "string" or type(s) == "number", "SetText non-string on " .. name); self.text = tostring(s) end end
		if k == "SetDisabled" then return function(self, b) self.disabled = b end end
		if k == "RegisterCallback" then return function(self, ev, f) self.callbacks[ev] = f end end
		if k == "GetSizeY" then return function() return 20 end end
		return function() end
	end })
end
MOCK.NewControl = NewControl

Controls = setmetatable({}, { __index = function(t, k) local c = NewControl(k); rawset(t, k, c); return c end })
ContextPtr = { SetInputHandler = function(self, f) MOCK.inputHandler = f end, SetHide = function() end }

InstanceManager = {}
function InstanceManager:new(name, root, parent)
	local im = { name = name, root = root, live = {} }
	function im:GetInstance()
		local inst = setmetatable({}, { __index = function(t, k) local c = NewControl(name .. "." .. k); rawset(t, k, c); return c end })
		self.live[#self.live + 1] = inst
		return inst
	end
	function im:ResetInstances() self.live = {} end
	return im
end

function include(name)
	if name == "InstanceManager" then return end
	for _, d in ipairs({ MOD_DIR .. "/Lua/", MOD_DIR .. "/UI/" }) do
		local f = io.open(d .. name, "r")
		if f then f:close(); dofile(d .. name); return end
	end
	error("include not found: " .. name)
end

function MOCK.Click(control)
	local cb = control.callbacks[Mouse.eLClick]
	assert(cb, "no click callback on " .. tostring(control.name))
	assert(not control.disabled, "clicked a disabled control " .. tostring(control.name))
	cb()
end

-- ---------------------------------------------------------------------
-- Strict globals: reading any global the real game does not provide is an
-- error (and is recorded even if the mod's pcall swallows it).
-- ---------------------------------------------------------------------
local ALLOWED_UNDEFINED = { RL = true, PRELOAD_USERDATA = true, SIM_USERDATA = true }
setmetatable(_G, { __index = function(_, k)
	if ALLOWED_UNDEFINED[k] then return nil end
	local msg = "ERROR: read of undefined global '" .. tostring(k) .. "' (not provided by Civ V)"
	MOCK.errors[#MOCK.errors + 1] = msg
	error(msg, 2)
end })
