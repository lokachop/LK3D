LK3D = LK3D or {}
LK3D.Radiosa = LK3D.Radiosa or {}
-- The main solver, calculates lighting with radiosity algorithm
local solver = {}
solver.MultiPass = true
solver.PassCount = LK3D.Radiosa.RADIOSITY_STEPS

local math = math
local math_floor = math.floor
local math_exp = math.exp
local math_min = math.min
local math_max = math.max
local math_deg = math.deg
local math_acos = math.acos


local bit = bit
local bit_band = bit.band
local bit_rshift = bit.rshift
local bit_lshift = bit.lshift

local render = render
local render_CapturePixels = render.CapturePixels
local render_ReadPixel = render.ReadPixel
local render_PushRenderTarget = render.PushRenderTarget
local render_PopRenderTarget = render.PopRenderTarget
local render_GetToneMappingScaleLinear = render.GetToneMappingScaleLinear
local render_SetToneMappingScaleLinear = render.SetToneMappingScaleLinear
local render_SetViewPort = render.SetViewPort
local render_Clear = render.Clear



-- Tweakables
local CAPT_BUFF_SIZE = LK3D.Radiosa.RADIOSITY_BUFFER_SZ

local DEBUG_highestVisCount = 0

local MAX_RGB = 16777216



local HP_DMULT = 16
local function packRGB_LP(int)
	int = int * HP_DMULT
	local r = int / 65536 % 256
	local g = int / 256 % 256
	local b = int % 256

	return r, g, b
end

local function unpackRGB_LP(r, g, b)
	local var = (r * 65536 + g * 256 + b)

	return math_floor(var / HP_DMULT)
end

local CAPT_BUFF_SIZE_H = CAPT_BUFF_SIZE * .5

local univVisibility = LK3D.NewUniverse("lk3d_radiosa_radiosity_universe_visibility")

local RT_sizeMode = RT_SIZE_DEFAULT
local RT_depthMode = MATERIAL_RT_DEPTH_SEPARATE
local RT_texFlags = bit.bor(1, 256)
local RT_rtFlags = CREATERENDERTARGETFLAGS_UNFILTERABLE_OK
local RT_imageFormat = IMAGE_FORMAT_RGBA8888

local RT_debugIdentifier = "pass5"

local bSize = CAPT_BUFF_SIZE







local CaptureRT_UP =        GetRenderTargetEx("lk3d_radiosity_buffer_up_" .. bSize .. RT_debugIdentifier, bSize, bSize, RT_sizeMode, RT_depthMode, RT_texFlags, RT_rtFlags, RT_imageFormat)
local CaptureRT_FORWARD =   GetRenderTargetEx("lk3d_radiosity_buffer_fw_" .. bSize .. RT_debugIdentifier, bSize, bSize, RT_sizeMode, RT_depthMode, RT_texFlags, RT_rtFlags, RT_imageFormat)
local CaptureRT_LEFT =      GetRenderTargetEx("lk3d_radiosity_buffer_le_" .. bSize .. RT_debugIdentifier, bSize, bSize, RT_sizeMode, RT_depthMode, RT_texFlags, RT_rtFlags, RT_imageFormat)
local CaptureRT_RIGHT =     GetRenderTargetEx("lk3d_radiosity_buffer_ri_" .. bSize .. RT_debugIdentifier, bSize, bSize, RT_sizeMode, RT_depthMode, RT_texFlags, RT_rtFlags, RT_imageFormat)
local CaptureRT_DOWN =      GetRenderTargetEx("lk3d_radiosity_buffer_dw_" .. bSize .. RT_debugIdentifier, bSize, bSize, RT_sizeMode, RT_depthMode, RT_texFlags, RT_rtFlags, RT_imageFormat)


local function renderHemicubeRTsTest(x, y)
	local rtSz = 64
	render.DrawTextureToScreenRect(CaptureRT_UP, x       , y - rtSz, rtSz, rtSz)
	render.DrawTextureToScreenRect(CaptureRT_FORWARD, x       , y       , rtSz, rtSz)
	render.DrawTextureToScreenRect(CaptureRT_LEFT, x - rtSz, y       , rtSz, rtSz)
	render.DrawTextureToScreenRect(CaptureRT_RIGHT, x + rtSz, y       , rtSz, rtSz)
	render.DrawTextureToScreenRect(CaptureRT_DOWN, x       , y + rtSz, rtSz, rtSz)
end


