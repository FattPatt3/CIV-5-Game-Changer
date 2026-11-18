-- =====================================================================
-- ASCENSION: ROGUELITE OVERHAUL -- UI controller & game-event wiring
-- This InGameUIAddin context hosts the whole mod: it loads the data and
-- engine, subscribes to game events and drives every panel.
-- =====================================================================

include("InstanceManager")
include("RL_Util.lua")
include("RL_Data_Cards.lua")
include("RL_Data_World.lua")
include("RL_Data_Events.lua")
include("RL_Engine.lua")

local C = RL.C
local S -- RL.State

local cardIM    = InstanceManager:new("CardInstance", "Card", Controls.CardStack)
local optionIM  = InstanceManager:new("OptionInstance", "Option", Controls.OptionStack)
local lineIM    = InstanceManager:new("LineInstance", "Line", Controls.OverviewStack)
local upgradeIM = InstanceManager:new("UpgradeInstance", "Row", Controls.UpgradeStack)

local PANELS = { "DraftPanel", "EventPanel", "InfoPanel", "OverviewPanel", "StartPanel", "RunOverPanel" }
local startAsc, startOrigin = 0, 1
local eventResolved = false

local function AutoOpen() return RL.Meta.Num("optNoAuto") == 0 end

local function AnyOpen()
	for _, n in ipairs(PANELS) do if not Controls[n]:IsHidden() then return true end end
	return false
end

local function HideAll() for _, n in ipairs(PANELS) do Controls[n]:SetHide(true) end end

local function Sound(name) pcall(function() Events.AudioPlay2DSound(name) end) end

