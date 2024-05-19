LK3D = LK3D or {}
LK3D.Radiosa = LK3D.Radiosa or {}
-- Calculates lighting via the LK3D.GetLightIntensity()
local solver = {}

-- This gets called constantly, return true when done preprocessing!
function solver.PreProcess()
	return true
end

local DO_EMMISIVEPATCH_LIGHT = false
local EMMISIVEPATCH_LIGHT_MUL = 2.25
local EMMISIVEPATCH_COL_MUL = 0.1
local EMMISIVEPATCH_SMOOTH_LIGHT = true
local MULTISAMPLE_SIZE = 2 -- 2 x 2 = 4


local math_min = math.min
local math_max = math.max
local math_floor = math.floor
local EPSILON = 0.001

local RED = Color(255, 0, 0)
local GREEN = Color(0, 255, 0)
local function light_mult_at_pos(pos, normal)
	local lVal1R, lVal1G, lVal1B = LK3D.AmbientCol:Unpack()
	lVal1R = lVal1R / 255
	lVal1G = lVal1G / 255
	lVal1B = lVal1B / 255

	local dn = normal ~= nil

	local rayOrigin = Vector(pos + (normal * EPSILON))

	local normAng = normal:Angle()
	local right = normAng:Right()
	local forward = normAng:Forward()

	local texelSize = (LK3D.Radiosa.LIGHTMAP_TRI_SZ / LK3D.Radiosa.LIGHTMAP_RES) * 1


	LK3D.SetTraceReturnTable(true)
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
		local visMul = 0
		local addVal = 1 / ((MULTISAMPLE_SIZE * 2) * (MULTISAMPLE_SIZE * 2))

		for x = -MULTISAMPLE_SIZE, MULTISAMPLE_SIZE do
			local xc = x / MULTISAMPLE_SIZE
			for y = -MULTISAMPLE_SIZE, MULTISAMPLE_SIZE do
				local yc = y / MULTISAMPLE_SIZE

				local realRayPos = rayOrigin + (right * xc * texelSize) + (forward * yc * texelSize)

				local hit2, pos2, dist2 = LK3D.Radiosa.FTraceTraceLine(pos_l, realRayPos)
				if dist2 < 1 then -- i put < 1 via praying that it worked and it somehow works, what?
					continue
				end
				visMul = visMul + addVal
			end
		end


		--[[
		LK3D.PushProcessingMessage("-------")
		for i = 0, msItr do
			local xc = (i % MULTISAMPLE_SIZE) / MULTISAMPLE_SIZE
			local yc = (math_floor(i / MULTISAMPLE_SIZE)) / MULTISAMPLE_SIZE

			xc = (xc - .5) * 2
			yc = (yc - .5) * 2
			LK3D.PushProcessingMessage(";; " .. tostring(xc) .. ", " .. tostring(yc))

			local realRayPos = rayOrigin + (right * xc * texelSize) + (forward * yc * texelSize)


			local hit2, pos2, dist2 = LK3D.Radiosa.FTraceTraceLine(pos_l, realRayPos)
			if dist2 < 1 then -- i put < 1 via praying that it worked and it somehow works, what?
				continue
			end
			visMul = visMul + addVal
		end
		]]--

		if visMul == 0 then
			continue
		end

		--LK3D.DebugUtils.Line(rayOrigin, rayOrigin + (forward * 1), 64, Color(0, 255, 0))

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
		lVal1R = lVal1R + col_l[1] * dv1c * visMul
		lVal1G = lVal1G + col_l[2] * dv1c * visMul
		lVal1B = lVal1B + col_l[3] * dv1c * visMul
	end
	LK3D.SetTraceReturnTable(false)


	lVal1R = math_min(math_max(lVal1R, 0), 1)
	lVal1G = math_min(math_max(lVal1G, 0), 1)
	lVal1B = math_min(math_max(lVal1B, 0), 1)

	return lVal1R, lVal1G, lVal1B
end


local univRT = LK3D.NewUniverse("universe_radiosa_raytraced")
function solver.PreProcess()
	LK3D.WipeUniverse(univRT)
	local prevUniv = LK3D.CurrUniv
	local lights = LK3D.GetUniverseLights(prevUniv)


	LK3D.PushUniverse(univRT)
		for k, v in pairs(lights) do
			local lightPos = Vector(v[1])
			local lightIntensity = v[2]
			local lightCol = v[3]
			local lightColAssemble = Color(lightCol[1] * 255, lightCol[2] * 255, lightCol[3] * 255)
			local lightSmooth = v[4]

			LK3D.AddLight(k, lightPos, lightIntensity, lightColAssemble, lightSmooth)

			LK3D.PushProcessingMessage("Cloned light \"" .. k .. "\"!")
		end

		-- add emmissive patches as lights
		if DO_EMMISIVEPATCH_LIGHT then
			local patchRegistry = LK3D.Radiosa.GetPatchRegistry()
			local patchCount = #patchRegistry
			for i = 1, patchCount do
				if (i % 2000) == 0 then
					LK3D.PushProcessingMessage("Adding lights to emmisive patches; " .. tostring(i) .. "/" .. tostring(patchCount))
					LK3D.RenderProcessingMessage("[RADIOSA] PreProcess... ", (i / patchCount) * 100)
				end



				local patch = patchRegistry[i]

				local pEmm = LK3D.Radiosa.GetPatchEmission(patch)
				if pEmm[1] == 0 and pEmm[2] == 0 and pEmm[3] == 0 then
					continue
				end

				local pPos = LK3D.Radiosa.GetPatchPos(patch)
				local pNorm = LK3D.Radiosa.GetPatchNormal(patch)

				local lPos = pPos + (pNorm * 0.1)
				local lInt = ((pEmm[1] + pEmm[2] + pEmm[3]) / 3) * EMMISIVEPATCH_LIGHT_MUL
				local lCol = Color(pEmm[1] * EMMISIVEPATCH_COL_MUL, pEmm[2] * EMMISIVEPATCH_COL_MUL, pEmm[3] * EMMISIVEPATCH_COL_MUL)



				LK3D.AddLight("p_emm" .. i, lPos, lInt, lCol, EMMISIVEPATCH_SMOOTH_LIGHT)
			end
		end
	LK3D.PopUniverse()

	return true
end


function solver.CalculateValue(patch, pos, norm)
	LK3D.PushUniverse(univRT)
		local valR, valG, valB = light_mult_at_pos(pos, norm)
	LK3D.PopUniverse()

	--LK3D.DebugUtils.Line(pos, pos + norm, 64, RED)


	return {valR * 255, valG * 255, valB * 255}
end


return solver