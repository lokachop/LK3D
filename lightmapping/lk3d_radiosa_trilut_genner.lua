LK3D = LK3D or {}
LK3D.Radiosa = LK3D.Radiosa or {}

local INSET_AMOUNT = (2048 / LK3D.Radiosa.LIGHTMAP_RES) * 0.0075


local math = math
local math_floor = math.floor
local math_sqrt = math.sqrt
local math_min = math.min
local math_max = math.max

local function getTriCenter(uv1, uv2, uv3)
	local uSum = uv1[1] + uv2[1] + uv3[1]
	local vSum = uv1[2] + uv2[2] + uv3[2]

	return {uSum / 3, vSum / 3}
end


local function lerpNoClamp(t, a, b)
	return a * (1 - t) + b * t
end


local function getInsetUV(uv, center)
	local uDirCalc = uv[1] - center[1]
	local vDirCalc = uv[2] - center[2]

	local len = math.sqrt(uDirCalc * uDirCalc + vDirCalc * vDirCalc)
	uDirCalc = uDirCalc / len
	vDirCalc = vDirCalc / len

	uDirCalc = uDirCalc * INSET_AMOUNT
	vDirCalc = vDirCalc * INSET_AMOUNT


	return {uv[1] + uDirCalc, uv[2] + vDirCalc}
end

-- point inside tri
-- https://stackoverflow.com/questions/2049582/how-to-determine-if-a-point-is-in-a-2d-triangle
local function uv_inside_tri(uv, uv1, uv2, uv3)
	local s = (uv1[1] - uv3[1]) * (uv[2] - uv3[2]) - (uv1[2] - uv3[2]) * (uv[1] - uv3[1])
	local t = (uv2[1] - uv1[1]) * (uv[2] - uv1[2]) - (uv2[2] - uv1[2]) * (uv[1] - uv1[1])

	if ((s < 0) ~= (t < 0) and s ~= 0 and t ~= 0) then
		return false
	end

	local d = (uv3[1] - uv2[1]) * (uv[2] - uv2[2]) - (uv3[2] - uv2[2]) * (uv[1] - uv2[1])


	return d == 0 or (d < 0) == (s + t <= 0)
end




local _v0 = {0, 0}
local _v1 = {0, 0}
local _v2 = {0, 0}

local _d00, _d01, _d11, _d20, _d21 = 0, 0, 0, 0, 0
local function barycentric(px, py, ax, ay, bx, by, cx, cy)
	_v0[1] = bx - ax
	_v0[2] = by - ay

	_v1[1] = cx - ax
	_v1[2] = cy - ay

	_v2[1] = px - ax
	_v2[2] = py - ay

	_d00 = _v0[1] * _v0[1] + _v0[2] * _v0[2]

	_d01 = _v0[1] * _v1[1] + _v0[2] * _v1[2]

	_d11 = _v1[1] * _v1[1] + _v1[2] * _v1[2]

	_d20 = _v2[1] * _v0[1] + _v2[2] * _v0[2]

	_d21 = _v2[1] * _v1[1] + _v2[2] * _v1[2]

	local denom = _d00 * _d11 - _d01 * _d01
	local v = (_d11 * _d20 - _d01 * _d21) / denom
	local w = (_d00 * _d21 - _d01 * _d20) / denom
	local u = 1 - v - w

	return v, w, u
end



local CLAMP_LERP = 0.01
local function clampUV(uv, uv1, uv2, uv3)

	local center = getTriCenter(uv1, uv2, uv3)

	--local uv1_i = getInsetUV(uv1, center)
	--local uv2_i = getInsetUV(uv2, center)
	--local uv3_i = getInsetUV(uv3, center)




	local u, v, w = barycentric(
		uv[1], uv[2],
		uv1[1], uv1[2],
		uv2[1], uv2[2],
		uv3[1], uv3[2]
	)

	local u2, v2, w2 = barycentric(
		center[1], center[2],
		uv1[1], uv1[2],
		uv2[1], uv2[2],
		uv3[1], uv3[2]
	)

	--if len > 1 or len < 0 then
	--	return
	--end


	u = Lerp(CLAMP_LERP, u, u2) --u - CLAMP_MUL
	v = Lerp(CLAMP_LERP, v, v2) --v - CLAMP_MUL
	w = Lerp(CLAMP_LERP, w, w2) --w - CLAMP_MUL


	local uc = (w * uv1[1]) + (u * uv2[1]) + (v * uv3[1])
	local vc = (w * uv1[2]) + (u * uv2[2]) + (v * uv3[2])

	return {uc, vc}
