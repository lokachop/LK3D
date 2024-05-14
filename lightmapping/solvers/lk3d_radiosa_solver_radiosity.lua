LK3D = LK3D or {}
LK3D.Radiosa = LK3D.Radiosa or {}
-- The main solver, calculates lighting with radiosity algorithm

local math = math
local math_floor = math.floor

local render = render
local render_ReadPixel = render.ReadPixel


local function intSnap(int, base)
	local bh = (base * .5)
	return math_floor((int + bh) - ((int + bh) % base))
end

local LP_ST_SZ = 16
local LP_SZ_INV = 256 / LP_ST_SZ
local LP_MAX_VALUE = 16777216 / LP_ST_SZ
local function packRGB_LP(int)
	local b = (int % LP_ST_SZ) * LP_SZ_INV
	local g = math_floor(int / LP_ST_SZ) * LP_SZ_INV
	local r = math_floor(math_floor(int / LP_ST_SZ) / LP_ST_SZ) * LP_SZ_INV
	return intSnap(r, LP_SZ_INV), intSnap(g, LP_SZ_INV), intSnap(b, LP_SZ_INV)
end

local function unpackRGB_LP(r, g, b)
	local bs1 = intSnap(b, LP_SZ_INV) / LP_SZ_INV
	local bs2 = (intSnap(g, LP_SZ_INV) / LP_SZ_INV) * LP_ST_SZ
	local bs3 = (intSnap(r, LP_SZ_INV) / LP_SZ_INV) * LP_ST_SZ * LP_ST_SZ
	return math_floor(bs1 + bs2 + bs3)
end



local solver = {}
solver.MultiPass = true
solver.PassCount = LK3D.Radiosa.RADIOSITY_STEPS

local CAPT_BUFF_SIZE = 8
local CAPT_BUFF_SIZE_H = CAPT_BUFF_SIZE * .5


local univVisibility = LK3D.NewUniverse("lk3d_radiosa_radiosity_universe_visibility")

local CaptureRT_UP =        GetRenderTarget("lk3d_radiosity_buffer_up_" .. CAPT_BUFF_SIZE, CAPT_BUFF_SIZE, CAPT_BUFF_SIZE)
local CaptureRT_FORWARD =   GetRenderTarget("lk3d_radiosity_buffer_fw_" .. CAPT_BUFF_SIZE, CAPT_BUFF_SIZE, CAPT_BUFF_SIZE)
local CaptureRT_LEFT =      GetRenderTarget("lk3d_radiosity_buffer_le_" .. CAPT_BUFF_SIZE, CAPT_BUFF_SIZE, CAPT_BUFF_SIZE)
local CaptureRT_RIGHT =     GetRenderTarget("lk3d_radiosity_buffer_ri_" .. CAPT_BUFF_SIZE, CAPT_BUFF_SIZE, CAPT_BUFF_SIZE)
local CaptureRT_DOWN =      GetRenderTarget("lk3d_radiosity_buffer_dw_" .. CAPT_BUFF_SIZE, CAPT_BUFF_SIZE, CAPT_BUFF_SIZE)


local function renderHemicubeRTsTest(x, y)
	local rtSz = 64
	render.DrawTextureToScreenRect(CaptureRT_UP, x       , y - rtSz, rtSz, rtSz)
	render.DrawTextureToScreenRect(CaptureRT_FORWARD, x       , y       , rtSz, rtSz)
	render.DrawTextureToScreenRect(CaptureRT_LEFT, x - rtSz, y       , rtSz, rtSz)
	render.DrawTextureToScreenRect(CaptureRT_RIGHT, x + rtSz, y       , rtSz, rtSz)
	render.DrawTextureToScreenRect(CaptureRT_DOWN, x       , y + rtSz, rtSz, rtSz)
end

local function renderHemicube(pos, dir)
	local old_pos, old_ang = LK3D.CamPos, LK3D.CamAng
	local old_dbg = LK3D.Debug

	LK3D.Debug = false

	LK3D.SetCamPos(pos)
	LK3D.SetCamFOV(LK3D.RADIOSITY_FOV)

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

	LK3D.SetCamPos(old_pos)
	LK3D.SetCamAng(old_ang)
	LK3D.Debug = old_dbg
end


local patchVisibilityList = {}
local DEBUG_highestVisCount = 0
local EPSILON = 0.01

