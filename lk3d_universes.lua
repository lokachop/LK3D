LK3D = LK3D or {}

LK3D.CurrUniv = LK3D.DEF_UNIVERSE
LK3D.UniverseStack = {}
LK3D.UniverseRegistry = LK3D.UniverseRegistry or {}
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

function LK3D.PushUniverse(univ)
	LK3D.UniverseStack[#LK3D.UniverseStack + 1] = LK3D.CurrUniv
	LK3D.CurrUniv = univ
end

function LK3D.PopUniverse()
	LK3D.CurrUniv = LK3D.UniverseStack[#LK3D.UniverseStack] or LK3D.DEF_UNIVERSE
	LK3D.UniverseStack[#LK3D.UniverseStack] = nil
end

function LK3D.WipeUniverse(univ)
	univ = univ or LK3D.CurrUniv

	univ["objects"] = {}
	univ["lights"] = {}
	univ["lightcount"] = 0
	univ["particles"] = {}
	univ["physics"] = {}
end