local nilToneMappingScale = Vector(1, 1, 1)
local function renderHemicube(pos, dir)
	local old_pos, old_ang = LK3D.CamPos, LK3D.CamAng
	local old_dbg = LK3D.Debug

	LK3D.Debug = false

	LK3D.SetCamPos(pos)
	LK3D.SetCamFOV(LK3D.RADIOSITY_FOV)

	local oldTMSL = render_GetToneMappingScaleLinear()
	render_SetToneMappingScaleLinear(nilToneMappingScale)
		-- up
		LK3D.PushRenderTarget(CaptureRT_UP)
			LK3D.RenderClear(0, 0, 0)
			local mat_up = Matrix()
			mat_up:SetAngles(dir:Angle())
			mat_up:Rotate(Angle(-90, 0, 0))

			LK3D.SetCamAng(mat_up:GetAngles())
			LK3D.RenderActiveUniverse()
		LK3D.PopRenderTarget()

		-- forward
		LK3D.PushRenderTarget(CaptureRT_FORWARD)
			LK3D.RenderClear(0, 0, 0)
			LK3D.SetCamAng(dir:Angle())
			LK3D.RenderActiveUniverse()
		LK3D.PopRenderTarget()

		-- left
		LK3D.PushRenderTarget(CaptureRT_LEFT)
			LK3D.RenderClear(0, 0, 0)
			local mat_le = Matrix()
			mat_le:SetAngles(dir:Angle())
			mat_le:Rotate(Angle(0, 90, 0))

			LK3D.SetCamAng(mat_le:GetAngles())
			LK3D.RenderActiveUniverse()
		LK3D.PopRenderTarget()

		-- right
		LK3D.PushRenderTarget(CaptureRT_RIGHT)
			LK3D.RenderClear(0, 0, 0)
			local mat_ri = Matrix()
			mat_ri:SetAngles(dir:Angle())
			mat_ri:Rotate(Angle(0, -90, 0))

			LK3D.SetCamAng(mat_ri:GetAngles())
			LK3D.RenderActiveUniverse()
		LK3D.PopRenderTarget()

		-- down
		LK3D.PushRenderTarget(CaptureRT_DOWN)
			LK3D.RenderClear(0, 0, 0)
			local mat_dw = Matrix()
			mat_dw:SetAngles(dir:Angle())
			mat_dw:Rotate(Angle(90, 0, 0))

			LK3D.SetCamAng(mat_dw:GetAngles())
			LK3D.RenderActiveUniverse()
		LK3D.PopRenderTarget()
		render_SetToneMappingScaleLinear(oldTMSL)

	LK3D.SetCamPos(old_pos)
	LK3D.SetCamAng(old_ang)
	LK3D.Debug = old_dbg
end

local EXCIDENT_DIV = 0
EXCIDENT_DIV = EXCIDENT_DIV + (CAPT_BUFF_SIZE * CAPT_BUFF_SIZE_H)
EXCIDENT_DIV = EXCIDENT_DIV + (CAPT_BUFF_SIZE * CAPT_BUFF_SIZE)
EXCIDENT_DIV = EXCIDENT_DIV + (CAPT_BUFF_SIZE_H * CAPT_BUFF_SIZE)
EXCIDENT_DIV = EXCIDENT_DIV + (CAPT_BUFF_SIZE_H * CAPT_BUFF_SIZE)
EXCIDENT_DIV = EXCIDENT_DIV + (CAPT_BUFF_SIZE * CAPT_BUFF_SIZE_H)

local ACCUM_TOTAL_EXCIDENT = 0
local function addPatchToVisibilityList(visListTemp, srcPatch, addPatch, addPatchIndex)
	--local srcPos = srcPatch.pos
	local srcNorm = srcPatch.norm


	--local addPos = addPatch.pos
	local addNorm = addPatch.norm

	--local dist = srcPos:Distance(addPos) + 1
	local dotVal = math_deg(math_acos(srcNorm:Dot(addNorm))) / 180
	dotVal = math_min(math_max(dotVal, 0), 1)

	if dotVal > 1 then
		LK3D.PushProcessingMessage("DotVal Wrong: " .. tostring(dotVal))
		dotVal = 1
	end

	local energyExcident = dotVal
	ACCUM_TOTAL_EXCIDENT = ACCUM_TOTAL_EXCIDENT + energyExcident

	if visListTemp[addPatchIndex] then
		visListTemp[addPatchIndex] = visListTemp[addPatchIndex] + energyExcident
	end

	visListTemp[addPatchIndex] = energyExcident
end

