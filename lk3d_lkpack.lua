--[[--
## LK3D Data Archive
---

Module to handle LKPack, a method to pack data into a single .ain file for workshop  
It is highly recommended to read through the Basics of LKPack manual first before using these functions.
]]
-- @module lkpack

LK3D = LK3D or {}
-- LK3D LKPACK
-- lk3d file that gets packed into .ain which can later be loaded
-- used for adding alot of content w/o needing to split it into 64kb lua files
file.CreateDir("lk3d/lkpack/compile")
file.CreateDir("lk3d/lkpack/out")
file.CreateDir("lk3d/lkpack/temp")
file.CreateDir("lk3d/lkpack/decomp_active")

local VAL_FOLDER_ID = 0xFFFFFFFF

LK3D.ActiveLKPack = LK3D.ActiveLKPack

-- makes a flat table which has each key being 
-- {
--      ftype = 1,
--      name = "hello.txt",
--      parent = "folder/"
--}
local function recursive_build_file_table(path, path_rela, tbl_ptr)
	path_rela = path_rela or "/"
	local files, dirs = file.Find(path .. path_rela .. "*", "DATA")
	for k, v in pairs(files) do
		tbl_ptr[#tbl_ptr + 1] = {
			ftype = 1,
			name = v,
			parent = path_rela,
			read_path = path .. path_rela .. v
		}
	end

	for k, v in pairs(dirs) do
		tbl_ptr[#tbl_ptr + 1] = {
			ftype = 2,
			name = v,
			parent = path_rela,
		}
		recursive_build_file_table(path, path_rela .. v .. "/", tbl_ptr)
	end
end



