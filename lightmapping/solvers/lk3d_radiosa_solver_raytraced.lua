LK3D = LK3D or {}
LK3D.Radiosa = LK3D.Radiosa or {}
-- Calculates lighting via the LK3D.GetLightIntensity()
local solver = {}

-- This gets called constantly, return true when done preprocessing!
function solver.PreProcess()
	return true
end



local math_min = math.min
local math_max = math.max
local EPSILON = 0.00001
local function light_mult_at_pos(pos, normal)
	local lVal1R, lVal1G, lVal1B = LK3D.AmbientCol:Unpack()
	lVal1R = lVal1R / 255
	lVal1G = lVal1G / 255
	lVal1B = lVal1B / 255

	local dn = normal ~= nil

	local rayOrigin = pos + (normal * EPSILON)


	for k, v in pairs(LK3D.CurrUniv["lights"]) do
		if lVal1R >= 1 and lVal1G >= 1 and lVal1B >= 1 then
			break
		end

		local pos_l = v[1]
		local inten_l = v[2]
		local col_l = v[3]
		local sm = v[4]

		local dc = (sm and inten_l ^ 2 or inten_l)
		local pd = pos:Distance(pos_l)
		if pd > dc then
			continue
		end

		-- raycast to see if we can say

		local hit, pos, dist = LK3D.Radiosa.FTraceTraceLine(pos_l, rayOrigin)
		if hit then
			continue
		end



		if sm then
			pd = pd ^ .5
		end
		local vimv1d = (inten_l - pd)
		if dn then
			local pos_loc = pos_l - pos
			pos_loc:Normalize()
			vimv1d = vimv1d * math_max(pos_loc:Dot(normal), 0)
		end

		-- dv1pc = math_abs(vimv1d < 0 and 0 or vimv1d)
		local dv1pc = vimv1d < 0 and 0 or vimv1d
		local dv1c = dv1pc > 1 and 1 or dv1pc
		lVal1R = lVal1R + col_l[1] * dv1c
		lVal1G = lVal1G + col_l[2] * dv1c
		lVal1B = lVal1B + col_l[3] * dv1c
	end


	lVal1R = math_min(math_max(lVal1R, 0), 1)
	lVal1G = math_min(math_max(lVal1G, 0), 1)
	lVal1B = math_min(math_max(lVal1B, 0), 1)

	return lVal1R, lVal1G, lVal1B
end



function solver.CalculateValue(patch, pos, norm)
	local valR, valG, valB = light_mult_at_pos(pos, norm)


	return {valR * 255, valG * 255, valB * 255}
end


return solver