LK3D = LK3D or {}

local render = render
local render_SetMaterial = render.SetMaterial

local cam = cam

local math = math

local mesh = mesh
local mesh_Color = mesh.Color
local mesh_Position = mesh.Position
local mesh_TexCoord = mesh.TexCoord
local mesh_AdvanceVertex = mesh.AdvanceVertex
local mesh_End = mesh.End
local mesh_Begin = mesh.Begin


local wfMat = Material("editor/wireframe")

local function d_print(...)
	if not LK3D.Debug then
		return
	end

	MsgC(Color(255, 100, 100), "[Hardware renderer debug]: ", Color(200, 255, 200), ..., "\n")
end

local light_mult_at_pos = include("lightmult.lua")
local function cacheModel(name, tag, func, delta, m_ind)
	if not LK3D.CurrUniv["modelCache"] then
		LK3D.CurrUniv["modelCache"] = {}
	end


	local object = LK3D.CurrUniv["objects"][name]
	if not object then
		return
	end



	local mdlinfo = LK3D.Models[object.mdl]
	local verts = mdlinfo.verts
	local uvs = mdlinfo.uvs
	local lightmap_uvs = object.lightmap_uvs
	local dolightmap = (lightmap_uvs ~= nil) and true or false
	local doLmUvs = (object["UV_USE_LIGHTMAP"] ~= nil) and true or false


	local ind = mdlinfo.indices
	local normals = mdlinfo.normals
	local s_norm = mdlinfo.s_normals

	local mat = object.mat
	local col = object.col
	local scl = object.scl

	local pos = object.pos
	local ang = object.ang

	local r, g, b = col.r, col.g, col.b

	local mesh_obj = Mesh(LK3D.WireFrame and wfMat or (object.limap_tex and LK3D.Textures[mat].mat_lm or LK3D.Textures[mat].mat))

	local ns = object["NORM_LIGHT_AFFECT"]
	mesh_Begin(mesh_obj, MATERIAL_TRIANGLES, #ind)
	for i = 1, #ind do
		local rc1, gc1, bc1 = r, g, b
		local rc2, gc2, bc2 = r, g, b
		local rc3, gc3, bc3 = r, g, b


		local index = ind[i]

		local uv1 = uvs[index[1][2]]
		local uv2 = uvs[index[2][2]]
		local uv3 = uvs[index[3][2]]

		local lm_uv1
		local lm_uv2
		local lm_uv3
		if dolightmap or (doLmUvs and dolightmap) then
			lm_uv1 = lightmap_uvs[index[1][3] or 0]
			lm_uv2 = lightmap_uvs[index[2][3] or 0]
			lm_uv3 = lightmap_uvs[index[3][3] or 0]
		end

		local v1 = Vector(verts[index[1][1]])
		local v2 = Vector(verts[index[2][1]])
		local v3 = Vector(verts[index[3][1]])

		local norm = normals[i]:GetNormalized()
		norm:Rotate(ang)

		if (func ~= nil) then -- if mesh is animated
			local rgbtbl1, rgbtbl2, rgbtbl3 = {rc1, gc1, bc1}, {rc2, gc2, bc2}, {rc3, gc3, bc3}
			local cuv1, cuv2, cuv3 = {uv1[1], uv1[2]}, {uv2[1], uv2[2]}, {uv3[1], uv3[2]}

			local norm1, norm2, norm3
			if object["SHADER_NO_SMOOTHNORM"] then -- normal
				norm1, norm2, norm3 = norm, norm, norm
			else
				local sn1 = Vector(s_norm[index[1][1]] or normals[i])
				local sn2 = Vector(s_norm[index[2][1]] or normals[i])
				local sn3 = Vector(s_norm[index[3][1]] or normals[i])
				sn1:Rotate(ang)
				sn2:Rotate(ang)
				sn3:Rotate(ang)
				norm1, norm2, norm3 = sn1, sn2, sn3
			end


			LK3D.SHADER_OBJREF = object
			LK3D.SHADER_VERTID = i * 3
			LK3D.SHADER_VERTINDEX = index[1][1]
			pcall(func, delta, v1, cuv1, rgbtbl1, norm1)
			LK3D.SHADER_VERTID = (i * 3) + 1
			LK3D.SHADER_VERTINDEX = index[2][1]
			pcall(func, delta, v2, cuv2, rgbtbl2, norm2)
			LK3D.SHADER_VERTID = (i * 3) + 2
			LK3D.SHADER_VERTINDEX = index[3][1]
			pcall(func, delta, v3, cuv3, rgbtbl3, norm3)

			rc1, gc1, bc1 = rgbtbl1[1], rgbtbl1[2], rgbtbl1[3]
			rc2, gc2, bc2 = rgbtbl2[1], rgbtbl2[2], rgbtbl2[3]
			rc3, gc3, bc3 = rgbtbl3[1], rgbtbl3[2], rgbtbl3[3]

			uv1 = cuv1
			uv2 = cuv2
			uv3 = cuv3
		end

		-- call lite once
		if object["VERT_SHADER"] ~= nil then
			local rgbtbl1, rgbtbl2, rgbtbl3 = {rc1, gc1, bc1}, {rc2, gc2, bc2}, {rc3, gc3, bc3}
			local cuv1, cuv2, cuv3 = {uv1[1], uv1[2]}, {uv2[1], uv2[2]}, {uv3[1], uv3[2]}

			local norm1, norm2, norm3
			if object["SHADER_NO_SMOOTHNORM"] then -- normal
				norm1, norm2, norm3 = norm, norm, norm
			else
				local sn1 = Vector(s_norm[index[1][1]] or normals[i])
				local sn2 = Vector(s_norm[index[2][1]] or normals[i])
				local sn3 = Vector(s_norm[index[3][1]] or normals[i])
				sn1:Rotate(ang)
				sn2:Rotate(ang)
				sn3:Rotate(ang)
				norm1, norm2, norm3 = sn1, sn2, sn3
			end


			LK3D.SHADER_OBJREF = object
			LK3D.SHADER_VERTID = i * 3
			LK3D.SHADER_VERTINDEX = index[1][1]
			pcall(object["VERT_SHADER"], v1, cuv1, rgbtbl1, norm1)
			LK3D.SHADER_VERTID = (i * 3) + 1
			LK3D.SHADER_VERTINDEX = index[2][1]
			pcall(object["VERT_SHADER"], v2, cuv2, rgbtbl2, norm2)
			LK3D.SHADER_VERTID = (i * 3) + 2
			LK3D.SHADER_VERTINDEX = index[3][1]
			pcall(object["VERT_SHADER"], v3, cuv3, rgbtbl3, norm3)

			rc1, gc1, bc1 = rgbtbl1[1], rgbtbl1[2], rgbtbl1[3]
			rc2, gc2, bc2 = rgbtbl2[1], rgbtbl2[2], rgbtbl2[3]
			rc3, gc3, bc3 = rgbtbl3[1], rgbtbl3[2], rgbtbl3[3]

			uv1 = cuv1
			uv2 = cuv2
			uv3 = cuv3
		end
		if LK3D.DoDirLighting and not object["NO_SHADING"] then
			if object["SHADING_SMOOTH"] then -- do gouraud shading
				local sn1 = Vector(s_norm[index[1][1]])
				local sn2 = Vector(s_norm[index[2][1]])
				local sn3 = Vector(s_norm[index[3][1]])
				sn1:Rotate(ang)
				sn2:Rotate(ang)
				sn3:Rotate(ang)

				if object["NORM_INVERT"] then
					sn1 = -sn1
					sn2 = -sn2
					sn3 = -sn3
				end


				local n1, n2, n3

				if object["LIDOT_MUL"] then
					n1 = (((sn1:Dot(LK3D.SunDir) + 1) / 2) + (object["LIDOT_ADD"] or 0)) * object["LIDOT_MUL"]
					n2 = (((sn2:Dot(LK3D.SunDir) + 1) / 2) + (object["LIDOT_ADD"] or 0)) * object["LIDOT_MUL"]
					n3 = (((sn3:Dot(LK3D.SunDir) + 1) / 2) + (object["LIDOT_ADD"] or 0)) * object["LIDOT_MUL"]
				else
					n1 = ((sn1:Dot(LK3D.SunDir) + 1) / 3) + 0.333
					n2 = ((sn2:Dot(LK3D.SunDir) + 1) / 3) + 0.333
					n3 = ((sn3:Dot(LK3D.SunDir) + 1) / 3) + 0.333
				end

				rc1, gc1, bc1 = rc1 * n1, gc1 * n1, bc1 * n1
				rc2, gc2, bc2 = rc2 * n2, gc2 * n2, bc2 * n2
				rc3, gc3, bc3 = rc3 * n3, gc3 * n3, bc3 * n3
			else -- do flat shading
				if object["NORM_INVERT"] then
					norm = -norm
				end

				local ncol
				if object["LIDOT_MUL"] then
					ncol = (((norm:Dot(LK3D.SunDir) + 1) / 2) + (object["LIDOT_ADD"] or 0)) * object["LIDOT_MUL"]
				else
					ncol = ((norm:Dot(LK3D.SunDir) + 1) / 3) + 0.333
				end

				rc1, gc1, bc1 = rc1 * ncol, gc1 * ncol, bc1 * ncol
				rc2, gc2, bc2 = rc2 * ncol, gc2 * ncol, bc2 * ncol
				rc3, gc3, bc3 = rc3 * ncol, gc3 * ncol, bc3 * ncol

				if object["NORM_INVERT"] then
					norm = -norm
				end
			end
		end

		if not object["NO_LIGHTING"] then
			local v1t = v1 * scl
			local v2t = v2 * scl
			local v3t = v3 * scl
			v1t:Rotate(ang)
			v2t:Rotate(ang)
			v3t:Rotate(ang)

			v1t:Add(pos)
			v2t:Add(pos)
			v3t:Add(pos)

			local lr1, lg1, lb1 = 0, 0, 0
			local lr2, lg2, lb2 = 0, 0, 0
			local lr3, lg3, lb3 = 0, 0, 0
			if object["SHADING_SMOOTH"] then -- do gouraud shading
				local sn1 = Vector(s_norm[index[1][1]])
				local sn2 = Vector(s_norm[index[2][1]])
				local sn3 = Vector(s_norm[index[3][1]])
				sn1:Rotate(ang)
				sn2:Rotate(ang)
				sn3:Rotate(ang)


				lr1, lg1, lb1 = light_mult_at_pos(v1t, ns, sn1, object["LIGHT_BLACKLIST"])
				lr2, lg2, lb2 = light_mult_at_pos(v2t, ns, sn2, object["LIGHT_BLACKLIST"])
				lr3, lg3, lb3 = light_mult_at_pos(v3t, ns, sn3, object["LIGHT_BLACKLIST"])
			else
				lr1, lg1, lb1 = light_mult_at_pos(v1t, ns, norm, object["LIGHT_BLACKLIST"])
				lr2, lg2, lb2 = light_mult_at_pos(v2t, ns, norm, object["LIGHT_BLACKLIST"])
				lr3, lg3, lb3 = light_mult_at_pos(v3t, ns, norm, object["LIGHT_BLACKLIST"])
			end

			if object["BAKE_AO"] then
				local vind1 = index[1][1]
				local vind2 = index[2][1]
				local vind3 = index[3][1]

				local aoc1 = ao_store[vind1]
				lr1 = lr1 * aoc1
				lg1 = lg1 * aoc1
				lb1 = lb1 * aoc1

				local aoc2 = ao_store[vind2]
				lr2 = lr2 * aoc2
				lg2 = lg2 * aoc2
				lb2 = lb2 * aoc2

				local aoc3 = ao_store[vind3]
				lr3 = lr3 * aoc3
				lg3 = lg3 * aoc3
				lb3 = lb3 * aoc3
			end

			rc1 = rc1 * lr1
			rc2 = rc2 * lr2
			rc3 = rc3 * lr3

			gc1 = gc1 * lg1
			gc2 = gc2 * lg2
			gc3 = gc3 * lg3

			bc1 = bc1 * lb1
			bc2 = bc2 * lb2
			bc3 = bc3 * lb3
		end


		if object["NORM_INVERT"] then
			mesh_Color(rc1, gc1, bc1, 255)
			mesh_Position(v1)
			mesh_TexCoord(0, doLmUvs and lm_uv1[1] or uv1[1], doLmUvs and lm_uv1[2] or uv1[2])
			if dolightmap then
				mesh_TexCoord(1, lm_uv1[1], lm_uv1[2])
			end
			mesh_AdvanceVertex()

			mesh_Color(rc2, gc2, bc2, 255)
			mesh_Position(v2)
			mesh_TexCoord(0, doLmUvs and lm_uv2[1] or uv2[1], doLmUvs and lm_uv2[2] or uv2[2])
			if dolightmap then
				mesh_TexCoord(1, lm_uv2[1], lm_uv2[2])
			end
			mesh_AdvanceVertex()

			mesh_Color(rc3, gc3, bc3, 255)
			mesh_Position(v3)
			mesh_TexCoord(0, doLmUvs and lm_uv3[1] or uv3[1], doLmUvs and lm_uv3[2] or uv3[2])
			if dolightmap then
				mesh_TexCoord(1, lm_uv3[1], lm_uv3[2])
			end
			mesh_AdvanceVertex()
		else
			mesh_Color(rc3, gc3, bc3, 255)
			mesh_Position(v3)
			mesh_TexCoord(0, doLmUvs and lm_uv3[1] or uv3[1], doLmUvs and lm_uv3[2] or uv3[2])
			if dolightmap then
				mesh_TexCoord(1, lm_uv3[1], lm_uv3[2])
			end
			mesh_AdvanceVertex()

			mesh_Color(rc2, gc2, bc2, 255)
			mesh_Position(v2)
			mesh_TexCoord(0, doLmUvs and lm_uv2[1] or uv2[1], doLmUvs and lm_uv2[2] or uv2[2])
			if dolightmap then
				mesh_TexCoord(1, lm_uv2[1], lm_uv2[2])
			end
			mesh_AdvanceVertex()

			mesh_Color(rc1, gc1, bc1, 255)
			mesh_Position(v1)
			mesh_TexCoord(0, doLmUvs and lm_uv1[1] or uv1[1], doLmUvs and lm_uv1[2] or uv1[2])
			if dolightmap then
				mesh_TexCoord(1, lm_uv1[1], lm_uv1[2])
			end
			mesh_AdvanceVertex()
		end
	end
	mesh_End()


	if not object.mdlCache then
		object.mdlCache = {}
	end

	if not tag then
		object.mdlCache[1] = mesh_obj
	else
		object.mdlCache[tag].meshes[m_ind] = mesh_obj
	end
end


local function renderCached(object)
	if object.mdlCache == nil then
		object.mdlCache = {}
	end

	local tag = object.anim_index

	if not tag then -- use num indx for faster index if not animated
		if not object.mdlCache[1] then
			cacheModel(object.name)
		end
	else
		local anim_nfo = object.mdlCache[tag]
		if not anim_nfo then
			d_print("No animinfo for anim \"" .. tag .. "\"")
			return
		end

		if not anim_nfo.genned then
			local frames = anim_nfo.frames
			for i = 1, frames do
				local delta_calc = (i - 1) / (frames - 1)
				cacheModel(object.name, tag, anim_nfo.func, delta_calc, i)
			end

			anim_nfo.genned = true
		end
	end

	local mat = object.mat

	render_SetMaterial(LK3D.WireFrame and wfMat or (object.limap_tex and LK3D.Textures[mat].mat_lm or LK3D.Textures[mat].mat))
	render.SetLightmapTexture(object.limap_tex and LK3D.Textures[object.limap_tex].rt or LK3D.Textures["lightmap_neutral2"].rt)

	local m_obj = Matrix()
	m_obj:SetAngles(object.ang)
	m_obj:SetTranslation(object.pos)
	m_obj:SetScale(object.scl)

	cam.PushModelMatrix(m_obj)
	if not tag then
		object.mdlCache[1]:Draw()
	else
		local anim_nfo = object.mdlCache[tag]
		local frameCount = anim_nfo.frames


		if (FrameNumber() - (object.anim_lastframe or 0)) > 0 and object.anim_state then
			if LK3D.AnimFrameDiv then
				object.anim_delta = ((object.anim_delta or 0) + (FrameTime() * (object.anim_rate / frameCount))) % 1.00001
			else
				object.anim_delta = ((object.anim_delta or 0) + (FrameTime() * object.anim_rate)) % 1.00001
			end
			object.anim_lastframe = FrameNumber()
		end





		local frame_t_calc = math.floor(object.anim_delta * (anim_nfo.frames - 1)) + 1

		object.mdlCache[tag].meshes[frame_t_calc]:Draw()
	end
	cam.PopModelMatrix()
end



return cacheModel, renderCached