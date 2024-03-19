LK3D = LK3D or {}


-- lets make a faster but bigger model format
file.CreateDir("lk3d/fam_export")
function LK3D.ExportFastAnimatedModel(name, path, mdlData)
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

function LK3D.LoadFastAnimatedModel(path)
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
	local dataBase, hadNormalBase = LK3D.ParseOBJMesh(objBase)
	if not hadNormalBase then
		LK3D.GenerateNormals(dataBase)
	end
	LK3D.ExportFastAnimatedModel(mdlName, mdlName, dataBase)


	for k, v in pairs(params.animations) do
		local animIndex = k
		local fStart = tonumber(v.fStart)
		local fEnd = tonumber(v.fEnd)

		file.CreateDir("lk3d/fam_export/" .. mdlName .. "/anims/" .. animIndex)
		for i = fStart, fEnd do
			local objStr = LK3D.ReadFileFromLKPack("models/" .. fpath .. "/anims/" .. animIndex .. "/" .. mdlName .. i .. ".obj")
			local data, hadNormal = LK3D.ParseOBJMesh(objStr)
			if not hadNormal then
				LK3D.GenerateNormals(data)
			end


			LK3D.ExportFastAnimatedModel(mdlName .. i, mdlName .. "/anims/" .. animIndex, data)
		end
	end
end