end







local function getTriangleByTexCoord(triList, uv)
	for i = 1, #triList do
		local tri = triList[i]

		local uv1 = tri[1].lm_uv
		local uv2 = tri[2].lm_uv
		local uv3 = tri[3].lm_uv


		local center = getTriCenter(uv1, uv2, uv3)


		--local uv_i = getInsetUV(uv, center)

		local uv1_i = getInsetUV(uv1, center)
		local uv2_i = getInsetUV(uv2, center)
		local uv3_i = getInsetUV(uv3, center)

		--local checkUV = clampUV(uv, uv1, uv2, uv3)
		--if not checkUV then
		--	continue
		--end

		local inside = uv_inside_tri(uv, uv1_i, uv2_i, uv3_i)
		if not inside then
			continue
		end

		return tri
	end
end


local function triUVToWorld(objPtr, tri, uv)
	local v1 = tri[1].pos * 1
	local v2 = tri[2].pos * 1
	local v3 = tri[3].pos * 1

	local objMatrix = objPtr.tmatrix

	v1:Mul(objMatrix)
	v2:Mul(objMatrix)
	v3:Mul(objMatrix)

	local uv1 = tri[1].lm_uv
	local uv2 = tri[2].lm_uv
	local uv3 = tri[3].lm_uv


	local i = 1 / ((uv2[2] - uv1[2]) * (uv3[1] - uv1[1]) - (uv2[1] - uv1[1]) * (uv3[2] - uv1[2]))
	local s = i * ( (uv3[1] - uv1[1]) * (uv[2] - uv1[2]) - (uv3[2] - uv1[2]) * (uv[1] - uv1[1]))
	local t = i * (-(uv2[1] - uv1[1]) * (uv[2] - uv1[2]) + (uv2[2] - uv1[2]) * (uv[1] - uv1[1]))


	local retPos = Vector(
		v1[1] + s * (v2[1] - v1[1]) + t * (v3[1] - v1[1]),
		v1[2] + s * (v2[2] - v1[2]) + t * (v3[2] - v1[2]),
		v1[3] + s * (v2[3] - v1[3]) + t * (v3[3] - v1[3])
	)

	local norm = (v2 - v1):Cross(v3 - v1)
	norm:Normalize()

	return retPos, norm
end


local function getTexUVFromTriCoord(tri, coord)
	local size = LK3D.Radiosa.LIGHTMAP_RES

	local l_uv1 = tri[1].lm_uv
	local l_uv2 = tri[2].lm_uv
	local l_uv3 = tri[3].lm_uv


	local l_u1 = l_uv1[1]
	local l_v1 = l_uv1[2]

	local l_u2 = l_uv2[1]
	local l_v2 = l_uv2[2]

	local l_u3 = l_uv3[1]
	local l_v3 = l_uv3[2]

	--local minU = math_min(l_u1, l_u2, l_u3)
	--local minV = math_min(l_v1, l_v2, l_v3)

	--coord[1] = coord[1] - minU
	--coord[2] = coord[2] - minV

	local u, v, w = barycentric(
		coord[1], coord[2],
		l_u1 * size, l_v1 * size,
		l_u2 * size, l_v2 * size,
		l_u3 * size, l_v3 * size
	)

	local uv1 = tri[1].uv
	local uv2 = tri[2].uv
	local uv3 = tri[3].uv

	local u1 = uv1[1]
	local v1 = uv1[2]

	local u2 = uv2[1]
	local v2 = uv2[2]

	local u3 = uv3[1]
	local v3 = uv3[2]

	local uc = (w * u1) + (u * u2) + (v * u3)
	local vc = (w * v1) + (u * v2) + (v * v3)

	return {uc, vc}
end




local setupTri = nil
local function patchSetup_pushTriangle(tri)
	setupTri = tri
