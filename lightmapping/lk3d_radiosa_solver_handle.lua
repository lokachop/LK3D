LK3D = LK3D or {}

local objectPatchLUT = {}
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

	objectPatchLUT[tag] = LK3D.Radiosa.GenerateObjectPatchesLUT(tag)
end

function LK3D.Radiosa.GetPatchLUTForObject(tag)
	return objectPatchLUT[tag]
end


local function prePreProcess()
	LK3D.PushProcessingMessage("[RADIOSA] PrePreProcess...")

	objectPatchLUT = {}

	local toLM = LK3D.Radiosa.GetLightmapMarkedObjects()

	for k, v in pairs(toLM) do
		setupObject(k)
	end

	LK3D.Radiosa.FTraceSetupScene()
end

local function preProcess()
	LK3D.PushProcessingMessage("[RADIOSA] PreProcess...")
	local solver = LK3D.Radiosa.GetSolver()
	-- call preprocess until done
	local itr = 0

	while true do
		itr = itr + 1
		if (itr % 512) == 0 then
			LK3D.RenderProcessingMessage("[RADIOSA] PreProcess... ")
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

		local patchID = patchLUT[i]
		if not patchID then
			continue
		end
		local patch = LK3D.Radiosa.GetPatchFromRegistry(patchID)

		local pos = LK3D.Radiosa.GetPatchPos(patch)
		local norm = LK3D.Radiosa.GetPatchNormal(patch)

		local valCol = solver.CalculateValue(patch, pos, norm, patchID)
		pixelValuesRet[i] = valCol
	end

	return pixelValuesRet
end


local function calculateValueMultiPass(solver, patchLUT, pass)
	local size = LK3D.Radiosa.LIGHTMAP_RES
	local pixelItr = (size * size) - 1


	local passes = solver.PassCount
	local passStr = "[PASS " .. pass .. "/" .. passes .. "]"

	for i = 0, pixelItr do
		if (i % 1024) == 0 then
			LK3D.RenderProcessingMessage("[RADIOSA] " .. passStr .. " Calculate MultiPass... ", (i / pixelItr) * 100)
		end

		local patchID = patchLUT[i]
		if not patchID then
			continue
		end
		local patch = LK3D.Radiosa.GetPatchFromRegistry(patchID)

		local pos = LK3D.Radiosa.GetPatchPos(patch)
		local norm = LK3D.Radiosa.GetPatchNormal(patch)

		solver.CalculateValue(patch, pos, norm, patchID)
	end


end

local function afterIterationMultiPass(solver, patchLUT, pass)
	local size = LK3D.Radiosa.LIGHTMAP_RES
	local pixelItr = (size * size) - 1


	local passes = solver.PassCount
	local passStr = "[PASS " .. pass .. "/" .. passes .. "]"

	if solver.CalculateAfterIteration then
		for i = 0, pixelItr do
			if (i % 1024) == 0 then
				LK3D.RenderProcessingMessage("[RADIOSA] " .. passStr .. " Calculate MultiPass AfterIteration... ", (i / pixelItr) * 100)
			end

			local patchID = patchLUT[i]
			if not patchID then
				continue
			end
			local patch = LK3D.Radiosa.GetPatchFromRegistry(patchID)

			local pos = LK3D.Radiosa.GetPatchPos(patch)
			local norm = LK3D.Radiosa.GetPatchNormal(patch)

			solver.CalculateAfterIteration(patch, pos, norm, patchID)
		end
	end
end



local function finalizeMultiPass(solver, patchLUT)
	local size = LK3D.Radiosa.LIGHTMAP_RES
	local pixelItr = (size * size) - 1

	local pixelValuesRet = {}
	for i = 0, pixelItr do
		if (i % 2048) == 0 then
			LK3D.RenderProcessingMessage("[RADIOSA] FinalPass MultiPass... ", (i / pixelItr) * 100)
		end

		local patchID = patchLUT[i]
		if not patchID then
			continue
		end
		local patch = LK3D.Radiosa.GetPatchFromRegistry(patchID)

		local pos = LK3D.Radiosa.GetPatchPos(patch)
		local norm = LK3D.Radiosa.GetPatchNormal(patch)

		local valCol = solver.FinalPass(patch, pos, norm, patchID)
		pixelValuesRet[i] = valCol
	end

	return pixelValuesRet
end



local function renderPixelValuesToTex(tag, pixelValues)
	LK3D.PushProcessingMessage("[RADIOSA] Rendering for \"" .. tag .. "\"...")

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

local function mainLoopMultiPass()
	local solver = LK3D.Radiosa.GetSolver()
	local toLM = LK3D.Radiosa.GetLightmapMarkedObjects()

	for i = 1, solver.PassCount do
		for k, v in pairs(toLM) do
			local patchLUT = objectPatchLUT[k]

			LK3D.PushProcessingMessage("[RADIOSA] Calculating values for object \"" .. k .. "\" [MULTIPASS]")
			calculateValueMultiPass(solver, patchLUT, i)
		end


		for k, v in pairs(toLM) do
			local patchLUT = objectPatchLUT[k]

			LK3D.PushProcessingMessage("[RADIOSA] Calculating AfterIteration for object \"" .. k .. "\" [MULTIPASS]")
			afterIterationMultiPass(solver, patchLUT, i)
		end
	end

	for k, v in pairs(toLM) do
		local patchLUT = objectPatchLUT[k]

		LK3D.PushProcessingMessage("[RADIOSA] Finalizing MultiPass for object \"" .. k .. "\" [MULTIPASS]")
		pixelValues = finalizeMultiPass(solver, patchLUT)

		renderPixelValuesToTex(k, pixelValues)
	end
end

local function mainLoopNormal()
	local solver = LK3D.Radiosa.GetSolver()
	local toLM = LK3D.Radiosa.GetLightmapMarkedObjects()

	for k, v in pairs(toLM) do
		LK3D.PushProcessingMessage("[RADIOSA] Calculating values for object \"" .. k .. "\" [NORMAL]")
		pixelValues = calculateValueNormal(solver, patchLUT)

		renderPixelValuesToTex(k, pixelValues)
	end
end



local function mainLoop()
	local solver = LK3D.Radiosa.GetSolver()

	if solver.MultiPass then
		mainLoopMultiPass()
	else
		mainLoopNormal()
	end
end


local function doCleanup()
	local solver = LK3D.Radiosa.GetSolver()

	if solver.Cleanup then
		solver.Cleanup()
	end

end


function LK3D.Radiosa.BeginLightmapping()
	print("::Start lightmapping")
	LK3D.PushProcessingMessage("[RADIOSA] Start lightmapping")

	prePreProcess()
	LK3D.PushProcessingMessage("[RADIOSA] PrePreProcess done")
	print("::PrePreProcess done")

	preProcess()
	LK3D.PushProcessingMessage("[RADIOSA] PreProcess done")
	print(":: PreProcess done")

	-- Main processing
	mainLoop()
	LK3D.PushProcessingMessage("[RADIOSA] Main Loop done")
	print(":: Main Loop done")

	doCleanup()
	LK3D.PushProcessingMessage("[RADIOSA] Cleanup done")
	print(":: Cleanup done")
end