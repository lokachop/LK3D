LK3D = LK3D or {}

-----------------------------
-- Models
-----------------------------

LK3D.Models = LK3D.Models or {}
file.CreateDir("lk3d")

function LK3D.GenerateNormals(data, invert, smoothOnly)
	if not data then
		LK3D.New_D_Print("Data not provided when genning normals!", LK3D_SEVERITY_WARN, "ModelUtils")
		return
	end

	data.normals = {}

	local verts = data.verts
	local ind = data.indices
	for i = 1, #ind do
		local index = ind[i]

		local v1 = Vector(verts[index[1][1]])
		local v2 = Vector(verts[index[2][1]])
		local v3 = Vector(verts[index[3][1]])

		local norm = (v2 - v1):Cross(v3 - v1)
		norm:Normalize()
		if invert then
			norm = -norm
		end
		data["normals"][i] = norm
	end

	data.s_normals = {}
	for i = 1, #data["normals"] do
		local n = data["normals"][i]
		local index = ind[i]


		local id1 = index[1][1]
		data.s_normals[id1] = (data.s_normals[id1] or Vector(0, 0, 0)) + n
		local id2 = index[2][1]
		data.s_normals[id2] = (data.s_normals[id2] or Vector(0, 0, 0)) + n
		local id3 = index[3][1]

		data.s_normals[id3] = (data.s_normals[id3] or Vector(0, 0, 0)) + n
	end


	for i = 1, #data["s_normals"] do
		if data["s_normals"][i] then
			data["s_normals"][i]:Normalize()
		else
			data["s_normals"][i] = Vector(0, 1, 0)
		end
	end
	LK3D.New_D_Print("Generated normals for data!", LK3D_SEVERITY_DEBUG, "ModelUtils")
end

-- returns a table that merges matching verts for perf
local concat_tbl_vert = {}
local concat_round = 4
local function hashVec(v)
	concat_tbl_vert[1] = "x"
	concat_tbl_vert[2] = math.Round(v[1], concat_round)
	concat_tbl_vert[3] = "y"
	concat_tbl_vert[4] = math.Round(v[2], concat_round)
	concat_tbl_vert[5] = "z"
	concat_tbl_vert[6] = math.Round(v[3], concat_round)

	return table.concat(concat_tbl_vert, "")
end

local concat_tbl_uv = {}
local function hashUV(uv)
	concat_tbl_uv[1] = "u"
	concat_tbl_uv[2] = math.Round(uv[1], concat_round)
	concat_tbl_uv[3] = "v"
	concat_tbl_uv[4] = math.Round(uv[2], concat_round)



	return table.concat(concat_tbl_uv, "")
end


