-- =====================================================================
-- Offline simulation of full Ascension runs.
--   lua5.1 tools/sim/run_sim.lua [scenario] [seed]
-- Loads the real mod files through the mock API, starts a run by clicking
-- the real Start panel, then plays N turns: firing game events, clicking
-- drafts/events/infos through the UI controls, killing units (including
-- Warlords and the Champion), advancing eras, capturing cities, and
-- round-tripping the save every turn. Fails on any Lua error.
-- =====================================================================

local here = arg[0]:match("(.*)/") or "."
MOCK_DIR = here
MOD_DIR = here .. "/../../Ascension Roguelite (v 1)"

local scenario = arg[1] or "standard"
local seed = tonumber(arg[2] or "1")
math.randomseed(seed)

dofile(MOCK_DIR .. "/mock_civ.lua")
os.time = function() return 1700000000 + seed end   -- reproducible run seeds
if scenario == "colonstore" then MOCK.storeStyle = "colon" end
if scenario == "quick" then MOCK.speed = 2 end
if scenario == "marathon" then MOCK.speed = 0 end

if scenario == "asc10" then MOCK.userData.ascUnlocked = 10; MOCK.userData.legacy = 300 end
if scenario == "asc5life" then MOCK.userData.ascUnlocked = 5; MOCK.userData.up_SECOND_WIND = 1 end
-- Profile carried between runs (meta-progression test)
if PRELOAD_USERDATA then for k, v in pairs(PRELOAD_USERDATA) do MOCK.userData[k] = v end end

-- World: human 0, AIs 1..3, barbarians 63
MOCK.MakePlayer(0, true)
for i = 1, 3 do MOCK.MakePlayer(i, false) end
MOCK.MakePlayer(63, false, true)
Players[63].alive = true

