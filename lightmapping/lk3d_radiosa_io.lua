--[[--
## Lightmapping / Radiosity
---

Module that generates calculates lightmaps on objects using radiosity  
Rewritten from scratch again, major issues solved and speed increased!!  
This module is basically a GLua implementation of [this radiosity article](https://www.jmeiners.com/Hugo-Elias-Radiosity/)  
[Reading the manual entry on the lightmapper is recommended!](../manual/lightmapper-radiosity.md.html)
]]

LK3D = LK3D or {}
LK3D.Radiosa = LK3D.Radiosa or {}


file.CreateDir("lk3d/lightmap_export")
file.CreateDir("lk3d/lightmap_export/" .. engine.ActiveGamemode())

-- Export
local function copyUV(uv)
	return {uv[1], uv[2]}
end

-- a more simplistic file format, less compressed than others
local function exportLightmapObject(obj, obj_id) -- this exports it as custom file lightmap
	if not obj_id then
		LK3D.New_D_Print("Attempt to export lightmap for non-existing object!", LK3D_SEVERITY_ERROR, "Radiosity")
		return
	end


	LK3D.New_D_Print("Exporting lightmap for object \"" .. obj_id .. "\"", LK3D_SEVERITY_DEBUG, "Radiosity")

	local tag = LK3D.CurrUniv["tag"]
	local targ_folder = "lk3d/lightmap_export/" .. engine.ActiveGamemode() .. "/" .. tag .. "/"

	file.Write(targ_folder .. obj_id .. "_temp.txt", "temp")
	local f_pointer_temp = file.Open(targ_folder .. obj_id .. "_temp.txt", "wb", "DATA")

	local lm_t = obj.limap_tex

	local tex_p = LK3D.Textures[lm_t]
	local tw, th = tex_p.rt:Width(), tex_p.rt:Height()
	LK3D.New_D_Print("Lightmap resolution is " .. tw .. "x" .. th, LK3D_SEVERITY_DEBUG, "Radiosity")

	f_pointer_temp:Write("LKL2") -- lkl2 header LKLight2
	f_pointer_temp:WriteULong(tw)
	f_pointer_temp:WriteULong(th)

	-- lets capture with png instead
	local ow, oh = ScrW(), ScrH()
	render.SetViewPort(0, 0, tw, th)
	render.PushRenderTarget(tex_p.rt)
		local png_data = render.Capture({
			format = "png",
			alpha = true,
			x = 0,
			y = 0,
			w = tw,
			h = th,
		})
	render.PopRenderTarget()
	render.SetViewPort(0, 0, ow, oh)

	if not png_data then
		LK3D.New_D_Print("Failure to render.Capture the PNG (main menu was open), Aborting!", LK3D_SEVERITY_ERROR, "Radiosity")
		f_pointer_temp:Close()
		file.Delete(targ_folder .. obj_id .. "_temp.txt", "DATA")

		return
	end


	-- write data temporarily
	file.Write("lk3d/lightmap_temp/export_png.png", png_data)
	local f_pointer_pngDat = file.Open("lk3d/lightmap_temp/export_png.png", "rb", "DATA")

	local length_png_data = #png_data

	local chunkSz = 16384
	local chunkCount = math.ceil(length_png_data / chunkSz)
	chunkCount = math.max(chunkCount, 1)
	LK3D.New_D_Print("File will have " .. chunkCount .. " PNGChunks...", LK3D_SEVERITY_DEBUG, "Radiosity")

	-- split into chunks
	f_pointer_temp:WriteULong(chunkCount)
	local lengthAccum = length_png_data
	for i = 1, chunkCount do
		local lengthCurr = math.min(lengthAccum, chunkSz)
		lengthAccum = lengthAccum - chunkSz
		LK3D.New_D_Print("Chunk º" .. i .. "; Length " .. lengthCurr, LK3D_SEVERITY_DEBUG, "Radiosity")


		f_pointer_temp:WriteULong(lengthCurr)
		f_pointer_temp:Write(f_pointer_pngDat:Read(lengthCurr))
	end
	f_pointer_pngDat:Close()
	f_pointer_temp:Write("DNE") -- done




	local object_uvs = {}
	local lm_uvs = obj.lightmap_uvs

	for i = 1, #lm_uvs do
		object_uvs[#object_uvs + 1] = copyUV(lm_uvs[i])
	end

	--local object_uvs = {}
	--local tri_list = LK3D.Radiosa.GetTriTable(obj_id)

	--[[
	for k, v in ipairs(tri_list) do
		object_uvs[#object_uvs + 1] = {
			copyUV(v[1].lm_uv),
			copyUV(v[2].lm_uv),
			copyUV(v[3].lm_uv),
		}
	end
	]]--

	local uv_count = #object_uvs
	f_pointer_temp:WriteULong(uv_count)
	for i = 1, uv_count do
		local uv_dat = object_uvs[i]
		f_pointer_temp:WriteDouble(uv_dat[1])
		f_pointer_temp:WriteDouble(uv_dat[2])
	end
	f_pointer_temp:Write("DNE") -- done

	-- indices to lm uvs [idx 3 on model]
	local mdlinfo = LK3D.Models[obj.mdl]
	local indices = mdlinfo.indices

	local index_count = #indices -- each index is a tri so each thing holds 3
	f_pointer_temp:WriteULong(index_count)
	for i = 1, index_count do
		local index = indices[i]
		f_pointer_temp:WriteULong(index[1][3])
		f_pointer_temp:WriteULong(index[2][3])
		f_pointer_temp:WriteULong(index[3][3])
	end
	f_pointer_temp:Write("DNE") -- done


	f_pointer_temp:Write("LKLM") -- header end
	f_pointer_temp:Close()

	file.Write(targ_folder .. obj_id .. ".llm.txt", util.Compress(file.Read(targ_folder .. obj_id .. "_temp.txt", "DATA")))
	file.Delete(targ_folder .. obj_id .. "_temp.txt", "DATA")
end

--- Exports all of the lightmaps on the active universe
-- @usage LK3D.ExportLightmaps()
function LK3D.ExportLightmaps()
	if not LK3D.CurrUniv["tag"] then
		LK3D.New_D_Print("Attempting to export lightmaps for a universe without a tag!", LK3D_SEVERITY_ERROR, "Radiosity")
		return
	end

	local tag = LK3D.CurrUniv["tag"]
	local targ_folder = "lk3d/lightmap_export/" .. engine.ActiveGamemode() .. "/" .. tag .. "/"
	file.CreateDir(targ_folder)

	for k, v in pairs(LK3D.CurrUniv["objects"]) do
		local lm_tex = v.limap_tex
		if not lm_tex then -- object not lightmapped
			continue
		end

		exportLightmapObject(v, k)
	end

	LK3D.New_D_Print("Exported lightmaps for universe \"" .. tag .. "\"!", LK3D_SEVERITY_INFO, "Radiosity")
	LK3D.New_D_Print("Lightmaps are located at \"data/" .. targ_folder .. "\"", LK3D_SEVERITY_INFO, "Radiosity")
end

concommand.Add("lk3d_exportlightmaps", function(ply, cmd, args)
	if not args[1] then
		LK3D.New_D_Print("Usage: lk3d_exportlightmaps <universeName>", LK3D_SEVERITY_WARN, "Radiosity")
		return
	end

	local univ = LK3D.UniverseRegistry[args[1]]
	if univ == nil then
		LK3D.New_D_Print("Target Universe \"" .. args[1] .. "\" doesnt exist!", LK3D_SEVERITY_WARN, "Radiosity")
		return
	end

	LK3D.PushUniverse(univ)
		LK3D.ExportLightmaps()
	LK3D.PopUniverse()
end)



file.CreateDir("lk3d/lightmap_temp")
file.CreateDir("lk3d/lightmap_temp/" .. engine.ActiveGamemode())
local targ_temp = "lk3d/lightmap_temp/" .. engine.ActiveGamemode() .. "/"
local lastAccumChange = CurTime()
local lightmapAccum = 0
local matDontDeleteArchive = {}

local function loadLightmapObject_Legacy(data, tag, obj_idx)
	if CurTime() > lastAccumChange then
		lightmapAccum = 0
	end
	lastAccumChange = CurTime() + 2
	lightmapAccum = lightmapAccum + 1
	if not data then
		LK3D.New_D_Print("Attempting to load lightmap with no data!", LK3D_SEVERITY_ERROR, "Radiosity")
		return
	end

	file.Write(targ_temp .. "temp1.txt", util.Decompress(data))


	local f_pointer_temp = file.Open(targ_temp .. "temp1.txt", "rb", "DATA")
	local header = f_pointer_temp:Read(4)
	if header ~= "LKLM" then
		LK3D.New_D_Print("Failure decoding LKLM file! (start header no match)", LK3D_SEVERITY_ERROR, "Radiosity")
		f_pointer_temp:Close()
		return
	end

	local tw = f_pointer_temp:ReadULong() * LK3D.LightmapUpscale
	local th = f_pointer_temp:ReadULong() * LK3D.LightmapUpscale


	local prevFilter = LK3D.FilterMode
	LK3D.SetFilterMode(LK3D.LightmapFilterMode)
	local lm_tex_idx = "lightmap_" .. tag .. "_" .. obj_idx .. "_" .. tw .. "_" .. th
	LK3D.DeclareTextureFromFunc(lm_tex_idx, tw, th, function()
		render.Clear(4, 32, 8, 255)
		draw.SimpleText("Lightmap Load, Stage1", "BudgetLabel", 0, 0, Color(16, 255, 32))
	end)
	LK3D.SetFilterMode(prevFilter)

	local thing_path = targ_temp .. tag .. "_" .. obj_idx .. "_" .. tw .. "_" .. th .. ".png"
	local png_data_writer = file.Open(thing_path, "wb", "DATA")

	local chunkCount = f_pointer_temp:ReadULong()
	for i = 1, chunkCount do
		local lengthRead = f_pointer_temp:ReadULong()
		png_data_writer:Write(f_pointer_temp:Read(lengthRead))
	end
	png_data_writer:Close()

	local read_post_verif = f_pointer_temp:Read(3)
	if read_post_verif ~= "DNE" then
		LK3D.New_D_Print("Failure decoding LKLM file! (colour DNE fail)", LK3D_SEVERITY_ERROR, "Radiosity")
		f_pointer_temp:Close()
		return
	end

	if not matDontDeleteArchive[tag] then
		matDontDeleteArchive[tag] = {}
	end

	--matDontDeleteArchive[tag][obj_idx] = Material("../data/" .. thing_path, "ignorez nocull") -- actually load it
	timer.Simple(2, function() -- wait abit before loading
		local _lmMat = Material("../data/" .. thing_path, "ignorez nocull")

		local prevFilter = LK3D.FilterMode
		LK3D.SetFilterMode(LK3D.LightmapFilterMode)
		LK3D.DeclareTextureFromFunc(lm_tex_idx, tw, th, function()
			render.Clear(4, 8, 32, 255)
			draw.SimpleText("Lightmap Load, Stage2", "BudgetLabel", 0, 0, Color(16, 32, 255))

			surface.SetMaterial(_lmMat)
			surface.SetDrawColor(255, 255, 255, 255)
			surface.DrawTexturedRect(0, 0, tw, th)
		end)
		LK3D.SetFilterMode(prevFilter)
		--file.Delete(thing_path, "DATA") -- this breaks lightmapping
	end)

	local lm_uvs = {}
	local tri_count = f_pointer_temp:ReadULong()
	for i = 1, tri_count do
		local uv1 = {
			math.Round(f_pointer_temp:ReadDouble(), 8),
			math.Round(f_pointer_temp:ReadDouble(), 8)
		}

		local uv2 = {
			math.Round(f_pointer_temp:ReadDouble(), 8),
			math.Round(f_pointer_temp:ReadDouble(), 8)
		}

		local uv3 = {
			math.Round(f_pointer_temp:ReadDouble(), 8),
			math.Round(f_pointer_temp:ReadDouble(), 8)
		}

		lm_uvs[#lm_uvs + 1] = uv1
		lm_uvs[#lm_uvs + 1] = uv2
		lm_uvs[#lm_uvs + 1] = uv3
	end

	read_post_verif = f_pointer_temp:Read(3)
	if read_post_verif ~= "DNE" then
		LK3D.New_D_Print("Failure decoding LKLM file! (lm_uv DNE fail)", LK3D_SEVERITY_ERROR, "Radiosity")
		f_pointer_temp:Close()
		return
	end

	local obj_ptr = LK3D.CurrUniv["objects"][obj_idx]
	local mdlinfo = LK3D.Models[obj_ptr.mdl]
	if not mdlinfo then
		LK3D.New_D_Print("Model \"" .. obj_ptr.mdl .. "\" doesnt exist!", LK3D_SEVERITY_ERROR, "Radiosity")
		return
	end

	local indices = mdlinfo.indices

	local index_count = f_pointer_temp:ReadULong()
	for i = 1, index_count do
		indices[i][1][3] = f_pointer_temp:ReadULong()
		indices[i][2][3] = f_pointer_temp:ReadULong()
		indices[i][3][3] = f_pointer_temp:ReadULong()
	end

	read_post_verif = f_pointer_temp:Read(3)
	if read_post_verif ~= "DNE" then
		LK3D.New_D_Print("Failure decoding LKLM file! (index_lm DNE fail)", LK3D_SEVERITY_ERROR, "Radiosity")
		f_pointer_temp:Close()
		return
	end

	local read_header_end = f_pointer_temp:Read(4)
	f_pointer_temp:Close()
	if read_header_end ~= "LKLM" then
		LK3D.New_D_Print("Failure decoding LKLM file! (end header fail)", LK3D_SEVERITY_ERROR, "Radiosity")
		return
	end



	LK3D.CurrUniv["objects"][obj_idx].limap_tex = lm_tex_idx
	LK3D.CurrUniv["objects"][obj_idx].lightmap_uvs = lm_uvs
end


local function loadLightmapObject(data, tag, obj_idx)
	if CurTime() > lastAccumChange then
		lightmapAccum = 0
	end
	lastAccumChange = CurTime() + 2
	lightmapAccum = lightmapAccum + 1
	if not data then
		LK3D.New_D_Print("Attempting to load lightmap with no data!", LK3D_SEVERITY_ERROR, "Radiosity")
		return
	end

	file.Write(targ_temp .. "temp1.txt", util.Decompress(data))


	local f_pointer_temp = file.Open(targ_temp .. "temp1.txt", "rb", "DATA")
	local header = f_pointer_temp:Read(4)
	if header ~= "LKL2" then
		LK3D.New_D_Print("Failure decoding LKLM file! (start header no match)", LK3D_SEVERITY_ERROR, "Radiosity")
		f_pointer_temp:Close()
		return
	end

	local tw = f_pointer_temp:ReadULong() * LK3D.LightmapUpscale
	local th = f_pointer_temp:ReadULong() * LK3D.LightmapUpscale


	local prevFilter = LK3D.FilterMode
	LK3D.SetFilterMode(LK3D.LightmapFilterMode)
	local lm_tex_idx = "lightmap_new_" .. tag .. "_" .. obj_idx .. "_" .. tw .. "_" .. th
	LK3D.DeclareTextureFromFunc(lm_tex_idx, tw, th, function()
		render.Clear(4, 32, 8, 255)
		draw.SimpleText("Lightmap Load, Stage1", "BudgetLabel", 0, 0, Color(16, 255, 32))
	end)
	LK3D.SetFilterMode(prevFilter)

	local thing_path = targ_temp .. tag .. "_" .. obj_idx .. "_" .. tw .. "_" .. th .. ".png"
	local png_data_writer = file.Open(thing_path, "wb", "DATA")

	local chunkCount = f_pointer_temp:ReadULong()
	for i = 1, chunkCount do
		local lengthRead = f_pointer_temp:ReadULong()
		png_data_writer:Write(f_pointer_temp:Read(lengthRead))
	end
	png_data_writer:Close()

	local read_post_verif = f_pointer_temp:Read(3)
	if read_post_verif ~= "DNE" then
		LK3D.New_D_Print("Failure decoding LKLM file! (colour DNE fail)", LK3D_SEVERITY_ERROR, "Radiosity")
		f_pointer_temp:Close()
		return
	end

	if not matDontDeleteArchive[tag] then
		matDontDeleteArchive[tag] = {}
	end

	--matDontDeleteArchive[tag][obj_idx] = Material("../data/" .. thing_path, "ignorez nocull") -- actually load it
	timer.Simple(2, function() -- wait abit before loading
		local _lmMat = Material("../data/" .. thing_path, "ignorez nocull")

		local prevFilter = LK3D.FilterMode
		LK3D.SetFilterMode(LK3D.LightmapFilterMode)
		LK3D.DeclareTextureFromFunc(lm_tex_idx, tw, th, function()
			render.Clear(4, 8, 32, 255)
			draw.SimpleText("Lightmap Load, Stage2", "BudgetLabel", 0, 0, Color(16, 32, 255))

			surface.SetMaterial(_lmMat)
			surface.SetDrawColor(255, 255, 255, 255)
			surface.DrawTexturedRect(0, 0, tw, th)
		end)

		LK3D.SetFilterMode(prevFilter)

		--file.Delete(thing_path, "DATA") -- this breaks lightmapping
	end)

	local lm_uvs = {}
	local uv_count = f_pointer_temp:ReadULong()
	for i = 1, uv_count do
		local uv = {
			math.Round(f_pointer_temp:ReadDouble(), 8),
			math.Round(f_pointer_temp:ReadDouble(), 8)
		}
		lm_uvs[#lm_uvs + 1] = uv
	end

	read_post_verif = f_pointer_temp:Read(3)
	if read_post_verif ~= "DNE" then
		LK3D.New_D_Print("Failure decoding LKLM file! (lm_uv DNE fail)", LK3D_SEVERITY_ERROR, "Radiosity")
		f_pointer_temp:Close()
		return
	end

	local obj_ptr = LK3D.CurrUniv["objects"][obj_idx]
	local mdlinfo = LK3D.Models[obj_ptr.mdl]
	if not mdlinfo then
		LK3D.New_D_Print("Model \"" .. obj_ptr.mdl .. "\" doesnt exist!", LK3D_SEVERITY_ERROR, "Radiosity")
		return
	end

	local indices = mdlinfo.indices

	local index_count = f_pointer_temp:ReadULong()
	for i = 1, index_count do
		indices[i][1][3] = f_pointer_temp:ReadULong()
		indices[i][2][3] = f_pointer_temp:ReadULong()
		indices[i][3][3] = f_pointer_temp:ReadULong()
	end

	read_post_verif = f_pointer_temp:Read(3)
	if read_post_verif ~= "DNE" then
		LK3D.New_D_Print("Failure decoding LKLM file! (index_lm DNE fail)", LK3D_SEVERITY_ERROR, "Radiosity")
		f_pointer_temp:Close()
		return
	end

	local read_header_end = f_pointer_temp:Read(4)
	f_pointer_temp:Close()
	if read_header_end ~= "LKLM" then
		LK3D.New_D_Print("Failure decoding LKLM file! (end header fail)", LK3D_SEVERITY_ERROR, "Radiosity")
		return
	end



	LK3D.CurrUniv["objects"][obj_idx].limap_tex = lm_tex_idx
	LK3D.CurrUniv["objects"][obj_idx].lightmap_uvs = lm_uvs
end

--- Loads a lightmap of an object from a file in LKPack
-- @tparam string obj_idx Index tag of the object
-- @usage LK3D.LoadLightmapFromFile("sub_lower")
function LK3D.LoadLightmapFromFile(obj_idx)
	LK3D.ClearLightmapCache() -- attempt to clear cache first

	local tag = LK3D.CurrUniv["tag"]
	if not tag then
		LK3D.New_D_Print("Attempting to load lightmap on universe with no tag!", LK3D_SEVERITY_ERROR, "Radiosity")
		return
	end

	local obj_check = LK3D.CurrUniv["objects"][obj_idx]
	if not obj_check then
		LK3D.New_D_Print("Attempting to load lightmap for non-existing object \"" .. obj_idx .. "\"!", LK3D_SEVERITY_ERROR, "Radiosity")
		return
	end


	local fcontents = LK3D.ReadFileFromLKPack("lightmaps/" .. tag .. "/" .. obj_idx .. ".llm")
	if not fcontents then
		LK3D.New_D_Print("Attempting to load missing lightmap from LKPack! (" .. tag .. "): [" .. obj_idx .. "]", LK3D_SEVERITY_ERROR, "Radiosity")
		return
	end


	-- we must parse the header now to check if we have a new-gen one or old-gen one
	file.Write(targ_temp .. "temp1.txt", util.Decompress(fcontents))

	local f_pointer_temp = file.Open(targ_temp .. "temp1.txt", "rb", "DATA")
	local header = f_pointer_temp:Read(4)
	f_pointer_temp:Close()

	if header == "LKLM" then -- legacy
		loadLightmapObject_Legacy(fcontents, tag, obj_idx)
	elseif header == "LKL2" then -- radiosa new
		loadLightmapObject(fcontents, tag, obj_idx)
	else
		LK3D.New_D_Print("Attempt to load lightmap with unknown header \"" .. header .. "\"!", LK3D_SEVERITY_ERROR, "Radiosity")
		return
	end

	LK3D.New_D_Print("Loaded lightmap for \"" .. obj_idx .. "\" from LKPack successfully!", LK3D_SEVERITY_INFO, "Radiosity")
end



-- Clearing
LK3D_LIGHTMAP_HAVE_WE_CLEARED_GLOBAL = LK3D_LIGHTMAP_HAVE_WE_CLEARED_GLOBAL or false
local function recursiveClearCache(base)
	local files, dirs = file.Find(base .. "/*.png", "LUA")

	for k, v in ipairs(files) do
		-- now delete
		local fPath = base .. "/" .. v
		file.Delete(fPath)
		LK3D.New_D_Print("Deleted PNG cache file \"" .. fPath .. "\"", LK3D_SEVERITY_DEBUG, "Radiosity")
	end

	for k, v in ipairs(dirs) do
		-- empty child folders
		recursiveClearCache(base .. "/" .. v)
	end
end




--- Clears the PNG lightmap cache  
-- @usage LK3D.ClearLightmapCache()
function LK3D.ClearLightmapCache()
	if LK3D_LIGHTMAP_HAVE_WE_CLEARED_GLOBAL then
		return
	end
	LK3D_LIGHTMAP_HAVE_WE_CLEARED_GLOBAL = true

	LK3D.New_D_Print("Clearing lightmap PNG cache!", LK3D_SEVERITY_DEBUG, "Radiosity")
	local root = "lk3d/lightmap_temp/"
	recursiveClearCache(root)

	LK3D.New_D_Print("Cleared lightmap PNG cache successfully!", LK3D_SEVERITY_DEBUG, "Radiosity")
end
