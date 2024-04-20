---
-- @module modelutils
LK3D = LK3D or {}

--[[
	LKCOMP docs
	rev1

	start should be "LKC " (4C 4B 43 00 in hex) otherwise its not an lkc file
	after those 4 bytes, the next byte is the revision

	then after that its the number of verts as a ULONG (4bytes)
	
	each vert is three bunched up longs each long is the float * 10000 floored
	(x, y, z)

	after that its the number of UVDATAS as a ULONG (4 bytes)

	each uvdata is 2 ushorts (u * 65534, v * 65534)

	after that its the number of indexes as a ULONG (4 bytes)
	theres 3 indexdata for each vert
	each indexdata is 2 ulongs (index vert, index uv)

	then its an ascii E

]]

local LKCOMP_VER = 1 -- lkcomp revision
local LKCOMP_ENCODERS = {
	[1] = function(name, f_pointer, fname)
		local mdldata = LK3D.Models[name]
		if not mdldata then
			return 1
		end
		f_pointer:Seek(0)

		-- marker
		f_pointer:WriteByte(string.byte("L")) -- L
		f_pointer:WriteByte(string.byte("K")) -- K
		f_pointer:WriteByte(string.byte("C")) -- C
		f_pointer:WriteByte(0x00) -- void

		f_pointer:WriteByte(LKCOMP_VER) -- revision
		f_pointer:WriteULong(#mdldata.verts) -- byte length of vert data

		LK3D.New_D_Print(#mdldata.verts .. " verts...", LK3D_SEVERITY_DEBUG, "LKCOMP")

		-- write vert data
		for k, v in ipairs(mdldata.verts) do
			local vec_dat = v

			local calcvar = vec_dat[1]
			f_pointer:WriteLong(math.floor(calcvar * 10000))

			calcvar = vec_dat[2]
			f_pointer:WriteLong(math.floor(calcvar * 10000))

			calcvar = vec_dat[3]
			f_pointer:WriteLong(math.floor(calcvar * 10000))
		end
		LK3D.New_D_Print("Done vertWriting!", LK3D_SEVERITY_DEBUG, "LKCOMP")

		f_pointer:WriteULong(#mdldata.uvs) -- byte length of uv data
		LK3D.New_D_Print(#mdldata.uvs .. " uvs...", LK3D_SEVERITY_DEBUG, "LKCOMP")

		for k, v in ipairs(mdldata.uvs) do
			local uv_dat = v
			f_pointer:WriteUShort(math.floor(uv_dat[1] * 65534) % 65535)
			f_pointer:WriteUShort(math.floor(uv_dat[2] * 65534) % 65535)
		end
		LK3D.New_D_Print("Done uvWriting!", LK3D_SEVERITY_DEBUG, "LKCOMP")

		f_pointer:WriteULong(#mdldata.indices) -- byte length of index data
		LK3D.New_D_Print(#mdldata.indices .. " indices...", LK3D_SEVERITY_DEBUG, "LKCOMP")

		for k, v in ipairs(mdldata.indices) do
			local idx_dat = v

			-- we use ushorts cuz low poly models so we dont have to worry about hi poly counts, use legacy compress system for that instead
			f_pointer:WriteUShort(math.floor(idx_dat[1][1]))
			f_pointer:WriteUShort(math.floor(idx_dat[1][2]))

			f_pointer:WriteUShort(math.floor(idx_dat[2][1]))
			f_pointer:WriteUShort(math.floor(idx_dat[2][2]))

			f_pointer:WriteUShort(math.floor(idx_dat[3][1]))
			f_pointer:WriteUShort(math.floor(idx_dat[3][2]))
		end
		LK3D.New_D_Print("Done indexWriting!", LK3D_SEVERITY_DEBUG, "LKCOMP")

		-- e to mark end
		f_pointer:WriteByte(string.byte("E")) -- E
		f_pointer:Close()


		local act_name = fname .. ".lkc.txt"
		--file.Write(fname .. "_raw" .. ".txt", file.Read(act_name, "DATA"))
		--file.Write(fname .. "_nolzma" .. ".txt", util.Base64Encode(file.Read(act_name, "DATA"), true))

		file.Write(act_name, util.Base64Encode(util.Compress(file.Read(act_name, "DATA")), true))

	end
}


--- Compresses a model into a LKComp model
-- @tparam string name LK3D model name
-- @usage LK3D.CompressModelLKC("cube_nuv")
-- -- file written to "lk3d/lkcomp_models/cube_nuv.lkc.txt"
function LK3D.CompressModelLKC(name)
	LK3D.New_D_Print("Compressing \"" .. name .. "\" with LKC revision " .. LKCOMP_VER .. "....", LK3D_SEVERITY_INFO, "LKCOMP")
	file.CreateDir("lk3d/lkcomp_models")

	local fnm = "lk3d/lkcomp_models/" .. name
	file.Write(fnm, "")

	local f_pointer = file.Open(fnm .. ".lkc.txt", "wb", "DATA")
	if LKCOMP_ENCODERS[LKCOMP_VER] then
		local fine, err = pcall(LKCOMP_ENCODERS[LKCOMP_VER], name, f_pointer, fnm)
		if not fine then
			LK3D.New_D_Print("Error compressing \"" .. name .. "\" with LKC revision " .. LKCOMP_VER .. ": \"" .. err .. "\"", LK3D_SEVERITY_FATAL, "LKCOMP")
		end
	end

	f_pointer:Close()
end


local round_var_rev1 = 4
local LKCOMP_DECODERS = {
	[1] = function(name, f_pointer)
		local mdlDat = {}

		local vertCount = f_pointer:ReadULong()
		LK3D.New_D_Print(name .. " has " .. vertCount .. " verts...", LK3D_SEVERITY_DEBUG, "LKCOMP")

		-- read verts..
		mdlDat.verts = {}
		for i = 1, vertCount do
			local vx = math.Round(f_pointer:ReadLong() / 10000, round_var_rev1)
			local vy = math.Round(f_pointer:ReadLong() / 10000, round_var_rev1)
			local vz = math.Round(f_pointer:ReadLong() / 10000, round_var_rev1)

			mdlDat.verts[#mdlDat.verts + 1] = Vector(vx, vy, vz)
		end

		local uvCount = f_pointer:ReadULong()
		LK3D.New_D_Print(name .. " has " .. uvCount .. " uvs...", LK3D_SEVERITY_DEBUG, "LKCOMP")

		-- read uvs..
		mdlDat.uvs = {}
		for i = 1, uvCount do
			local u = math.Round(f_pointer:ReadUShort() / 65534, round_var_rev1)
			local v = math.Round(f_pointer:ReadUShort() / 65534, round_var_rev1)

			mdlDat.uvs[#mdlDat.uvs + 1] = {u, v}
		end


		local indexCount = f_pointer:ReadULong()
		LK3D.New_D_Print(name .. " has " .. indexCount .. " indices...", LK3D_SEVERITY_DEBUG, "LKCOMP")

		mdlDat.indices = {}
		for i = 1, indexCount do
			local i1_j1 = f_pointer:ReadUShort()
			local i1_j2 = f_pointer:ReadUShort()

			local i2_j1 = f_pointer:ReadUShort()
			local i2_j2 = f_pointer:ReadUShort()

			local i3_j1 = f_pointer:ReadUShort()
			local i3_j2 = f_pointer:ReadUShort()

			mdlDat.indices[#mdlDat.indices + 1] = {
				{i1_j1, i1_j2},
				{i2_j1, i2_j2},
				{i3_j1, i3_j2}
			}
		end

		if string.char(f_pointer:ReadByte()) ~= "E" then
			LK3D.New_D_Print("Failed to decode \"" .. name .. "\"!", LK3D_SEVERITY_FATAL, "LKCOMP")
			return
		end

		LK3D.DeclareModel(name, mdlDat)
	end
}

--- Loads a LKComp model
-- @tparam string name LK3D model name
-- @tparam string data LKComp data
-- @usage -- Don't do this, use DeclareModelFromLKCFile
-- LK3D.AddModelLKC("crystal_bad", LK3D.ReadFileFromLKPack("models/dd_main/crystal.lkc"))
function LK3D.AddModelLKC(name, data)
	LK3D.New_D_Print("Decompressing LKCOMP \"" .. name .. "\"...", LK3D_SEVERITY_DEBUG, "LKCOMP")
	if not data then
		return
	end

	local data_nocomp = util.Decompress(util.Base64Decode(data) or "")

	if not data_nocomp then
		return
	end

	file.Write("lk3d/decomp_temp.txt", data_nocomp)
	local f_pointer = file.Open("lk3d/decomp_temp.txt", "rb", "DATA")


	-- read header
	local head = f_pointer:ReadLong()
	if head ~= 4410188 then
		LK3D.New_D_Print("Header LKC no match!", LK3D_SEVERITY_DEBUG, "LKCOMP")
		f_pointer:Close()
		return
	end

	local rev = f_pointer:ReadByte()
	LK3D.New_D_Print(name .. " is rev" .. rev .. "...", LK3D_SEVERITY_DEBUG, "LKCOMP")

	if LKCOMP_DECODERS[rev] then
		local fine, err = pcall(LKCOMP_DECODERS[rev], name, f_pointer)
		if not fine then
			LK3D.New_D_Print("Error decompressing \"" .. name .. "\" with LKC revision " .. rev .. ": \"" .. err .. "\"", LK3D_SEVERITY_FATAL, "LKComp")
		end
	end

	f_pointer:Close()
end

--- Loads a LKComp model from a LKPack path
-- @tparam string name LK3D model name
-- @tparam string fpath LKPack path to model, without extension
-- @usage LK3D.DeclareModelFromLKCFile("crystal_good", "models/dd_main/crystal")
function LK3D.DeclareModelFromLKCFile(name, fpath)
	local fcontents = LK3D.ReadFileFromLKPack("models/" .. fpath .. ".lkc")
	LK3D.New_D_Print("Loading LKC model \"" .. name .. "\" (" .. fpath .. ") from LKPack!", LK3D_SEVERITY_INFO, "ModelUtils")

	LK3D.AddModelLKC(name, fcontents)
end