LK3D = LK3D or {}

local objectPatchLUT = {}
local objectUVInfos = {}
local function setupObject(tag)
	local unwrapped_tris = LK3D.Radiosa.GetUVUnwrappedTris(tag)
	local packed, lightmap_uvs, index_list = LK3D.Radiosa.PackUVs(unwrapped_tris)

	-- make the tex
	local texName = LK3D.Radiosa.GetObjectLightmapTextureName(tag)
	LK3D.DeclareTextureFromFunc(texName, LK3D.Radiosa.LIGHTMAP_RES, LK3D.Radiosa.LIGHTMAP_RES, function() -- generate an OK texture as a placeholder
		surface.SetDrawColor(255, 0, 255)
		surface.DrawRect(0, 0, ScrW(), ScrH())

		local gradItr = 64
		local stepSize = LK3D.Radiosa.LIGHTMAP_RES / gradItr
		for i = 0, gradItr do
			local delta = i / gradItr

			surface.SetDrawColor(delta * 255, 0, 255)
			surface.DrawRect(0, i * stepSize, ScrW(), stepSize)
		end
	end)


	LK3D.Radiosa.PushLightmapUVsToObject(tag, packed, lightmap_uvs, index_list)

	objectUVInfos[tag] = {packed, lightmap_uvs, index_list}
	objectPatchLUT[tag] = LK3D.Radiosa.GenerateObjectPatchesLUT(tag)
end

function LK3D.Radiosa.GetUVInfoForObject(tag)
	return objectUVInfos[tag]
end

function LK3D.Radiosa.GetPatchLUTForObject(tag)
	return objectPatchLUT[tag]
end

function LK3D.Radiosa.GetPatchLUTTable()
	return objectPatchLUT
end


local function prePreProcess()
	objectPatchLUT = {}

	local toLM = LK3D.Radiosa.GetLightmapMarkedObjects()

	for k, v in pairs(toLM) do
		setupObject(k)
	end

	LK3D.Radiosa.FTraceSetupScene()
end

local function preProcess()
	local solver = LK3D.Radiosa.GetSolver()
	-- call preprocess until done
	local itr = 0

	while true do
		itr = itr + 1
		if (itr % 2048) == 0 then
			LK3D.RenderProcessingMessage("[RADIOSA] PreProcess... ", 0)
		end

		local escape = solver.PreProcess()
		if escape then
			break
		end
	end
end


local function calculateValueNormal(solver, patchLUT)
	local size = LK3D.Radiosa.LIGHTMAP_RES
	local pixelItr = (size * size) - 1

	local pixelValuesRet = {}
	for i = 0, pixelItr do
		if (i % 2048) == 0 then
			LK3D.RenderProcessingMessage("[RADIOSA] Calculate... ", (i / pixelItr) * 100)
		end

		local patch = patchLUT[i]
		if not patch then
			continue
		end
		patch = LK3D.Radiosa.GetPatchFromRegistry(patch)

		local pos = LK3D.Radiosa.GetPatchPos(patch)
		local norm = LK3D.Radiosa.GetPatchNormal(patch)

		local valCol = solver.CalculateValue(patch, pos, norm)
		pixelValuesRet[i] = valCol
	end

	return pixelValuesRet
end


local function calculateValueMultiPass(solver, patchLUT)
	local size = LK3D.Radiosa.LIGHTMAP_RES
	local pixelItr = (size * size) - 1

	local passes = solver.PassCount

	for j = 1, passes do
		local passStr = "[PASS " .. j .. "/" .. passes .. "]"
		for i = 0, pixelItr do
			if (i % 1024) == 0 then
				LK3D.RenderProcessingMessage("[RADIOSA] " .. passStr .. " Calculate MultiPass... ", (i / pixelItr) * 100)
			end

			local patch = patchLUT[i]
			if not patch then
				continue
			end
			patch = LK3D.Radiosa.GetPatchFromRegistry(patch)

			local pos = LK3D.Radiosa.GetPatchPos(patch)
			local norm = LK3D.Radiosa.GetPatchNormal(patch)

			solver.CalculateValue(patch, pos, norm)
		end
	end

	local pixelValuesRet = {}
	for i = 0, pixelItr do
		if (i % 2048) == 0 then
			LK3D.RenderProcessingMessage("[RADIOSA] FinalPass MultiPass... ", (i / pixelItr) * 100)
		end

		local patch = patchLUT[i]
		if not patch then
			continue
		end
		patch = LK3D.Radiosa.GetPatchFromRegistry(patch)

		local pos = LK3D.Radiosa.GetPatchPos(patch)
		local norm = LK3D.Radiosa.GetPatchNormal(patch)

		local valCol = solver.FinalPass(patch, pos, norm)
		pixelValuesRet[i] = valCol
	end

	return pixelValuesRet
end



local function renderPixelValuesToTex(tag, pixelValues)
	local size = LK3D.Radiosa.LIGHTMAP_RES
	local pixelItr = (size * size) - 1

	local texName = LK3D.Radiosa.GetObjectLightmapTextureName(tag)
	LK3D.UpdateTexture(texName, function()
		local oldW, oldH = ScrW(), ScrH()
		for i = 0, pixelItr do
			local xc = i % size
			local yc = math.floor(i / size)

			local value = pixelValues[i]
			if not value then
				continue
			end

			render.SetViewPort(xc, yc, 1, 1)
			render.Clear(value[1], value[2], value[3], 255)
		end

		render.SetViewPort(0, 0, oldW, oldH)
	end)
end


local function mainLoop()
	local toLM = LK3D.Radiosa.GetLightmapMarkedObjects()
	for k, v in pairs(toLM) do
		-- loop thru all of its patches and call the func
		local patchLUT = objectPatchLUT[k]

		local solver = LK3D.Radiosa.GetSolver()

		local pixelValues = {}
		if solver.MultiPass then
			pixelValues = calculateValueMultiPass(solver, patchLUT)
		else
			pixelValues = calculateValueNormal(solver, patchLUT)
		end

		renderPixelValuesToTex(k, pixelValues)
	end
end


function LK3D.Radiosa.BeginLightmapping()
	print("::Start lightmapping")

	prePreProcess()
	print("::PrePreProcess done")

	preProcess()
	print(":: PreProcess done")

	-- Main processing
	mainLoop()
	print(":: Done lightmapping!")
end