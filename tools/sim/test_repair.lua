-- Regression test: a save made with v1's spawning bug (UnitAITypes) must
-- repair itself on the next turn: the overdue raid fires and every Warlord
-- that should already have arrived is queued and spawned one at a time.
--   lua5.1 tools/sim/test_repair.lua
local here = arg[0]:match("(.*)/") or "."
MOCK_DIR = here
MOD_DIR = here .. "/../../Ascension Roguelite (v 1)"
math.randomseed(7)
dofile(MOCK_DIR .. "/mock_civ.lua")
MOCK.MakePlayer(0, true); MOCK.MakePlayer(1, false); MOCK.MakePlayer(63, false, true)
local function fail(m) MOCK.realprint("FAIL [repair]: " .. m); for _, e in ipairs(MOCK.errors) do MOCK.realprint("  " .. e) end; os.exit(1) end

include("AscensionRoguelite.lua")
MOCK.FoundCity(0, 12, 12, "Roma"); MOCK.FoundCity(1, 30, 25, "AI")
Events.LoadScreenClose.Fire()
MOCK.Click(Controls.StartBegin)

-- Recreate the broken save: turn 150, Renaissance, raid overdue since turn 38,
-- no Warlord ever spawned, era already recorded as processed.
local S = RL.State
MOCK.turn = 150
Players[0].era = 3; RL.PD(0).era = 3
S.wave.next = 38; S.wave.warned = true; S.wave.count = 0
S.bossesSpawned = {}; S.boss = { active = false }
RL.Save(); RL.State = nil; RL.Load(); S = RL.State

GameEvents.PlayerDoTurn.Fire(0)
if #MOCK.errors > 0 then fail(MOCK.errors[1]) end
if S.wave.count ~= 1 then fail("overdue raid did not fire") end
if S.wave.next <= 150 then fail("next raid not rescheduled") end
local barbs = 0; for _ in pairs(Players[63].units) do barbs = barbs + 1 end
if barbs < 3 then fail("raid spawned too few units: " .. barbs) end
if not S.boss.active or S.boss.idx ~= 0 then fail("first overdue Warlord (Grak) did not spawn") end
local q = table.concat(S.boss.queue, ",")
if q ~= "1,2,3" then fail("expected Warlords 1,2,3 queued, got " .. q) end

-- Slay each Warlord in turn: the next queued one must arrive.
for expect = 1, 3 do
	local leader = Players[63].units[S.boss.unitId]
	local t = leader.type; leader:Kill(false, -1)
	GameEvents.UnitKilledInCombat.Fire(0, 63, t)
	MOCK.turn = MOCK.turn + 1
	GameEvents.PlayerDoTurn.Fire(0)
	if #MOCK.errors > 0 then fail(MOCK.errors[1]) end
	if not S.boss.active or S.boss.idx ~= expect then fail("Warlord " .. expect .. " did not arrive after the previous one fell") end
end
-- Nothing is spawned twice
MOCK.turn = MOCK.turn + 1
GameEvents.PlayerDoTurn.Fire(0)
if #S.boss.queue ~= 0 then fail("queue not empty: " .. table.concat(S.boss.queue, ",")) end
MOCK.realprint("PASS [repair    ] broken v1 save recovered: raid fired (" .. barbs .. " units), Warlords 0-3 arrived in order, bossesSlain=" .. S.bossesSlain)