end

local setupObjPtr = nil
local function patchSetup_pushObjectPointer(objPtr)
	setupObjPtr = objPtr
end

local setupObjRGB = {1, 1, 1}
local function patchSetup_pushObjectColour(col)
	setupObjRGB = {col.r / 255, col.g / 255, col.b / 255}
end

local setupTexArray = nil
local setupTexW = nil
local setupTexH = nil
local setupTexEmissive = nil
local function patchSetup_pushObjectTexParams(texArray, tW, tH, tEmissive)
	setupTexArray = texArray
	setupTexW = tW
	setupTexH = tH
	setupTexEmissive = tEmissive
end

local lightmapSize = LK3D.Radiosa.LIGHTMAP_RES
local function setupPatch(patch, xc, yc)
	local uv = {(xc + .5) / lightmapSize, (yc + .5) / lightmapSize}

	local pos, norm = triUVToWorld(setupObjPtr, setupTri, uv)

	LK3D.Radiosa.SetPatchPosition(patch, pos)
	LK3D.Radiosa.SetPatchNormal(patch, norm)


	local uvCoord = getTexUVFromTriCoord(setupTri, {xc, yc})

	local tX = math_min(math_max(math_floor(uvCoord[1] * setupTexW), 0), setupTexW - 1)
	local tY = math_min(math_max(math_floor(uvCoord[2] * setupTexH), 0), setupTexH - 1)

	local texInd = (tX + (tY * setupTexW)) + 1
	local texData = setupTexArray[texInd]

	local normalizedR = (texData[1] / 255) * setupObjRGB[1]
	local normalizedG = (texData[2] / 255) * setupObjRGB[2]
	local normalizedB = (texData[3] / 255) * setupObjRGB[3]

	local normalizedColour = {normalizedR, normalizedG, normalizedB}
	LK3D.Radiosa.SetPatchReflectivity(patch, normalizedColour)

	if setupTexEmissive then
		local emissionColour = {normalizedR * LK3D.Radiosa.EMISSIVE_MUL, normalizedG * LK3D.Radiosa.EMISSIVE_MUL, normalizedB * LK3D.Radiosa.EMISSIVE_MUL}
		LK3D.Radiosa.SetPatchEmission(patch, emissionColour)
		LK3D.Radiosa.SetPatchEmitConstant(patch, true)

		emissionColour = nil
	end

	normalizedColour = nil
end





