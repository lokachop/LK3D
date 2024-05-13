LK3D = LK3D or {}
LK3D.Radiosa = LK3D.Radiosa or {}
-- Calculates lighting via the LK3D.GetLightIntensity()
local solver = {}

-- This gets called constantly, return true when done preprocessing!
function solver.PreProcess()
	return true
end

local ao_mdist = 0.4
local ao_itr = 3
local ao_st_delta = 1 / ((ao_itr * ao_itr) - 1)
local ao_itr2 = (ao_itr / 2)
local function ao_at_pos(pos, norm) -- sucks
	local sub_var = 0
	local n_a = norm:Angle()
	for i = 0, (ao_itr * ao_itr) - 1 do
		local upc = n_a:Up() * ((math.floor(i / ao_itr) - ao_itr2) / ao_itr2) -- dy
		local ric = n_a:Right() * (((i % ao_itr) - ao_itr2) / ao_itr2) -- dx

		upc:Add(ric)
		upc:Normalize()

		local startRay = pos + (norm * .0015)
		local endRay = (pos + (norm * .0015)) + upc

		local _, _, dist = LK3D.Radiosa.FTraceTraceLine(startRay, endRay)

		dist = math.min(dist, 1)
		if dist < ao_mdist then
			sub_var = sub_var + (ao_st_delta * math.abs(1 - dist))
		end
	end

	return math.abs(1 - sub_var)
end


-- Return RGB struct, 0-255
function solver.CalculateValue(patch, pos, norm) -- return table colour {1, 1, 1}
	local aoVal = ao_at_pos(pos, norm)



	return {aoVal * 16, aoVal * 16, aoVal * 16}
end


return solver