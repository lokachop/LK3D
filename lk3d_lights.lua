LK3D = LK3D or {}

function LK3D.AddLight(index, pos, intensity, col, smooth)
	LK3D.CurrUniv["lights"][index] = {pos or Vector(0, 0, 0), intensity or 2, col and {col.r / 255, col.g / 255, col.b / 255} or {1, 1, 1}, (smooth == true) and true or false}
	LK3D.CurrUniv["lightcount"] = LK3D.CurrUniv["lightcount"] + 1
end

function LK3D.RemoveLight(index)
	if not LK3D.CurrUniv["lights"][index] then
		return
	end

	LK3D.CurrUniv["lights"][index] = nil
	LK3D.CurrUniv["lightcount"] = LK3D.CurrUniv["lightcount"] - 1
end

function LK3D.UpdateLightPos(index, pos)
	if not LK3D.CurrUniv["lights"][index] then
		return
	end
	LK3D.CurrUniv["lights"][index][1] = pos
end

function LK3D.UpdateLightSmooth(index, smooth)
	if not LK3D.CurrUniv["lights"][index] then
		return
	end
	LK3D.CurrUniv["lights"][index][4] = smooth
end

function LK3D.UpdateLightIntensity(index, intensity)
	if not LK3D.CurrUniv["lights"][index] then
		return
	end

	LK3D.CurrUniv["lights"][index][2] = intensity
end

function LK3D.UpdateLightColour(index, col)
	if not LK3D.CurrUniv["lights"][index] then
		return
	end

	LK3D.CurrUniv["lights"][index][3] = col
end

function LK3D.UpdateLight(index, pos, intensity, col)
	if not LK3D.CurrUniv["lights"][index] then
		return
	end
	local pp = LK3D.CurrUniv["lights"][index][1]
	local pi = LK3D.CurrUniv["lights"][index][2]
	local pc = LK3D.CurrUniv["lights"][index][3]

	LK3D.CurrUniv["lights"][index] = {pos and pos or pp, intensity and intensity or pi, col and col or pc}
end



local math_min = math.min
local math_max = math.max

local function light_mult_at_pos(pos, normal)
	local lVal1R, lVal1G, lVal1B = LK3D.AmbientCol:Unpack()
	lVal1R = lVal1R / 255
	lVal1G = lVal1G / 255
	lVal1B = lVal1B / 255

	local dn = normal ~= nil

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



function LK3D.GetLightIntensity(pos, norm)
	return light_mult_at_pos(pos, normal)
end