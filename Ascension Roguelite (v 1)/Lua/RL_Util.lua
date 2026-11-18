-- =====================================================================
-- ASCENSION: ROGUELITE OVERHAUL -- Utilities
-- Serializer, seeded RNG, safe-call helpers, text helpers.
-- Pure Lua 5.1, no game API dependencies except where noted.
-- =====================================================================

RL = RL or {}

-- ---------------------------------------------------------------------
-- Logging / safety
-- ---------------------------------------------------------------------
RL.DEBUG = false

function RL.Log(...)
	local parts = {}
	for i = 1, select("#", ...) do parts[#parts + 1] = tostring(select(i, ...)) end
	print("[Ascension] " .. table.concat(parts, " "))
end

-- Run fn(...) and swallow/log any error so a single bad effect can never
-- break turn processing.
function RL.Try(label, fn, ...)
	local ok, a, b, c = pcall(fn, ...)
	if not ok then
		RL.Log("ERROR in " .. tostring(label) .. ": " .. tostring(a))
		return nil
	end
	return a, b, c
end

-- ---------------------------------------------------------------------
-- Serializer (length-prefixed, no loadstring required)
--   N<number>;   S<len>:<bytes>   B1/B0   T ... E   (table = key,value pairs)
-- ---------------------------------------------------------------------
local function ser(v, out)
	local t = type(v)
	if t == "number" then
		if v == math.floor(v) and math.abs(v) < 1e15 then
			out[#out + 1] = "N" .. string.format("%d", v) .. ";"
		else
			out[#out + 1] = "N" .. string.format("%.17g", v) .. ";"
		end
	elseif t == "string" then
		out[#out + 1] = "S" .. #v .. ":" .. v
	elseif t == "boolean" then
		out[#out + 1] = v and "B1" or "B0"
	elseif t == "table" then
		out[#out + 1] = "T"
		for k, val in pairs(v) do
			local kt, vt = type(k), type(val)
			if (kt == "number" or kt == "string") and (vt ~= "function" and vt ~= "userdata") then
				ser(k, out)
				ser(val, out)
			end
		end
		out[#out + 1] = "E"
	end
end

function RL.Serialize(v)
	local out = {}
	ser(v, out)
	return table.concat(out)
end

local function des(s, i)
	local c = s:sub(i, i)
	if c == "N" then
		local j = s:find(";", i, true)
		return tonumber(s:sub(i + 1, j - 1)), j + 1
	elseif c == "S" then
		local j = s:find(":", i, true)
		local len = tonumber(s:sub(i + 1, j - 1))
		return s:sub(j + 1, j + len), j + len + 1
	elseif c == "B" then
		return s:sub(i + 1, i + 1) == "1", i + 2
	elseif c == "T" then
		local t = {}
		i = i + 1
		while s:sub(i, i) ~= "E" do
			if i > #s then error("unterminated table") end
			local k, v
			k, i = des(s, i)
			v, i = des(s, i)
			t[k] = v
		end
		return t, i + 1
	end
	error("bad token '" .. c .. "' at " .. i)
end

function RL.Deserialize(s)
	if type(s) ~= "string" or s == "" then return nil end
	local ok, v = pcall(des, s, 1)
	if ok then return v end
	RL.Log("Deserialize failed: " .. tostring(v))
	return nil
end

-- ---------------------------------------------------------------------
-- Seeded RNG (Park-Miller minimal standard; exact in doubles)
-- The run seed lives in the save, so reloading a save reproduces the
-- same draft / event rolls: no save-scumming your way to a Legendary.
-- ---------------------------------------------------------------------
RL.rngState = 12345

function RL.SeedRNG(seed)
	seed = math.floor(tonumber(seed) or 1) % 2147483647
	if seed <= 0 then seed = seed + 2147483646 end
	RL.rngState = seed
end

function RL.NextRaw()
	RL.rngState = (RL.rngState * 16807) % 2147483647
	return RL.rngState
end

-- Integer in [0, n-1]
function RL.Rand(n)
	n = math.floor(n or 0)
	if n <= 1 then RL.NextRaw(); return 0 end
	return RL.NextRaw() % n
end

-- Integer in [a, b]
function RL.RandRange(a, b)
	if b < a then a, b = b, a end
	return a + RL.Rand(b - a + 1)
end

function RL.Chance(pct)
	return RL.Rand(100) < pct
end

function RL.Pick(list)
	if not list or #list == 0 then return nil end
	return list[RL.Rand(#list) + 1]
end

-- list of {item=..., w=weight}
function RL.WeightedPick(entries)
	local total = 0
	for _, e in ipairs(entries) do total = total + math.max(0, e.w) end
	if total <= 0 then return nil end
	local r = RL.Rand(total)
	for _, e in ipairs(entries) do
		r = r - math.max(0, e.w)
		if r < 0 then return e.item end
	end
	return entries[#entries].item
end

function RL.Shuffle(list)
	for i = #list, 2, -1 do
		local j = RL.Rand(i) + 1
		list[i], list[j] = list[j], list[i]
	end
	return list
end

-- ---------------------------------------------------------------------
-- Table helpers
-- ---------------------------------------------------------------------
function RL.Count(t)
	local n = 0
	if t then for _ in pairs(t) do n = n + 1 end end
	return n
end

function RL.Contains(list, v)
	if not list then return false end
	for _, x in ipairs(list) do if x == v then return true end end
	return false
end

function RL.Clamp(v, lo, hi)
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end

function RL.Round(x)
	return math.floor(x + 0.5)
end

-- ---------------------------------------------------------------------
-- Text helpers (Civ5 colour markup)
-- ---------------------------------------------------------------------
RL.C = {
	pos    = "[COLOR_POSITIVE_TEXT]",
	neg    = "[COLOR_NEGATIVE_TEXT]",
	gold   = "[COLOR_YIELD_GOLD]",
	food   = "[COLOR_YIELD_FOOD]",
	yellow = "[COLOR_YELLOW]",
	cyan   = "[COLOR_CYAN]",
	magenta= "[COLOR_MAGENTA]",
	white  = "[COLOR_WHITE]",
	grey   = "[COLOR_GREY]",
	e      = "[ENDCOLOR]",
}

function RL.Col(key, s)
	return (RL.C[key] or "") .. tostring(s) .. RL.C.e
end

RL.RARITY = {
	{ key = "COMMON",    name = "Common",    color = "white",   weight = 62 },
	{ key = "RARE",      name = "Rare",      color = "cyan",    weight = 27 },
	{ key = "EPIC",      name = "Epic",      color = "magenta", weight = 9  },
	{ key = "LEGENDARY", name = "Legendary", color = "gold",    weight = 2  },
}

function RL.RarityText(r)
	local def = RL.RARITY[r] or RL.RARITY[1]
	return RL.Col(def.color, def.name)
end

RL.TAGS = {
	WAR     = { name = "War",       icon = "[ICON_WAR]" },
	GOLD    = { name = "Commerce",  icon = "[ICON_GOLD]" },
	SCIENCE = { name = "Knowledge", icon = "[ICON_RESEARCH]" },
	GROWTH  = { name = "Growth",    icon = "[ICON_FOOD]" },
	CULTURE = { name = "Culture",   icon = "[ICON_CULTURE]" },
	FAITH   = { name = "Faith",     icon = "[ICON_PEACE]" },
	BUILD   = { name = "Industry",  icon = "[ICON_PRODUCTION]" },
	SEA     = { name = "Seafaring", icon = "[ICON_TRADE]" },
	HERO    = { name = "Champion",  icon = "[ICON_GREAT_GENERAL]" },
	FATE    = { name = "Fate",      icon = "[ICON_HAPPINESS_1]" },
}

function RL.TagText(tags)
	if not tags then return "" end
	local parts = {}
	for _, t in ipairs(tags) do
		local d = RL.TAGS[t]
		if d then parts[#parts + 1] = d.icon .. " " .. d.name end
	end
	return table.concat(parts, "   ")
end