local function getFinalizedVisibility(visListTemp)
	local ret = {}
	if #visListTemp > DEBUG_highestVisCount then
		DEBUG_highestVisCount = #visListTemp
	end

	for k, v in pairs(visListTemp) do
		ret[#ret + 1] = {k, v / EXCIDENT_DIV}

		visListTemp[k] = nil
	end

	ACCUM_TOTAL_EXCIDENT = 0
	visListTemp = nil

	return ret
end


local function getPatchVisibility(patch)
	local patchRegistry = LK3D.Radiosa.GetPatchRegistry()

	local visListTemp = {}

	local pos = LK3D.Radiosa.GetPatchPos(patch)
	local norm = LK3D.Radiosa.GetPatchNormal(patch)

	LK3D.PushUniverse(univVisibility)
		renderHemicube(pos, norm)
	LK3D.PopUniverse()

	-- capture buffers
	local captItr = 0
	local r, g, b = 0, 0, 0
	local indexGet = 0
	local patchGet = nil

	local xc = 0
	local yc = 0


	local oldTMSL = render_GetToneMappingScaleLinear()
	render_SetToneMappingScaleLinear(nilToneMappingScale)

	-- top
	captItr = (CAPT_BUFF_SIZE * CAPT_BUFF_SIZE_H) - 1
	render_PushRenderTarget(CaptureRT_UP)
		render_CapturePixels()
		for i = 0, captItr do
			xc = i % CAPT_BUFF_SIZE
			yc = CAPT_BUFF_SIZE_H + math_floor(i / CAPT_BUFF_SIZE)

			r, g, b = render_ReadPixel(xc, yc)
			indexGet = unpackRGB_LP(r, g, b)
			patchGet = patchRegistry[indexGet]
			if not patchGet then
				if indexGet ~= 0 then
					LK3D.PushProcessingMessage("NoPatchGet for Index #" .. indexGet)
				end
				continue
			end

			addPatchToVisibilityList(visListTemp, patch, patchGet, indexGet)
		end
	render_PopRenderTarget()



	-- forward
	captItr = (CAPT_BUFF_SIZE * CAPT_BUFF_SIZE) - 1
	render_PushRenderTarget(CaptureRT_FORWARD)
		render_CapturePixels()
		for i = 0, captItr do
			xc = i % CAPT_BUFF_SIZE
			yc = math_floor(i / CAPT_BUFF_SIZE)

			r, g, b = render_ReadPixel(xc, yc)
			indexGet = unpackRGB_LP(r, g, b)
			patchGet = patchRegistry[indexGet]
			if not patchGet then
				if indexGet ~= 0 then
					LK3D.PushProcessingMessage("NoPatchGet for Index #" .. indexGet)
				end
				continue
			end

			addPatchToVisibilityList(visListTemp, patch, patchGet, indexGet)
		end
	render_PopRenderTarget()



	-- left
	captItr = (CAPT_BUFF_SIZE * CAPT_BUFF_SIZE_H) - 1
	render_PushRenderTarget(CaptureRT_LEFT)
		render_CapturePixels()
		for i = 0, captItr do
			xc = CAPT_BUFF_SIZE_H + (i % CAPT_BUFF_SIZE_H)
			yc = math_floor(i / CAPT_BUFF_SIZE_H)

			r, g, b = render_ReadPixel(xc, yc)
			indexGet = unpackRGB_LP(r, g, b)
			patchGet = patchRegistry[indexGet]
			if not patchGet then
				if indexGet ~= 0 then
					LK3D.PushProcessingMessage("NoPatchGet for Index #" .. indexGet)
				end
				continue
			end

			addPatchToVisibilityList(visListTemp, patch, patchGet, indexGet)
		end
	render_PopRenderTarget()


	-- right
	captItr = (CAPT_BUFF_SIZE * CAPT_BUFF_SIZE_H) - 1
	render_PushRenderTarget(CaptureRT_RIGHT)
		render_CapturePixels()
		for i = 0, captItr do
			xc = (i % CAPT_BUFF_SIZE_H)
			yc = math_floor(i / CAPT_BUFF_SIZE_H)

			r, g, b = render_ReadPixel(xc, yc)
			indexGet = unpackRGB_LP(r, g, b)
			patchGet = patchRegistry[indexGet]
			if not patchGet then
				if indexGet ~= 0 then
					LK3D.PushProcessingMessage("NoPatchGet for Index #" .. indexGet)
				end
				continue
			end

			addPatchToVisibilityList(visListTemp, patch, patchGet, indexGet)
		end
	render_PopRenderTarget()


	-- bottom
	captItr = (CAPT_BUFF_SIZE * CAPT_BUFF_SIZE_H) - 1
	render_PushRenderTarget(CaptureRT_DOWN)
		render_CapturePixels()
		for i = 0, captItr do
			xc = i % CAPT_BUFF_SIZE
			yc = math_floor(i / CAPT_BUFF_SIZE)

			r, g, b = render_ReadPixel(xc, yc)
			indexGet = unpackRGB_LP(r, g, b)
			patchGet = patchRegistry[indexGet]
			if not patchGet then
				if indexGet ~= 0 then
					LK3D.PushProcessingMessage("NoPatchGet for Index #" .. indexGet)
				end
				continue
			end

			addPatchToVisibilityList(visListTemp, patch, patchGet, indexGet)
		end
	render_PopRenderTarget()

	render_SetToneMappingScaleLinear(oldTMSL)

	-- now return the patch visibility
	return getFinalizedVisibility(visListTemp)


	-- now push the patch visibility list
	--pushVisibilityListForPatch(patchIndex, visListTemp)
end





local DO_HIGH_PATCH = false
local function setupCloneObject(tag, objData)
	LK3D.PushProcessingMessage("[RADIOSA] Cloning object \"" .. tag .. "\"...")


	local tag_1 = tag .. "_clone"
	LK3D.AddObjectToUniverse(tag_1, objData.mdl)
	LK3D.SetObjectPos(tag_1, objData.pos)
	LK3D.SetObjectAng(tag_1, objData.ang)
	LK3D.SetObjectScale(tag_1, objData.scl)

	LK3D.SetObjectFlag(tag_1, "NO_SHADING", true)
	LK3D.SetObjectFlag(tag_1, "NO_LIGHTING", true)
	LK3D.SetObjectFlag(tag_1, "CONSTANT", true)


	-- make a material with its patches
	local size = LK3D.Radiosa.LIGHTMAP_RES
	local patchLUT = LK3D.Radiosa.GetPatchLUTForObject(tag)
	if patchLUT then
		local texTag = LK3D.CurrUniv["tag"] .. "_" .. tag .. "_patchMap_" .. size
		LK3D.DeclareTextureFromFunc(texTag, size, size, function()
			render_Clear(0, 0, 0, 255)

			local oW, oH = ScrW(), ScrH()

			local oldTMSL = render_GetToneMappingScaleLinear()
			render_SetToneMappingScaleLinear(nilToneMappingScale)
			local itr = (size * size) - 1
			for i = 0, itr do
				local patchIndex = patchLUT[i]
				if not patchIndex then
					continue
				end

				local r, g, b = packRGB_LP(patchIndex)
				--surface.SetDrawColor(r, g, b)
				--surface.DrawRect(i % size, math_floor(i / size), 1, 1)

				render_SetViewPort(i % size, math_floor(i / size), 1, 1)
				render_Clear(r, g, b, 255)
			end
			render_SetToneMappingScaleLinear(oldTMSL)

			render_SetViewPort(0, 0, oW, oH)
		end)

		LK3D.SetObjectFlag(tag_1, "lightmap_uvs", objData.lightmap_uvs)
		LK3D.SetObjectFlag(tag_1, "UV_USE_LIGHTMAP", true)
		LK3D.SetObjectMat(tag_1, texTag)
	else
		LK3D.SetObjectMat(tag_1, "white")
		LK3D.SetObjectCol(tag_1, Color(0, 0, 0))
	end


	local tag_2 = tag .. "_clone_inv"
	LK3D.AddObjectToUniverse(tag_2, objData.mdl)
	LK3D.SetObjectPos(tag_2, objData.pos)
	LK3D.SetObjectAng(tag_2, objData.ang)
	LK3D.SetObjectScale(tag_2, objData.scl)

	LK3D.SetObjectFlag(tag_2, "NO_SHADING", true)
	LK3D.SetObjectFlag(tag_2, "NO_LIGHTING", true)
	LK3D.SetObjectFlag(tag_2, "CONSTANT", true)

	LK3D.SetObjectMat(tag_2, "white")
	LK3D.SetObjectCol(tag_2, Color(0, 0, 0))
	LK3D.SetObjectFlag(tag_2, "NORM_INVERT", true)
end

local function preProcessLK3DUniv()
	LK3D.PushProcessingMessage("Setting up universe visibility clone...")
	local objs = LK3D.GetUniverseObjects()

	LK3D.PushUniverse(univVisibility)
		for k, v in pairs(objs) do
			setupCloneObject(k, v)
		end
	LK3D.PopUniverse()
end



local function doSetup()
	local maxIndex = #LK3D.Radiosa.GetPatchRegistry()

	if maxIndex > MAX_RGB then
		LK3D.PushProcessingMessage("[RADIOSA] Too many patches for LowPatch mode! (" .. maxIndex .. ">" .. MAX_RGB .. ")")
		LK3D.PushProcessingMessage("[RADIOSA] Enabling HighPatch mode (slower...)")

		DO_HIGH_PATCH = true -- TODO: implement
	end

	preProcessLK3DUniv()
	--calcMultiplierTables()
end





function solver.PreProcess()
	doSetup()
	return true
end


--[[
-- emmissive-shoot method
-- seems broken?
function solver.CalculateValue(patch, pos, norm, index)
	local exciSelf = patch.excident
	if exciSelf[1] == 0 and exciSelf[2] == 0 and exciSelf[3] == 0 then
		return
	end

	local visibilities = getPatchVisibility(patch)
	if not visibilities then
		LK3D.PushProcessingMessage("[RADIOSA] No visibilities for patch, WRONG!")
		return
	end

	if #visibilities == 0 then
		return
	end



	local registry = LK3D.Radiosa.GetPatchRegistry()
	for i = 1, #visibilities do
		local struct = visibilities[i]
		local otherPatchIndex = struct[1]
		local otherPatch = registry[otherPatchIndex]
		if not otherPatch then
			continue
		end

		local giveAmount = struct[2]

		otherPatch.incident[1] = otherPatch.incident[1] + (exciSelf[1] * giveAmount)
		otherPatch.incident[2] = otherPatch.incident[2] + (exciSelf[2] * giveAmount)
		otherPatch.incident[3] = otherPatch.incident[3] + (exciSelf[3] * giveAmount)
	end


	visibilities = nil
end
]]--


-- emmissive-gather method
-- slower but works
function solver.CalculateValue(patch, pos, norm, index)
	local visibilities = getPatchVisibility(patch)
	if not visibilities then
		LK3D.PushProcessingMessage("[RADIOSA] No visibilities for patch, WRONG!")
		return
	end

	if #visibilities == 0 then
		patch.incident[1] = 0
		patch.incident[2] = 0
		patch.incident[3] = 0
		return
	end

	-- emit out emmision out to others
	local registry = LK3D.Radiosa.GetPatchRegistry()

	for i = 1, #visibilities do
		local struct = visibilities[i]
		local otherPatchIndex = struct[1]
		local otherPatch = registry[otherPatchIndex]
		if not otherPatch then
			continue
		end

		local exciOther = otherPatch.excident
		if exciOther[1] == 0 and exciOther[2] == 0 and exciOther[3] == 0 then
			continue
		end

		local giveAmount = struct[2]

		patch.incident[1] = patch.incident[1] + (exciOther[1] * giveAmount)
		patch.incident[2] = patch.incident[2] + (exciOther[2] * giveAmount)
		patch.incident[3] = patch.incident[3] + (exciOther[3] * giveAmount)
	end
end

function solver.CalculateAfterIteration(patch, pos, norm, index)
	patch.excident[1] = (patch.incident[1] * 1) * patch.reflectivity[1]
	patch.excident[2] = (patch.incident[2] * 1) * patch.reflectivity[2]
	patch.excident[3] = (patch.incident[3] * 1) * patch.reflectivity[3]
end


local bMul = LK3D.Radiosa.BRIGHTNESS_MUL

local bayer4 = {
	 0 / 16,  8 / 16,  1 / 16,  9 / 16,
	12 / 16,  4 / 16, 13 / 16,  5 / 16,
	 3 / 16, 11 / 16,  2 / 16, 10 / 16,
	15 / 16,  7 / 16, 14 / 16,  6 / 16,
}


local _e = 2.718281828
local texSz = LK3D.Radiosa.LIGHTMAP_RES
local bIntensity = LK3D.Radiosa.BRIGHTNESS_INTENSITY
function solver.FinalPass(patch, pos, norm, index, texIndex)
	local xc = texIndex % texSz
	local yc = math_floor(texIndex / texSz)

	local bayerIdx = (xc % 4) + ((yc % 4) * 4) + 1

	local luma = patch.incident
	local bayer = bayer4[bayerIdx] * .5


	local brR = 1 - math_exp(-(luma[1] * bIntensity))
	local brG = 1 - math_exp(-(luma[2] * bIntensity))
	local brB = 1 - math_exp(-(luma[3] * bIntensity))

	local valR = math_min((brR * bMul) + bayer, 255)
	local valG = math_min((brG * bMul) + bayer, 255)
	local valB = math_min((brB * bMul) + bayer, 255)
	return {valR, valG, valB}
end

-- clean up mem garbage here
function solver.Cleanup()
	collectgarbage("collect")
end


return solver