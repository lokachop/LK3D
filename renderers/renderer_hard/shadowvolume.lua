LK3D = LK3D or {}

local render = render
local render_SetStencilReferenceValue = render.SetStencilReferenceValue
local render_SetStencilCompareFunction = render.SetStencilCompareFunction
local render_SetStencilPassOperation = render.SetStencilPassOperation
local render_SetStencilFailOperation = render.SetStencilFailOperation
local render_SetStencilZFailOperation = render.SetStencilZFailOperation

local render_SetColorMaterial = render.SetColorMaterial

local math = math
local math_floor = math.floor
local math_huge = math.huge

local mesh = mesh
local mesh_Color = mesh.Color
local mesh_Position = mesh.Position
local mesh_TexCoord = mesh.TexCoord
local mesh_AdvanceVertex = mesh.AdvanceVertex
local mesh_End = mesh.End
local mesh_Begin = mesh.Begin


local function d_print(...)
	if not LK3D.Debug then
		return
	end

	MsgC(Color(255, 100, 100), "[Hardware renderer debug]: ", Color(200, 255, 200), ..., "\n")
end


local he_begin = "["
local he_separator = ":"
local he_separator2 = "|"
local he_concat_tbl = {
	[1] = he_begin,
	[3] = he_separator,
	[5] = he_separator,
	[7] = he_separator2,
	[9] = he_separator,
	[11] = he_separator,
}
local he_empty_connect = ""
local function hashEdge(e)
	he_concat_tbl[2] = math_floor(e[1][1] * 100) / 1000
	he_concat_tbl[4] = math_floor(e[1][2] * 100) / 1000
	he_concat_tbl[6] = math_floor(e[1][3] * 100) / 1000

	he_concat_tbl[8] = math_floor(e[2][1] * 1000) / 1000
	he_concat_tbl[10] = math_floor(e[2][2] * 1000) / 1000
	he_concat_tbl[12] = math_floor(e[2][3] * 1000) / 1000


	return table.concat(he_concat_tbl, he_empty_connect)
end