local function fail(msg)
	MOCK.realprint("FAIL [" .. scenario .. " seed " .. seed .. "]: " .. msg)
	for i = math.max(1, #MOCK.logs - 15), #MOCK.logs do MOCK.realprint("   log: " .. MOCK.logs[i]) end
	os.exit(1)
end

local ok, err = pcall(include, "AscensionRoguelite.lua")
if not ok then fail("loading UI: " .. tostring(err)) end
if #MOCK.errors > 0 then fail("errors during load: " .. MOCK.errors[1]) end

-- Settlers found capitals on turn 0
local cap = MOCK.FoundCity(0, 12, 12, "Roma")
for i = 1, 3 do MOCK.FoundCity(i, 10 + i * 9, 25, "AI" .. i) end
GameEvents.PlayerCityFounded.Fire(0, 12, 12)

Events.LoadScreenClose.Fire()
if Controls.StartPanel.hidden then fail("start panel not shown on a fresh game") end

-- Choose ascension & origin via the UI
local wantAsc = 0
if scenario == "asc10" then wantAsc = 10 end
if scenario == "asc5life" then wantAsc = 5 end
for i = 1, wantAsc do MOCK.Click(Controls.AscUp) end
if scenario == "asc10" then
	-- cycle to a locked origin and buy it
	MOCK.Click(Controls.OriginNext); MOCK.Click(Controls.OriginNext); MOCK.Click(Controls.OriginNext)
	if not Controls.OriginBuy.hidden and not Controls.OriginBuy.disabled then MOCK.Click(Controls.OriginBuy) end
	if Controls.StartBegin.disabled then MOCK.Click(Controls.OriginNext); for i = 1, 5 do MOCK.Click(Controls.OriginNext) end end
end
-- buy any affordable legacy upgrade through the UI
local im = nil
MOCK.Click(Controls.StartBegin)
if not RL.State.started then fail("run did not start") end
if RL.State.ascension ~= math.min(wantAsc, RL.Meta.AscUnlocked()) then fail("ascension mismatch " .. RL.State.ascension) end
if not RL.ChampionUnit() then fail("champion not spawned") end

local function resolveUI()
	local guard = 0
	while guard < 50 do
		guard = guard + 1
		RL.UI.ShowNext(true)
		if not Controls.InfoPanel.hidden then
			MOCK.Click(Controls.InfoOK)
		elseif not Controls.EventPanel.hidden then
			-- click a random enabled option through the real option instances
			local live = {}
			for _, inst in ipairs(MOCK.lastOptionIM and MOCK.lastOptionIM.live or {}) do end
			local ev = RL.DescribeEvent()
			local choices = {}
			for i, o in ipairs(ev.options) do if o.ok then choices[#choices + 1] = i end end
			if #choices == 0 then fail("event with no available option: " .. ev.title) end
			local before = #RL.State.pending
			local res = RL.ResolveEvent(choices[math.random(#choices)])
			if res == nil or #RL.State.pending ~= before - 1 then fail("event did not resolve: " .. ev.title) end
			Controls.EventPanel.hidden = true
		elseif not Controls.DraftPanel.hidden then
			local d = RL.State.drafts[1]
			if #d.cards < 2 then fail("draft with <2 cards: " .. d.title) end
			local r = math.random(10)
			if r == 1 and RL.State.rerolls > 0 then MOCK.Click(Controls.DraftReroll)
			elseif r == 2 then MOCK.Click(Controls.DraftSkip)
			else RL.ChooseDraft(math.random(#d.cards)); Controls.DraftPanel.hidden = true end
		elseif not Controls.RunOverPanel.hidden then
			MOCK.Click(Controls.RunOverContinue)
		else
			return
		end
		if #MOCK.errors > 0 then fail(MOCK.errors[1]) end
	end
	fail("UI queue did not drain")
end
resolveUI()

local TURNS = (scenario == "short") and 120 or 330
local eraTurns = { 45, 90, 135, 175, 215, 255, 295 }
local killedChampion = false
for turn = 1, TURNS do
	MOCK.turn = turn
	-- eras advance on a schedule (AIs slightly behind)
	for e, t in ipairs(eraTurns) do
		if turn == t then Players[0].era = e end
		if turn == t + 8 then for i = 1, 3 do Players[i].era = e end end
	end
	-- expansion
	if turn % 40 == 0 and Players[0]:GetNumCities() < 6 then
		local c = MOCK.FoundCity(0, 8 + turn % 30, 6 + (turn / 40) * 3, "Colony" .. turn)
		GameEvents.PlayerCityFounded.Fire(0, c.x, c.y)
	end
	-- combat: human kills some barbarians (sometimes the Warlord), loses some units
	for _, u in pairs(Players[63].units) do
		if math.random(100) <= 22 then
			local t = u.type
			u:Kill(false, -1)
			GameEvents.UnitKilledInCombat.Fire(0, 63, t)
		end
	end
	if math.random(100) <= 8 then
		for _, u in pairs(Players[0].units) do
			if u:IsCombatUnit() and not RL.IsChampion(u) then local t = u.type; u:Kill(false, -1); GameEvents.UnitKilledInCombat.Fire(63, 0, t); break end
		end
	end
	if turn == 100 and not killedChampion then
		local c = RL.ChampionUnit()
		if c then
			MOCK.livesAtChampionDeath = RL.State.lives
			local t = c.type; c:Kill(false, -1); GameEvents.UnitKilledInCombat.Fire(63, 0, t); killedChampion = true
			resolveUI()
			if RL.State.ascension >= 5 then
				-- Last Stand: run ends unless an extra life absorbs it
				if MOCK.livesAtChampionDeath == 0 and not RL.State.over then fail("Last Stand did not end the run") end
				if MOCK.livesAtChampionDeath > 0 and RL.State.lives ~= MOCK.livesAtChampionDeath - 1 then fail("extra life not consumed") end
			end
		end
	end
	if math.random(100) <= 5 then for i = 1, 3 do GameEvents.UnitKilledInCombat.Fire(i, 63, GameInfoTypes.UNIT_WARRIOR) end end
	Players[0].policies = math.floor(turn / 15)
	Players[0].gold = Players[0].gold + 8

	for pid = 0, 3 do GameEvents.PlayerDoTurn.Fire(pid) end
	GameEvents.PlayerDoTurn.Fire(63)
	if #MOCK.errors > 0 then fail("turn " .. turn .. ": " .. MOCK.errors[1]) end

	Events.ActivePlayerTurnStart.Fire()
	resolveUI()

	-- overview, legacy & tooltip rendering must never error
	if turn % 25 == 0 then
		MOCK.Click(Controls.HUDButton)
		if Controls.OverviewPanel.hidden then fail("overview did not open") end
		MOCK.Click(Controls.OvLegacy)
		MOCK.Click(Controls.StartClose)
	end

	-- save/load round trip
	local before = RL.Serialize(RL.State)
	RL.State = nil
	RL.Load()
	local after = RL.Serialize(RL.State)
	if #before ~= #after then
		local b, a = RL.Deserialize(before), RL.State
		for k, v in pairs(b) do
			local x, y = RL.Serialize(v), RL.Serialize(a[k])
			if x ~= y then MOCK.realprint("  differs: " .. tostring(k) .. "\n    mem:  " .. x:sub(1, 300) .. "\n    save: " .. y:sub(1, 300)) end
		end
		fail("save round-trip changed state at turn " .. turn)
	end

	-- dummy-building invariants: the human's cities hold exactly what the run says
	for city in Players[0]:Cities() do
		for id, n in pairs(city.buildings) do
			if n > 12 then fail("runaway building stack " .. GameInfo.Buildings[id].Type .. " x" .. n) end
		end
	end
	Events.ActivePlayerTurnEnd.Fire()

	if scenario == "lose" and turn == 150 then
		-- capital falls
		local livesBefore = RL.State.lives
		MOCK.TransferCity(cap, 63)
		GameEvents.CityCaptureComplete.Fire(0, true, cap.x, cap.y, 63, 3, true)
		resolveUI()
		if livesBefore == 0 and not RL.State.over then fail("capital loss did not end the run") end
		if livesBefore > 0 then
			if RL.State.lives ~= livesBefore - 1 or RL.State.over then fail("extra life did not absorb capital loss") end
			-- the heart of the empire moves to the new capital; lose that too to end it for real
			local nc = Players[0]:GetCapitalCity()
			if nc and RL.State.lives == 0 then
				MOCK.TransferCity(nc, 63)
				GameEvents.CityCaptureComplete.Fire(0, true, nc.x, nc.y, 63, 3, true)
				resolveUI()
				if not RL.State.over then fail("second capital loss did not end the run") end
			end
		end
	end
end

local S = RL.State
local cards = 0
for _, s in pairs(RL.PD(0).cards) do cards = cards + s end
local aiCards = 0
for i = 1, 3 do for _, s in pairs(RL.PD(i).cards) do aiCards = aiCards + s end end
local hasTemp = 0
for city in Players[0]:Cities() do for _ in pairs(city.buildings) do hasTemp = hasTemp + 1 end end

-- Sanity expectations for a full run
if scenario == "asc5life" then
	if (MOCK.livesAtChampionDeath or 0) < 1 then fail("expected an extra life at champion death") end
	if not RL.ChampionUnit() and not S.over then fail("champion not respawned after extra life") end
end
if scenario == "lose" then
	if S.won or not S.over then fail("lost run ended as won=" .. tostring(S.won) .. " over=" .. tostring(S.over)) end
end
local fullSpeed = (scenario ~= "marathon") and not (S.ascension >= 5 and MOCK.livesAtChampionDeath == 0)
if scenario ~= "short" and scenario ~= "lose" and fullSpeed then
	if S.bossesSlain < 3 then fail("too few warlords slain: " .. S.bossesSlain) end
	if S.wave.count < 5 then fail("too few horde raids: " .. S.wave.count) end
	if S.stats.events < 8 then fail("too few events: " .. S.stats.events) end
end
if cards < 5 then fail("too few boons acquired: " .. cards) end
if aiCards < 3 then fail("AI rivals got no boons") end
if not killedChampion and TURNS >= 100 then fail("champion death path not exercised") end

MOCK.realprint(string.format("PASS [%-10s seed %2d] asc=%d turns=%d boons=%d aiBoons=%d curses=%d warlords=%d raids=%d events=%d drafts=%d bounties=%d legacy=%d won=%s over=%s champTier=%d spawned=%d",
	scenario, seed, S.ascension, TURNS, cards, aiCards, RL.Fx.CurseCount(0), S.bossesSlain, S.wave.count, S.stats.events, S.stats.drafts,
	S.stats.quests, RL.Meta.Legacy(), tostring(S.won), tostring(S.over), S.champion.tier, MOCK.spawned or 0))

-- hand the profile to the next run in the same process (meta-progression)
SIM_USERDATA = MOCK.userData
if os.getenv("SIM_LOG") then for i = #RL.State.log, 1, -1 do MOCK.realprint("  " .. RL.State.log[i]) end end
