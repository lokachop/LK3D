LK3D = LK3D or {}
LK3D.Radiosa = LK3D.Radiosa or {}
-- The main solver, calculates lighting with radiosity algorithm
local solver = {}
solver.MultiPass = true
solver.PassCount = LK3D.Radiosa.RADIOSITY_STEPS

local math = math
local math_floor = math.floor

local render = render
local render_ReadPixel = render.ReadPixel

-- Tweakables
local CAPT_BUFF_SIZE = 64
local LP_ST_SZ = (256)





local patchVisibilityList = {}
local DEBUG_highestVisCount = 0
local EPSILON = 0.01


local function intSnap(int, base)
	local bh = (base * .5)
	return math_floor((int + bh) - ((int + bh) % base))
end

local LP_SZ_INV = 256 / LP_ST_SZ
local LP_MAX_VALUE = 16777216 / LP_ST_SZ



local HP_DMULT = 16
local function packRGB_LP(int)
	--[[
	local b = (int % LP_ST_SZ) * LP_SZ_INV
	local g = math_floor(int / LP_ST_SZ) * LP_SZ_INV
	local r = math_floor(math_floor(int / LP_ST_SZ) / LP_ST_SZ) * LP_SZ_INV
	return intSnap(r, LP_SZ_INV), intSnap(g, LP_SZ_INV), intSnap(b, LP_SZ_INV)
	]]--

	int = int * HP_DMULT
	local r = bit.band(bit.rshift(int, 16), 255)
	local g = bit.band(bit.rshift(int,  8), 255)
	local b = bit.band(bit.rshift(int,  0), 255)

	return r, g, b
end

local function unpackRGB_LP(r, g, b)
	--[[
	local bs1 = intSnap(b, LP_SZ_INV) / LP_SZ_INV
	local bs2 = (intSnap(g, LP_SZ_INV) / LP_SZ_INV) * LP_ST_SZ
	local bs3 = (intSnap(r, LP_SZ_INV) / LP_SZ_INV) * LP_ST_SZ * LP_ST_SZ


	return math_floor(bs1 + bs2 + bs3)
	]]--

	local var = (bit.lshift(r, 16) + bit.lshift(g, 8) + b)

	return math.floor(var / HP_DMULT)
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

	local oldTMSL = render.GetToneMappingScaleLinear()
	render.SetToneMappingScaleLinear(nilToneMappingScale)
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
	render.SetToneMappingScaleLinear(oldTMSL)

	LK3D.SetCamPos(old_pos)
	LK3D.SetCamAng(old_ang)
	LK3D.Debug = old_dbg
end


file.CreateDir("lk3d/radiosa/radiosity/")
local function getVisListUniverseName()
	return string.lower(LK3D.CurrUniv["tag"])
end