--local material_white_cull = LK3D.FriendlySourceTexture(""

local modelEdgeList = {}

-- shadow volumes, uses carmack's reverse
local function bakeShadows(object)
	local mdlinfo = LK3D.Models[object.mdl]
	if not mdlinfo then
		return
	end

	local verts = mdlinfo.verts
	local ind = mdlinfo.indices
	local normals = mdlinfo.normals

	object.ShadowBakedMesh = Mesh()
	object.ShadowBakedMeshCaps = Mesh()
	object.ShadowBakedMeshInv = Mesh()
	object.ShadowBakedMeshInvCaps = Mesh()

	local scl = object.scl
	local pos = object.pos
	local ang = object.ang

	local closestLight = nil
	local closestLightDist = math_huge
	local do_zpass = (object["SHADOW_ZPASS"] == true)

	if not object["SHADOW_DOSUN"] then
		for k, v in pairs(LK3D.CurrUniv["lights"]) do
			local dcalc = v[1]:DistToSqr(pos)
			if dcalc < closestLightDist then
				closestLightDist = dcalc
				closestLight = k
			end
		end

		if not closestLight then
			return
		end
	end

	local lightData = LK3D.CurrUniv["lights"][closestLight]

	local liPos = (object["SHADOW_DOSUN"] and (LK3D.SunDir * 10000000) or Vector(lightData[1]))
	local edgeList = {}
	local triList = {}


	local edgeCount = 0
	for i = 1, #ind do
		local index = ind[i]
		local norm = normals[i]:GetNormalized()
		norm:Rotate(ang)

		local v1 = verts[index[1][1]] * scl
		local v2 = verts[index[2][1]] * scl
		local v3 = verts[index[3][1]] * scl

		v1:Rotate(ang)
		v1:Add(pos)

		v2:Rotate(ang)
		v2:Add(pos)

		v3:Rotate(ang)
		v3:Add(pos)

		local vavg = (v1 + v2 + v3)
		vavg:Div(3)


		local lightIncident = vavg - liPos

		if lightIncident:Dot(norm) >= 0 then
			triList[#triList + 1] = {v1, v2, v3, norm}

			local edge1 = {v3, v2}
			local edge2 = {v2, v3}

			local edge3 = {v2, v1}
			local edge4 = {v1, v2}

			local edge5 = {v1, v3}
			local edge6 = {v3, v1}


			local h1 = hashEdge(edge1)
			local h2 = hashEdge(edge2)
			if edgeList[h1] or edgeList[h2] then
				edgeList[h1] = nil
				edgeList[h2] = nil
				edgeCount = edgeCount - 1
			elseif not edgeList[h1] then
				edgeList[h1] = edge1
				edgeCount = edgeCount + 1
			end

			local h3 = hashEdge(edge3)
			local h4 = hashEdge(edge4)
			if edgeList[h3] or edgeList[h4] then
				edgeList[h3] = nil
				edgeList[h4] = nil
				edgeCount = edgeCount - 1
			elseif not edgeList[h3] then
				edgeList[h3] = edge3
				edgeCount = edgeCount + 1
			end

			local h5 = hashEdge(edge5)
			local h6 = hashEdge(edge6)
			if edgeList[h5] or edgeList[h6] then
				edgeList[h5] = nil
				edgeList[h6] = nil
				edgeCount = edgeCount - 1
			elseif not edgeList[h5] then
				edgeList[h5] = edge5
				edgeCount = edgeCount + 1
			end
		end
	end

	local extrude_dist = LK3D.ShadowExtrude or 10 -- this game uses close z values so we only need 10 extrude
	local extr_epsilon = -0.0001


	if not do_zpass then
		mesh_Begin(object.ShadowBakedMeshCaps, MATERIAL_TRIANGLES, #triList * 2)
			for k, v in ipairs(triList) do
				mesh_Color(0, 255, 0, 255)
				mesh_Position(v[1])
				mesh_TexCoord(0, 0, 0)
				mesh_AdvanceVertex()

				mesh_Color(0, 255, 0, 255)
				mesh_Position(v[2])
				mesh_TexCoord(0, 0, 0)
				mesh_AdvanceVertex()

				mesh_Color(0, 255, 0, 255)
				mesh_Position(v[3])
				mesh_TexCoord(0, 0, 0)
				mesh_AdvanceVertex()
			end

			for k, v in ipairs(triList) do
				mesh_Color(0, 255, 0, 255)
				mesh_Position(v[3] + (v[3] - liPos):GetNormalized() * extrude_dist)
				mesh_TexCoord(0, 0, 0)
				mesh_AdvanceVertex()

				mesh_Color(0, 255, 0, 255)
				mesh_Position(v[2] + (v[2] - liPos):GetNormalized() * extrude_dist)
				mesh_TexCoord(0, 0, 0)
				mesh_AdvanceVertex()

				mesh_Color(0, 255, 0, 255)
				mesh_Position(v[1] + (v[1] - liPos):GetNormalized() * extrude_dist)
				mesh_TexCoord(0, 0, 0)
				mesh_AdvanceVertex()
			end
		mesh_End()



		mesh_Begin(object.ShadowBakedMesh, MATERIAL_TRIANGLES, edgeCount * 2)
		for k, v in pairs(edgeList) do
			local quad1 = v[1]
			local quad2 = v[2]
			local quad3 = v[1] + (v[1] - liPos):GetNormalized() * extrude_dist
			local quad4 = v[2] + (v[2] - liPos):GetNormalized() * extrude_dist

			mesh_Color(0, 255, 0, 255)
			mesh_Position(quad1)
			mesh_TexCoord(0, 0, 0)
			mesh_AdvanceVertex()

			mesh_Color(0, 255, 0, 255)
			mesh_Position(quad2)
			mesh_TexCoord(0, 0, 1)
			mesh_AdvanceVertex()

			mesh_Color(0, 255, 0, 255)
			mesh_Position(quad3)
			mesh_TexCoord(0, 1, 1)
			mesh_AdvanceVertex()

			mesh_Color(0, 255, 0, 255)
			mesh_Position(quad4)
			mesh_TexCoord(0, 0, 1)
			mesh_AdvanceVertex()

			mesh_Color(0, 255, 0, 255)
			mesh_Position(quad3)
			mesh_TexCoord(0, 0, 0)
			mesh_AdvanceVertex()

			mesh_Color(0, 255, 0, 255)
			mesh_Position(quad2)
			mesh_TexCoord(0, 1, 1)
			mesh_AdvanceVertex()
		end
		mesh_End()


		mesh_Begin(object.ShadowBakedMeshInvCaps, MATERIAL_TRIANGLES, #triList * 2)
			for k, v in ipairs(triList) do
				mesh_Color(0, 255, 0, 255)
				mesh_Position(v[3] + (v[4] * extr_epsilon))
				mesh_TexCoord(0, 0, 0)
				mesh_AdvanceVertex()


				mesh_Color(0, 255, 0, 255)
				mesh_Position(v[2] + (v[4] * extr_epsilon))
				mesh_TexCoord(0, 0, 0)
				mesh_AdvanceVertex()

				mesh_Color(0, 255, 0, 255)
				mesh_Position(v[1] + (v[4] * extr_epsilon))
				mesh_TexCoord(0, 0, 0)
				mesh_AdvanceVertex()
			end

			for k, v in ipairs(triList) do
				mesh_Color(0, 255, 0, 255)
				mesh_Position(v[1] + (v[1] - liPos):GetNormalized() * extrude_dist)
				mesh_TexCoord(0, 0, 0)
				mesh_AdvanceVertex()

				mesh_Color(0, 255, 0, 255)
				mesh_Position(v[2] + (v[2] - liPos):GetNormalized() * extrude_dist)
				mesh_TexCoord(0, 0, 0)
				mesh_AdvanceVertex()

				mesh_Color(0, 255, 0, 255)
				mesh_Position(v[3] + (v[3] - liPos):GetNormalized() * extrude_dist)
				mesh_TexCoord(0, 0, 0)
				mesh_AdvanceVertex()
			end
		mesh_End()

		mesh_Begin(object.ShadowBakedMeshInv, MATERIAL_TRIANGLES, edgeCount * 2)
		for k, v in pairs(edgeList) do
			local quad1 = v[1]
			local quad2 = v[2]
			local quad3 = v[1] + (v[1] - liPos):GetNormalized() * extrude_dist
			local quad4 = v[2] + (v[2] - liPos):GetNormalized() * extrude_dist

			mesh_Color(255, 0, 0, 255)
			mesh_Position(quad3)
			mesh_TexCoord(0, 0, 0)
			mesh_AdvanceVertex()

			mesh_Color(255, 0, 0, 255)
			mesh_Position(quad2)
			mesh_TexCoord(0, 0, 1)
			mesh_AdvanceVertex()

			mesh_Color(255, 0, 0, 255)
			mesh_Position(quad1)
			mesh_TexCoord(0, 1, 1)
			mesh_AdvanceVertex()


			mesh_Color(255, 0, 0, 255)
			mesh_Position(quad2)
			mesh_TexCoord(0, 0, 1)
			mesh_AdvanceVertex()

			mesh_Color(255, 0, 0, 255)
			mesh_Position(quad3)
			mesh_TexCoord(0, 0, 0)
			mesh_AdvanceVertex()

			mesh_Color(255, 0, 0, 255)
			mesh_Position(quad4)
			mesh_TexCoord(0, 1, 1)
			mesh_AdvanceVertex()
		end
		mesh_End()
	else
		mesh_Begin(object.ShadowBakedMesh, MATERIAL_TRIANGLES, edgeCount * 2)
		for k, v in pairs(edgeList) do
			local quad1 = v[1]
			local quad2 = v[2]
			local quad3 = v[1] + (v[1] - liPos):GetNormalized() * extrude_dist
			local quad4 = v[2] + (v[2] - liPos):GetNormalized() * extrude_dist

			mesh_Color(0, 255, 0, 255)
			mesh_Position(quad1)
			mesh_TexCoord(0, 0, 0)
			mesh_AdvanceVertex()

			mesh_Color(0, 255, 0, 255)
			mesh_Position(quad2)
			mesh_TexCoord(0, 0, 1)
			mesh_AdvanceVertex()

			mesh_Color(0, 255, 0, 255)
			mesh_Position(quad3)
			mesh_TexCoord(0, 1, 1)
			mesh_AdvanceVertex()

			mesh_Color(0, 255, 0, 255)
			mesh_Position(quad4)
			mesh_TexCoord(0, 0, 1)
			mesh_AdvanceVertex()

			mesh_Color(0, 255, 0, 255)
			mesh_Position(quad3)
			mesh_TexCoord(0, 0, 0)
			mesh_AdvanceVertex()

			mesh_Color(0, 255, 0, 255)
			mesh_Position(quad2)
			mesh_TexCoord(0, 1, 1)
			mesh_AdvanceVertex()
		end
		mesh_End()

		mesh_Begin(object.ShadowBakedMeshInv, MATERIAL_TRIANGLES, edgeCount * 2)
		for k, v in pairs(edgeList) do
			local quad1 = v[1]
			local quad2 = v[2]
			local quad3 = v[1] + (v[1] - liPos):GetNormalized() * extrude_dist
			local quad4 = v[2] + (v[2] - liPos):GetNormalized() * extrude_dist

			mesh_Color(255, 0, 0, 255)
			mesh_Position(quad3)
			mesh_TexCoord(0, 0, 0)
			mesh_AdvanceVertex()

			mesh_Color(255, 0, 0, 255)
			mesh_Position(quad2)
			mesh_TexCoord(0, 0, 1)
			mesh_AdvanceVertex()

			mesh_Color(255, 0, 0, 255)
			mesh_Position(quad1)
			mesh_TexCoord(0, 1, 1)
			mesh_AdvanceVertex()


			mesh_Color(255, 0, 0, 255)
			mesh_Position(quad2)
			mesh_TexCoord(0, 0, 1)
			mesh_AdvanceVertex()

			mesh_Color(255, 0, 0, 255)
			mesh_Position(quad3)
			mesh_TexCoord(0, 0, 0)
			mesh_AdvanceVertex()

			mesh_Color(255, 0, 0, 255)
			mesh_Position(quad4)
			mesh_TexCoord(0, 1, 1)
			mesh_AdvanceVertex()
		end
		mesh_End()
	end
end



local function renderShadows(object)
	local mdlinfo = LK3D.Models[object.mdl]
	if not mdlinfo then
		return
	end

	local verts = mdlinfo.verts
	local ind = mdlinfo.indices
	local normals = mdlinfo.normals
	local do_zpass = (object["SHADOW_ZPASS"] == true)


	if object["SHADOW_VOLUME_BAKE"] then
		if not object.ShadowBakedMesh or (object["SHADOW_VOLUME_BAKE_CLEAR"] == true) then
			bakeShadows(object)
			object["SHADOW_VOLUME_BAKE_CLEAR"] = false
		end

		if object["PREV_ZPASS"] ~= do_zpass then
			bakeShadows(object)
			object["PREV_ZPASS"] = do_zpass
		end


		render_SetColorMaterial()
		render_SetStencilCompareFunction(STENCIL_ALWAYS)
		render_SetStencilReferenceValue(1)


		if not do_zpass then
			render_SetStencilPassOperation(STENCIL_KEEP)
			render_SetStencilFailOperation(STENCIL_KEEP)
			render_SetStencilZFailOperation(STENCIL_INCR)
			object.ShadowBakedMeshInv:Draw()
			object.ShadowBakedMeshInvCaps:Draw()


			render_SetStencilPassOperation(STENCIL_KEEP)
			render_SetStencilFailOperation(STENCIL_KEEP)
			render_SetStencilZFailOperation(STENCIL_DECRSAT)
			object.ShadowBakedMesh:Draw()
			object.ShadowBakedMeshCaps:Draw()
		else
			render_SetStencilPassOperation(STENCIL_INCR)
			render_SetStencilFailOperation(STENCIL_KEEP)
			render_SetStencilZFailOperation(STENCIL_KEEP)
			object.ShadowBakedMesh:Draw()


			render_SetStencilPassOperation(STENCIL_DECRSAT)
			render_SetStencilFailOperation(STENCIL_KEEP)
			render_SetStencilZFailOperation(STENCIL_KEEP)
			object.ShadowBakedMeshInv:Draw()
		end

		return
	end

	if not modelEdgeList[object.mdl] then
		modelEdgeList[object.mdl] = {}
		d_print("generating stencilshadow model edge list for \"" .. object.mdl .. "\"")
		local time_start = SysTime()

		local tblpointer = modelEdgeList[object.mdl]
		tblpointer.edges = {}
		-- calculate edges
		for i = 1, #ind do
			local index = ind[i]

			local v1 = verts[index[1][1]]
			local v2 = verts[index[2][1]]
			local v3 = verts[index[3][1]]

			local h1 = hashEdge({v1, v2})
			local h2 = hashEdge({v2, v1})

			local h3 = hashEdge({v2, v3})
			local h4 = hashEdge({v3, v2})

			local h5 = hashEdge({v3, v1})
			local h6 = hashEdge({v1, v3})

			local add1, add2, add3 = true, true, true
			for k, v in ipairs(tblpointer.edges) do
				local hv = hashEdge(v)
				if hv == h1 or hv == h2 then
					add1 = false
				end
				if hv == h3 or hv == h4 then
					add2 = false
				end
				if hv == h5 or hv == h6 then
					add3 = false
				end
			end

			if add1 then
				tblpointer.edges[#tblpointer.edges + 1] = {v1, v2}
			end

			if add2 then
				tblpointer.edges[#tblpointer.edges + 1] = {v2, v3}
			end

			if add3 then
				tblpointer.edges[#tblpointer.edges + 1] = {v3, v1}
			end
		end


		tblpointer.triedges = {}
		for i = 1, #ind do
			local index = ind[i]
			tblpointer.triedges[i] = {}

			local v1 = verts[index[1][1]]
			local v2 = verts[index[2][1]]
			local v3 = verts[index[3][1]]

			local h1 = hashEdge({v1, v2})
			local h2 = hashEdge({v2, v1})

			local h3 = hashEdge({v2, v3})
			local h4 = hashEdge({v3, v2})

			local h5 = hashEdge({v3, v1})
			local h6 = hashEdge({v1, v3})


			for k, v in ipairs(tblpointer.edges) do
				local hv = hashEdge(v)
				if hv == h1 or hv == h2 then
					tblpointer.triedges[i][1] = k
				end

				if hv == h3 or hv == h4 then
					tblpointer.triedges[i][2] = k
				end

				if hv == h5 or hv == h6 then
					tblpointer.triedges[i][3] = k
				end
			end
		end

		d_print("took " .. ((SysTime() - time_start) * 1000) .. "ms!")
	end


	--local s_norm = mdlinfo.s_normals

	--local mat = object.mat
	--local col = object.col
	local scl = object.scl

	local pos = object.pos
	local ang = object.ang

	--local m_obj = Matrix()
	--m_obj:SetAngles(ang)
	--m_obj:SetTranslation(pos)



	local closestLight = nil
	local closestLightDist = math_huge


	if not object["SHADOW_DOSUN"] then
		for k, v in pairs(LK3D.CurrUniv["lights"]) do
			local dcalc = v[1]:DistToSqr(pos)
			if dcalc < closestLightDist then
				closestLightDist = dcalc
				closestLight = k
			end
		end

		if not closestLight then
			return
		end
	end

	local lightData = LK3D.CurrUniv["lights"][closestLight]
	local edgeData = modelEdgeList[object.mdl]

	local liPos = (object["SHADOW_DOSUN"] and (LK3D.SunDir * 10000000) or Vector(lightData[1]))
	local edgeList = {}
	local triList = {}


	local edgeCount = 0
	for i = 1, #ind do
		local index = ind[i]
		local norm = normals[i]:GetNormalized()
		norm:Rotate(ang)

		--local snorm = s_norm[i]:GetNormalized()
		--snorm:Rotate(ang)

		local v1 = verts[index[1][1]] * scl
		local v2 = verts[index[2][1]] * scl
		local v3 = verts[index[3][1]] * scl

		v1:Rotate(ang)
		v1:Add(pos)

		v2:Rotate(ang)
		v2:Add(pos)

		v3:Rotate(ang)
		v3:Add(pos)

		local vavg = (v1 + v2 + v3)
		vavg:Div(3)



		local lightIncident = vavg - liPos


		local currEdges = edgeData.triedges[i]
		if lightIncident:Dot(norm) >= 0 then
			if not do_zpass then
				triList[#triList + 1] = {v1, v2, v3, norm}
			end

			local e1i = currEdges[1]
			local e2i = currEdges[2]
			local e3i = currEdges[3]

			if edgeList[e1i] then
				edgeList[e1i] = nil
				edgeCount = edgeCount - 1
			elseif not edgeList[e1i] then
				edgeList[e1i] = {v2, v1} --edgeData.edges[e1i]
				edgeCount = edgeCount + 1
			end

			if edgeList[e2i] then
				edgeList[e2i] = nil
				edgeCount = edgeCount - 1
			elseif not edgeList[e2i] then
				edgeList[e2i] = {v3, v2} --edgeData.edges[e2i]
				edgeCount = edgeCount + 1
			end

			if edgeList[e3i] then
				edgeList[e3i] = nil
				edgeCount = edgeCount - 1
			elseif not edgeList[e3i] then
				edgeList[e3i] = {v1, v3} --edgeData.edges[e3i]
				edgeCount = edgeCount + 1
			end
		end
	end

	local extrude_dist = LK3D.ShadowExtrude or 10 -- close z values, use 10
	local extr_epsilon = -0.0001
	render_SetColorMaterial()
	render_SetStencilCompareFunction(STENCIL_ALWAYS)
	render_SetStencilReferenceValue(1)


	if not do_zpass then
		render_SetStencilPassOperation(STENCIL_KEEP)
		render_SetStencilFailOperation(STENCIL_KEEP)
		render_SetStencilZFailOperation(STENCIL_INCR)

		mesh_Begin(MATERIAL_TRIANGLES, #triList * 2)
			for k, v in ipairs(triList) do
				mesh_Color(0, 255, 0, 255)
				mesh_Position(v[3] + (v[4] * extr_epsilon))
				mesh_TexCoord(0, 0, 0)
				mesh_AdvanceVertex()


				mesh_Color(0, 255, 0, 255)
				mesh_Position(v[2] + (v[4] * extr_epsilon))
				mesh_TexCoord(0, 0, 0)
				mesh_AdvanceVertex()

				mesh_Color(0, 255, 0, 255)
				mesh_Position(v[1] + (v[4] * extr_epsilon))
				mesh_TexCoord(0, 0, 0)
				mesh_AdvanceVertex()
			end

			for k, v in ipairs(triList) do
				mesh_Color(0, 255, 0, 255)
				mesh_Position(v[1] + (v[1] - liPos):GetNormalized() * extrude_dist)
				mesh_TexCoord(0, 0, 0)
				mesh_AdvanceVertex()

				mesh_Color(0, 255, 0, 255)
				mesh_Position(v[2] + (v[2] - liPos):GetNormalized() * extrude_dist)
				mesh_TexCoord(0, 0, 0)
				mesh_AdvanceVertex()

				mesh_Color(0, 255, 0, 255)
				mesh_Position(v[3] + (v[3] - liPos):GetNormalized() * extrude_dist)
				mesh_TexCoord(0, 0, 0)
				mesh_AdvanceVertex()

			end
		mesh_End()



		mesh_Begin(MATERIAL_TRIANGLES, edgeCount * 2)
		for k, v in pairs(edgeList) do
			local quad1 = v[1]
			local quad2 = v[2]
			local quad3 = v[1] + (v[1] - liPos):GetNormalized() * extrude_dist
			local quad4 = v[2] + (v[2] - liPos):GetNormalized() * extrude_dist

			mesh_Color(255, 0, 0, 255)
			mesh_Position(quad3)
			mesh_TexCoord(0, 0, 0)
			mesh_AdvanceVertex()

			mesh_Color(255, 0, 0, 255)
			mesh_Position(quad2)
			mesh_TexCoord(0, 0, 1)
			mesh_AdvanceVertex()

			mesh_Color(255, 0, 0, 255)
			mesh_Position(quad1)
			mesh_TexCoord(0, 1, 1)
			mesh_AdvanceVertex()


			mesh_Color(255, 0, 0, 255)
			mesh_Position(quad2)
			mesh_TexCoord(0, 0, 1)
			mesh_AdvanceVertex()

			mesh_Color(255, 0, 0, 255)
			mesh_Position(quad3)
			mesh_TexCoord(0, 0, 0)
			mesh_AdvanceVertex()

			mesh_Color(255, 0, 0, 255)
			mesh_Position(quad4)
			mesh_TexCoord(0, 1, 1)
			mesh_AdvanceVertex()
		end
		mesh_End()

		render_SetStencilPassOperation(STENCIL_KEEP)
		render_SetStencilFailOperation(STENCIL_KEEP)
		render_SetStencilZFailOperation(STENCIL_DECRSAT)
		mesh_Begin(MATERIAL_TRIANGLES, #triList * 2)
			for k, v in ipairs(triList) do
				mesh_Color(0, 255, 0, 255)
				mesh_Position(v[1])
				mesh_TexCoord(0, 0, 0)
				mesh_AdvanceVertex()

				mesh_Color(0, 255, 0, 255)
				mesh_Position(v[2])
				mesh_TexCoord(0, 0, 0)
				mesh_AdvanceVertex()

				mesh_Color(0, 255, 0, 255)
				mesh_Position(v[3])
				mesh_TexCoord(0, 0, 0)
				mesh_AdvanceVertex()
			end

			for k, v in ipairs(triList) do
				mesh_Color(0, 255, 0, 255)
				mesh_Position(v[3] + (v[3] - liPos):GetNormalized() * extrude_dist)
				mesh_TexCoord(0, 0, 0)
				mesh_AdvanceVertex()

				mesh_Color(0, 255, 0, 255)
				mesh_Position(v[2] + (v[2] - liPos):GetNormalized() * extrude_dist)
				mesh_TexCoord(0, 0, 0)
				mesh_AdvanceVertex()

				mesh_Color(0, 255, 0, 255)
				mesh_Position(v[1] + (v[1] - liPos):GetNormalized() * extrude_dist)
				mesh_TexCoord(0, 0, 0)
				mesh_AdvanceVertex()
			end
		mesh_End()

		mesh_Begin(MATERIAL_TRIANGLES, edgeCount * 2)
			for k, v in pairs(edgeList) do
				local quad1 = v[1]
				local quad2 = v[2]
				local quad3 = v[1] + (v[1] - liPos):GetNormalized() * extrude_dist
				local quad4 = v[2] + (v[2] - liPos):GetNormalized() * extrude_dist

				mesh_Color(0, 255, 0, 255)
				mesh_Position(quad1)
				mesh_TexCoord(0, 0, 0)
				mesh_AdvanceVertex()

				mesh_Color(0, 255, 0, 255)
				mesh_Position(quad2)
				mesh_TexCoord(0, 0, 1)
				mesh_AdvanceVertex()

				mesh_Color(0, 255, 0, 255)
				mesh_Position(quad3)
				mesh_TexCoord(0, 1, 1)
				mesh_AdvanceVertex()

				mesh_Color(0, 255, 0, 255)
				mesh_Position(quad4)
				mesh_TexCoord(0, 0, 1)
				mesh_AdvanceVertex()

				mesh_Color(0, 255, 0, 255)
				mesh_Position(quad3)
				mesh_TexCoord(0, 0, 0)
				mesh_AdvanceVertex()

				mesh_Color(0, 255, 0, 255)
				mesh_Position(quad2)
				mesh_TexCoord(0, 1, 1)
				mesh_AdvanceVertex()
			end
		mesh_End()

	else
		render_SetStencilPassOperation(STENCIL_INCR)
		render_SetStencilFailOperation(STENCIL_KEEP)
		render_SetStencilZFailOperation(STENCIL_KEEP)

		mesh_Begin(MATERIAL_TRIANGLES, edgeCount * 2)
			for k, v in pairs(edgeList) do
				local quad1 = v[1]
				local quad2 = v[2]
				local quad3 = v[1] + (v[1] - liPos):GetNormalized() * extrude_dist
				local quad4 = v[2] + (v[2] - liPos):GetNormalized() * extrude_dist

				mesh_Color(0, 255, 0, 255)
				mesh_Position(quad1)
				mesh_TexCoord(0, 0, 0)
				mesh_AdvanceVertex()

				mesh_Color(0, 255, 0, 255)
				mesh_Position(quad2)
				mesh_TexCoord(0, 0, 1)
				mesh_AdvanceVertex()

				mesh_Color(0, 255, 0, 255)
				mesh_Position(quad3)
				mesh_TexCoord(0, 1, 1)
				mesh_AdvanceVertex()

				mesh_Color(0, 255, 0, 255)
				mesh_Position(quad4)
				mesh_TexCoord(0, 0, 1)
				mesh_AdvanceVertex()

				mesh_Color(0, 255, 0, 255)
				mesh_Position(quad3)
				mesh_TexCoord(0, 0, 0)
				mesh_AdvanceVertex()

				mesh_Color(0, 255, 0, 255)
				mesh_Position(quad2)
				mesh_TexCoord(0, 1, 1)
				mesh_AdvanceVertex()
			end
		mesh_End()


		render_SetStencilPassOperation(STENCIL_DECRSAT)
		render_SetStencilFailOperation(STENCIL_KEEP)
		render_SetStencilZFailOperation(STENCIL_KEEP)
		mesh_Begin(MATERIAL_TRIANGLES, edgeCount * 2)
			for k, v in pairs(edgeList) do
				local quad1 = v[1]
				local quad2 = v[2]
				local quad3 = v[1] + (v[1] - liPos):GetNormalized() * extrude_dist
				local quad4 = v[2] + (v[2] - liPos):GetNormalized() * extrude_dist

				mesh_Color(255, 0, 0, 255)
				mesh_Position(quad3)
				mesh_TexCoord(0, 0, 0)
				mesh_AdvanceVertex()

				mesh_Color(255, 0, 0, 255)
				mesh_Position(quad2)
				mesh_TexCoord(0, 0, 1)
				mesh_AdvanceVertex()

				mesh_Color(255, 0, 0, 255)
				mesh_Position(quad1)
				mesh_TexCoord(0, 1, 1)
				mesh_AdvanceVertex()


				mesh_Color(255, 0, 0, 255)
				mesh_Position(quad2)
				mesh_TexCoord(0, 0, 1)
				mesh_AdvanceVertex()

				mesh_Color(255, 0, 0, 255)
				mesh_Position(quad3)
				mesh_TexCoord(0, 0, 0)
				mesh_AdvanceVertex()

				mesh_Color(255, 0, 0, 255)
				mesh_Position(quad4)
				mesh_TexCoord(0, 1, 1)
				mesh_AdvanceVertex()
			end
		mesh_End()
	end
end


return renderShadows