-- Generates docs/CONTENT.md from the mod's data files.
--   lua5.1 tools/gen_docs.lua > docs/CONTENT.md
local here = arg[0]:match("(.*)/") or "."
MOCK_DIR = here .. "/sim"
MOD_DIR = here .. "/../Ascension Roguelite (v 1)"
dofile(MOCK_DIR .. "/mock_civ.lua")
MOCK.MakePlayer(0, true)
include("RL_Util.lua"); include("RL_Data_Cards.lua"); include("RL_Data_World.lua"); include("RL_Data_Events.lua"); include("RL_Engine.lua")

local out = {}
local function w(s) out[#out + 1] = s or "" end
local function clean(s)
	s = tostring(s or "")
	s = s:gsub("%[COLOR_[A-Z_]+%]", ""):gsub("%[ENDCOLOR%]", ""):gsub("%[NEWLINE%]", " ")
	s = s:gsub("%[ICON_STRENGTH%] Combat", "Combat"):gsub("%[ICON_STRENGTH%]", "Combat Strength")
	s = s:gsub("%[ICON_BULLET%]", "- "):gsub("%[ICON_[A-Z_0-9]+%]", "")
	return (s:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", ""))
end
local function desc(c) local d = c.desc; if type(d) == "function" then d = d(1) end; return clean(d) end
local P = { [0] = true }

w("# Ascension - Content Catalog")
w()
w("_Generated from the mod's Lua data by `tools/gen_docs.lua`. Amounts marked \"per era\" scale with your current era and with game speed._")
w()
local nB = 0; for _, c in ipairs(RL.Cards) do if not c.hidden then nB = nB + 1 end end
w(string.format("**%d Boons - %d Curses - %d Events - %d Era Warlords - %d Bounties - %d Synergies - %d Origins - %d Legacy upgrades - %d Ascension levels**",
	nB, #RL.Curses, #RL.Events, 8, #RL.Quests, #RL.Synergies, #RL.Origins, #RL.LegacyUpgrades, RL.MAX_ASCENSION))
w()
w("## Boons")
for r = 1, 4 do
	w()
	w("### " .. RL.RARITY[r].name)
	w()
	w("| Boon | Themes | Max | Effect |")
	w("|---|---|---|---|")
	for _, c in ipairs(RL.Cards) do
		if not c.hidden and c.rarity == r then
			local tags = {}
			for _, t in ipairs(c.tags) do tags[#tags + 1] = RL.TAGS[t].name end
			w(string.format("| %s%s | %s | %d | %s |", c.name, c.humanOnly and " *" or "", table.concat(tags, ", "), c.max, desc(c)))
		end
	end
end
w()
w("`*` = player only (never given to AI rivals). Champion-themed boons are player only.")
w()
w("## Curses")
w()
w("| Curse | Max stacks | Effect |")
w("|---|---|---|")
for _, c in ipairs(RL.Curses) do w(string.format("| %s | %d | %s |", c.name, c.max, clean(c.desc))) end
w()
w("## Synergies")
w()
w("| Set bonus | Theme | Boons needed | Bonus |")
w("|---|---|---|---|")
for _, s in ipairs(RL.Synergies) do w(string.format("| %s | %s | %d | %s |", s.name, RL.TAGS[s.tag].name, s.need, s.desc)) end
w()
w("## Events")
w()
for _, e in ipairs(RL.Events) do
	local params = e.roll and e.roll(0) or {}
	w("### " .. e.title)
	w()
	w("> " .. clean(type(e.text) == "function" and e.text(0, params) or e.text))
	w()
	for _, o in ipairs(e.options) do
		local l = o.label; if type(l) == "function" then l = l(0, params) end
		w("- " .. clean(l))
	end
	w()
end
w("## Era Warlords")
w()
w("| # | Warlord | Arrives | Escorts |")
w("|---|---|---|---|")
for i = 0, 7 do
	local b = RL.Bosses[i]
	local when = (i == 0) and ("Turn " .. RL.FIRST_BOSS_TURN .. " (standard speed)") or ("Entering the " .. ({ "Classical", "Medieval", "Renaissance", "Industrial", "Modern", "Atomic", "Information" })[i] .. " Era")
	w(string.format("| %d | %s%s | %s | %d |", i, b.name, (i == RL.FINAL_BOSS) and " **(FINAL)**" or ((i == 7) and " (Endless)" or ""), when, #b.escorts))
end
w()
w("## Bounties")
w()
for _, q in ipairs(RL.Quests) do w("- **" .. q.name .. "** - " .. clean(q.desc:gsub("%%d", "N")) .. " (" .. q.duration .. " turns)") end
w()
w("## Origins")
w()
w("| Origin | Unlock cost | Start |")
w("|---|---|---|")
for _, o in ipairs(RL.Origins) do w(string.format("| %s | %s | %s |", o.name, o.cost == 0 and "Free" or (o.cost .. " Legacy"), clean(o.desc))) end
w()
w("## Legacy upgrades")
w()
w("| Upgrade | Rank costs | Effect |")
w("|---|---|---|")
for _, u in ipairs(RL.LegacyUpgrades) do w(string.format("| %s | %s | %s |", u.name, table.concat(u.costs, " / "), clean(u.desc))) end
w()
w("## Ascension levels (cumulative)")
w()
for i = 1, RL.MAX_ASCENSION do w(string.format("%d. **%s** - %s", i, RL.Ascensions[i].name, RL.Ascensions[i].desc)) end
w()
io.write(table.concat(out, "\n"))
