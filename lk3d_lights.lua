--[[--
## Lets you manage lights
---

Module to create / update / delete lights on the active universe  
It also allows you to get the light intensity at a position on the universe
]]
-- @module lights
LK3D = LK3D or {}

--- Adds a light to the active universe
-- @tparam string index Index name of the light
-- @tparam vector pos Position of the light
-- @tparam number intensity Intensity of the light
-- @tparam color col Colour of the light
-- @tparam bool smooth Sets the distance to linear rather than exponential
-- @usage -- adds a green light at the center of the universe
-- LK3D.AddLight("loka_light_green", Vector(0, 0, 0), 2, Color(0, 255, 0), false)
-- @usage -- adds a huge smooth blue light at the center of the universe
-- LK3D.AddLight("loka_light_blue", Vector(0, 0, 0), 3.5, Color(0, 0, 255), true)
function LK3D.AddLight(index, pos, intensity, col, smooth)
	LK3D.CurrUniv["lights"][index] = {pos or Vector(0, 0, 0), intensity or 2, col and {col.r / 255, col.g / 255, col.b / 255} or {1, 1, 1}, (smooth == true) and true or false}
	LK3D.CurrUniv["lightcount"] = LK3D.CurrUniv["lightcount"] + 1
end

--- Removes a light from the active universe
-- @tparam string index Index name of the light
-- @usage LK3D.RemoveLight("loka_light_green")
function LK3D.RemoveLight(index)
	if not LK3D.CurrUniv["lights"][index] then
		return
	end

	LK3D.CurrUniv["lights"][index] = nil
	LK3D.CurrUniv["lightcount"] = LK3D.CurrUniv["lightcount"] - 1
end


--- Updates the position of a light
-- @tparam string index Index name of the light
-- @tparam vector pos New position of the light
-- @usage LK3D.UpdateLightPos("loka_light_blue", Vector(0, 2, 0))
function LK3D.UpdateLightPos(index, pos)
	if not LK3D.CurrUniv["lights"][index] then
		return
	end
	LK3D.CurrUniv["lights"][index][1] = pos
end


--- Updates the intensity of a light
-- @tparam string index Index name of the light
-- @tparam number intensity New intensity of the light
-- @usage LK3D.UpdateLightIntensity("loka_light_blue", 3.75)
function LK3D.UpdateLightIntensity(index, intensity)
	if not LK3D.CurrUniv["lights"][index] then
		return
	end

	LK3D.CurrUniv["lights"][index][2] = intensity
end


--- Updates the colour of a light
-- @tparam string index Index name of the light
-- @tparam color col New colour of the light
-- @usage LK3D.UpdateLightColour("loka_light_blue", Color(64, 128, 255))
function LK3D.UpdateLightColour(index, col)
	if not LK3D.CurrUniv["lights"][index] then
		return
	end

	LK3D.CurrUniv["lights"][index][3] = col
end

--- Updates the smoothness of a light
-- @tparam string index Index name of the light
-- @tparam bool smooth New smoothness of the light
-- @usage LK3D.UpdateLightSmooth("loka_light_blue", false)
function LK3D.UpdateLightSmooth(index, smooth)
	if not LK3D.CurrUniv["lights"][index] then
		return
	end
	LK3D.CurrUniv["lights"][index][4] = smooth
end


--- Updates all of the parameters of a light
-- @tparam string index Index name of the light
-- @tparam ?vector pos New position of the light
-- @tparam ?number intensity New intensity of the light
-- @tparam ?color col New colour of the light
-- @tparam ?bool smooth New smoothness of the light
-- @usage LK3D.UpdateLight("loka_light_blue", Vector(0, 2, 0), 3.75, Color(64, 128, 255), false)
function LK3D.UpdateLight(index, pos, intensity, col, smooth)
	if not LK3D.CurrUniv["lights"][index] then
		return
	end
	local prevPos = LK3D.CurrUniv["lights"][index][1]
	local prevIntensity = LK3D.CurrUniv["lights"][index][2]
	local prevCol = LK3D.CurrUniv["lights"][index][3]
	local prevSmooth = LK3D.CurrUniv["lights"][index][4]

	LK3D.CurrUniv["lights"][index][1] = pos and pos or prevPos
	LK3D.CurrUniv["lights"][index][2] = intensity and intensity or prevIntensity
	LK3D.CurrUniv["lights"][index][3] = col and {col.r / 255, col.g / 255, col.b / 255} or prevCol
	LK3D.CurrUniv["lights"][index][4] = (smooth ~= nil) and smooth or prevSmooth
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


--- Gets the light intensity at a pos on the active universe
-- @tparam vector pos Position to get the light intensity from
-- @tparam ?vector norm Normal to use to calculate intensity
-- @treturn number intR Red channel intensity between 0-1
-- @treturn number intG Green channel intensity between 0-1
-- @treturn number intB Blue channel intensity between 0-1
-- @usage -- Gets light values at Vector(0, 0, 0)
-- LK3D.GetLightIntensity(Vector(0, 0, 0))
-- @usage -- Gets light values at Vector(0, 0, 0) of a flat plane aiming up
-- LK3D.GetLightIntensity(Vector(0, 0, 0), Vector(0, 0, 1))
function LK3D.GetLightIntensity(pos, norm)
	return light_mult_at_pos(pos, norm)
end