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

-- todo fix bonetransforms
function LK3D.DeclareModelFromSource(name, mdl)
	local meshes = util.GetModelMeshes(mdl, 12)
	if not meshes then
		return
	end

	if not meshes[1] then
		return
	end

	local data = {}
	data.verts = {}
	data.uvs = {}
	data.indices = {}

	local prevPos = {}

	for i = 1, #meshes[1].triangles, 3 do
		local v1 = meshes[1].triangles[i]
		local v2 = meshes[1].triangles[i + 1]
		local v3 = meshes[1].triangles[i + 2]

		if not v1 or not v2 or not v3 then
			break
		end


		local round_var = 8
		local v1p = v1.pos
		local ovr1, ovr2, ovr3
		if not prevPos[v1p] then
			prevPos[v1p] = {v = #data.verts + 1, uv = #data.uvs + 1}
			ovr1 = {v = #data.verts + 1, uv = #data.uvs + 1}
			data.verts[#data.verts + 1] = Vector(math.Round(v1p.x, round_var), math.Round(v1p.y, round_var), math.Round(v1p.z, round_var))
			data.uvs[#data.uvs + 1] = {math.Round(v1.u, round_var), math.Round(v1.v, round_var)}
		else
			ovr1 = prevPos[v1p]
		end

		local v2p =  v2.pos
		if not prevPos[v2p] then
			prevPos[v2p] = {v = #data.verts + 1, uv = #data.uvs + 1}
			ovr2 = {v = #data.verts + 1, uv = #data.uvs + 1}
			data.verts[#data.verts + 1] = Vector(math.Round(v2p.x, round_var), math.Round(v2p.y, round_var), math.Round(v2p.z, round_var))
			data.uvs[#data.uvs + 1] = {math.Round(v2.u, round_var), math.Round(v2.v, round_var)}
		else
			ovr2 = prevPos[v2p]
		end

		local v3p =  v3.pos
		if not prevPos[v3p] then
			prevPos[v3p] = {v = #data.verts + 1, uv = #data.uvs + 1}
			ovr3 = {v = #data.verts + 1, uv = #data.uvs + 1}
			data.verts[#data.verts + 1] = Vector(math.Round(v3p.x, round_var), math.Round(v3p.y, round_var), math.Round(v3p.z, round_var))
			data.uvs[#data.uvs + 1] = {math.Round(v3.u, round_var), math.Round(v3.v, round_var)}
		else
			ovr3 = prevPos[v3p]
		end

		data.indices[#data.indices + 1] = {{ovr3.v, ovr3.uv}, {ovr2.v, ovr2.uv}, {ovr1.v, ovr1.uv}}
	end

	local data_c = LK3D.GetOptimizedModelTable(data)
	LK3D.Models[name] = data_c
	LK3D.GenerateNormals(LK3D.Models[name])
	LK3D.New_D_Print("Declared model \"" .. name .. "\" with " .. #data_c.verts .. " verts [SRC]", LK3D_SEVERITY_INFO, "ModelUtils")
end

-- makes a compressed ver. of model with x name in ur data folder under "lk3d"
function LK3D.CompressModel(name)
	LK3D.New_D_Print("This ModelFormat is deprecated, use LK3D.CompressModelLKC(name) instead...", LK3D_SEVERITY_WARN, "LKComp_Legacy")
	file.CreateDir("lk3d/compmodels")
	local mdl = LK3D.Models[name]

	if not mdl then
		LK3D.New_D_Print("No model \"" .. name .. "\" to compress!", LK3D_SEVERITY_WARN, "LKComp_Legacy")
		return
	end

	local fnm = "lk3d/compmodels/" .. name .. ".txt"

	file.Write(fnm, "")

	local buffer = ""

	local r_vert = 3
	local r_uv = 4

	-- verts
	buffer = buffer .. "="
	for k, v in ipairs(mdl.verts) do
		buffer = buffer .. math.Round(v.x, r_vert) .. ":" .. math.Round(v.y, r_vert) .. ":" .. math.Round(v.z, r_vert) .. ">"
	end

	-- uvs
	buffer = buffer .. "!"
	for k, v in ipairs(mdl.uvs) do
		buffer = buffer .. math.Round(v[1], r_uv) .. ":" .. math.Round(v[2], r_uv) .. ">"
	end

	-- indices BIG GAIN
	buffer = buffer .. "?"
	for k, v in ipairs(mdl.indices) do
		buffer = buffer .. v[1][1] .. ":" .. v[1][2] .. ":" .. v[2][1] .. ":" .. v[2][2] .. ":" .. v[3][1] .. ":" .. v[3][2] ..  ">"
	end

	-- compress
	buffer = util.Compress(buffer, true)
	buffer = util.Base64Encode(buffer, true)
	file.Write(fnm, buffer)
end

local tn = tonumber
function LK3D.AddModelCompStr(name, str)
	local dstr = util.Decompress(util.Base64Decode(str))
	if not dstr then
		LK3D.New_D_Print("Failed adding model \"" .. name .. "\" while uncompressing!", LK3D_SEVERITY_WARN, "LKComp_Legacy")
		return
	end


	local s1, s2, s3 = string.match(dstr, "=([%d-.>:]+)!([%d-.>:]+)?([%d-.>:]+)")
	local mdldat = {
		["verts"] = {},
		["uvs"] = {},
		["indices"] = {},
	}

	local verts = string.gmatch(s1, "([-%d.:]+)>")
	for vec in verts do
		local x, y, z = string.match(vec, "([-%d.]+):([-%d.]+):([-%d.]+)")
		mdldat.verts[#mdldat.verts + 1] = Vector(tn(x), tn(y), tn(z))
	end


	local uvs = string.gmatch(s2, "([-%d.:]+)>")
	for uv in uvs do
		local u, v = string.match(uv, "([-%d.]+):([-%d.]+)")
		mdldat.uvs[#mdldat.uvs + 1] = {tn(u), tn(v)}
	end

	local indices = string.gmatch(s3, "([-%d.:]+)>")
	for index in indices do
		local i11, i12, i21, i22, i31, i32 = string.match(index, "([-%d.]+):([-%d.]+):([-%d.]+):([-%d.]+):([-%d.]+):([-%d.]+)")
		mdldat.indices[#mdldat.indices + 1] = {{tn(i11), tn(i12)}, {tn(i21), tn(i22)}, {tn(i31), tn(i32)}}
	end

	LK3D.Models[name] = mdldat
	LK3D.GenerateNormals(LK3D.Models[name])

	LK3D.New_D_Print("Declared model \"" .. name .. "\" with " .. #mdldat.verts .. " verts [COMP]", LK3D_SEVERITY_INFO, "LKComp_Legacy")
end





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


local string = string
local string_Trim = string.Trim
local string_TrimRight = string.TrimRight
local string_sub = string.sub
local string_Explode = string.Explode


local function parseOBJMesh(objData)
	local data = {}
	data["verts"] = {}
	data["uvs"] = {}
	data["indices"] = {}
	data["normals"] = {}
	data["s_normals"] = {}

	local verts = data["verts"]
	local uvs = data["uvs"]
	local indices = data["indices"]
	local normals = data["normals"]
	local s_normals = data["s_normals"]

	local _fileNormBuff = {}

	local hadNormal = false

	-- its obj so parse each line
	for k, v in ipairs(string_Explode("\n", objData, false)) do
		local ident = string_sub(v, 1, 2)
		ident = string_TrimRight(ident)
		local cont = string_sub(v, #ident + 2) -- shit code
		if not cont then
			continue
		end

		if ident == "#" then
			LK3D.New_D_Print("[Comment]: " .. cont, LK3D_SEVERITY_DEBUG, "ModelUtils")
		elseif ident == "v" then
			local expVars = string_Explode(" ", cont, false)

			local x = tonumber(string_Trim(expVars[1]))
			local y = tonumber(string_Trim(expVars[2]))
			local z = tonumber(string_Trim(expVars[3]))

			local vecBuild = Vector(x, y, z)
			verts[#verts + 1] = vecBuild
		elseif ident == "vt" then
			local expVars = string_Explode(" ", cont, false)

			local uR = tonumber(string_Trim(expVars[1]))
			local vR = tonumber(string_Trim(expVars[2]))

			uvs[#uvs + 1] = {uR, vR}
		elseif ident == "vn" then
			hadNormal = true

			local expVars = string_Explode(" ", cont, false)
			local x = tonumber(string_Trim(expVars[1]))
			local y = tonumber(string_Trim(expVars[2]))
			local z = tonumber(string_Trim(expVars[3]))

			local vecBuild = Vector(x, y, z)
			vecBuild:Normalize()
			_fileNormBuff[#_fileNormBuff + 1] = vecBuild
		elseif ident == "f" then
			local expVars = string_Explode(" ", cont, false)

			local bInd = {}

			local applyNormFromIdx = false

			for i = 1, 3 do
				local datExp2 = string_Explode("/", expVars[i], false)
				local i1, i2, i3 = tonumber(datExp2[1]), tonumber(datExp2[2]), tonumber(datExp2[3])

				if i1 and (not i2) and (not i3) then -- pos only
					bInd[#bInd + 1] = {i1, 1}
					LK3D.New_D_Print("OBJ Load fail!, no texcoord! (posOnly)", LK3D_SEVERITY_FATAL, "ModelUtils")
				end

				if i1 and i2 and (not i3) then -- pos / tex
					bInd[#bInd + 1] = {i1, i2}
				end

				if i1 and i2 and i3 then -- pos / tex / norm
					applyNormFromIdx = true
					bInd[#bInd + 1] = {i1, i2}

					s_normals[i1] = _fileNormBuff[i3] * 1
				end

				if i1 and (not i2) and i3 then -- pos // norm
					applyNormFromIdx = true
					bInd[#bInd + 1] = {i1, 1}

					s_normals[i1] = _fileNormBuff[i3] * 1

					LK3D.New_D_Print("OBJ Load fail!, no texcoord! (pos // norm)", LK3D_SEVERITY_FATAL, "ModelUtils")
				end
			end

			if hadNormal and applyNormFromIdx then -- we still need to make a sharp normal
				local v1 = Vector(verts[bInd[1][1]])
				local v2 = Vector(verts[bInd[2][1]])
				local v3 = Vector(verts[bInd[3][1]])

				local norm = (v2 - v1):Cross(v3 - v1)
				norm:Normalize()

				normals[#normals + 1] = norm * 1
			end

			indices[#indices + 1] = bInd
		end
	end

	return data, hadNormal
end


function LK3D.AddModelOBJ(name, objData)
	local data, hadNormal = parseOBJMesh(objData)

	LK3D.Models[name] = data
	if not hadNormal then
		LK3D.GenerateNormals(LK3D.Models[name])
	end


	LK3D.New_D_Print("Declared model \"" .. name .. "\" with " .. #data.verts .. " verts! [OBJ]", LK3D_SEVERITY_DEBUG, "ModelUtils")
end

function LK3D.DeclareModelFromOBJFile(name, fpath)
	local fcontents = LK3D.ReadFileFromLKPack("models/" .. fpath .. ".obj")
	LK3D.New_D_Print("Loading OBJ model \"" .. name .. "\" (" .. fpath .. ") from LKPack!", LK3D_SEVERITY_INFO, "ModelUtils")

	LK3D.AddModelOBJ(name, fcontents)
end

function LK3D.DeclareModelFromLKCFile(name, fpath)
	local fcontents = LK3D.ReadFileFromLKPack("models/" .. fpath .. ".lkc")
	LK3D.New_D_Print("Loading LKC model \"" .. name .. "\" (" .. fpath .. ") from LKPack!", LK3D_SEVERITY_INFO, "ModelUtils")

	LK3D.AddModelLKC(name, fcontents)
end


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

-- lets make a faster but bigger model format
file.CreateDir("lk3d/fam_export")
local function exportFastAnimatedModel(name, path, mdlData)
	if not mdlData then
		return
	end

	file.Write("lk3d/fam_export/" .. path .. "/" .. name .. ".fam.txt", "TEMP")
	local fPtr = file.Open("lk3d/fam_export/" .. path .. "/" .. name .. ".fam.txt", "wb", "DATA")
	if not fPtr then
		return
	end

	local verts = mdlData.verts
	local uvs = mdlData.uvs
	local ind = mdlData.indices
	local normals = mdlData.normals
	local s_norm = mdlData.s_normals

	fPtr:WriteByte(string.byte("F"))
	fPtr:WriteByte(string.byte("A"))
	fPtr:WriteByte(string.byte("M"))
	fPtr:WriteByte(0x00)

	fPtr:WriteULong(#verts)
	for i = 1, #verts do
		local vert = verts[i]
		fPtr:WriteFloat(vert[1])
		fPtr:WriteFloat(vert[2])
		fPtr:WriteFloat(vert[3])
	end

	fPtr:WriteULong(#uvs)
	for i = 1, #uvs do
		local uv = uvs[i]
		fPtr:WriteFloat(uv[1])
		fPtr:WriteFloat(uv[2])
	end

	fPtr:WriteULong(#ind)
	for i = 1, #ind do
		local idx = ind[i]
		fPtr:WriteULong(idx[1][1])
		fPtr:WriteULong(idx[1][2])

		fPtr:WriteULong(idx[2][1])
		fPtr:WriteULong(idx[2][2])

		fPtr:WriteULong(idx[3][1])
		fPtr:WriteULong(idx[3][2])
	end

	fPtr:WriteULong(#normals)
	for i = 1, #normals do
		local norm = normals[i]
		fPtr:WriteFloat(norm[1])
		fPtr:WriteFloat(norm[2])
		fPtr:WriteFloat(norm[3])
	end

	fPtr:WriteULong(#s_norm)
	for i = 1, #s_norm do
		local snorm = s_norm[i]
		fPtr:WriteFloat(snorm[1])
		fPtr:WriteFloat(snorm[2])
		fPtr:WriteFloat(snorm[3])
	end

	fPtr:WriteByte(string.byte("E"))
	fPtr:WriteByte(0x00)
	fPtr:WriteByte(0x00)
	fPtr:WriteByte(0x00)

	fPtr:Close()
end

local function loadFastAnimatedModel(path)
	local fPtr = file.Open(path, "rb", "DATA")
	if not fPtr then
		return
	end

	-- read header
	local head_read = fPtr:ReadULong()
	if head_read ~= 5062982 then
		error("invalid header; ", head_read)
		fPtr:Close()
		return
	end

	local mdlData = {
		verts = {},
		uvs = {},
		indices = {},
		normals = {},
		s_normals = {},
	}

	local verts = mdlData.verts
	local uvs = mdlData.uvs
	local ind = mdlData.indices
	local normals = mdlData.normals
	local s_norm = mdlData.s_normals



	local vertCount = fPtr:ReadULong()
	for i = 1, vertCount do
		verts[i] = Vector(fPtr:ReadFloat(), fPtr:ReadFloat(), fPtr:ReadFloat())
	end

	local uvCount = fPtr:ReadULong()
	for i = 1, uvCount do
		uvs[i] = {fPtr:ReadFloat(), fPtr:ReadFloat()}
	end

	local indCount = fPtr:ReadULong()
	for i = 1, indCount do
		ind[i] = {
			{fPtr:ReadULong(), fPtr:ReadULong()},
			{fPtr:ReadULong(), fPtr:ReadULong()},
			{fPtr:ReadULong(), fPtr:ReadULong()}
		}
	end

	local normCount = fPtr:ReadULong()
	for i = 1, normCount do
		normals[i] = Vector(fPtr:ReadFloat(), fPtr:ReadFloat(), fPtr:ReadFloat())
	end

	local s_normCount = fPtr:ReadULong()
	for i = 1, s_normCount do
		s_norm[i] = Vector(fPtr:ReadFloat(), fPtr:ReadFloat(), fPtr:ReadFloat())
	end

	fPtr:Close()

	return mdlData
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
		local mdlData = loadFastAnimatedModel(realPath)
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
				data, hadNormal = parseOBJMesh(objStr)
				if not hadNormal then
					LK3D.GenerateNormals(data)
				end
			elseif mdlFormat == "fam" then
				local realPath =  LK3D.GetDataPathToFile("models/" .. fpath .. "/anims/" .. animIndex .. "/" .. mdlName .. i .. ".fam")
				data = loadFastAnimatedModel(realPath)
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


function LK3D.ExportAnimatedModelFAM(index, fpath)
	local jsonInfo = LK3D.ReadFileFromLKPack("models/" .. fpath .. "/params.json")
	local params = util.JSONToTable(jsonInfo)

	if not params then
		LK3D.New_D_Print("Failed to load JSON info when loading animated model \"" .. name .. "\"!", LK3D_SEVERITY_ERROR, "ModelUtils")
		return
	end

	local mdlName = params.modelName

	file.CreateDir("lk3d/fam_export/" .. mdlName)

	local objBase = LK3D.ReadFileFromLKPack("models/" .. fpath .. "/" .. mdlName .. ".obj")
	local dataBase, hadNormalBase = parseOBJMesh(objBase)
	if not hadNormalBase then
		LK3D.GenerateNormals(dataBase)
	end
	exportFastAnimatedModel(mdlName, mdlName, dataBase)


	for k, v in pairs(params.animations) do
		local animIndex = k
		local fStart = tonumber(v.fStart)
		local fEnd = tonumber(v.fEnd)

		file.CreateDir("lk3d/fam_export/" .. mdlName .. "/anims/" .. animIndex)
		for i = fStart, fEnd do
			local objStr = LK3D.ReadFileFromLKPack("models/" .. fpath .. "/anims/" .. animIndex .. "/" .. mdlName .. i .. ".obj")
			local data, hadNormal = parseOBJMesh(objStr)
			if not hadNormal then
				LK3D.GenerateNormals(data)
			end


			exportFastAnimatedModel(mdlName .. i, mdlName .. "/anims/" .. animIndex, data)
		end
	end
end




LK3D.New_D_Print("LK3D modelutils fully loaded!", LK3D_SEVERITY_INFO, "Base")