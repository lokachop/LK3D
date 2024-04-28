--[[--
## Universe Module
---

This module handles the universe system in LK3D  
Universes are where all of the objects, lights, particles and physics bodies live in LK3D
]]
-- @module universes
LK3D = LK3D or {}

LK3D.CurrUniv = LK3D.DEF_UNIVERSE
LK3D.UniverseStack = {}
LK3D.UniverseRegistry = LK3D.UniverseRegistry or {}


--- Creates a new universe
-- @tparam string tag Universe tag
-- @treturn table LK3D universe
-- @usage local univGame = LK3D.NewUniverse("universe_game")
function LK3D.NewUniverse(tag)
	local newUniv = {
		["lk3d"] = true,
		["objects"] = {},
		["lights"] = {},
		["lightcount"] = 0,
		["particles"] = {},
		["physics"] = {},

	}

	if tag == nil then
		LK3D.New_D_Print("Calling LK3D.NewUniverse without a tag, universe will not work with baked radiosity...", LK3D_SERVERITY_WARN, "LK3D")
	else
		LK3D.New_D_Print("Created universe with tag \"" .. tostring(tag) .. "\"", LK3D_SEVERITY_INFO, "LK3D")

		LK3D.UniverseRegistry[tag] = newUniv
		newUniv["tag"] = tag
	end

	return newUniv
end

--- Pushes a new active universe to the stack
-- @tparam table univ Universe to push
-- @usage LK3D.PushUniverse(univGame)
function LK3D.PushUniverse(univ)
	LK3D.UniverseStack[#LK3D.UniverseStack + 1] = LK3D.CurrUniv
	LK3D.CurrUniv = univ
end

--- Restores the last active universe from the stack  
-- @usage LK3D.PopUniverse()
function LK3D.PopUniverse()
	LK3D.CurrUniv = LK3D.UniverseStack[#LK3D.UniverseStack] or LK3D.DEF_UNIVERSE
	LK3D.UniverseStack[#LK3D.UniverseStack] = nil
end

--- Clears the active universe of all of its contents
-- @tparam ?table univ Universe to clear, defaults to active one
-- @usage LK3D.WipeUniverse()
function LK3D.WipeUniverse(univ)
	univ = univ or LK3D.CurrUniv

	univ["objects"] = {}
	univ["lights"] = {}
	univ["lightcount"] = 0
	univ["particles"] = {}
	univ["physics"] = {}
end

--- Gets a universe by its tag
-- @tparam string tag Universe tag
-- @treturn table LK3D universe, nil if non-existant
-- @usage LK3D.GetUniverseByTag("universeGame")
function LK3D.GetUniverseByTag(tag)
	return LK3D.UniverseRegistry[tag]
end