LK3D = LK3D or {}

local math = math
local math_min = math.min
local math_max = math.max


local function light_mult_at_pos(pos, dn, normal, blacklist)
	local lVal1R, lVal1G, lVal1B = (LK3D.AmbientCol.r / 255), (LK3D.AmbientCol.g / 255), (LK3D.AmbientCol.b / 255)

	local dobl = (blacklist ~= nil)
	for k, v in pairs(LK3D.CurrUniv["lights"]) do
		if lVal1R >= 1 and lVal1G >= 1 and lVal1B >= 1 then
			break
		end

		if dobl and blacklist[k] == true then
			continue
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

return light_mult_at_pos