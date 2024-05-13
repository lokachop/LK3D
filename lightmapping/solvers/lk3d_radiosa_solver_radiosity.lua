LK3D = LK3D or {}
LK3D.Radiosa = LK3D.Radiosa or {}
-- The main solver, calculates lighting with radiosity algorithm

local math = math
local math_floor = math.floor




local solver = {}
solver.MultiPass = true
solver.PassCount = LK3D.Radiosa.RADIOSITY_STEPS

local bufferSize = 128


local univVisibility = LK3D.NewUniverse("lk3d_radiosa_radiosity_universe_visibility")

local CaptureRT_UP =        GetRenderTarget("lk3d_radiosity_buffer_up_" .. bufferSize, bufferSize, bufferSize)
local CaptureRT_FORWARD =   GetRenderTarget("lk3d_radiosity_buffer_fw_" .. bufferSize, bufferSize, bufferSize)
local CaptureRT_LEFT =      GetRenderTarget("lk3d_radiosity_buffer_le_" .. bufferSize, bufferSize, bufferSize)
local CaptureRT_RIGHT =     GetRenderTarget("lk3d_radiosity_buffer_ri_" .. bufferSize, bufferSize, bufferSize)
local CaptureRT_DOWN =      GetRenderTarget("lk3d_radiosity_buffer_dw_" .. bufferSize, bufferSize, bufferSize)

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




local distTreshold = 16 * 16
local patchVisibilityList = {}
local EPSILON = 0.00001
local function setupPatchVisibility(patch, patchIndex)


end




local function intSnap(int, base)
	local bh = (base * .5)
	return math_floor((int + bh) - ((int + bh) % base))
end

local LP_ST_SZ = 4
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

local function setupCloneObject(tag, objData)
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

				if patchIndex > LP_MAX_VALUE then
					error("Too many patches! TODO: multiPass increase patch limit...")
				end


				local r, g, b = packRGB_LP(patchIndex)
				render.SetViewPort(i % size, math_floor(i / size), 1, 1)
				render.Clear(r, g, b, 255)
			end

			render.SetViewPort(0, 0, oW, oH)
		end)

		--local uvInfo = LK3D.Radiosa.GetUVInfoForObject(tag)
		--LK3D.Radiosa.PushLightmapUVsToObject(tag_1, uvInfo[1], uvInfo[2], uvInfo[3])
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
	local objs = LK3D.GetUniverseObjects()

	LK3D.PushUniverse(univVisibility)
		for k, v in pairs(objs) do
			setupCloneObject(k, v)
		end
	LK3D.PopUniverse()
end





local patchesPerItr = 4096
local lastPatch = 1
local didSetup = false
function solver.PreProcess()
	if not didSetup then
		preProcessLK3DUniv()

		didSetup = true
	end

	local registry = LK3D.Radiosa.GetPatchRegistry()
	for i = lastPatch, lastPatch + patchesPerItr do
		lastPatch = lastPatch + 1
		local patch = registry[i]

		if not patch then
			break
		end

		setupPatchVisibility(patch, i)
	end

	if lastPatch > #registry then
		return true
	end
end

function solver.CalculateValue(patch, pos, norm)

end


function solver.FinalPass(patch, pos, norm)
	return {(norm.x + 1) * 64, (norm.y + 1) * 64, (norm.z + 1) * 64}
end


return solver