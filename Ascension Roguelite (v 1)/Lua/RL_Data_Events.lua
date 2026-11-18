-- =====================================================================
-- ASCENSION: ROGUELITE OVERHAUL -- Events
-- Choice events fire every ~12-18 turns (scaled by game speed).
--
-- Event fields
--   id, title, weight, minTurn, minEra, maxEra, cond(pid)
--   roll(pid) -> params table (saved with the pending event, so reloading
--                 a save shows exactly the same prices and outcomes)
--   text(pid, p) -> string
--   options = { { label = string|function(pid,p),
--                 avail = function(pid,p) -> ok, reason   (optional)
--                 run   = function(pid,p) -> result text } }
-- =====================================================================

RL = RL or {}
local Fx = function() return RL.Fx end
local P = function(pid) return Players[pid] end

RL.Events = {}
local function Event(t) t.weight = t.weight or 10; t.minTurn = t.minTurn or 0; RL.Events[#RL.Events + 1] = t end

local function CanPay(pid, cost) if P(pid):GetGold() >= cost then return true end return false, "Not enough [ICON_GOLD] Gold" end
local function CanPayFaith(pid, cost) if P(pid):GetFaith() >= cost then return true end return false, "Not enough [ICON_PEACE] Faith" end
local function G(n) return n .. " [ICON_GOLD]" end
local POS, NEG, E = "[COLOR_POSITIVE_TEXT]", "[COLOR_NEGATIVE_TEXT]", "[ENDCOLOR]"

-- 1 ------------------------------------------------------------------
Event{ id = "MERCHANT", title = "The Wandering Merchant", weight = 14, minTurn = 8,
	roll = function(pid) return { cost = Fx().Cost(pid, 120, 60), mapCost = Fx().Cost(pid, 40, 20) } end,
	text = function(pid, p) return "A merchant with a mule train of curiosities arrives at your capital. Beneath a silk cloth something glows faintly. \"Everything has a price, friend. Some things have two.\"" end,
	options = {
		{ label = function(pid, p) return "Buy the glowing relic (" .. G(p.cost) .. "): a random Rare or Epic boon." end,
		  avail = function(pid, p) return CanPay(pid, p.cost) end,
		  run = function(pid, p) Fx().Gold(pid, -p.cost); local c = Fx().GrantRandomCard(pid, 2, 3); return "The relic is yours: " .. (c and c.name or "nothing") .. "." end },
		{ label = function(pid, p) return "Buy his maps (" .. G(p.mapCost) .. "): reveal the surrounding land and a hidden cache." end,
		  avail = function(pid, p) return CanPay(pid, p.mapCost) end,
		  run = function(pid, p) Fx().Gold(pid, -p.mapCost); Fx().RevealAround(pid, 10); return Fx().Treasure(pid) end },
		{ label = "Send him on his way.", run = function() return "The merchant shrugs and moves on." end },
	} }

-- 2 ------------------------------------------------------------------
Event{ id = "RUINS", title = "Ruins in the Wilds", weight = 12,
	roll = function(pid) return { good = RL.Chance(60) } end,
	text = function() return "Scouts report a buried city, older than any record. Its gates are sealed with strange sigils. Something might still guard it." end,
	options = {
		{ label = "Excavate the inner vaults (60%: a burst of science / 40%: awaken its guardians).",
		  run = function(pid, p)
			if p.good then Fx().ResearchFraction(pid, 0.5); return POS .. "Your scholars decode the vault's tablets!" .. E .. " Half of your current research is complete." end
			Fx().SpawnHostilesNear(pid, 2, "Guardians of the ruins awaken!")
			Fx().Culture(pid, Fx().Amt(pid, 10, 10))
			return NEG .. "Ancient guardians stir and march on your lands!" .. E .. " (Your scholars still salvage some lore.)" end },
		{ label = "Loot the outer halls and sell what you find.",
		  run = function(pid) local g = Fx().Amt(pid, 40, 20); Fx().Gold(pid, g); return "You sell pottery and bronze for " .. G(g) .. "." end },
		{ label = "Leave the dead in peace.", run = function(pid) Fx().Faith(pid, Fx().Amt(pid, 10, 5)); return "The priests approve of your restraint." end },
	} }

-- 3 ------------------------------------------------------------------
Event{ id = "PLAGUE", title = "Sickness in the Streets", weight = 9, minTurn = 25,
	roll = function(pid) return { cost = Fx().Cost(pid, 80, 40), faith = Fx().Amt(pid, 40, 20) } end,
	text = function() return "A fever spreads through the crowded districts of your capital. The physicians ask for funds; the priests ask for prayer; the people ask for nothing but to live." end,
	options = {
		{ label = function(pid, p) return "Fund the physicians (" .. G(p.cost) .. ")." end,
		  avail = function(pid, p) return CanPay(pid, p.cost) end,
		  run = function(pid, p) Fx().Gold(pid, -p.cost); return "The fever is contained." end },
		{ label = function(pid, p) return "Hold days of prayer (" .. p.faith .. " [ICON_PEACE])." end,
		  avail = function(pid, p) return CanPayFaith(pid, p.faith) end,
		  run = function(pid, p) Fx().Faith(pid, -p.faith); Fx().AddTemp(pid, "BUILDING_RL_TEMP_HAPPY", 1, 8, "Shared Faith"); return "The city comes together in prayer. The fever breaks." end },
		{ label = "Let it run its course.",
		  run = function(pid) Fx().AddTemp(pid, "BUILDING_RL_TEMP_PLAGUE", 1, 10, "Sickness"); Fx().CapitalPop(pid, -1); return NEG .. "The capital loses 1 population and every city suffers -1 Happiness for 10 turns." .. E end },
	} }

-- 4 ------------------------------------------------------------------
Event{ id = "SELLSWORDS", title = "A Sellsword Company", weight = 10, minTurn = 12,
	roll = function(pid) return { cost = Fx().Cost(pid, 100, 60), loot = Fx().Amt(pid, 60, 30) } end,
	text = function() return "A hard-bitten mercenary captain offers you his company's swords. \"We fight for whoever pays. Today, that could be you.\"" end,
	options = {
		{ label = function(pid, p) return "Hire them (" .. G(p.cost) .. "): 2 of your best melee units." end,
		  avail = function(pid, p) return CanPay(pid, p.cost) end,
		  run = function(pid, p) Fx().Gold(pid, -p.cost); Fx().SpawnRole(pid, "MELEE", 2); return "The company joins your army." end },
		{ label = function(pid, p) return "Seize their pay-chest (" .. G(p.loot) .. ", but they turn on you)." end,
		  run = function(pid, p) Fx().Gold(pid, p.loot); Fx().SpawnHostilesNear(pid, 3, "The betrayed sellswords seek revenge!"); return NEG .. "Three hostile companies take the field against you." .. E end },
		{ label = "Decline.", run = function() return "The captain spits and rides off." end },
	} }

-- 5 ------------------------------------------------------------------
Event{ id = "COMET", title = "A Comet Blazes", weight = 9,
	text = function() return "A comet hangs over the land for nine nights. Everyone agrees it means something. Nobody agrees on what." end,
	options = {
		{ label = "Proclaim it an omen of glory: a 6-turn [ICON_GOLDEN_AGE] Golden Age.", run = function(pid) Fx().GoldenAge(pid, 6); return "The people celebrate a new golden age!" end },
		{ label = "Study it: +40% of your current research.", run = function(pid) Fx().ResearchFraction(pid, 0.4); return "Astronomers chart its path and learn much." end },
		{ label = "Declare it a sign from the heavens: [ICON_PEACE] Faith.", run = function(pid) local f = Fx().Amt(pid, 40, 30); Fx().Faith(pid, f); return "+" .. f .. " [ICON_PEACE] Faith." end },
	} }

-- 6 ------------------------------------------------------------------
Event{ id = "REFUGEES", title = "Refugees at the Gates", weight = 9, minTurn = 15,
	text = function() return "Thousands flee a war beyond your borders and gather outside your walls. They are hungry, tired, and many." end,
	options = {
		{ label = "Welcome them: capital +2 [ICON_CITIZEN], but -1 Happiness in every city for 8 turns.",
		  run = function(pid) Fx().CapitalPop(pid, 2); Fx().AddTemp(pid, "BUILDING_RL_TEMP_PLAGUE", 1, 8, "Crowding"); return "Your capital swells with new citizens." end },
		{ label = "Put them to work: a free Worker and a 10-turn production boom.",
		  run = function(pid) Fx().SpawnRole(pid, "WORKER", 1); Fx().AddTemp(pid, "BUILDING_RL_TEMP_PRODUCTION", 1, 10, "Many Hands"); return "Many hands make light work." end },
		{ label = "Turn them away.", run = function() return "The refugees move on. Some will remember." end },
	} }

-- 7 ------------------------------------------------------------------
Event{ id = "DARK_PACT", title = "The Stranger in Black", weight = 6, minTurn = 30,
	text = function() return "He appears in your throne room without passing a single guard. \"I can give you what you want most. The price is small. Just a little... misfortune.\"" end,
	options = {
		{ label = "Accept the great pact: a random [COLOR_YIELD_GOLD]Legendary[ENDCOLOR] boon and [COLOR_NEGATIVE_TEXT]2 Curses[ENDCOLOR].",
		  run = function(pid) local c = Fx().GrantRandomCard(pid, 4, 4); Fx().AddCurse(pid); Fx().AddCurse(pid); return "\"A pleasure.\" You gain " .. (c and c.name or "power") .. ", and feel something cold settle on your empire." end },
		{ label = "Accept a lesser pact: a random Epic boon and 1 Curse.",
		  run = function(pid) local c = Fx().GrantRandomCard(pid, 3, 3); Fx().AddCurse(pid); return "You gain " .. (c and c.name or "power") .. ". The shadows lengthen." end },
		{ label = "Refuse.", run = function(pid) Fx().Faith(pid, Fx().Amt(pid, 15, 10)); return "He smiles and is gone. Your priests praise your wisdom." end },
	} }

-- 8 ------------------------------------------------------------------
Event{ id = "TOURNAMENT", title = "The Grand Tournament", weight = 9, minTurn = 10,
	cond = function(pid) return Fx().ChampionAlive() end,
	roll = function(pid) return { roll = RL.Rand(100), cost = Fx().Cost(pid, 50, 25) } end,
	text = function(pid, p) return "Champions from every land gather for a tournament of arms. Your own Champion is eager to compete. (Win chance: " .. Fx().TourneyChance() .. "%)" end,
	options = {
		{ label = function() return "Enter your Champion (" .. Fx().TourneyChance() .. "% to win glory, XP and Culture)." end,
		  run = function(pid, p)
			if p.roll < Fx().TourneyChance() then
				Fx().ChampionXP(25); Fx().Culture(pid, Fx().Amt(pid, 30, 20)); Fx().AddTemp(pid, "BUILDING_RL_TEMP_HAPPY", 1, 10, "Tournament Glory")
				return POS .. "Your Champion is victorious!" .. E .. " +25 XP, Culture and 10 turns of celebration."
			end
			Fx().ChampionDamage(50); Fx().ChampionXP(10)
			return NEG .. "Your Champion is unhorsed and badly hurt." .. E .. " (+10 XP for the lesson.)" end },
		{ label = function(pid, p) return "Host the games without competing (" .. G(p.cost) .. ")." end,
		  avail = function(pid, p) return CanPay(pid, p.cost) end,
		  run = function(pid, p) Fx().Gold(pid, -p.cost); Fx().AddTemp(pid, "BUILDING_RL_TEMP_HAPPY", 1, 10, "Grand Games"); return "The crowds love the spectacle." end },
		{ label = "Ignore it.", run = function() return "The tournament goes on without you." end },
	} }

-- 9 ------------------------------------------------------------------
Event{ id = "LIBRARY", title = "The Lost Library", weight = 10, minTurn = 20,
	text = function() return "Beneath a collapsed temple your workers uncover shelves of sealed scrolls - the library of a forgotten dynasty." end,
	options = {
		{ label = "Copy the scrolls: +50% of your current research.", run = function(pid) Fx().ResearchFraction(pid, 0.5); return "Your scholars feast on the knowledge." end },
		{ label = "Sell them to collectors: [ICON_GOLD] Gold.", run = function(pid) local g = Fx().Amt(pid, 60, 40); Fx().Gold(pid, g); return "Collectors pay " .. G(g) .. "." end },
		{ label = "Display them publicly: [ICON_CULTURE] Culture.", run = function(pid) local c = Fx().Amt(pid, 40, 30); Fx().Culture(pid, c); return "+" .. c .. " [ICON_CULTURE] Culture." end },
	} }

-- 10 -----------------------------------------------------------------
Event{ id = "BANDITS", title = "Bandits on the Roads", weight = 10, minTurn = 10,
	roll = function(pid) return { cost = Fx().Cost(pid, 60, 30) } end,
	text = function() return "Bandits have seized a mountain pass and demand a toll from every caravan bound for your cities." end,
	options = {
		{ label = function(pid, p) return "Pay the toll (" .. G(p.cost) .. ")." end,
		  avail = function(pid, p) return CanPay(pid, p.cost) end,
		  run = function(pid, p) Fx().Gold(pid, -p.cost); return "Trade flows again." end },
		{ label = "Root them out: 3 bandit units appear near one of your cities.",
		  run = function(pid) Fx().SpawnHostilesNear(pid, 3, "Bandits come down from the hills!", -1); return "Your soldiers prepare for battle." end },
		{ label = "Ignore them: -10% Gold in all cities for 10 turns.",
		  run = function(pid) Fx().AddTemp(pid, "BUILDING_RL_CURSE_CORRUPTION", 1, 10, "Banditry"); return NEG .. "Caravans are robbed for 10 turns." .. E end },
	} }

-- 11 -----------------------------------------------------------------
Event{ id = "GOLD_RUSH", title = "Gold in the Hills", weight = 8, minTurn = 15,
	text = function() return "A shepherd stumbles into your court with a nugget the size of a fist. There is more where it came from." end,
	options = {
		{ label = "Stake a claim: a new Gold resource appears near one of your cities.",
		  run = function(pid) if Fx().PlaceResource(pid, "RESOURCE_GOLD") then return "Prospectors find a rich vein. Improve it with a Mine!" end Fx().Gold(pid, Fx().Amt(pid, 80, 40)); return "No good ground found - but the nugget sells well." end },
		{ label = "Pan the streams right now: [ICON_GOLD] Gold.", run = function(pid) local g = Fx().Amt(pid, 80, 40); Fx().Gold(pid, g); return "+" .. G(g) .. "." end },
	} }

-- 12 -----------------------------------------------------------------
Event{ id = "EARTHQUAKE", title = "Earthquake!", weight = 7, minTurn = 20,
	roll = function(pid) return { cost = Fx().Cost(pid, 70, 35) } end,
	text = function() return "The ground heaves. Walls crack, towers fall, and dust hangs over your capital for days." end,
	options = {
		{ label = function(pid, p) return "Rebuild at once (" .. G(p.cost) .. "): +10% Production for 8 turns as crews keep working." end,
		  avail = function(pid, p) return CanPay(pid, p.cost) end,
		  run = function(pid, p) Fx().Gold(pid, -p.cost); Fx().AddTemp(pid, "BUILDING_RL_TEMP_PRODUCTION", 1, 8, "Rebuilding"); return "Your capital rises stronger." end },
		{ label = "Let the people rebuild: capital takes heavy damage and -10% Production for 8 turns.",
		  run = function(pid) Fx().DamageCapital(pid, 60); Fx().AddTemp(pid, "BUILDING_RL_CURSE_DECAY", 1, 8, "Ruins"); return NEG .. "The walls lie in ruins for now." .. E end },
	} }

-- 13 -----------------------------------------------------------------
Event{ id = "PROPHET", title = "A Wild-Eyed Prophet", weight = 8, minTurn = 15,
	text = function() return "A ragged prophet preaches in the market that the end is near - and that your reign is either its cause or its cure. Crowds hang on every word." end,
	options = {
		{ label = "Embrace his message: [ICON_PEACE] Faith, but unrest for 10 turns.",
		  run = function(pid) local f = Fx().Amt(pid, 60, 30); Fx().Faith(pid, f); Fx().AddTemp(pid, "BUILDING_RL_CURSE_UNREST", 1, 10, "Fervor"); return "+" .. f .. " [ICON_PEACE] Faith. The streets are restless." end },
		{ label = "Give him a stage: +25% Culture for 10 turns.", run = function(pid) Fx().AddTemp(pid, "BUILDING_RL_TEMP_CULTURE", 1, 10, "The Prophet's Stage"); return "His sermons become poetry." end },
		{ label = "Exile him: [ICON_CULTURE] Culture.", run = function(pid) local c = Fx().Amt(pid, 20, 15); Fx().Culture(pid, c); return "Order is restored." end },
	} }

-- 14 -----------------------------------------------------------------
Event{ id = "SPY", title = "A Foreign Spy", weight = 8, minTurn = 30,
	text = function() return "Your guards catch a foreigner copying the plans of your granaries. Under his cloak: letters in a rival's cipher." end,
	options = {
		{ label = "Interrogate him: +30% of current research.", run = function(pid) Fx().ResearchFraction(pid, 0.3); return "He talks. Your engineers take notes." end },
		{ label = "Ransom him back: [ICON_GOLD] Gold.", run = function(pid) local g = Fx().Amt(pid, 50, 30); Fx().Gold(pid, g); return "+" .. G(g) .. "." end },
		{ label = "Make an example of him: 10 turns of national pride (+1 Happiness per city).",
		  run = function(pid) Fx().AddTemp(pid, "BUILDING_RL_TEMP_HAPPY", 1, 10, "National Pride"); return "The people rally around the throne." end },
	} }

-- 15 -----------------------------------------------------------------
Event{ id = "VOLCANIC", title = "Volcanic Soil", weight = 7, minTurn = 20,
	roll = function(pid) return { cost = Fx().Cost(pid, 100, 50) } end,
	cond = function(pid) return Fx().CanGain(pid, "FERTILE") end,
	text = function() return "An old volcano has gone quiet. Its ash has turned the valleys below into the richest farmland anyone has seen." end,
	options = {
		{ label = function(pid, p) return "Fund new farming villages (" .. G(p.cost) .. "): gain the Fertile Lands boon." end,
		  avail = function(pid, p) return CanPay(pid, p.cost) end,
		  run = function(pid, p) Fx().Gold(pid, -p.cost); Fx().GrantCard(pid, "FERTILE"); return "Fertile Lands acquired (+2 Food in all cities)." end },
		{ label = "Quarry the obsidian: a production burst in every city.", run = function(pid) Fx().ProductionBurst(pid, Fx().Amt(pid, 20, 15)); return "Obsidian tools flood your workshops." end },
	} }

-- 16 -----------------------------------------------------------------
Event{ id = "GAMBLER", title = "The Gambler's Den", weight = 8, minTurn = 10,
	roll = function(pid) return { bet = Fx().Cost(pid, 50, 30), r1 = RL.Rand(100), r2 = RL.Rand(100) } end,
	text = function() return "Your treasurer has found a den where the dice are said to be honest. He would like to try his luck - with the state's money." end,
	options = {
		{ label = function(pid, p) return "A modest bet (" .. G(p.bet) .. "): 50% to double it." end,
		  avail = function(pid, p) return CanPay(pid, p.bet) end,
		  run = function(pid, p) if p.r1 < 50 then Fx().Gold(pid, p.bet); return POS .. "Winner! +" .. G(p.bet) .. E end Fx().Gold(pid, -p.bet); return NEG .. "Lost " .. G(p.bet) .. "." .. E end },
		{ label = "Bet a quarter of the treasury: 40% to triple it.",
		  avail = function(pid) if P(pid):GetGold() >= 40 then return true end return false, "Treasury too small" end,
		  run = function(pid, p) local b = math.floor(P(pid):GetGold() / 4)
			if p.r2 < 40 then Fx().Gold(pid, b * 2); return POS .. "Fortune smiles! +" .. G(b * 2) .. E end
			Fx().Gold(pid, -b); return NEG .. "The house wins. -" .. G(b) .. E end },
		{ label = "Walk away.", run = function() return "Your treasurer sulks." end },
	} }

-- 17 -----------------------------------------------------------------
Event{ id = "SMITH", title = "The Legendary Smith", weight = 9, minTurn = 15,
	roll = function(pid) return { cost = Fx().Cost(pid, 90, 45), hcost = Fx().Cost(pid, 60, 30) } end,
	text = function() return "A smith whose blades are spoken of in songs offers to work for you - for a single season." end,
	options = {
		{ label = function(pid, p) return "Arm your army (" .. G(p.cost) .. "): all military units +15 XP." end,
		  avail = function(pid, p) return CanPay(pid, p.cost) end,
		  run = function(pid, p) Fx().Gold(pid, -p.cost); Fx().UnitsXP(pid, 15); return "Your soldiers carry finer steel." end },
		{ label = function(pid, p) return "Forge a blade for your Champion (" .. G(p.hcost) .. "): +40 XP." end,
		  avail = function(pid, p) if not Fx().ChampionAlive() then return false, "No living Champion" end return CanPay(pid, p.hcost) end,
		  run = function(pid, p) Fx().Gold(pid, -p.hcost); Fx().ChampionXP(40); return "Your Champion wields a legend." end },
		{ label = "Decline.", run = function() return "The smith moves on to your rivals..." end },
	} }

-- 18 -----------------------------------------------------------------
Event{ id = "HARVEST_EV", title = "A Bumper Harvest", weight = 10,
	text = function() return "The granaries overflow. It is the best harvest in living memory." end,
	options = {
		{ label = "Hold a great feast: +1 Happiness per city for 10 turns.", run = function(pid) Fx().AddTemp(pid, "BUILDING_RL_TEMP_HAPPY", 1, 10, "The Great Feast"); return "The feasting lasts for days." end },
		{ label = "Sell the surplus: [ICON_GOLD] Gold.", run = function(pid) local g = Fx().Amt(pid, 50, 30); Fx().Gold(pid, g); return "+" .. G(g) .. "." end },
		{ label = "Store it: +10% Food in all cities for 15 turns.", run = function(pid) Fx().AddTemp(pid, "BUILDING_RL_TEMP_GROWTH", 1, 15, "Full Granaries"); return "Your cities grow fat and happy." end },
	} }

-- 19 -----------------------------------------------------------------
Event{ id = "IDOL", title = "The Cursed Idol", weight = 7, minTurn = 20,
	text = function() return "Explorers return with a golden idol, warm to the touch. Every one of them has had the same nightmare since they found it." end,
	options = {
		{ label = "Melt it down: lots of [ICON_GOLD] Gold, and [COLOR_NEGATIVE_TEXT]a random Curse[ENDCOLOR].",
		  run = function(pid) local g = Fx().Amt(pid, 150, 75); Fx().Gold(pid, g); local c = Fx().AddCurse(pid); return "+" .. G(g) .. ". " .. NEG .. "Curse: " .. (c and c.name or "?") .. E end },
		{ label = "Destroy it in a holy fire: [ICON_PEACE] Faith.", run = function(pid) local f = Fx().Amt(pid, 25, 10); Fx().Faith(pid, f); return "The nightmares stop." end },
		{ label = "Bury it where it was found.", run = function() return "Some things are best left alone." end },
	} }

-- 20 -----------------------------------------------------------------
Event{ id = "PERIL", title = "A Village in Peril", weight = 9, minTurn = 10,
	cond = function(pid) return Fx().ChampionAlive() end,
	roll = function(pid) return { cost = Fx().Cost(pid, 40, 20) } end,
	text = function() return "A frontier village begs for help against a monster that takes their cattle - and lately, their children." end,
	options = {
		{ label = "Send your Champion: +30 XP and Culture, but it is wounded.",
		  run = function(pid) Fx().ChampionXP(30); Fx().ChampionDamage(30); Fx().Culture(pid, Fx().Amt(pid, 15, 10)); return "The beast is slain. Songs are already being written." end },
		{ label = function(pid, p) return "Send hunters with a bounty (" .. G(p.cost) .. ")." end,
		  avail = function(pid, p) return CanPay(pid, p.cost) end,
		  run = function(pid, p) Fx().Gold(pid, -p.cost); Fx().AddTemp(pid, "BUILDING_RL_TEMP_HAPPY", 1, 8, "Saved Village"); return "The hunters return victorious." end },
		{ label = "Ignore them: unrest for 8 turns.", run = function(pid) Fx().AddTemp(pid, "BUILDING_RL_CURSE_UNREST", 1, 8, "Abandoned"); return NEG .. "Word spreads that the crown does not protect its people." .. E end },
	} }

-- 21 -----------------------------------------------------------------
Event{ id = "CARTOGRAPHER", title = "The Mysterious Cartographer", weight = 8,
	text = function() return "A veiled woman with ink-stained fingers offers to draw you a map. \"Of lands,\" she says, \"or of fate. Choose.\"" end,
	options = {
		{ label = "A map of fate: an extra draft.", run = function(pid) Fx().QueueDraft("The Cartographer's Fate", 1); return "Your fate unfolds before you..." end },
		{ label = "A map of chances: +2 Rerolls.", run = function() Fx().Rerolls(2); return "+2 Rerolls." end },
		{ label = "A map of lands: reveal everything within 15 tiles of your capital.", run = function(pid) Fx().RevealAround(pid, 15); return "The world grows smaller." end },
	} }

-- 22 -----------------------------------------------------------------
Event{ id = "DESERTERS", title = "Deserters!", weight = 7, minTurn = 30,
	cond = function(pid) return Fx().CountMilitary(pid) >= 3 end,
	roll = function(pid) return { cost = Fx().Cost(pid, 60, 30) } end,
	text = function() return "Unpaid and homesick, a regiment threatens to desert. Their officers are waiting for your answer." end,
	options = {
		{ label = function(pid, p) return "Pay their back wages (" .. G(p.cost) .. ")." end,
		  avail = function(pid, p) return CanPay(pid, p.cost) end,
		  run = function(pid, p) Fx().Gold(pid, -p.cost); return "The regiment stays loyal." end },
		{ label = "Let them go: lose one random military unit.", run = function(pid) local n = Fx().KillRandomMilitary(pid); return NEG .. (n or "A unit") .. " deserts." .. E end },
		{ label = "Hang the ringleaders: unrest for 10 turns, but the rest fight harder (+10 XP all).",
		  run = function(pid) Fx().AddTemp(pid, "BUILDING_RL_CURSE_UNREST", 1, 10, "Harsh Discipline"); Fx().UnitsXP(pid, 10); return "Discipline is restored. Grimly." end },
	} }

-- 23 -----------------------------------------------------------------
Event{ id = "GENIUS", title = "A Generation of Genius", weight = 4, minTurn = 40,
	text = function() return "Something is in the water. Your academies overflow with prodigies, and one among them stands above the rest." end,
	options = {
		{ label = "Nurture the scientist: a free Great Scientist.", run = function(pid) Fx().SpawnUnitType(pid, "UNIT_SCIENTIST", 1); return "A Great Scientist appears in your capital." end },
		{ label = "Nurture the engineer: a free Great Engineer.", run = function(pid) Fx().SpawnUnitType(pid, "UNIT_ENGINEER", 1); return "A Great Engineer appears in your capital." end },
		{ label = "Nurture the merchant: a free Great Merchant.", run = function(pid) Fx().SpawnUnitType(pid, "UNIT_MERCHANT", 1); return "A Great Merchant appears in your capital." end },
	} }

-- 24 -----------------------------------------------------------------
Event{ id = "HORDE_SCOUTS", title = "Horde Scouts Sighted", weight = 9, minTurn = 25,
	text = function() return "Riders in Horde colours have been seen watching your walls. An attack is coming - the question is when, and how ready you will be." end,
	options = {
		{ label = "Muster the militia: all cities +10 Defense for 10 turns, and the next raid is delayed 5 turns.",
		  run = function(pid) Fx().AddTemp(pid, "BUILDING_RL_TEMP_DEFENSE", 1, 10, "Mustered Militia"); Fx().DelayWave(5); return "Your walls bristle with spears." end },
		{ label = "Ambush the scouts: 2 weak Horde units appear (free XP).",
		  run = function(pid) Fx().SpawnHostilesNear(pid, 2, "Horde scouts ambushed!", -1); return "The trap is set." end },
		{ label = "Ignore them: the next raid brings 2 extra units.", run = function() Fx().WaveBonus(2); return NEG .. "The Horde gathers in strength..." .. E end },
	} }

-- 25 -----------------------------------------------------------------
Event{ id = "DEBATE", title = "The Great Debate", weight = 8, minTurn = 15,
	text = function() return "Your court is divided over the future of the realm. Whichever faction you favour will shape the next opportunity you are offered. (Your next draft will be weighted heavily toward that theme.)" end,
	options = {
		{ label = "The generals: [ICON_WAR] War.", run = function() Fx().SetFocus("WAR"); return "The next draft favours War." end },
		{ label = "The merchants: [ICON_GOLD] Commerce.", run = function() Fx().SetFocus("GOLD"); return "The next draft favours Commerce." end },
		{ label = "The scholars: [ICON_RESEARCH] Knowledge.", run = function() Fx().SetFocus("SCIENCE"); return "The next draft favours Knowledge." end },
		{ label = "The farmers: [ICON_FOOD] Growth.", run = function() Fx().SetFocus("GROWTH"); return "The next draft favours Growth." end },
	} }

-- 26 -----------------------------------------------------------------
Event{ id = "FESTIVAL", title = "Festival of Lights", weight = 8,
	roll = function(pid) return { cost = Fx().Cost(pid, 50, 25) } end,
	text = function() return "The guilds propose a festival of lanterns, music and theatre, the grandest your empire has ever seen. They only need a royal patron." end,
	options = {
		{ label = function(pid, p) return "Be their patron (" .. G(p.cost) .. "): +25% Culture and +1 Happiness per city for 10 turns." end,
		  avail = function(pid, p) return CanPay(pid, p.cost) end,
		  run = function(pid, p) Fx().Gold(pid, -p.cost); Fx().AddTemp(pid, "BUILDING_RL_TEMP_CULTURE", 1, 10, "Festival"); Fx().AddTemp(pid, "BUILDING_RL_TEMP_HAPPY", 1, 10, "Festival"); return "The skies glow for ten nights." end },
		{ label = "Decline.", run = function() return "A smaller festival happens anyway." end },
	} }

-- 27 -----------------------------------------------------------------
Event{ id = "SHRINE", title = "The Ancient Shrine", weight = 8, minTurn = 20,
	roll = function(pid) return { good = RL.Chance(60) } end,
	text = function() return "Pilgrims lead you to a shrine older than your gods. It is said to wash away misfortune - or to bring it, to the unworthy." end,
	options = {
		{ label = "Pray at the shrine (60%: cleanse a Curse or gain Faith).",
		  run = function(pid, p)
			if p.good then
				if Fx().CurseCount(pid) > 0 then Fx().CleanseCurses(pid, 1); return POS .. "A curse is lifted from your empire!" .. E end
				local f = Fx().Amt(pid, 50, 25); Fx().Faith(pid, f); return POS .. "+" .. f .. " [ICON_PEACE] Faith." .. E
			end
			Fx().AddTemp(pid, "BUILDING_RL_CURSE_HERESY", 1, 10, "Unanswered Prayers"); return NEG .. "The shrine is silent. Your faithful are shaken (-1 Faith per city, 10 turns)." .. E end },
		{ label = "Strip its gold: [ICON_GOLD] Gold, but -1 Faith per city for 15 turns.",
		  run = function(pid) local g = Fx().Amt(pid, 90, 45); Fx().Gold(pid, g); Fx().AddTemp(pid, "BUILDING_RL_CURSE_HERESY", 1, 15, "Sacrilege"); return "+" .. G(g) .. ". The priests are horrified." end },
		{ label = "Leave an offering and go.", run = function(pid) Fx().Faith(pid, Fx().Amt(pid, 10, 5)); return "You feel watched over." end },
	} }

-- 28 -----------------------------------------------------------------
Event{ id = "CARAVAN", title = "The Lost Caravan", weight = 8, minTurn = 15,
	text = function() return "A rich foreign caravan has lost its way in your deserts. Its guards are dying of thirst. Its cargo is worth a fortune." end,
	options = {
		{ label = "Rescue them: [ICON_GOLD] Gold reward and +10% Gold for 10 turns.",
		  run = function(pid) local g = Fx().Amt(pid, 60, 30); Fx().Gold(pid, g); Fx().AddTemp(pid, "BUILDING_RL_TEMP_GOLD", 1, 10, "Grateful Traders"); return "The grateful merchants spread word of your kindness." end },
		{ label = "Take everything: a fortune in Gold and the permanent [COLOR_NEGATIVE_TEXT]Cursed Gold[ENDCOLOR] curse.",
		  run = function(pid) local g = Fx().Amt(pid, 160, 80); Fx().Gold(pid, g); Fx().AddCurse(pid, "CURSED_GOLD"); return "+" .. G(g) .. ". The gold never feels clean." end },
	} }

-- 29 -----------------------------------------------------------------
Event{ id = "WARLORD_ENVOY", title = "An Envoy from the Horde", weight = 6, minTurn = 35,
	roll = function(pid) return { cost = Fx().Cost(pid, 120, 60) } end,
	text = function() return "A Horde envoy rides in under a white banner. \"Pay tribute, and my masters will look elsewhere. For a while.\"" end,
	options = {
		{ label = function(pid, p) return "Pay tribute (" .. G(p.cost) .. "): the next raid is delayed 12 turns." end,
		  avail = function(pid, p) return CanPay(pid, p.cost) end,
		  run = function(pid, p) Fx().Gold(pid, -p.cost); Fx().DelayWave(12); return "The Horde turns its gaze elsewhere. For now." end },
		{ label = "Send back his head: +1 Happiness per city for 10 turns, but the next raid brings 3 extra units.",
		  run = function(pid) Fx().AddTemp(pid, "BUILDING_RL_TEMP_HAPPY", 1, 10, "Defiance"); Fx().WaveBonus(3); return "Your people cheer. The Horde will answer." end },
	} }

-- 30 -----------------------------------------------------------------
Event{ id = "INVENTOR", title = "The Eccentric Inventor", weight = 7, minTurn = 40,
	roll = function(pid) return { good = RL.Chance(55) } end,
	text = function() return "An inventor begs for a royal workshop. His last machine exploded. His one before that changed agriculture forever." end,
	options = {
		{ label = "Fund the workshop (55%: a free technology / 45%: a fire and a production slump).",
		  run = function(pid, p)
			if p.good then Fx().FreeTech(pid); return POS .. "It works! You learn a new technology." .. E end
			Fx().DamageCapital(pid, 30); Fx().AddTemp(pid, "BUILDING_RL_CURSE_DECAY", 1, 6, "Workshop Fire"); return NEG .. "The workshop explodes." .. E end },
		{ label = "Give him a modest stipend: +10% Science for 10 turns.", run = function(pid) Fx().AddTemp(pid, "BUILDING_RL_TEMP_SCIENCE", 1, 10, "Royal Workshop"); return "Small steps, steady progress." end },
		{ label = "Show him the door.", run = function() return "He mutters something about \"visionaries\"." end },
	} }

RL.EventById = {}
for _, e in ipairs(RL.Events) do RL.EventById[e.id] = e end