-- Makes a LUT of which patch each pixel is
-- It also generates those patches in the first place
-- Make sure to call after LK3D.Radiosa.PushLightmapUVsToObject()
function LK3D.Radiosa.GenerateObjectPatchesLUT(obj)
	if not obj then
		return
	end

	if not LK3D.CurrUniv["objects"][obj] then
		return
	end

	local objPtr = LK3D.CurrUniv["objects"][obj]
	patchSetup_pushObjectPointer(objPtr)


	local triList = LK3D.Radiosa.GetTriTable(obj)
	local size = LK3D.Radiosa.LIGHTMAP_RES


	-- Material shit
	-- Emission
	local emissive = objPtr["RADIOSITY_LIT"]

	-- Colour
	local objCol = objPtr.col
	patchSetup_pushObjectColour(objCol)

	-- Texture
	local tex = LK3D.GetTextureByIndex(objPtr.mat).mat
	local tW, tH = tex:Width(), tex:Width()
	local texArray = LK3D.GetTexturePixelArray(objPtr.mat, true)

	patchSetup_pushObjectTexParams(texArray, tW, tH, emissive)

	local patchLUT = {}
	local tempPatchTriangleLUT = {}
	local itr = (size * size) - 1
	for i = 0, itr do
		if (i % 2048) == 0 then
			LK3D.RenderProcessingMessage("[RADIOSA] Generate pixel->patch LUT", (i / itr) * 100)
		end



		local xc = i % size
		local yc = math_floor(i / size)

		local uv = {(xc + .5) / size, (yc + .5) / size}

		local triTarget = getTriangleByTexCoord(triList, uv)
		if not triTarget then
			continue
		end
		patchSetup_pushTriangle(triTarget)

		-- Make the patch
		local patch = LK3D.Radiosa.NewPatch()

		setupPatch(patch, xc, yc)

		patchLUT[i] = LK3D.Radiosa.AddPatchToRegistry(patch)
		tempPatchTriangleLUT[i] = triTarget
	end

	-- postExpand LUT
	local expandItr = 6

	for j = 1, expandItr do
		local expandItrStr = "[" .. j .. "/" .. expandItr .. "]"



		local patchesToAdd = {}
		for i = 0, itr do
			if (i % 2048) == 0 then
				LK3D.RenderProcessingMessage("[RADIOSA] " .. expandItrStr .. " Expand pixel->patch LUT", (i / itr) * 100)
			end

			local xc = i % size
			local yc = math_floor(i / size)

			local ourIndex = xc + (yc * size)


			-- make sure there's no patch already
			local iCheck = xc + (yc * size)
			if patchLUT[iCheck] ~= nil then
				continue
			end

			-- check all of our 8 neighbours, if any of them have a patch, we will add one later

			-- #--
			-- - -
			-- ---
			iCheck = (xc - 1) + ((yc - 1) * size)
			if patchLUT[iCheck] ~= nil then
				patchesToAdd[#patchesToAdd + 1] = {ourIndex, iCheck}
				continue
			end

			-- -#-
			-- - -
			-- ---
			iCheck = xc      + ((yc - 1) * size)
			if patchLUT[iCheck] ~= nil then
				patchesToAdd[#patchesToAdd + 1] = {ourIndex, iCheck}
				continue
			end

			-- --#
			-- - -
			-- ---
			iCheck = (xc + 1) + ((yc - 1) * size)
			if patchLUT[iCheck] ~= nil then
				patchesToAdd[#patchesToAdd + 1] = {ourIndex, iCheck}
				continue
			end

			-- ---
			-- # -
			-- ---
			iCheck = (xc - 1) + (yc * size)
			if patchLUT[iCheck] ~= nil then
				patchesToAdd[#patchesToAdd + 1] = {ourIndex, iCheck}
				continue
			end

			-- ---
			-- - #
			-- ---
			iCheck = (xc + 1) + (yc * size)
			if patchLUT[iCheck] ~= nil then
				patchesToAdd[#patchesToAdd + 1] = {ourIndex, iCheck}
				continue
			end

			-- ---
			-- - -
			-- #--
			iCheck = (xc - 1) + ((yc + 1) * size)
			if patchLUT[iCheck] ~= nil then
				patchesToAdd[#patchesToAdd + 1] = {ourIndex, iCheck}
				continue
			end

			-- ---
			-- - -
			-- -#-
			iCheck = xc + ((yc + 1) * size)
			if patchLUT[iCheck] ~= nil then
				patchesToAdd[#patchesToAdd + 1] = {ourIndex, iCheck}
				continue
			end

			-- ---
			-- - -
			-- --#
			iCheck = (xc - 1) + ((yc + 1) * size)
			if patchLUT[iCheck] ~= nil then
				patchesToAdd[#patchesToAdd + 1] = {ourIndex, iCheck}
				continue
			end
		end


		local patchAddCount = #patchesToAdd
		for i = 1, patchAddCount do
			if (i % 1024) == 0 then
				LK3D.RenderProcessingMessage("[RADIOSA] " .. expandItrStr .. " Adding expanded pixel->patch patches.. ", (i / patchAddCount) * 100)
			end

			local patchToAdd = patchesToAdd[i]



			local patchIndex = patchToAdd[1]
			local patchParent = patchToAdd[2]


			local triParent = tempPatchTriangleLUT[patchParent]
			patchSetup_pushTriangle(triParent)

			local patch = LK3D.Radiosa.NewPatch()

			local xc = patchIndex % size
			local yc = math_floor(patchIndex / size)

			setupPatch(patch, xc, yc)

			patchLUT[patchIndex] = LK3D.Radiosa.AddPatchToRegistry(patch)
			tempPatchTriangleLUT[patchIndex] = triParent
		end
	end


	-- Cleanup
	for i = 1, #tempPatchTriangleLUT do
		tempPatchTriangleLUT[i] = nil
	end
	tempPatchTriangleLUT = nil

	return patchLUT
end