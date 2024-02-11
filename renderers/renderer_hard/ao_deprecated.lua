LK3D = LK3D or {}

local math = math
local math_min = math.min
local math_floor = math.floor
local math_max = math.max
local math_abs = math.abs
local math_huge = math.huge

local ao_mdist = 0.025
local ao_itr = 3
local ao_st_delta = 1 / ((ao_itr * ao_itr) - 1)
local ao_itr2 = (ao_itr / 2)
local function ao_at_pos(pos, norm, scl) -- sucks
	local sub_var = 0
	local n_a = norm:Angle()
	for i = 0, (ao_itr * ao_itr) - 1 do
		local upc = n_a:Up() * ((math_floor(i / ao_itr) - ao_itr2) / ao_itr2) -- dy
		local ric = n_a:Right() * (((i % ao_itr) - ao_itr2) / ao_itr2) -- dx

		upc:Add(ric)
		upc:Normalize()

		local n_pos, _ = LK3D.TraceRayScene(pos + (norm * (.0015 * scl)), upc)


		local dc = n_pos:Distance(pos)
		if dc < (ao_mdist * scl) then
			sub_var = sub_var + (ao_st_delta * math_abs(1 - dc))
		end
	end

	return math_abs(1 - sub_var)
end