-- =====================================================================
-- HUD
-- =====================================================================
function RL.UI.Refresh()
	S = RL.State
	if not S then return end
	if not S.started then
		Controls.HUDLabel:SetText(C.yellow .. "ASCENSION: Begin your run" .. C.e)
		return
	end
	local waiting = #S.drafts + #S.pending + #S.infos
	local status = "ASC " .. S.ascension .. "  [ICON_TROPHY_GOLD] " .. S.bossesSlain .. "  [ICON_GOLDEN_AGE] " .. RL.Meta.Legacy()
	if S.won then status = C.gold .. "VICTORIOUS" .. C.e .. "  " .. status
	elseif S.over then status = C.neg .. "RUN OVER" .. C.e .. "  " .. status end
	if waiting > 0 then status = status .. "  " .. C.pos .. "(" .. waiting .. " waiting)" .. C.e end
	Controls.HUDLabel:SetText(status)

	local tip = {}
	tip[#tip + 1] = "Ascension " .. S.ascension .. "   Run seed " .. tostring(S.seed)
	tip[#tip + 1] = "Drafts waiting: " .. #S.drafts .. "   Events waiting: " .. #S.pending
	tip[#tip + 1] = "Rerolls: " .. S.rerolls .. "   Extra lives: " .. S.lives
	if not S.over or S.won then
		local t = S.wave.next - Game.GetGameTurn()
		tip[#tip + 1] = "Next Horde raid: " .. ((t > 0) and (t .. " turns") or "imminent") .. " (~" .. RL.WaveSize() .. " units)"
	end
	if S.boss.active then tip[#tip + 1] = C.neg .. "Warlord at large: " .. (S.boss.name or "?") .. C.e end
	if S.quest then
		local prog, target = RL.QuestProgress()
		tip[#tip + 1] = "Bounty: " .. S.quest.desc .. " (" .. math.max(0, prog) .. "/" .. target .. ", ends T" .. S.quest.deadline .. ")"
	end
	tip[#tip + 1] = "[NEWLINE]Click to open the run overview."
	Controls.HUDButton:SetToolTipString(table.concat(tip, "[NEWLINE]"))
end

-- =====================================================================
-- DRAFT PANEL
-- =====================================================================
local function ShowDraft()
	S = RL.State
	local d = S.drafts[1]
	if not d then Controls.DraftPanel:SetHide(true); return false end
	HideAll()
	cardIM:ResetInstances()
	Controls.DraftTitle:SetText(C.gold .. d.title .. C.e)
	local sub = "Choose one Boon. (" .. #S.drafts .. " draft" .. (#S.drafts > 1 and "s" or "") .. " waiting)"
	if d.floor and d.floor >= 2 then sub = sub .. "  Guaranteed " .. RL.RarityText(d.floor) .. " or better." end
	if d.focus and RL.TAGS[d.focus] then sub = sub .. "  Focus: " .. RL.TAGS[d.focus].icon .. " " .. RL.TAGS[d.focus].name end
	Controls.DraftSub:SetText(sub)
	for i, id in ipairs(d.cards) do
		local c = RL.CardById[id]
		if c then
			local inst = cardIM:GetInstance()
			local owned = RL.Fx.Stacks(S.human, id)
			inst.Rarity:SetText(RL.RarityText(c.rarity))
			inst.Name:SetText(C.white .. c.name .. C.e)
			inst.Tags:SetText(RL.TagText(c.tags))
			local desc = c.desc
			if type(desc) == "function" then desc = RL.Try("desc", desc, owned + 1) or "" end
			inst.Desc:SetText(desc)
			inst.Owned:SetText((c.max > 1) and ("Owned " .. owned .. " / " .. c.max) or (owned > 0 and "Owned" or ""))
			if d.pacts and d.pacts[i] then
				inst.Pact:SetText(C.neg .. "PACT:" .. C.e .. " also gain a random " .. RL.RarityText(2) .. " boon AND a random " .. C.neg .. "Curse" .. C.e)
			else
				inst.Pact:SetText("")
			end
			inst.Card:SetToolTipString(c.name .. "[NEWLINE]" .. desc)
			inst.Card:RegisterCallback(Mouse.eLClick, function()
				Sound("AS2D_INTERFACE_NEW_ERA")
				RL.ChooseDraft(i)
				RL.UI.Refresh()
				Controls.DraftPanel:SetHide(true)
				RL.UI.ShowNext(true)
			end)
		end
	end
	Controls.CardStack:CalculateSize()
	Controls.CardStack:ReprocessAnchoring()
	Controls.DraftReroll:SetText("Reroll (" .. S.rerolls .. " left)")
	Controls.DraftReroll:SetDisabled(S.rerolls <= 0)
	Controls.DraftSkip:SetText("Skip: +" .. RL.Fx.Amt(S.human, 30, 20) .. " [ICON_GOLD] and +1 Reroll")
	Controls.DraftPanel:SetHide(false)
	return true
end

Controls.DraftReroll:RegisterCallback(Mouse.eLClick, function()
	if RL.RerollDraft() then Sound("AS2D_INTERFACE_CITY_SCREEN_PURCHASE"); ShowDraft(); RL.UI.Refresh() end
end)
Controls.DraftSkip:RegisterCallback(Mouse.eLClick, function()
	RL.SkipDraft(); RL.UI.Refresh(); Controls.DraftPanel:SetHide(true); RL.UI.ShowNext(true)
end)
Controls.DraftLater:RegisterCallback(Mouse.eLClick, function() Controls.DraftPanel:SetHide(true) end)

-- =====================================================================
-- EVENT PANEL
-- =====================================================================
local function ShowEvent()
	S = RL.State
	local ev = RL.DescribeEvent()
	if not ev then Controls.EventPanel:SetHide(true); return false end
	HideAll()
	eventResolved = false
	optionIM:ResetInstances()
	Controls.EventTitle:SetText(C.yellow .. ev.title .. C.e)
	Controls.EventText:SetText(ev.text)
	Controls.EventText:SetHide(false)
	Controls.EventResult:SetHide(true)
	Controls.EventContinue:SetHide(true)
	Controls.EventLater:SetHide(false)
	Controls.OptionStack:SetHide(false)
	-- options are stacked upward from the bottom, so add them in reverse
	for i = #ev.options, 1, -1 do
		local o = ev.options[i]
		local inst = optionIM:GetInstance()
		local label = o.label
		if not o.ok then label = C.grey .. label .. C.e .. "  " .. C.neg .. "(" .. (o.reason or "Unavailable") .. ")" .. C.e end
		inst.OptionText:SetText(label)
		pcall(function()
			local h = inst.OptionText:GetSizeY() + 18
			inst.Option:SetSizeY(math.max(40, h))
		end)
		inst.Option:SetDisabled(not o.ok)
		inst.Option:RegisterCallback(Mouse.eLClick, function()
			if eventResolved then return end
			local result = RL.ResolveEvent(i)
			if result == nil then return end
			eventResolved = true
			Sound("AS2D_INTERFACE_POLICY")
			Controls.OptionStack:SetHide(true)
			Controls.EventText:SetHide(true)
			Controls.EventLater:SetHide(true)
			Controls.EventResult:SetText(result)
			Controls.EventResult:SetHide(false)
			Controls.EventContinue:SetHide(false)
			RL.UI.Refresh()
		end)
	end
	Controls.OptionStack:CalculateSize()
	Controls.OptionStack:ReprocessAnchoring()
	Controls.EventPanel:SetHide(false)
	return true
end

Controls.EventContinue:RegisterCallback(Mouse.eLClick, function() Controls.EventPanel:SetHide(true); RL.UI.ShowNext(true) end)
Controls.EventLater:RegisterCallback(Mouse.eLClick, function() Controls.EventPanel:SetHide(true) end)

-- =====================================================================
-- INFO PANEL
-- =====================================================================
local infoX, infoY = -1, -1
local function ShowInfo()
	S = RL.State
	local info = S.infos[1]
	if not info then Controls.InfoPanel:SetHide(true); return false end
	HideAll()
	Controls.InfoTitle:SetText(C.gold .. info.title .. C.e)
	Controls.InfoText:SetText((string.gsub(info.text, "\n", "[NEWLINE]")))
	infoX, infoY = info.x or -1, info.y or -1
	Controls.InfoLook:SetHide(infoX < 0)
	Controls.InfoPanel:SetHide(false)
	return true
end

Controls.InfoOK:RegisterCallback(Mouse.eLClick, function()
	RL.PopInfo(); RL.UI.Refresh(); Controls.InfoPanel:SetHide(true); RL.UI.ShowNext(true)
end)
Controls.InfoLook:RegisterCallback(Mouse.eLClick, function()
	local pl = Map.GetPlot(infoX, infoY)
	if pl then pcall(function() UI.LookAt(pl, 0) end) end
	RL.PopInfo(); RL.UI.Refresh(); Controls.InfoPanel:SetHide(true)
end)

-- =====================================================================
-- OVERVIEW PANEL
-- =====================================================================
local function Line(text)
	local inst = lineIM:GetInstance()
	inst.Line:SetText(text)
end

local function ShowOverview()
	S = RL.State
	HideAll()
	lineIM:ResetInstances()
	local pid = S.human
	local p = Players[pid]
	local turn = Game.GetGameTurn()
	local o = RL.OriginById[S.origin]

	Line(C.gold .. "THE RUN" .. C.e)
	Line("Ascension " .. S.ascension .. "   |   Origin: " .. (o and o.name or "-") .. "   |   Seed " .. tostring(S.seed) .. "   |   Score " .. RL.RunScore())
	Line("Warlords slain: " .. S.bossesSlain .. "   Kills: " .. S.stats.kills .. "   Losses: " .. S.stats.losses .. "   Boons: " .. S.stats.cards .. "   Events: " .. S.stats.events .. "   Bounties: " .. S.stats.quests)
	Line("Rerolls: " .. S.rerolls .. "   Extra lives: " .. S.lives .. "   Luck: " .. S.luck .. "   Legacy this run: " .. (S.stats.legacy or 0) .. "   Legacy banked: " .. RL.Meta.Legacy())
	if S.won then Line(C.gold .. "RUN WON - you are in Endless mode." .. C.e)
	elseif S.over then Line(C.neg .. "RUN OVER - roguelite systems are paused; boons stay active." .. C.e) end

	local champ = RL.ChampionUnit()
	if champ then
		Line("Champion: " .. C.white .. S.champion.name .. C.e .. " (tier " .. S.champion.tier .. ", level " .. champ:GetLevel() .. ", " .. champ:GetExperience() .. " XP, " .. (100 - champ:GetDamage()) .. " HP)")
	elseif S.champion.spawned then
		Line(C.neg .. "Champion: " .. S.champion.name .. " has fallen." .. C.e)
	end

	Line(" ")
	Line(C.gold .. "THREATS" .. C.e)
	if not S.over or S.won then
		local t = S.wave.next - turn
		Line("Next Horde raid: " .. ((t > 0) and ("in " .. t .. " turns") or "imminent") .. ", ~" .. RL.WaveSize() .. " units. Raids so far: " .. S.wave.count)
	end
	if S.boss.active then Line(C.neg .. "Warlord at large: " .. (S.boss.name or "?") .. C.e .. " (since turn " .. (S.boss.turn or "?") .. ")") end
	local nextIdx
	for i = 0, 7 do if not S.bossesSpawned[i] then nextIdx = i; break end end
	if nextIdx and RL.Bosses[nextIdx] then
		local when = (nextIdx == 0) and ("turn " .. RL.Interval(RL.FIRST_BOSS_TURN)) or ("the " .. RL.EraName(nextIdx))
		Line("Next Warlord: " .. RL.Bosses[nextIdx].name .. " (arrives with " .. when .. ")" .. ((nextIdx == RL.FINAL_BOSS) and C.gold .. "  FINAL" .. C.e or ""))
	end
	if S.ascension > 0 then
		local muts = {}
		for i = 1, S.ascension do muts[#muts + 1] = RL.Ascensions[i].name end
		Line("Ascension mutators: " .. table.concat(muts, ", "))
	end

	Line(" ")
	Line(C.gold .. "BOUNTY" .. C.e)
	if S.quest then
		local prog, target = RL.QuestProgress()
		Line(S.quest.name .. ": " .. S.quest.desc .. "  Progress " .. math.max(0, prog) .. "/" .. target .. ", " .. (S.quest.deadline - turn) .. " turns left.")
	else
		Line("No active bounty. Next in " .. math.max(0, S.nextQuestTurn - turn) .. " turns.")
	end

	Line(" ")
	Line(C.gold .. "SYNERGIES" .. C.e .. "  (own enough boons of a theme to unlock a set bonus)")
	local counts = RL.TagCounts(pid)
	local parts = {}
	for _, syn in ipairs(RL.Synergies) do
		local have = counts[syn.tag] or 0
		local txt = RL.TAGS[syn.tag].icon .. " " .. syn.name .. " " .. math.min(have, syn.need) .. "/" .. syn.need
		if have >= syn.need then txt = C.pos .. txt .. C.e end
		parts[#parts + 1] = txt
	end
	Line(table.concat(parts, "    "))
	for _, syn in ipairs(RL.ActiveSynergies(pid)) do Line("  " .. C.pos .. syn.name .. ":" .. C.e .. " " .. syn.desc) end

	Line(" ")
	Line(C.gold .. "BOONS" .. C.e)
	local pd = RL.PD(pid)
	local any = false
	for _, id in ipairs(pd.order) do
		local c = RL.CardById[id]
		local s = pd.cards[id]
		if c and s and s > 0 then
			any = true
			local desc = c.desc
			if type(desc) == "function" then desc = RL.Try("desc", desc, s) or "" end
			Line(RL.RarityText(c.rarity) .. " " .. C.white .. c.name .. C.e .. ((s > 1) and (" x" .. s) or "") .. " - " .. desc)
		end
	end
	if not any then Line("None yet.") end

	Line(" ")
	Line(C.neg .. "CURSES" .. C.e)
	any = false
	for id, s in pairs(pd.curses) do
		local c = RL.CardById[id]
		if c and s > 0 then any = true; Line(C.neg .. c.name .. C.e .. ((s > 1) and (" x" .. s) or "") .. " - " .. c.desc) end
	end
	if not any then Line("None. (For now.)") end

	if #S.temps > 0 then
		Line(" ")
		Line(C.gold .. "TIMED EFFECTS" .. C.e)
		for _, t in ipairs(S.temps) do
			if t.pid == pid then Line((t.label ~= "" and t.label or t.b) .. " - " .. (t.untilTurn - turn) .. " turns left") end
		end
	end

	-- Rivals' boons (only civs you have met)
	Line(" ")
	Line(C.gold .. "RIVALS" .. C.e)
	local myTeam = Teams[p:GetTeam()]
	for i = 0, GameDefines.MAX_MAJOR_CIVS - 1 do
		local rp = Players[i]
		if i ~= pid and rp and rp:IsAlive() and not rp:IsMinorCiv() and myTeam:IsHasMet(rp:GetTeam()) then
			local rd = RL.PD(i)
			local names = {}
			for _, id in ipairs(rd.order) do local c = RL.CardById[id]; if c and not c.hidden then names[#names + 1] = c.name .. ((rd.cards[id] or 0) > 1 and (" x" .. rd.cards[id]) or "") end end
			Line(Locale.ConvertTextKey(rp:GetCivilizationShortDescription()) .. ": " .. ((#names > 0) and table.concat(names, ", ") or "no boons"))
		end
	end

	Line(" ")
	Line(C.gold .. "RUN LOG" .. C.e)
	for i = 1, math.min(25, #S.log) do Line(C.grey .. S.log[i] .. C.e) end

	Controls.OverviewStack:CalculateSize()
	Controls.OverviewStack:ReprocessAnchoring()
	Controls.OverviewScroll:CalculateInternalSize()
	Controls.OvDrafts:SetText("Drafts (" .. #S.drafts .. ")")
	Controls.OvDrafts:SetDisabled(#S.drafts == 0)
	Controls.OvEvents:SetText("Events (" .. (#S.pending + #S.infos) .. ")")
	Controls.OvEvents:SetDisabled((#S.pending + #S.infos) == 0)
	Controls.OvAuto:SetText("Auto-open: " .. (AutoOpen() and "On" or "Off"))
	Controls.OverviewPanel:SetHide(false)
end

Controls.OvClose:RegisterCallback(Mouse.eLClick, function() Controls.OverviewPanel:SetHide(true) end)
Controls.OvDrafts:RegisterCallback(Mouse.eLClick, function() ShowDraft() end)
Controls.OvEvents:RegisterCallback(Mouse.eLClick, function() if not ShowInfo() then ShowEvent() end end)
Controls.OvAuto:RegisterCallback(Mouse.eLClick, function()
	RL.Meta.Set("optNoAuto", AutoOpen() and 1 or 0)
	Controls.OvAuto:SetText("Auto-open: " .. (AutoOpen() and "On" or "Off"))
end)

-- =====================================================================
-- START / LEGACY PANEL
-- =====================================================================
local ShowStart

local function RefreshStart(isStart)
	S = RL.State
	local legacy = RL.Meta.Legacy()
	Controls.StartTitle:SetText(isStart and (C.gold .. "ASCENSION - A NEW RUN BEGINS" .. C.e) or (C.gold .. "LEGACY" .. C.e))
	Controls.StartLegacy:SetText("[ICON_GOLDEN_AGE] Legacy: " .. C.yellow .. legacy .. C.e .. "   (lifetime " .. RL.Meta.Num("legacyTotal") .. ")   Runs: " .. RL.Meta.Num("runs") .. "   Wins: " .. RL.Meta.Num("wins") .. "   Highest Ascension unlocked: " .. RL.Meta.AscUnlocked())
	Controls.StartChoices:SetHide(not isStart)
	Controls.StartBegin:SetHide(not isStart)
	Controls.StartClose:SetHide(isStart)

	if isStart then
		local maxAsc = math.min(RL.MAX_ASCENSION, RL.Meta.AscUnlocked())
		startAsc = RL.Clamp(startAsc, 0, maxAsc)
		Controls.AscValue:SetText(tostring(startAsc))
		Controls.AscDown:SetDisabled(startAsc <= 0)
		Controls.AscUp:SetDisabled(startAsc >= maxAsc)
		local lines = {}
		if startAsc == 0 then lines[1] = "The base run. Win a run (slay the Final Warlord or win the game) or slay 5 Warlords to unlock Ascension 1." end
		for i = 1, startAsc do lines[#lines + 1] = "[ICON_BULLET]" .. RL.Ascensions[i].name .. ": " .. RL.Ascensions[i].desc end
		if startAsc > 0 then lines[#lines + 1] = C.pos .. "+" .. (10 * startAsc) .. "% Legacy earned." .. C.e end
		Controls.AscDesc:SetText(table.concat(lines, "[NEWLINE]"))

		local o = RL.Origins[startOrigin]
		local unlocked = RL.Meta.OriginUnlocked(o.id)
		Controls.OriginName:SetText((unlocked and C.white or C.grey) .. o.name .. C.e .. "  (" .. startOrigin .. "/" .. #RL.Origins .. ")")
		Controls.OriginDesc:SetText(o.desc .. (unlocked and "" or ("[NEWLINE]" .. C.neg .. "Locked." .. C.e)))
		Controls.OriginBuy:SetHide(unlocked)
		Controls.OriginBuy:SetText("Unlock for " .. o.cost .. " Legacy")
		Controls.OriginBuy:SetDisabled(legacy < o.cost)
		Controls.StartBegin:SetDisabled(not unlocked)
	end

	upgradeIM:ResetInstances()
	for _, u in ipairs(RL.LegacyUpgrades) do
		local inst = upgradeIM:GetInstance()
		local rank = RL.Meta.Rank(u.id)
		local maxRank = #u.costs
		inst.UName:SetText(C.white .. u.name .. C.e .. "   " .. C.yellow .. "Rank " .. rank .. "/" .. maxRank .. C.e)
		inst.UDesc:SetText(u.desc)
		local cost = u.costs[rank + 1]
		if cost then
			inst.UBuy:SetText("Buy (" .. cost .. ")")
			inst.UBuy:SetDisabled(legacy < cost)
			inst.UBuy:SetHide(false)
			local id = u.id
			inst.UBuy:RegisterCallback(Mouse.eLClick, function()
				if RL.Meta.BuyUpgrade(id) then Sound("AS2D_INTERFACE_CITY_SCREEN_PURCHASE"); RefreshStart(isStart) end
			end)
		else
			inst.UBuy:SetText("Maxed")
			inst.UBuy:SetDisabled(true)
		end
	end
	Controls.UpgradeStack:CalculateSize()
	Controls.UpgradeStack:ReprocessAnchoring()
	Controls.UpgradeScroll:CalculateInternalSize()
end

ShowStart = function(isStart)
	HideAll()
	RefreshStart(isStart)
	Controls.StartPanel:SetHide(false)
end

Controls.AscDown:RegisterCallback(Mouse.eLClick, function() startAsc = startAsc - 1; RefreshStart(true) end)
Controls.AscUp:RegisterCallback(Mouse.eLClick, function() startAsc = startAsc + 1; RefreshStart(true) end)
Controls.OriginPrev:RegisterCallback(Mouse.eLClick, function() startOrigin = ((startOrigin - 2) % #RL.Origins) + 1; RefreshStart(true) end)
Controls.OriginNext:RegisterCallback(Mouse.eLClick, function() startOrigin = (startOrigin % #RL.Origins) + 1; RefreshStart(true) end)
Controls.OriginBuy:RegisterCallback(Mouse.eLClick, function()
	if RL.Meta.BuyOrigin(RL.Origins[startOrigin].id) then Sound("AS2D_INTERFACE_CITY_SCREEN_PURCHASE") end
	RefreshStart(true)
end)
Controls.StartBegin:RegisterCallback(Mouse.eLClick, function()
	local o = RL.Origins[startOrigin]
	if not RL.Meta.OriginUnlocked(o.id) then return end
	RL.Meta.Set("lastAsc", startAsc)
	RL.Meta.Set("lastOrigin", startOrigin)
	RL.Try("BeginRun", RL.BeginRun, startAsc, o.id)
	Sound("AS2D_INTERFACE_NEW_ERA")
	Controls.StartPanel:SetHide(true)
	RL.UI.Refresh()
	RL.UI.ShowNext(true)
end)
Controls.StartClose:RegisterCallback(Mouse.eLClick, function() Controls.StartPanel:SetHide(true) end)
Controls.OvLegacy:RegisterCallback(Mouse.eLClick, function() ShowStart(false) end)

-- =====================================================================
-- RUN OVER
-- =====================================================================
function RL.UI.ShowRunOver(won, reason)
	S = RL.State
	HideAll()
	Controls.RunOverTitle:SetText(won and (C.gold .. "ASCENSION COMPLETE" .. C.e) or (C.neg .. "THE RUN HAS ENDED" .. C.e))
	local t = {}
	t[#t + 1] = reason
	t[#t + 1] = ""
	t[#t + 1] = "Ascension " .. S.ascension .. "   Score " .. RL.RunScore()
	t[#t + 1] = "Warlords slain: " .. S.bossesSlain .. "   Kills: " .. S.stats.kills .. "   Boons: " .. S.stats.cards .. "   Bounties: " .. S.stats.quests
	t[#t + 1] = "Legacy earned this run: " .. C.yellow .. (S.stats.legacy or 0) .. C.e .. "   Banked: " .. RL.Meta.Legacy()
	t[#t + 1] = ""
	if won then
		t[#t + 1] = "Your legend is complete. You may keep playing in Endless mode: the Horde and the Warlords will keep coming, and your boons remain."
	else
		t[#t + 1] = "You may keep playing this game, but the roguelite systems are paused and no more Legacy can be earned. Start a new game to begin your next run - spend your Legacy first!"
	end
	Controls.RunOverText:SetText(table.concat(t, "[NEWLINE]"))
	Controls.RunOverPanel:SetHide(false)
	RL.UI.Refresh()
end

Controls.RunOverContinue:RegisterCallback(Mouse.eLClick, function() Controls.RunOverPanel:SetHide(true); RL.UI.ShowNext(true) end)
Controls.RunOverLegacy:RegisterCallback(Mouse.eLClick, function() ShowStart(false) end)

-- =====================================================================
-- Queue: infos > events > drafts
-- =====================================================================
function RL.UI.ShowNext(force)
	S = RL.State
	if not S then return end
	if not S.started then ShowStart(true); return end
	if not force and (AnyOpen() or not AutoOpen()) then return end
	if ShowInfo() then return end
	if ShowEvent() then return end
	if ShowDraft() then return end
end

Controls.HUDButton:RegisterCallback(Mouse.eLClick, function()
	S = RL.State
	if not S then return end
	if not S.started then ShowStart(true) return end
	ShowOverview()
end)

-- =====================================================================
-- INPUT
-- =====================================================================
ContextPtr:SetInputHandler(function(uiMsg, wParam, lParam)
	if uiMsg == KeyEvents.KeyDown and wParam == Keys.VK_ESCAPE then
		if not Controls.StartPanel:IsHidden() and RL.State and not RL.State.started then return true end
		for _, n in ipairs(PANELS) do
			if not Controls[n]:IsHidden() then Controls[n]:SetHide(true); return true end
		end
	end
	return false
end)

-- =====================================================================
-- GAME EVENT WIRING
-- =====================================================================
local function Safe(label, fn)
	return function(...)
		local ok, err = pcall(fn, ...)
		if not ok then RL.Log("ERROR in " .. label .. ": " .. tostring(err)) end
	end
end

GameEvents.PlayerDoTurn.Add(Safe("PlayerDoTurn", function(pid) RL.OnPlayerDoTurn(pid) end))
GameEvents.UnitKilledInCombat.Add(Safe("UnitKilledInCombat", function(killer, killed, unitType) RL.OnUnitKilled(killer, killed, unitType) end))
GameEvents.PlayerCityFounded.Add(Safe("PlayerCityFounded", function(pid, x, y) RL.OnCityFounded(pid, x, y) end))
GameEvents.CityCaptureComplete.Add(Safe("CityCaptureComplete", function(oldOwner, isCap, x, y, newOwner) RL.OnCityCaptured(oldOwner, isCap, x, y, newOwner) end))
if GameEvents.CityTrained then
	GameEvents.CityTrained.Add(Safe("CityTrained", function(pid, cityId, unitId) RL.OnUnitTrained(pid, cityId, unitId) end))
end

Events.ActivePlayerTurnStart.Add(Safe("ActivePlayerTurnStart", function()
	-- All players' PlayerDoTurn hooks (including AI rivals, which run after
	-- the human) are done by now: flush everything into the save.
	if RL.State and RL.State.started then RL.Save() end
	RL.UI.Refresh()
	RL.UI.ShowNext(false)
end))

Events.ActivePlayerTurnEnd.Add(Safe("ActivePlayerTurnEnd", function() if RL.State and RL.State.started then RL.Save() end end))

if Events.EndGameShow then
	Events.EndGameShow.Add(Safe("EndGameShow", function() RL.OnGameEnd(); RL.UI.Refresh() end))
end

local function OnLoadScreenClose()
	RL.UI.Refresh()
	S = RL.State
	if S and not S.started then
		startAsc = RL.Clamp(RL.Meta.Num("lastAsc"), 0, RL.Meta.AscUnlocked())
		startOrigin = RL.Clamp(RL.Meta.Num("lastOrigin"), 1, #RL.Origins)
		if not RL.Meta.OriginUnlocked(RL.Origins[startOrigin].id) then startOrigin = 1 end
		ShowStart(true)
	else
		RL.UI.ShowNext(false)
	end
end
Events.LoadScreenClose.Add(Safe("LoadScreenClose", OnLoadScreenClose))

-- =====================================================================
-- INIT
-- =====================================================================
RL.Try("Load", RL.Load)
HideAll()
RL.UI.Refresh()
RL.Log("Ascension Roguelite loaded. Cards: " .. #RL.Cards .. ", events: " .. #RL.Events .. ", started: " .. tostring(RL.State and RL.State.started))
