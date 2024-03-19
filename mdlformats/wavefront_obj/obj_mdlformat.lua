LK3D = LK3D or {}

local string = string
local string_Trim = string.Trim
local string_TrimRight = string.TrimRight
local string_sub = string.sub
local string_Explode = string.Explode


function LK3D.ParseOBJMesh(objData)
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
	local data, hadNormal = LK3D.ParseOBJMesh(objData)

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
