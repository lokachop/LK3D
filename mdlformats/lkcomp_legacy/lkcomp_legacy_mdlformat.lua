---
-- @module modelutils
LK3D = LK3D or {}

--- Compresses a model into LKComp Legacy
-- @deprecated
-- @tparam string name LK3D model name
-- @usage -- THIS IS DEPRECATED!!!
-- LK3D.CompressModel("cube_nuv")
-- -- Model written to "lk3d/compmodels/cube_nuv.txt"
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
---Loads a LKComp Legacy model
-- @deprecated
-- @tparam string name LK3D model name
-- @tparam string str LKComp Legacy model data
-- @usage -- THIS IS DEPRECATED!!!
-- LK3D.AddModelCompStr("bad_deprecated", LK3D.ReadFileFromLKPack("models/bad.kcl"))
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
