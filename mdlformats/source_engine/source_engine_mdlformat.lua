---
-- @module modelutils
LK3D = LK3D or {}

--- Declares a LK3D model from a source engine model
-- @tparam string name LK3D model name
-- @tparam string mdl Source engine model name
-- @usage -- It's not adviced to use source models with LK3D due to polycount
-- LK3D.DeclareModelFromSource("player_epic", "models/player.mdl")
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