LK3D = LK3D or {}

local objectPatchLUT = {}
local function setupObject(tag)
	local unwrapped_tris = LK3D.Radiosa.GetUVUnwrappedTris(tag)
	local packed, lightmap_uvs, index_list = LK3D.Radiosa.PackUVs(unwrapped_tris)

	-- make the tex
	local size = LK3D.Radiosa.LIGHTMAP_RES
	local pixelItr = (size * size) - 1


	local texName = LK3D.Radiosa.GetObjectLightmapTextureName(tag)
	LK3D.DeclareTextureFromFunc(texName, LK3D.Radiosa.LIGHTMAP_RES, LK3D.Radiosa.LIGHTMAP_RES, function() -- generate an OK texture as a placeholder
		local oldW, oldH = ScrW(), ScrH()
		for i = 0, pixelItr do
			local xc = i % size
			local yc = math.floor(i / size)

			render.SetViewPort(xc, yc, 1, 1)
			render.Clear((xc / size) * 255, (yc / size) * 255, 0, 255)
		end

		render.SetViewPort(0, 0, oldW, oldH)
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
		if (i % 512) == 0 then
			LK3D.RenderProcessingMessage("[RADIOSA] Calculate... ", (i / pixelItr) * 100)
		end

		local patchID = patchLUT[i]
		if not patchID then
			continue
		end
		local patch = LK3D.Radiosa.GetPatchFromRegistry(patchID)

		local pos = LK3D.Radiosa.GetPatchPos(patch)
		local norm = LK3D.Radiosa.GetPatchNormal(patch)

		local valCol = solver.CalculateValue(patch, pos, norm, patchID, i)
		pixelValuesRet[i] = valCol
	end

	return pixelValuesRet
end



local function ratio2(a, b)
	if (a == 0) and (b == 0) then
		return 1.0
	end
	if (a == 0) or (b == 0) then
		return 0.0
	end

	if a > b then
		return b / a
	else
		return a / b
	end
end

local function ratio4(a, b, c, d)
	local q1 = ratio2(a, b)
	local q2 = ratio2(c, d)

	if (q1 < q2) then
		return q1
	else
		return q2
	end
end

local lmSize = LK3D.Radiosa.LIGHTMAP_RES
local function coordToPatchIndex(x, y)
	return x + (y * lmSize)
end

local function getPatchIncidentFromCoords(x, y, LUT)
	local pID = LUT[coordToPatchIndex(x, y)]
	local patch = LK3D.Radiosa.GetPatchFromRegistry(pID)
	if not patch then
		patch = {9999999, 9999999, 9999999} -- to not lerp just incase
	else
		patch = patch.incident
	end

	return patch
end



local function calculateValueMultiPass(solver, patchLUT, pass)
	local size = LK3D.Radiosa.LIGHTMAP_RES
	local pixelItr = (size * size) - 1


	local passes = solver.PassCount
	local passStr = "[PASS " .. pass .. "/" .. passes .. "]"

	local spacing = LK3D.Radiosa.RADIOSITY_SPACING * 1
	local quality = LK3D.Radiosa.RADIOSITY_QUALITY * 1



	local sX = 1
	local sY = 1

	local itr = 0
	for y = 1 - sY, size, spacing do
		for x = 1 - sX, size, spacing do
			itr = itr + 1
			if (itr % 1024) == 0 then
				LK3D.PushProcessingMessage("PreMultipass; " .. tostring(itr))
				LK3D.RenderProcessingMessage("[RADIOSA] Calculate PreMultiPass[P1]" .. passStr)
			end



			local patchID = patchLUT[coordToPatchIndex(x, y)]
			if not patchID then
				continue
			end

			local patch = LK3D.Radiosa.GetPatchFromRegistry(patchID)


			local pos = LK3D.Radiosa.GetPatchPos(patch)
			local norm = LK3D.Radiosa.GetPatchNormal(patch)

			patch.isCalculated = {1, 0, 1}
			solver.CalculateValue(patch, pos, norm, patchID)
		end
	end

	local x1 = 0
	local y1 = 0



	for i = 1, 4 do
		local threshold = math.pow(quality, spacing)

		local halfSpacing = spacing * .5
		local halfSpacingP1 = halfSpacing + 1


		for y = halfSpacingP1 - sY, (size + halfSpacing), spacing do
			for x = halfSpacingP1 - sX, (size + halfSpacing), spacing do
				itr = itr + 1
				if (itr % 1024) == 0 then
					LK3D.PushProcessingMessage("PreMultipass; " .. tostring(itr))
					LK3D.RenderProcessingMessage("[RADIOSA] Calculate PreMultiPass[P2]" .. passStr)
				end



				if x < size then
					x1 = x
					y1 = y - halfSpacing

					-- Read the 2 (left and right) neighbours from the Light Map
					local I1 = getPatchIncidentFromCoords(x1 + halfSpacing, y1, patchLUT)
					local I2 = getPatchIncidentFromCoords(x1 - halfSpacing, y1, patchLUT)

					-- If the neighbours are very similar, then just interpolate.
					if  (ratio2(I1[1],I2[1]) > threshold) and
						(ratio2(I1[2],I2[2]) > threshold) and
						(ratio2(I1[3],I2[3]) > threshold)
					then
						local patchID = patchLUT[coordToPatchIndex(x1, y1)]
						if not patchID then
							continue
						end
						local patch = LK3D.Radiosa.GetPatchFromRegistry(patchID)

						patch.isCalculated = {0, 1, 0}
						LK3D.Radiosa.SetPatchIncident(patch, {
							(I1[1] + I2[1]) * 0.5,
							(I1[2] + I2[2]) * 0.5,
							(I1[3] + I2[3]) * 0.5,
						})
					else
						local patchID = patchLUT[coordToPatchIndex(x1, y1)]
						if not patchID then
							continue
						end
						local patch = LK3D.Radiosa.GetPatchFromRegistry(patchID)

						local pos = LK3D.Radiosa.GetPatchPos(patch)
						local norm = LK3D.Radiosa.GetPatchNormal(patch)

						patch.isCalculated = {1, 0, 0}
						solver.CalculateValue(patch, pos, norm, patchID)
					end
				end


				if y < size then
					x1 = x - halfSpacing
					y1 = y

					-- Read the 2 (left and right) neighbours from the Light Map
					local I1 = getPatchIncidentFromCoords(x1, y1 - halfSpacing, patchLUT)
					local I2 = getPatchIncidentFromCoords(x1, y1 + halfSpacing, patchLUT)

					-- If the neighbours are very similar, then just interpolate.
					if   (ratio2(I1[1],I2[1]) > threshold) and
						 (ratio2(I1[2],I2[2]) > threshold) and
						 (ratio2(I1[3],I2[3]) > threshold)
					then
						local patchID = patchLUT[coordToPatchIndex(x1, y1)]
						if not patchID then
							continue
						end
						local patch = LK3D.Radiosa.GetPatchFromRegistry(patchID)

						patch.isCalculated = {0, 1, 0}
						LK3D.Radiosa.SetPatchIncident(patch, {
							(I1[1] + I2[1]) * 0.5,
							(I1[2] + I2[2]) * 0.5,
							(I1[3] + I2[3]) * 0.5,
						})
					else
						local patchID = patchLUT[coordToPatchIndex(x1, y1)]
						if not patchID then
							continue
						end
						local patch = LK3D.Radiosa.GetPatchFromRegistry(patchID)
						local pos = LK3D.Radiosa.GetPatchPos(patch)
						local norm = LK3D.Radiosa.GetPatchNormal(patch)

						patch.isCalculated = {1, 0, 0}
						solver.CalculateValue(patch, pos, norm, patchID)
					end
				end
			end
		end


		for y = halfSpacingP1 - sY, size - halfSpacing, spacing do
			for x = halfSpacingP1 - sX, size - halfSpacing, spacing do
				itr = itr + 1
				if (itr % 1024) == 0 then
					LK3D.PushProcessingMessage("PreMultipass; " .. tostring(itr))
					LK3D.RenderProcessingMessage("[RADIOSA] Calculate PreMultiPass[P3]" .. passStr)
				end


				local I1 = getPatchIncidentFromCoords(x, y - halfSpacing, patchLUT)
				local I2 = getPatchIncidentFromCoords(x, y + halfSpacing, patchLUT)
				local I3 = getPatchIncidentFromCoords(x - halfSpacing, y, patchLUT)
				local I4 = getPatchIncidentFromCoords(x + halfSpacing, y, patchLUT)

				if   (ratio4(I1[1], I2[1], I3[1], I4[1]) > threshold) and
					 (ratio4(I1[2], I2[2], I3[2], I4[2]) > threshold) and
					 (ratio4(I1[3], I2[3], I3[3], I4[3]) > threshold)
				then
					local patchIndexCurr = coordToPatchIndex(x, y)
					local patchID = patchLUT[patchIndexCurr]
					if not patchID then
						continue
					end
					local patch = LK3D.Radiosa.GetPatchFromRegistry(patchID)

					patch.isCalculated = {0, 1, 0}
					LK3D.Radiosa.SetPatchIncident(patch, {
						(I1[1] + I2[1] + I3[1] + I4[1]) * 0.25,
						(I1[2] + I2[2] + I3[2] + I4[2]) * 0.25,
						(I1[3] + I2[3] + I3[3] + I4[3]) * 0.25,
					})
				else
					local patchID = patchLUT[coordToPatchIndex(x, y)]
					local patch = LK3D.Radiosa.GetPatchFromRegistry(patchID)
					if not patch then
						continue
					end

					local pos = LK3D.Radiosa.GetPatchPos(patch)
					local norm = LK3D.Radiosa.GetPatchNormal(patch)

					patch.isCalculated = {1, 0, 0}
					solver.CalculateValue(patch, pos, norm, patchID)
				end
			end
		end

		LK3D.PushProcessingMessage("[RADIOSA] SpacingSize; " .. tostring(spacing))
		spacing = spacing * .5

		if spacing <= 1 then
			break
		end
	end
	LK3D.PushProcessingMessage("[RADIOSA] Done with OptiCalc!")


	--[[
	-- Brute force algorithm (calc. every pixel)
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
	]]--
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

		local valCol = solver.FinalPass(patch, pos, norm, patchID, i)
		pixelValuesRet[i] = valCol
	end

	return pixelValuesRet
end

local function cmp(coord)
	local size = LK3D.Radiosa.LIGHTMAP_RES
	return coord % size
end


-- This to fix the seams on linear filtering
local function expandBorders(pixelValues)
	LK3D.PushProcessingMessage("[RADIOSA] Expanding borders for linear...")

	local size = LK3D.Radiosa.LIGHTMAP_RES
	local pixelItr = (size * size) - 1

	local patchesToAdd = {}
	for i = 0, pixelItr do
		local xc = i % size
		local yc = math.floor(i / size)

		local ourIndex = xc + (yc * size)

		if pixelValues[i] then
			continue
		end

		-- check all of our 8 neighbours, if any of them have a patch, we will add one later

		-- #--
		-- - -
		-- ---
		iCheck = cmp(xc - 1) + (cmp(yc - 1) * size)
		if pixelValues[iCheck] ~= nil then
			patchesToAdd[#patchesToAdd + 1] = {ourIndex, iCheck}
			continue
		end

		-- -#-
		-- - -
		-- ---
		iCheck = xc      + (cmp(yc - 1) * size)
		if pixelValues[iCheck] ~= nil then
			patchesToAdd[#patchesToAdd + 1] = {ourIndex, iCheck}
			continue
		end

		-- --#
		-- - -
		-- ---
		iCheck = cmp(xc + 1) + (cmp(yc - 1) * size)
		if pixelValues[iCheck] ~= nil then
			patchesToAdd[#patchesToAdd + 1] = {ourIndex, iCheck}
			continue
		end

		-- ---
		-- # -
		-- ---
		iCheck = cmp(xc - 1) + (yc * size)
		if pixelValues[iCheck] ~= nil then
			patchesToAdd[#patchesToAdd + 1] = {ourIndex, iCheck}
			continue
		end

		-- ---
		-- - #
		-- ---
		iCheck = cmp(xc + 1) + (yc * size)
		if pixelValues[iCheck] ~= nil then
			patchesToAdd[#patchesToAdd + 1] = {ourIndex, iCheck}
			continue
		end

		-- ---
		-- - -
		-- #--
		iCheck = cmp(xc - 1) + (cmp(yc + 1) * size)
		if pixelValues[iCheck] ~= nil then
			patchesToAdd[#patchesToAdd + 1] = {ourIndex, iCheck}
			continue
		end

		-- ---
		-- - -
		-- -#-
		iCheck = xc + (cmp(yc + 1) * size)
		if pixelValues[iCheck] ~= nil then
			patchesToAdd[#patchesToAdd + 1] = {ourIndex, iCheck}
			continue
		end

		-- ---
		-- - -
		-- --#
		iCheck = cmp(xc - 1) + (cmp(yc + 1) * size)
		if pixelValues[iCheck] ~= nil then
			patchesToAdd[#patchesToAdd + 1] = {ourIndex, iCheck}
			continue
		end
	end

	for i = 1, #patchesToAdd do
		local patchToAdd = patchesToAdd[i]

		local patchIndex = patchToAdd[1]
		local patchParent = patchToAdd[2]

		local xc = patchIndex % size
		local yc = math.floor(patchIndex / size)

		local value = pixelValues[patchParent]

		pixelValues[patchIndex] = {value[1], value[2], value[3]}

		render.SetViewPort(xc, yc, 1, 1)
		render.Clear(value[1], value[2], value[3], 255)
	end
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

		for i = 1, 3 do
			expandBorders(pixelValues)
		end

		render.SetViewPort(0, 0, oldW, oldH)
	end)
end

local function mainLoopMultiPass()
	local solver = LK3D.Radiosa.GetSolver()
	local toLM = LK3D.Radiosa.GetLightmapMarkedObjects()

	--for k, v in pairs(toLM) do
	--	local patchLUT = objectPatchLUT[k]
	--	calculatePreMultipass(solver, patchLUT)
	--end

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
		local patchLUT = objectPatchLUT[k]

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
	LK3D.New_D_Print("Start lightmapping", LK3D_SEVERITY_INFO, "Radiosity")
	LK3D.PushProcessingMessage("[RADIOSA] Start lightmapping")

	prePreProcess()
	LK3D.PushProcessingMessage("[RADIOSA] PrePreProcess done")
	LK3D.New_D_Print("PrePreProcess done", LK3D_SEVERITY_INFO, "Radiosity")

	preProcess()
	LK3D.PushProcessingMessage("[RADIOSA] PreProcess done")
	LK3D.New_D_Print("PreProcess done", LK3D_SEVERITY_INFO, "Radiosity")

	-- Main processing
	mainLoop()
	LK3D.PushProcessingMessage("[RADIOSA] Main Loop done")
	LK3D.New_D_Print("Main Loop done", LK3D_SEVERITY_INFO, "Radiosity")

	doCleanup()
	LK3D.PushProcessingMessage("[RADIOSA] Cleanup done")
	LK3D.New_D_Print("Cleanup done", LK3D_SEVERITY_INFO, "Radiosity")

	if LK3D.Radiosa.LIGHTMAP_AUTO_EXPORT then
		LK3D.PushProcessingMessage("[RADIOSA] AutoExporting")
		LK3D.New_D_Print("Lightmap done! Automatically exporting...", LK3D_SEVERITY_INFO, "Radiosity")

		LK3D.ExportLightmaps()
	else
		LK3D.New_D_Print("Lightmap done! Please export with \"lk3d_exportlightmaps " .. LK3D.CurrUniv["tag"] .. "\"", LK3D_SEVERITY_INFO, "Radiosity")
	end


	-- Audio cue when done
	if CLIENT and IsValid(LocalPlayer()) then
		sound.Play("garrysmod/save_load1.wav", LocalPlayer():GetPos(), 0, 45, 1, 0)
		sound.Play("garrysmod/content_downloaded.wav", LocalPlayer():GetPos(), 0, 45, 1, 0)
	end
end