function LK3D.GetOptimizedModelTable(tblpointer)
	local verts = tblpointer.verts
	local uvs = tblpointer.uvs
	local indices = tblpointer.indices
	local normals = tblpointer.normals or {}
	local snormals = tblpointer.s_normals or {}

	local newtbl = {
		verts = {},
		uvs = {},
		indices = {},
		normals = {},
		s_normals = {},
	}

	-- build existing vert tbl
	local vert_existing_tbl = {}
	local vert_lookup = {}
	for i = 1, #verts do
		local vert = verts[i]
		local hash = hashVec(vert)
		if vert_existing_tbl[hash] == nil then
			local newind = #newtbl.verts + 1
			newtbl.verts[newind] = Vector(vert) -- copy the vert


			vert_existing_tbl[hash] = newind
			vert_lookup[i] = newind
		else
			vert_lookup[i] = vert_existing_tbl[hash]
		end
	end

	-- build uv existing table
	local uv_existing_tbl = {}
	local uv_lookup = {}
	for i = 1, #uvs do
		local uv = uvs[i]
		local hash = hashUV(uv)

		if uv_existing_tbl[hash] == nil then
			local newind = #newtbl.uvs + 1
			newtbl.uvs[newind] = {uv[1], uv[2]} -- copy the uv

			uv_existing_tbl[hash] = newind
			uv_lookup[i] = newind
		else
			uv_lookup[i] = uv_existing_tbl[hash]
		end
	end


	for i = 1, #snormals do
		local norm_s = Vector(snormals[vert_lookup[i]])

		newtbl.s_normals[#newtbl.s_normals + 1] = norm_s
	end


	for i = 1, #indices do
		local index = indices[i]

		-- use the lookups we made
		local v1id = vert_lookup[index[1][1]]
		local v2id = vert_lookup[index[2][1]]
		local v3id = vert_lookup[index[3][1]]


		local uv1id = uv_lookup[index[1][2]]
		local uv2id = uv_lookup[index[2][2]]
		local uv3id = uv_lookup[index[3][2]]

		-- convert index to new lookup
		newtbl.normals[#newtbl.normals + 1] = normals[i]
		newtbl.indices[#newtbl.indices + 1] = {
			{v1id, uv1id},
			{v2id, uv2id},
			{v3id, uv3id},
		}
	end

	-- optimized!
	return newtbl
end




-- declares a model from the output table of the helper script
-- refer to lk3d-obj_import.lua
function LK3D.DeclareModel(name, data)
	LK3D.Models[name] = data
	LK3D.GenerateNormals(LK3D.Models[name])
	LK3D.New_D_Print("Declared model \"" .. name .. "\" with " .. #data.verts .. " verts [TBL]", LK3D_SEVERITY_DEBUG, "ModelUtils")
end

local function t_copy(tbl)
	local nw = {}
	for k, v in pairs(tbl) do
		if type(v) ~= "table" then
			nw[k] = v
		else
			nw[k] = t_copy(v)
		end
	end

	return nw
end

function LK3D.CopyModel(from, to)
	if not LK3D.Models[from] then
		return
	end

	LK3D.Models[to] = t_copy(LK3D.Models[from])
	LK3D.GenerateNormals(LK3D.Models[to])
	LK3D.GenTrList(to)
	LK3D.New_D_Print("Copied model \"" .. from .. "\": to \"" .. to .. "\"", LK3D_SEVERITY_DEBUG, "ModelUtils")
end

include("mdlformats/source_engine/source_engine_mdlformat.lua")
include("mdlformats/lkcomp_legacy/lkcomp_legacy_mdlformat.lua")
include("mdlformats/lkcomp/lkcomp_mdlformat.lua")
include("mdlformats/wavefront_obj/obj_mdlformat.lua")
include("mdlformats/fam_legacy/fam_legacy_mdlformat.lua")

LK3D.AnimatedModelRegistry = LK3D.AnimatedModelRegistry or {}

local fake_SunDir = Vector(0.75, 1, 1)
fake_SunDir:Normalize()


local mesh = mesh
local mesh_Begin = mesh.Begin
local mesh_Position = mesh.Position
local mesh_Color = mesh.Color
local mesh_TexCoord = mesh.TexCoord
local mesh_AdvanceVertex = mesh.AdvanceVertex
local mesh_End = mesh.End


local function makeRegistryMesh(mdlinfo, shade, smooth)
	local verts = mdlinfo.verts
	local uvs = mdlinfo.uvs
	local ind = mdlinfo.indices
	local normals = mdlinfo.normals
	local s_norm = mdlinfo.s_normals


	local mesh_obj = Mesh()
	mesh_Begin(mesh_obj, MATERIAL_TRIANGLES, #ind)
	for i = 1, #ind do
		local index = ind[i]

		local v1 = Vector(verts[index[1][1]])
		local v2 = Vector(verts[index[2][1]])
		local v3 = Vector(verts[index[3][1]])

		local uv1 = uvs[index[1][2]]
		local uv2 = uvs[index[2][2]]
		local uv3 = uvs[index[3][2]]


		local norm = normals[i]:GetNormalized()


		local shVal1, shVal2, shVal3 = 255, 255, 255
		if shade then
			if smooth then -- gouraud
				local sn1 = Vector(s_norm[index[1][1]])
				local sn2 = Vector(s_norm[index[2][1]])
				local sn3 = Vector(s_norm[index[3][1]])

				sn1:Normalize()
				sn2:Normalize()
				sn3:Normalize()

				local shPr1 = ((sn1:Dot(fake_SunDir) + 1) / 3) + 0.333
				local shPr2 = ((sn2:Dot(fake_SunDir) + 1) / 3) + 0.333
				local shPr3 = ((sn3:Dot(fake_SunDir) + 1) / 3) + 0.333
				--local shCalc0 = (shPr1 + shPr2 + shPr3) / 3

				shVal1 = shVal1 * shPr1
				shVal2 = shVal2 * shPr2
				shVal3 = shVal3 * shPr3

				--[[
				shVal1 = shVal1 * ((sn1:Dot(fake_SunDir) + 1) / 3) + 0.333
				shVal2 = shVal2 * ((sn2:Dot(fake_SunDir) + 1) / 3) + 0.333
				shVal3 = shVal3 * ((sn3:Dot(fake_SunDir) + 1) / 3) + 0.333
				]]--
			else -- flat
				local shCalc0 = ((norm:Dot(fake_SunDir) + 1) / 3) + 0.333
				shVal1 = shVal1 * shCalc0
				shVal2 = shVal2 * shCalc0
				shVal3 = shVal3 * shCalc0
			end
		end


		mesh_Position(v3)
		mesh_Color(shVal3, shVal3, shVal3, 255)
		mesh_TexCoord(0, uv3[1], uv3[2])
		mesh_AdvanceVertex()

		mesh_Position(v2)
		mesh_Color(shVal2, shVal2, shVal2, 255)
		mesh_TexCoord(0, uv2[1], uv2[2])
		mesh_AdvanceVertex()

		mesh_Position(v1)
		mesh_Color(shVal1, shVal1, shVal1, 255)
		mesh_TexCoord(0, uv1[1], uv1[2])
		mesh_AdvanceVertex()
	end
	mesh_End()

	return mesh_obj
end


function LK3D.DeclareAnimatedModel(name, fpath, flush)
	LK3D.New_D_Print("Loading Animated model \"" .. name .. "\" (" .. fpath .. ") from LKPack!", LK3D_SEVERITY_INFO, "ModelUtils")
	local jsonInfo = LK3D.ReadFileFromLKPack("models/" .. fpath .. "/params.json")
	local params = util.JSONToTable(jsonInfo)

	if not params then
		LK3D.New_D_Print("Failed to load JSON info when loading animated model \"" .. name .. "\"!", LK3D_SEVERITY_ERROR, "ModelUtils")
		return
	end

	local mdlName = params.modelName
	local mdlFormat = params.modelFormat or "obj"


	if mdlFormat == "obj" then
		local objBase = LK3D.ReadFileFromLKPack("models/" .. fpath .. "/" .. mdlName .. ".obj")
		LK3D.AddModelOBJ(name, objBase)
	elseif mdlFormat == "fam" then
		local realPath = LK3D.GetDataPathToFile("models/" .. fpath .. "/" .. mdlName .. ".fam")
		local mdlData = LK3D.LoadFastAnimatedModel(realPath)
		LK3D.Models[name] = mdlData
	end

	if not LK3D.AnimatedModelRegistry[mdlName] or flush then
		LK3D.AnimatedModelRegistry[mdlName] = {
			name = mdlName,
			anims = {},
		}
	end

	local regTbl = LK3D.AnimatedModelRegistry[mdlName]

	for k, v in pairs(params.animations) do
		local animIndex = k
		local fStart = tonumber(v.fStart)
		local fEnd = tonumber(v.fEnd)

		if not regTbl.anims[animIndex] or flush then
			regTbl.anims[animIndex] = {
				fStart = fStart,
				fEnd = fEnd,
				meshesFB = {},
				meshesFlat = {},
				meshesSmooth = {}
			}
		end


		local animPtr = regTbl.anims[animIndex]
		for i = fStart, fEnd do
			local safeInd = (i - fStart) + 1

			if animPtr.meshesFB[safeInd] and (not flush) then
				continue
			end

			if LK3D.RenderProcessingMessage and i % 48 then
				LK3D.RenderProcessingMessage("Anim load [" .. name .. ": " .. animIndex .. "]", ((i - fStart) / (fEnd - fStart)) * 100)
			end

			local data, hadNormal = {}, false
			if mdlFormat == "obj" then
				local objStr = LK3D.ReadFileFromLKPack("models/" .. fpath .. "/anims/" .. animIndex .. "/" .. mdlName .. i .. ".obj")
				data, hadNormal = LK3D.ParseOBJMesh(objStr)
				if not hadNormal then
					LK3D.GenerateNormals(data)
				end
			elseif mdlFormat == "fam" then
				local realPath =  LK3D.GetDataPathToFile("models/" .. fpath .. "/anims/" .. animIndex .. "/" .. mdlName .. i .. ".fam")
				data = LK3D.LoadFastAnimatedModel(realPath)
			end


			animPtr.meshesFB[safeInd] = makeRegistryMesh(data, false, false)
			animPtr.meshesFlat[safeInd] = makeRegistryMesh(data, true, false)
			animPtr.meshesSmooth[safeInd] = makeRegistryMesh(data, true, true)
		end
	end
end

function LK3D.PushModelAnims(index, an_index)
	local object = LK3D.CurrUniv["objects"][index]

	if object.mdl ~= an_index then
		return
	end

	if object.mdlCache == nil then
		object.mdlCache = {}
	end


	local regTbl = LK3D.AnimatedModelRegistry[an_index]
	for k, v in pairs(regTbl.anims) do
		local frameCount = v.fEnd - v.fStart
		object.mdlCache[k] = {
			frames = frameCount,
			func = function() end,
			meshes = {},
			genned = true
		}

		local meshPush = nil
		if not object["NO_SHADING"] then
			if object["SHADING_SMOOTH"] then
				meshPush = v.meshesSmooth
			else
				meshPush = v.meshesFlat
			end
		else
			meshPush = v.meshesFB
		end

		object.mdlCache[k].meshes = meshPush
	end

	object.anim_delta = object.anim_delta or 0
	object.anim_rate = object.anim_rate or 1
	object.anim_state = object.anim_state or true
end


LK3D.New_D_Print("LK3D modelutils fully loaded!", LK3D_SEVERITY_INFO, "Base")