local ACCUM_TOTAL_EXCIDENT = 0
local function addPatchToVisibilityList(visListTemp, srcPatch, addPatch, addPatchIndex)
	local srcPos = srcPatch.pos
	local srcNorm = srcPatch.norm


	local addPos = addPatch.pos
	local addNorm = addPatch.norm

	local dist = srcPos:Distance(addPos)
	local dotVal = srcNorm:Dot(addNorm)



	local energyExcident =  (1 / dist) * (-dotVal)
	ACCUM_TOTAL_EXCIDENT = ACCUM_TOTAL_EXCIDENT + energyExcident

	visListTemp[#visListTemp + 1] = {addPatchIndex, energyExcident}
end

local function pushVisibilityListForPatch(patchIndex, visListTemp)
	patchVisibilityList[patchIndex] = {}
	if #visListTemp > DEBUG_highestVisCount then
		DEBUG_highestVisCount = #visListTemp
	end

	for i = 1, #visListTemp do
		local struct = visListTemp[i]

		patchVisibilityList[patchIndex][#patchVisibilityList[patchIndex] + 1] = {struct[1], struct[2] / ACCUM_TOTAL_EXCIDENT}

		visListTemp[i] = nil
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
		renderHemicube(pos + (norm * EPSILON), norm)
	LK3D.PopUniverse()

	-- capture buffers
	local captItr = 0
	local r, g, b = 0, 0, 0
	local indexGet = 0
	local patchGet = nil

	local xc = 0
	local yc = 0


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
				continue
			end

			addPatchToVisibilityList(visListTemp, patch, patchGet, indexGet)
		end
	render.PopRenderTarget()


	-- bottom
	captItr = (CAPT_BUFF_SIZE * CAPT_BUFF_SIZE_H) - 1
	render.PushRenderTarget(CaptureRT_UP)
		render.CapturePixels()
		for i = 0, captItr do
			xc = i % CAPT_BUFF_SIZE
			yc = math_floor(i / CAPT_BUFF_SIZE)

			r, g, b = render_ReadPixel(xc, yc)
			indexGet = unpackRGB_LP(r, g, b)
			patchGet = patchRegistry[indexGet]
			if not patchGet then
				continue
			end

			addPatchToVisibilityList(visListTemp, patch, patchGet, indexGet)
		end
	render.PopRenderTarget()


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

			local itr = (size * size) - 1
			for i = 0, itr do
				local patchIndex = patchLUT[i]
				if not patchIndex then
					continue
				end

				local r, g, b = packRGB_LP(patchIndex)
				render.SetViewPort(i % size, math_floor(i / size), 1, 1)
				render.Clear(r, g, b, 255)
			end

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
end





local patchesPerItr = 4
local lastPatch = 1
local didSetup = false
function solver.PreProcess()
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
		return true
	end
end

function solver.CalculateValue(patch, pos, norm, index)
	local visibilities = patchVisibilityList[index]
	if not visibilities then
		return
	end

	--patch.luminance[1] = 1
	--patch.luminance[2] = 0
	--patch.luminance[3] = 0


	-- emit out emmision out to others
	local registry = LK3D.Radiosa.GetPatchRegistry()

	for i = 1, #visibilities do
		local struct = visibilities[i]
		local otherPatchIndex = struct[1]
		local otherPatch = registry[otherPatchIndex]
		--if not otherPatch then
		--	continue
		--end
		local emm = otherPatch.emission
		--if emm[1] == 0 and emm[2] == 0 and emm[3] == 0 then
		--	continue
		--end


		local giveAmount = struct[2]

		patch.luminance[1] = emm[1]
		patch.luminance[2] = emm[2]
		patch.luminance[3] = emm[3] --patch.luminance[3] + emm[3]

		--LK3D.Radiosa.AddPatchLuminanceUnpacked(patch, emm[1] * 3200, emm[2] * 3200, emm[3] * 3200)
	end
end

function solver.CalculateAfterIteration(patch, pos, norm, index)


end


function solver.FinalPass(patch, pos, norm, index)
	local visibilities = patchVisibilityList[index]
	if not visibilities then
		LK3D.PushProcessingMessage("[RADIOSA] [WARN] No patch visibility for patch index #" .. tostring(index))
		return {255, 0, 0}
	end

	local visCount = #visibilities
	local colVal = (visCount / DEBUG_highestVisCount) * 128




	--local luma = patch.luminance
	--return {luma[1] * 255, luma[2] * 255, luma[3] * 255}



	return {colVal, colVal, colVal}
	--return {(norm.x + 1) * 64, (norm.y + 1) * 64, (norm.z + 1) * 64}
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