--- Creates an LKPack file from a dev directory
-- @tparam string dir Dev directory to turn into an LKPack
-- @usage LK3D.MakeLKPack("deepdive_content")
function LK3D.MakeLKPack(dir)
	if not dir then
		return
	end

	local exists = file.Exists("lk3d/lkpack/compile/" .. dir, "DATA")
	if not exists then
		LK3D.New_D_Print("Dir doesnt exist!", LK3D_SEVERITY_ERROR, "LKPack")
		return
	end
	LK3D.New_D_Print("Make LKPack", LK3D_SEVERITY_INFO, "LKPack")

	LK3D.PushProcessingMessage("Making LKPack for \"" .. dir .. "\"")

	local descriptors = {}
	recursive_build_file_table("lk3d/lkpack/compile/" .. dir, "/" , descriptors)
	local descriptorCount = #descriptors

	LK3D.PushProcessingMessage("Descriptor count: " .. tostring(descriptorCount))


	local file_count, dir_count = 0, 0
	for k, v in ipairs(descriptors) do
		LK3D.RenderProcessingMessage("MakeLKPack; Descriptor build [" .. v.name .. "]", (k / descriptorCount) * 100)

		if v.ftype == 1 then
			file_count = file_count + 1
		else
			dir_count = dir_count + 1
		end
	end
	--PrintTable(descriptors)

	-- the lookup table with the compressed contents of file, generate
	local index_arr = {}
	local id_to_descriptor = {}
	local descriptor_to_name = {}
	local descriptor_to_parent = {}
	local descriptor_to_file = {}

	local last_file_id = 1
	for k, v in ipairs(descriptors) do
		LK3D.RenderProcessingMessage("MakeLKPack; Descriptor LUTProcess [" .. v.name .. "]", (k / descriptorCount) * 100)



		descriptor_to_name[k] = v.name
		descriptor_to_parent[k] = v.parent
		descriptor_to_file[k] = v.ftype == 1 and last_file_id or -1

		if v.ftype == 2 then -- its folder, we make folder pointers later
			continue
		end

		v.file_id = last_file_id
		id_to_descriptor[last_file_id] = k

		local read = file.Read(v.read_path)
		index_arr[last_file_id] = util.Compress(read) -- we compress already

		last_file_id = last_file_id + 1
	end

	file.Write("lk3d/lkpack/temp/" .. dir .. ".ain.txt", "TEMP")
	local temp_f = file.Open("lk3d/lkpack/temp/" .. dir .. ".ain.txt", "wb", "DATA")
	temp_f:Write("LKPA")

	LK3D.PushProcessingMessage("Write descriptorCount")
	temp_f:WriteULong(#descriptors) -- write descriptor count

	-- write the descriptor_to_name lookup table
	--temp_f:WriteULong(#descriptor_to_name) -- number of entries
	LK3D.PushProcessingMessage("Write descriptorToName")
	for k, v in ipairs(descriptor_to_name) do
		temp_f:WriteULong(#v)
		temp_f:Write(v)
	end
	temp_f:WriteByte(0xF0) -- tag as done

	-- write the descriptor_to_parent lookup table
	--temp_f:WriteULong(#descriptor_to_parent) -- number of entries
	LK3D.PushProcessingMessage("Write descriptorToParent")
	for k, v in ipairs(descriptor_to_parent) do
		temp_f:WriteULong(#v)
		temp_f:Write(v)
	end
	temp_f:WriteByte(0xF0) -- tag as done

	-- write descriptor types
	--temp_f:WriteULong(#descriptor_to_type)
	LK3D.PushProcessingMessage("Write descriptorToFile")
	for k, v in ipairs(descriptor_to_file) do
		if v == -1 then
			temp_f:WriteULong(VAL_FOLDER_ID)
		else
			temp_f:WriteULong(v)
		end
	end
	temp_f:WriteByte(0xF0) -- tag as done


	-- now write the content table
	LK3D.PushProcessingMessage("Write content table")
	local indexArrCount = #index_arr
	temp_f:WriteULong(indexArrCount)
	for k, v in ipairs(index_arr) do
		LK3D.RenderProcessingMessage("MakeLKPack; WriteIndexContent [" .. tostring(k) .. "] sz. " .. tostring(#v), (k / indexArrCount) * 100)
		temp_f:WriteULong(#v)
		temp_f:Write(v)
	end
	temp_f:WriteByte(0xF0) -- tag as done
	temp_f:Write("LKPA") -- done marker
	temp_f:Close()


	local read_temp = file.Read("lk3d/lkpack/temp/" .. dir .. ".ain.txt")
	if not read_temp then
		LK3D.New_D_Print("Failed while creating, tempfile (" .. dir .. ") doesnt exist", LK3D_SEVERITY_ERROR, "LKPack")
		return
	end


	file.Write("lk3d/lkpack/out/" .. dir .. ".lkp.ain.txt", "FNAL")
	local real_f = file.Open("lk3d/lkpack/out/" .. dir .. ".lkp.ain.txt", "wb", "DATA")
	real_f:Write(util.Compress(read_temp))
	real_f:Close()

	LK3D.New_D_Print("LKPack generated for \"" .. dir .. "\"", LK3D_SEVERITY_INFO, "LKPack")
end

--- Loads an LKPack and sets it as the active LKPack
-- @tparam string name Name of the LKPack to load, relative to maps/
-- @usage LK3D.LoadLKPack("deepdive_content")
function LK3D.LoadLKPack(name)
	if LK3D.ActiveLKPack == name then -- Already loaded, avoid lagspike and abort!
		return
	end

	local data = file.Read("maps/" .. name .. ".lkp.ain", "GAME")
	if not data then
		LK3D.New_D_Print("LKPack doesnt exist! (" .. name .. ") [" .. "maps/" .. name .. ".lkp.ain]", LK3D_SEVERITY_FATAL, "LKPack")
		return
	end


	local data_dc = util.Decompress(data)
	if not data_dc then
		LK3D.New_D_Print("Fail decompressing LKPack! (" .. name .. ")", LK3D_SEVERITY_FATAL, "LKPack")
		return
	end

	file.Write("lk3d/lkpack/temp/" .. name .. ".txt", data_dc)

	local fp_decomp = file.Open("lk3d/lkpack/temp/" .. name .. ".txt", "rb", "DATA")
	if not fp_decomp then
		LK3D.New_D_Print("Fail making temp read file! (" .. name .. ")", LK3D_SEVERITY_FATAL, "LKPack")
		return
	end

	LK3D.PushProcessingMessage("Loading LKPack \"" .. name .. "\"!")

	local header = fp_decomp:Read(4)
	if header ~= "LKPA" then
		LK3D.New_D_Print("Header doesnt match! (possible corrupted file or unsupported revision, please update...) (" .. name .. ")", LK3D_SEVERITY_FATAL, "LKPack")
		fp_decomp:Close()
		return
	end



	local descriptor_count = fp_decomp:ReadULong()
	LK3D.New_D_Print(descriptor_count .. " descriptors...", LK3D_SEVERITY_DEBUG, "LKPack")
	LK3D.PushProcessingMessage("Descriptor count: " .. tostring(descriptor_count))

	-- name LUT
	local name_lut = {}
	for i = 1, descriptor_count do
		local read_len = fp_decomp:ReadULong()
		name_lut[i] = fp_decomp:Read(read_len)
	end

	local read_check = fp_decomp:ReadByte()
	if read_check ~= 0xF0 then
		LK3D.New_D_Print("Error while decoding! (name lut ~= 0xF0) (" .. name .. ")", LK3D_SEVERITY_FATAL, "LKPack")
		fp_decomp:Close()
		return
	end

	-- parent LUT
	local parent_lut = {}
	for i = 1, descriptor_count do
		local read_len = fp_decomp:ReadULong()
		parent_lut[i] = fp_decomp:Read(read_len)
	end

	read_check = fp_decomp:ReadByte()
	if read_check ~= 0xF0 then
		LK3D.New_D_Print("Error while decoding! (parent lut ~= 0xF0) (" .. name .. ")", LK3D_SEVERITY_FATAL, "LKPack")
		fp_decomp:Close()
		return
	end


	-- descriptor LUT
	local descriptor_lut = {}
	for i = 1, descriptor_count do
		local read_lookup = fp_decomp:ReadULong()

		descriptor_lut[i] = (read_lookup == VAL_FOLDER_ID) and -1 or read_lookup
	end

	read_check = fp_decomp:ReadByte()
	if read_check ~= 0xF0 then
		LK3D.New_D_Print("Error while decoding! (descriptor lut ~= 0xF0) (" .. name .. ")", LK3D_SEVERITY_FATAL, "LKPack")
		fp_decomp:Close()
		return
	end

	local content_lut = {}
	local empties = {}
	local content_count = fp_decomp:ReadULong()
	for i = 1, content_count do
		local len_content = fp_decomp:ReadULong()
		if len_content == 0 then -- empty file
			empties[i] = true
			content_lut[i] = 0x00
			continue
		end

		content_lut[i] = fp_decomp:Read(len_content)
	end

	read_check = fp_decomp:ReadByte()
	if read_check ~= 0xF0 then
		LK3D.New_D_Print("Error while decoding! (content lut ~= 0xF0) (" .. name .. ")", LK3D_SEVERITY_FATAL, "LKPack")
		fp_decomp:Close()
		return
	end

	local header_end = fp_decomp:Read(4)
	fp_decomp:Close()
	if header_end ~= "LKPA" then
		LK3D.New_D_Print("Error while decoding! (last header no match) (" .. name .. ")", LK3D_SEVERITY_FATAL, "LKPack")
		return
	end


	-- we now have enough data to build the folders without actually writing the files
	file.CreateDir("lk3d/lkpack/decomp_active/" .. name)


	for i = 1, descriptor_count do
		local ftype = descriptor_lut[i]
		if ftype ~= -1 then
			continue
		end

		if i % 64 == 0 then
			LK3D.PushProcessingMessage("Directory creation progress: " .. tostring(i) .. "/" .. tostring(descriptor_count))
			LK3D.RenderProcessingMessage("[LKPack] Load directory creation", (i / descriptor_count) * 100)
		end

		local parent = parent_lut[i]
		local f_name = name_lut[i]
		file.CreateDir("lk3d/lkpack/decomp_active/" .. name .. parent .. f_name)
	end

	-- now we write the files
	for i = 1, descriptor_count do
		local content_id = descriptor_lut[i]
		if content_id == -1 then
			continue
		end

		if i % 64 == 0 then
			LK3D.PushProcessingMessage("File write progress: " .. tostring(i) .. "/" .. tostring(descriptor_count))
			LK3D.RenderProcessingMessage("[LKPack] Load file creation", (i / descriptor_count) * 100)
		end

		local parent = parent_lut[i]
		local f_name = name_lut[i]

		if empties[content_id] then
			file.Write("lk3d/lkpack/decomp_active/" .. name .. parent .. f_name .. ".txt", "")
		else
			file.Write("lk3d/lkpack/decomp_active/" .. name .. parent .. f_name .. ".txt", util.Decompress(content_lut[content_id]))
			content_lut[content_id] = nil -- clean up ourselves so garbage collector has a happy evening
		end
	end

	LK3D.ActiveLKPack = name
	LK3D.New_D_Print("Loaded LKPack \"" .. name .. "\" successfully!", LK3D_SEVERITY_INFO, "LKPack")
end

--- Gets the real filepath to a LKPack file
-- @tparam string path LKPack filepath where to get the real path
-- @treturn string Real path to the file
-- @usage LK3D.GetDataPathToFile("models/dd_main/items/spray_can.obj")
function LK3D.GetDataPathToFile(path)
	if LK3D.LKPackDevMode then
		return "lk3d/lkpack/compile/" .. LK3D.FallbackLKPack .. "/" .. path
	end

	return "lk3d/lkpack/decomp_active/" .. LK3D.ActiveLKPack .. "/" .. path .. ".txt"
end


local function noLKPackCheck()
	if LK3D.ActiveLKPack ~= nil or LK3D.LKPackDevMode then
		return
	end


	LK3D.New_D_Print("No LKPack loaded, falling back to DevMode (raw read from compile directory...)", LK3D_SEVERITY_WARN, "LKPack")
	LK3D.New_D_Print("Fallback directory is \"lk3d/lkpack/compile/" .. LK3D.FallbackLKPack .. "\"", LK3D_SEVERITY_WARN, "LKPack")
	LK3D.New_D_Print("If you are actively developing, set LK3D.LKPackDevMode = true!", LK3D_SEVERITY_WARN, "LKPack")

	LK3D.LKPackDevMode = true
end


LK3D.LKPackDevMode = LK3D.LKPackDevMode ~= nil and LK3D.LKPackDevMode or false
LK3D.FallbackLKPack = LK3D.FallbackLKPack ~= nil and LK3D.FallbackLKPack or "none"

--- Reads a file from LKPack
-- @tparam string path LKPack filepath where to read the file
-- @treturn string Contents of the file, nil if not found
-- @usage LK3D.ReadFileFromLKPack("models/ponr_main/revolver/revolver_bakeduvs.obj")
function LK3D.ReadFileFromLKPack(path)
	noLKPackCheck()

	if LK3D.LKPackDevMode then
		local read = file.Read("lk3d/lkpack/compile/" .. LK3D.FallbackLKPack .. "/" .. path)
		if not read then
			LK3D.New_D_Print("Attempt to read missing file [\"" .. path .. "\"] (" .. LK3D.FallbackLKPack .. ")", LK3D_SEVERITY_ERROR, "LKPack")
			return
		end

		return read
	end

	local read = file.Read("lk3d/lkpack/decomp_active/" .. LK3D.ActiveLKPack .. "/" .. path .. ".txt")
	if not read then
		LK3D.New_D_Print("Attempt to read missing file [\"" .. path .. "\"] (" .. LK3D.ActiveLKPack .. ")", LK3D_SEVERITY_ERROR, "LKPack")
		return
	end

	return read
end

--- Opens a file from LKPack
-- @tparam string path LKPack filepath where to open the file
-- @tparam string openMode The file open mode, ex. "rb"
-- @treturn file_class File pointer, nil if not found
-- @usage LK3D.OpenFileFromLKPack("ponr_keyframes/intro/camera.lkf")
function LK3D.OpenFileFromLKPack(path, openMode)
	noLKPackCheck()

	if LK3D.LKPackDevMode then
		local fPtr = file.Open("lk3d/lkpack/compile/" .. LK3D.FallbackLKPack .. "/" .. path, openMode or "r", "DATA")
		if not fPtr then
			LK3D.New_D_Print("Attempt to open missing file [\"" .. path .. "\"] (" .. LK3D.FallbackLKPack .. ")", LK3D_SEVERITY_ERROR, "LKPack")
			return
		end

		return fPtr
	end

	local fPtr = file.Open("lk3d/lkpack/decomp_active/" .. LK3D.ActiveLKPack .. "/" .. path .. ".txt", openMode or "r", "DATA")
	if not fPtr then
		LK3D.New_D_Print("Attempt to open missing file [\"" .. path .. "\"] (" .. LK3D.ActiveLKPack .. ")", LK3D_SEVERITY_ERROR, "LKPack")
		return
	end

	return fPtr
end


-- TODO: audio module
local function makeFakeFile(path)
	local extension = string.match(path, "(%.[%a%d]+)$")
	local fRead = file.Read(path, "DATA")
	file.Write(path .. "_fake" .. extension, fRead)

	return path .. "_fake" .. extension
end

--- Plays a sound file from LKPack
-- @tparam string path LKPack filepath to the sound
-- @tparam string flags Sound flags, refer to [sound.PlayFile](https://wiki.facepunch.com/gmod/sound.PlayFile)
-- @tparam function callback Callback to execute once loaded
-- @usage LK3D.PlayAudioFromLKPack("sound/ponr_main/revolver/revolver_fire.wav")
function LK3D.PlayAudioFromLKPack(path, flags, callback)
	local realPath = LK3D.GetDataPathToFile("sound/" .. path)
	local fakePath = makeFakeFile(realPath)

	sound.PlayFile("data/" .. fakePath, flags, callback)
end



if LK3D.AutoLoadLKPack and not LK3D.LKPackDevMode then
	LK3D.LoadLKPack(LK3D.AutoLoadLKPack)
end

concommand.Add("lk3d_make_dev_lkpack", function()
	LK3D.New_D_Print("Making LKPack [" .. tostring(LK3D.FallbackLKPack) .. "]", LK3D_SEVERITY_INFO, "LKPack")
	LK3D.MakeLKPack(LK3D.FallbackLKPack)
end)