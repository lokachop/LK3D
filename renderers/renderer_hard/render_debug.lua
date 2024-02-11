LK3D = LK3D or {}
local render = render
local render_SetMaterial = render.SetMaterial
local render_OverrideDepthEnable = render.OverrideDepthEnable
local render_SetColorMaterial = render.SetColorMaterial

local cam = cam

local mesh = mesh
local mesh_Color = mesh.Color
local mesh_Position = mesh.Position
local mesh_TexCoord = mesh.TexCoord
local mesh_AdvanceVertex = mesh.AdvanceVertex
local mesh_End = mesh.End
local mesh_Begin = mesh.Begin


local wfMat = Material("editor/wireframe")
local type_calls = {
	["line"] = function(objs)
		for k, v in pairs(objs) do
			if CurTime() > v.life then
				table.remove(objs, k)
			end
		end

		render_SetColorMaterial()
		render_OverrideDepthEnable(true, false)
		mesh_Begin(MATERIAL_LINES, #objs)
			for k, v in ipairs(objs) do

				local col = v.col
				local s_p = v.s_pos or Vector(0, 0, 0)
				local e_p = v.e_pos or Vector(0, 0, 1)

				mesh_Color(col.r, col.g, col.b, 255)
				mesh_Position(s_p)
				mesh_TexCoord(0, 0, 0)
				mesh_AdvanceVertex()

				mesh_Color(col.r, col.g, col.b, 255)
				mesh_Position(e_p)
				mesh_TexCoord(0, 1, 1)
				mesh_AdvanceVertex()
			end
		mesh_End()
		render_OverrideDepthEnable(false, false)
	end,
	["box"] = function(objs)
		for k, v in pairs(objs) do
			if CurTime() > v.life then
				table.remove(objs, k)
			end
		end

		local mdlinfo = LK3D.Models["cube_nuv"]



		render_SetMaterial(wfMat)
		render_OverrideDepthEnable(true, false)


		for k, v in ipairs(objs) do
			local col = v.col
			local pos = v.pos or Vector(0, 0, 0)
			local sz = v.size or Vector(1, 1, 1)
			local ang = v.ang or Angle(0, 0, 0)
			local matrix_transl = Matrix()

			matrix_transl:SetScale(sz)
			matrix_transl:SetTranslation(pos)
			matrix_transl:SetAngles(ang)


			local verts = mdlinfo.verts
			local ind = mdlinfo.indices
			local uvs = mdlinfo.uvs
			cam.PushModelMatrix(matrix_transl, true)

			mesh_Begin(MATERIAL_TRIANGLES, 12) -- 12 tris in a box
			for i = 1, #ind do
				local index = ind[i]
				local uv1 = uvs[index[1][2]]
				local uv2 = uvs[index[2][2]]
				local uv3 = uvs[index[3][2]]

				mesh_Color(col.r, col.g, col.b, 255)
				mesh_Position(verts[index[3][1]])
				mesh_TexCoord(0, uv3[1], uv3[2])
				mesh_AdvanceVertex()

				mesh_Color(col.r, col.g, col.b, 255)
				mesh_Position(verts[index[2][1]])
				mesh_TexCoord(0, uv2[1], uv2[2])
				mesh_AdvanceVertex()

				mesh_Color(col.r, col.g, col.b, 255)
				mesh_Position(verts[index[1][1]])
				mesh_TexCoord(0, uv1[1], uv1[2])
				mesh_AdvanceVertex()
			end
			mesh_End()
			cam.PopModelMatrix()
		end

		render_OverrideDepthEnable(false, false)
	end,
}

local function renderDebug(data)
	if not LK3D.Debug then
		return
	end

	for k, v in pairs(type_calls) do
		if LK3D.CurrUniv["debug_obj"][k] then
			pcall(type_calls[k], LK3D.CurrUniv["debug_obj"][k])
		end
	end
end

return renderDebug