local function getVisibilityHash()
	local toLM = LK3D.Radiosa.GetLightmapMarkedObjects()

	local hashBuff = {}
	hashBuff[#hashBuff + 1] = LK3D.Radiosa.LIGHTMAP_TRI_SZ



	for k, v in pairs(toLM) do
		local objPtr = LK3D.CurrUniv["objects"][k]



		local tempModelHash = {}
		tempModelHash[#tempModelHash + 1] = objPtr.mdl
		tempModelHash[#tempModelHash + 1] = "1V(" .. objPtr.pos[1] .. ", " .. objPtr.pos[2] .. ", " .. objPtr.pos[3] .. ")"
		tempModelHash[#tempModelHash + 1] = "2A(" .. objPtr.ang[1] .. ", " .. objPtr.ang[2] .. ", " .. objPtr.ang[3] .. ")"
		tempModelHash[#tempModelHash + 1] = "3V(" .. objPtr.scl[1] .. ", " .. objPtr.scl[2] .. ", " .. objPtr.scl[3] .. ")"

		hashBuff[#hashBuff + 1] = table.concat(tempModelHash, ":")
	end

	return util.SHA256(table.concat(hashBuff, ";"))
end


local function writeVisibility(fPtr, index, vis)
	fPtr:WriteULong(index)

	local visCount = #vis
	fPtr:WriteULong(visCount)
	for i = 1, visCount do
		local struct = vis[i]

		fPtr:WriteULong(struct[1]) -- not space efficient but lets be safe
		fPtr:WriteDouble(struct[2])
	end
end



local function exportPatchVisList()
	local rootDir = "lk3d/radiosa/radiosity/" .. getVisListUniverseName()
	file.CreateDir(rootDir)

	local hashVis = getVisibilityHash()

	local fileName = rootDir .. "/" .. hashVis .. "_pvis.dat"

	local fPtr = file.Open(fileName, "wb", "DATA")
	fPtr:Write("PVIS")

	-- Bad Bad but not realtime
	local visCount = table.Count(patchVisibilityList)
	fPtr:WriteULong(visCount)

	for k, v in pairs(patchVisibilityList) do
		writeVisibility(fPtr, k, v)
	end

	fPtr:Write("DONE")
	fPtr:Close()

end


local function readVisibility(fPtr)
	local index = fPtr:ReadULong()
	patchVisibilityList[index] = {}


	local visCount = fPtr:ReadULong()
	for i = 1, visCount do
		local otherIndex = fPtr:ReadULong()
		local otherVis = fPtr:ReadDouble()

		patchVisibilityList[index][i] = {otherIndex, otherVis}

		otherIndex = nil
		otherVis = nil
	end
end


local function loadPatchVisList()
	patchVisibilityList = {}

	local rootDir = "lk3d/radiosa/radiosity/" .. getVisListUniverseName()
	local hashVis = getVisibilityHash()

	local fileName = rootDir .. "/" .. hashVis .. "_pvis.dat"
	if not file.Exists(fileName, "DATA") then
		return false
	end

	local fPtr = file.Open(fileName, "rb", "DATA")
	local magic = fPtr:Read(4)

	if magic ~= "PVIS" then
		fPtr:Close()

		return false
	end

	local patchCount = fPtr:ReadULong()
	for i = 1, patchCount do
		if i % 1000 == 0 then
			LK3D.PushProcessingMessage("[RADIOSA] Loading patch visibilities from file, " .. tostring(i) .. "/" .. tostring(patchCount))
			LK3D.RenderProcessingMessage("[RADIOSA] PreProcess... ")
		end


		readVisibility(fPtr)
	end


	magic = fPtr:Read(4)
	if magic ~= "DONE" then
		fPtr:Close()
		patchVisibilityList = {}

		return false
	end

	return true
end







local EXCIDENT_DIV = 0
EXCIDENT_DIV = EXCIDENT_DIV + (CAPT_BUFF_SIZE * CAPT_BUFF_SIZE_H)
EXCIDENT_DIV = EXCIDENT_DIV + (CAPT_BUFF_SIZE * CAPT_BUFF_SIZE)
EXCIDENT_DIV = EXCIDENT_DIV + (CAPT_BUFF_SIZE_H * CAPT_BUFF_SIZE)
EXCIDENT_DIV = EXCIDENT_DIV + (CAPT_BUFF_SIZE_H * CAPT_BUFF_SIZE)
EXCIDENT_DIV = EXCIDENT_DIV + (CAPT_BUFF_SIZE * CAPT_BUFF_SIZE_H)

local ACCUM_TOTAL_EXCIDENT = 0
local function addPatchToVisibilityList(visListTemp, srcPatch, addPatch, addPatchIndex)
	if visListTemp[addPatchIndex] then
		return
	end

	local srcPos = srcPatch.pos
	local srcNorm = srcPatch.norm


	local addPos = addPatch.pos
	local addNorm = addPatch.norm

	local dist = srcPos:Distance(addPos) + 1
	local dotVal = math.deg(math.acos(srcNorm:Dot(addNorm))) / 180
	dotVal = math.min(math.max(dotVal, 0), 1)

	--if dotVal > 1 then
	--	LK3D.PushProcessingMessage("DotVal Wrong: " .. tostring(dotVal))
	--	dotVal = 1
	--end

	local energyExcident =  (1 / dist) * dotVal
	ACCUM_TOTAL_EXCIDENT = ACCUM_TOTAL_EXCIDENT + energyExcident

	visListTemp[addPatchIndex] = energyExcident
end

local function pushVisibilityListForPatch(patchIndex, visListTemp)
	patchVisibilityList[patchIndex] = {}
	if #visListTemp > DEBUG_highestVisCount then
		DEBUG_highestVisCount = #visListTemp
	end

	for k, v in pairs(visListTemp) do
		patchVisibilityList[patchIndex][#patchVisibilityList[patchIndex] + 1] = {k, v / EXCIDENT_DIV}

		visListTemp[k] = nil
	end

	ACCUM_TOTAL_EXCIDENT = 0
	visListTemp = nil
end


local function setupPatchVisibility(patch, patchIndex)
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


	local oldTMSL = render.GetToneMappingScaleLinear()
	render.SetToneMappingScaleLinear(nilToneMappingScale)

	-- top
	captItr = (CAPT_BUFF_SIZE * CAPT_BUFF_SIZE_H) - 1
	render.PushRenderTarget(CaptureRT_UP)
		render.CapturePixels()
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
	render.PopRenderTarget()



	-- forward
	captItr = (CAPT_BUFF_SIZE * CAPT_BUFF_SIZE) - 1
	render.PushRenderTarget(CaptureRT_FORWARD)
		render.CapturePixels()
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
	render.PopRenderTarget()



	-- left
	captItr = (CAPT_BUFF_SIZE * CAPT_BUFF_SIZE_H) - 1
	render.PushRenderTarget(CaptureRT_LEFT)
		render.CapturePixels()
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
	render.PopRenderTarget()


	-- right
	captItr = (CAPT_BUFF_SIZE * CAPT_BUFF_SIZE_H) - 1
	render.PushRenderTarget(CaptureRT_RIGHT)
		render.CapturePixels()
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
	render.PopRenderTarget()


	-- bottom
	captItr = (CAPT_BUFF_SIZE * CAPT_BUFF_SIZE_H) - 1
	render.PushRenderTarget(CaptureRT_DOWN)
		render.CapturePixels()
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
	render.PopRenderTarget()

	render.SetToneMappingScaleLinear(oldTMSL)


	-- now push the patch visibility list
	pushVisibilityListForPatch(patchIndex, visListTemp)
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
			render.Clear(0, 0, 0, 255)

			local oW, oH = ScrW(), ScrH()

			local oldTMSL = render.GetToneMappingScaleLinear()
			render.SetToneMappingScaleLinear(nilToneMappingScale)
			local itr = (size * size) - 1
			for i = 0, itr do
				local patchIndex = patchLUT[i]
				if not patchIndex then
					continue
				end

				local r, g, b = packRGB_LP(patchIndex)
				--surface.SetDrawColor(r, g, b)
				--surface.DrawRect(i % size, math_floor(i / size), 1, 1)

				render.SetViewPort(i % size, math_floor(i / size), 1, 1)
				render.Clear(r, g, b, 255)
			end
			render.SetToneMappingScaleLinear(oldTMSL)

			render.SetViewPort(0, 0, oW, oH)
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

	if maxIndex > LP_MAX_VALUE then
		LK3D.PushProcessingMessage("[RADIOSA] Too many patches for LowPatch mode! (" .. maxIndex .. ">" .. LP_MAX_VALUE .. ")")
		LK3D.PushProcessingMessage("[RADIOSA] Enabling HighPatch mode (slower...)")

		DO_HIGH_PATCH = true -- TODO: implement
	end

	preProcessLK3DUniv()
	calcMultiplierTables()
end





local patchesPerItr = 4
local lastPatch = 1
local didSetup = false
local didAttemptToLoad = false
function solver.PreProcess()
	-- attempt to load first
	if not didAttemptToLoad then
		LK3D.PushProcessingMessage("[RADIOSA] Attempting to load visibility list...")
		LK3D.PushProcessingMessage("[RADIOSA] Universe hash is \"" .. getVisibilityHash() .. "\"...")

		local loadedCorrectly = loadPatchVisList()
		if loadedCorrectly then
			LK3D.PushProcessingMessage("[RADIOSA] Loaded visibility list from file...")
			return true -- Cool ! ! We can not do expensive
		end
		didAttemptToLoad = true
	end




	if not didSetup then
		doSetup()

		didSetup = true
	end

	local registry = LK3D.Radiosa.GetPatchRegistry()
	for i = lastPatch, lastPatch + patchesPerItr do
		if i % 1000 == 0 then
			LK3D.PushProcessingMessage("[RADIOSA] Calculating patch visibility, " .. tostring(i) .. "/" .. tostring(#registry))
			LK3D.RenderProcessingMessage("[RADIOSA] PreProcess... ", nil, function()
				renderHemicubeRTsTest(ScrW() - 128, 64)
			end)
		end

		if i % 6000 == 0 then
			LK3D.PushProcessingMessage("[RADIOSA] Collecting garbage...")
			LK3D.RenderProcessingMessage("[RADIOSA] PreProcess... ")
			collectgarbage("collect")
		end



		lastPatch = lastPatch + 1
		local patch = registry[i]

		if not patch then
			break
		end

		setupPatchVisibility(patch, i)
	end

	if lastPatch > #registry then
		LK3D.PushProcessingMessage("[RADIOSA] Done calculating patch visibilities!")

		LK3D.PushProcessingMessage("[RADIOSA] Exporting patch visibility list!")
		exportPatchVisList()



		return true
	end
end

function solver.CalculateValue(patch, pos, norm, index)
	local visibilities = patchVisibilityList[index]
	if not visibilities then
		return
	end

	if patch.emitconstant then
		--patch.excident[1] = patch.emission[1]
		--patch.excident[2] = patch.emission[2]
		--patch.excident[3] = patch.emission[3]

		--patch.incident[1] = patch.emission[1]
		--patch.incident[2] = patch.emission[2]
		--patch.incident[3] = patch.emission[3]
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

local texSz = LK3D.Radiosa.LIGHTMAP_RES
function solver.FinalPass(patch, pos, norm, index, texIndex)
	local xc = texIndex % texSz
	local yc = math_floor(texIndex / texSz)

	local bayerIdx = (xc % 4) + ((yc % 4) * 4) + 1

	local luma = patch.incident
	local bayer = bayer4[bayerIdx]

	local valR = math.min((luma[1] * bMul) + bayer, 255)
	local valG = math.min((luma[2] * bMul) + bayer, 255)
	local valB = math.min((luma[3] * bMul) + bayer, 255)

	return {valR, valG, valB}
end

-- clean up mem garbage here
function solver.Cleanup()
	local itrCount = #patchVisibilityList

	for i = 1, itrCount do
		if i % 2000 == 0 then
			LK3D.PushProcessingMessage("[RADIOSA] Cleaning up visibility table, " .. tostring(i) .. "/" .. tostring(itrCount))
			LK3D.RenderProcessingMessage("[RADIOSA] Cleanup...")
		end

		local visList = patchVisibilityList[i]

		for j = 1, #visList do
			visList[j] = nil
		end

		patchVisibilityList[i] = nil
	end

	patchVisibilityList = {}

	collectgarbage("collect")
end


return solver