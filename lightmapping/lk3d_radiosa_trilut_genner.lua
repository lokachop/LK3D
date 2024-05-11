LK3D = LK3D or {}
LK3D.Radiosa = LK3D.Radiosa or {}

local INSET_AMOUNT = (2048 / LK3D.Radiosa.LIGHTMAP_RES) * 0.006


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

local function getInsetUV(uv, center)
	local uDirCalc = uv[1] - center[1]
	local vDirCalc = uv[2] - center[2]

	local len = math_sqrt(uDirCalc * uDirCalc + vDirCalc * vDirCalc)
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


local function getTriangleByTexCoord(triList, uv)
	for i = 1, #triList do
		local tri = triList[i]

		local uv1 = tri[1].lm_uv
		local uv2 = tri[2].lm_uv
		local uv3 = tri[3].lm_uv


		local center = getTriCenter(uv1, uv2, uv3)

		local uv1_i = getInsetUV(uv1, center)
		local uv2_i = getInsetUV(uv2, center)
		local uv3_i = getInsetUV(uv3, center)

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

	local center = getTriCenter(uv1, uv2, uv3)

	local uv1_i = getInsetUV(uv1, center)
	local uv2_i = getInsetUV(uv2, center)
	local uv3_i = getInsetUV(uv3, center)


	local i = 1 / ((uv2_i[2] - uv1_i[2]) * (uv3_i[1] - uv1_i[1]) - (uv2_i[1] - uv1_i[1]) * (uv3_i[2] - uv1_i[2]))
	local s = i * ( (uv3_i[1] - uv1_i[1]) * (uv[2] - uv1_i[2]) - (uv3_i[2] - uv1_i[2]) * (uv[1] - uv1_i[1]))
	local t = i * (-(uv2_i[1] - uv1_i[1]) * (uv[2] - uv1_i[2]) + (uv2_i[2] - uv1_i[2]) * (uv[1] - uv1_i[1]))


	local retPos = Vector(
		v1[1] + s * (v2[1] - v1[1]) + t * (v3[1] - v1[1]),
		v1[2] + s * (v2[2] - v1[2]) + t * (v3[2] - v1[2]),
		v1[3] + s * (v2[3] - v1[3]) + t * (v3[3] - v1[3])
	)

	local norm = (v2 - v1):Cross(v3 - v1)
	norm:Normalize()

	return retPos, norm
end


local function barycentric(px, py, ax, ay, bx, by, cx, cy)
	local v0 = Vector(bx - ax, by - ay)
	local v1 = Vector(cx - ax, cy - ay)
	local v2 = Vector(px - ax, py - ay)

	local d00 = v0:Dot(v0)
	local d01 = v0:Dot(v1)
	local d11 = v1:Dot(v1)
	local d20 = v2:Dot(v0)
	local d21 = v2:Dot(v1)

	local denom = d00 * d11 - d01 * d01
	local v = (d11 * d20 - d01 * d21) / denom
	local w = (d00 * d21 - d01 * d20) / denom
	local u = 1 - v - w

	return v, w, u
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

	local triList = LK3D.Radiosa.GetTriTable(obj)
	local size = LK3D.Radiosa.LIGHTMAP_RES


	-- Material shit
	-- Emission
	local emissive = objPtr["RADIOSITY_LIT"]

	-- Colour
	local objCol = objPtr.col
	local colR, colG, colB = objCol:Unpack()
	colR = colR / 255
	colG = colG / 255
	colB = colB / 255

	-- Texture
	local tex = LK3D.GetTextureByIndex(objPtr.mat).mat
	local tW, tH = tex:Width(), tex:Width()
	local texArray = LK3D.GetTexturePixelArray(objPtr.mat, true)


	local patchLUT = {}
	local itr = (size * size) - 1
	for i = 0, itr do
		if (i % 2048) == 0 then
			LK3D.RenderProcessingMessage("[RADIOSA] Generate pixel->patch LUT", (i / itr) * 100)
		end



		local xc = i % size
		local yc = math_floor(i / size)

		local uv = {xc / size, yc / size}

		local triTarget = getTriangleByTexCoord(triList, uv)
		if not triTarget then
			continue
		end


		local pos, norm = triUVToWorld(objPtr, triTarget, uv)

		-- Make the patch
		local patch = LK3D.Radiosa.NewPatch()

		-- Position/normal setup
		LK3D.Radiosa.SetPatchPosition(patch, pos)
		LK3D.Radiosa.SetPatchNormal(patch, norm)

		-- The patch should inherit the reflectivity as the texture value
		-- so there's a bit of complicated setup


		local uvCoord = getTexUVFromTriCoord(triTarget, {xc, yc})
		--PrintTable(uvCoord)

		local tX = math_min(math_max(math_floor(uvCoord[1] * tW), 0), tW - 1)
		local tY = math_min(math_max(math_floor(uvCoord[2] * tH), 0), tH - 1)

		local texInd = (tX + (tY * tW)) + 1
		local texData = texArray[texInd]

		local normalizedR = (texData[1] / 255) * colR
		local normalizedG = (texData[2] / 255) * colG
		local normalizedB = (texData[3] / 255) * colB

		local normalizedColour = {normalizedR, normalizedG, normalizedB}
		LK3D.Radiosa.SetPatchReflectivity(patch, normalizedColour)

		if emissive then
			LK3D.Radiosa.SetPatchEmission(patch, normalizedColour)
		end

		patchLUT[i] = LK3D.Radiosa.AddPatchToRegistry(patch)
	end

	return patchLUT
end