--[[
	lk3d_renderer_hard.lua

	LK3D hardware (mesh. functions) renderer
	coded by lokachop
	"non-stop crash machine!"
	also yes, this file is a mess, sorry to anyone whos reading this


	contact at Lokachop#5862 or lokachop@gmail.com
]]--

LK3D = LK3D or {}
local Renderer = {}

Renderer.PrettyName = "Hardware (mesh)"

-- optimize
local render = render
local render_SetMaterial = render.SetMaterial
local render_SetViewPort = render.SetViewPort
local render_PushRenderTarget = render.PushRenderTarget
local render_PushFilterMag = render.PushFilterMag
local render_PushFilterMin = render.PushFilterMin
local render_PopFilterMag = render.PopFilterMag
local render_PopFilterMin = render.PopFilterMin
local render_PopRenderTarget = render.PopRenderTarget
local render_CapturePixels = render.CapturePixels
local render_ReadPixel = render.ReadPixel
local render_SetWriteDepthToDestAlpha = render.SetWriteDepthToDestAlpha


local render_SetStencilEnable = render.SetStencilEnable
local render_SetStencilWriteMask = render.SetStencilWriteMask
local render_SetStencilTestMask = render.SetStencilTestMask
local render_SetStencilReferenceValue = render.SetStencilReferenceValue
local render_SetStencilCompareFunction = render.SetStencilCompareFunction
local render_SetStencilPassOperation = render.SetStencilPassOperation
local render_SetStencilFailOperation = render.SetStencilFailOperation
local render_SetStencilZFailOperation = render.SetStencilZFailOperation
local render_ClearStencil = render.ClearStencil

local render_OverrideColorWriteEnable = render.OverrideColorWriteEnable
local render_OverrideDepthEnable = render.OverrideDepthEnable

local render_Clear = render.Clear
local render_Spin = render.Spin

local render_SetColorMaterial = render.SetColorMaterial
local render_OverrideBlend = render.OverrideBlend






local cam = cam
local cam_Start2D = cam.Start2D
local cam_End3D = cam.End3D
local cam_End2D = cam.End2D
local cam_Start = cam.Start

local math = math
local math_min = math.min
local math_floor = math.floor
local math_max = math.max
local math_abs = math.abs
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

local wfMat = Material("editor/wireframe")
local vertCount = 0
local triCount = 0
local mdlCount = 0
local cullCount = 0
local triCullCount = 0
local particleCount = 0
local cachedCount = 0

local light_mult_at_pos = include("lightmult.lua")
local ao_at_pos = include("ao_deprecated.lua")
local renderShadows = include("shadowvolume.lua")
local cacheModel, renderCached = include("model_cache.lua")

local function colLitApply(object)
	local mat = object.mat

	if object.ogMat then
		mat = object.ogMat
	end

	if not object.ogMat then
		object.ogMat = mat
	end


	local matnfo = LK3D.GetTextureByIndex(mat)
	local idx = matnfo.name .. "_col_" .. object.name .. (object["COL_LIT_CUST_TAG"] or "")

	if LK3D.Textures[idx] then
		object.mat = idx
		object.colLitMat = idx
		object.lastMat = idx
		return
	end


	LK3D.DeclareTextureFromFunc(idx, matnfo.mat:Width(), matnfo.mat:Height(), function()
	end)
	LK3D.CopyTexture(mat, idx)

	object.mat = idx
	object.colLitMat = idx
	object.lastMat = idx
end


local c_col_lit = Color(255, 255, 255)
local function renderModel(object)
	local mdlinfo = LK3D.Models[object.mdl]
	if not mdlinfo then
		return
	end


	local mat = object.mat
	if object["COL_LIT"] then
		--if (LK3D.MatRefresh or 0) > (object.last_matrefresh or 0) then
		--	object.last_matrefresh = (LK3D.MatRefresh or 0)
		--	colLitApply(object)
		--end

		if not object.ogMat then
			colLitApply(object)
		end
		if object.lastMat ~= object.mat then
			colLitApply(object)
		end

		if object["COL_LIT_CUST_TAG"] and (object.lastCLCTag ~= object["COL_LIT_CUST_TAG"]) then
			object.lastCLCTag = object["COL_LIT_CUST_TAG"]
			colLitApply(object)
		end


		local cr, cg, cb = 0, 0, 0

		if object["COL_LIT_CUSTOM"] ~= nil then
			cr = object["COL_LIT_CUSTOM"][1]
			cg = object["COL_LIT_CUSTOM"][2]
			cb = object["COL_LIT_CUSTOM"][3]
		else
			if object["COL_LIT_OFFSET"] ~= nil then
				cr, cg, cb = light_mult_at_pos(object.pos + object["COL_LIT_OFFSET"], false)
			else
				cr, cg, cb = light_mult_at_pos(object.pos, false)
			end
		end

		LK3D.UpdateTexture(object.colLitMat, function()
			c_col_lit.r = 255 * cr
			c_col_lit.g = 255 * cg
			c_col_lit.b = 255 * cb
			local matobj = LK3D.GetTextureByIndex(object.ogMat).mat
			render.SetMaterial(matobj)
			render.DrawQuad(Vector(0, 0), Vector(ScrW(), 0), Vector(ScrW(), ScrH()), Vector(0, ScrH()), c_col_lit)
			-- this was a pain
			-- the issue? whenever u loaded up a collit model on universeexplorer it would break the collit
			-- my fix sucks but its caused by surface.DrawTexturedRect so i had to use render.DrawQuad()
			-- yes i know colour objects are slow but oh well


			--render.OverrideBlend(true, BLEND_SRC_COLOR, BLEND_ONE, BLENDFUNC_REVERSE_SUBTRACT)
			--surface.DrawRect(0, 0, ScrW(), ScrH())
			--render.OverrideBlend(false)

			--surface.SetDrawColor(255 * cr, 255 * cg, 255 * cb)
			--surface.SetMaterial(matobj)
			--surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
		end)
	end

	if object["NEEDS_CACHE_UPDATE"] then
		cacheModel(object.name)
		object["NEEDS_CACHE_UPDATE"] = nil
	end

	if object["CONSTANT"] == true then
		renderCached(object)
		return
	end


	local verts = mdlinfo.verts
	local uvs = mdlinfo.uvs
	local lightmap_uvs = object.lightmap_uvs
	local dolightmap = (lightmap_uvs ~= nil) and true or false
	--if object["UV_USE_LIGHTMAP"] then
	--	uvs = lightmap_uvs
	--end

	local ind = mdlinfo.indices
	local normals = mdlinfo.normals
	local s_norm = mdlinfo.s_normals


	local col = object.col
	local scl = object.scl

	local pos = object.pos
	local ang = object.ang

	local r, g, b = col.r, col.g, col.b

	render_SetMaterial(LK3D.WireFrame and wfMat or (object.limap_tex and LK3D.Textures[mat].mat_lm or LK3D.Textures[mat].mat))
	render.SetLightmapTexture(object.limap_tex and LK3D.Textures[object.limap_tex].rt or LK3D.Textures["lightmap_neutral2"].rt)

	if (not object["NO_VW_CULLING"]) and ((pos - LK3D.CamPos):Dot(LK3D.CamAng:Forward()) < 0) then
		cullCount = cullCount + 1
		return
	end

	local doshader = object["VERT_SHADER"] ~= nil
	local vsh_parameter = object["VERT_SH_PARAMS"]
	local hasvshparameter = (vsh_parameter ~= nil) and true or nil
	local dobfculling = not object["NO_BF_CULLING"]

	if (hasvshparameter and vsh_parameter[4]) or (not hasvshparameter) then
		LK3D.SHADER_OBJREF = object
	end


	local m_obj = object.tmatrix


	cam.PushModelMatrix(m_obj, true)
	mesh_Begin(MATERIAL_TRIANGLES, #ind)
	for i = 1, #ind do
		local index = ind[i]

		local uv1, uv2, uv3 = uvs[index[1][2]], uvs[index[2][2]], uvs[index[3][2]]

		local lm_uv1
		local lm_uv2
		local lm_uv3
		if dolightmap then
			lm_uv1 = lightmap_uvs[index[1][3]]
			lm_uv2 = lightmap_uvs[index[2][3]]
			lm_uv3 = lightmap_uvs[index[3][3]]
		end

		local v1, v2, v3


		--  __________
		-- / my child \
		-- |will write |
		-- | good code |
		-- \_  _______/
		--   \|
		--  for i = 1,  ...  
		--                _____________
		--               /             \
		--               |optimizations|
		--               \______  _____/
		--                      |/
		local rc1, gc1, bc1 = r, g, b
		local rc2, gc2, bc2 = r, g, b
		local rc3, gc3, bc3 = r, g, b

		local norm = normals[i]:GetNormalized()
		norm:Rotate(ang)

		if object["NORM_INVERT"] then
			norm = -norm
		end

		local donorm = (hasvshparameter and vsh_parameter[5]) or (not hasvshparameter)
		if doshader then
			v1 = Vector(verts[index[1][1]])
			v2 = Vector(verts[index[2][1]])
			v3 = Vector(verts[index[3][1]])

			local cuv1, cuv2, cuv3 = hasvshparameter, hasvshparameter, hasvshparameter

			if (hasvshparameter and vsh_parameter[2]) or (not hasvshparameter) then -- vuv
				cuv1 = {uv1[1], uv1[2]}
				cuv2 = {uv2[1], uv2[2]}
				cuv3 = {uv3[1], uv3[2]}
			end

			local rgbtbl1, rgbtbl2, rgbtbl3 = hasvshparameter, hasvshparameter, hasvshparameter
			if (hasvshparameter and vsh_parameter[3]) or (not hasvshparameter) then -- vrgb
				rgbtbl1 = {rc1, gc1, bc1}
				rgbtbl2 = {rc2, gc2, bc2}
				rgbtbl3 = {rc3, gc3, bc3}
			end

			local norm1, norm2, norm3 = norm, norm, norm
			if donorm and not object["SHADER_NO_SMOOTHNORM"] then -- normal
				local sn1 = Vector(s_norm[index[1][1]] or normals[i])
				local sn2 = Vector(s_norm[index[2][1]] or normals[i])
				local sn3 = Vector(s_norm[index[3][1]] or normals[i])
				sn1:Rotate(ang)
				sn2:Rotate(ang)
				sn3:Rotate(ang)
				norm1, norm2, norm3 = sn1, sn2, sn3
			end

			LK3D.SHADER_VERTID = i * 3
			LK3D.SHADER_VERTINDEX = index[1][1]
			pcall(object["VERT_SHADER"], v1, cuv1, rgbtbl1, norm1)
			LK3D.SHADER_VERTID = (i * 3) + 1
			LK3D.SHADER_VERTINDEX = index[2][1]
			pcall(object["VERT_SHADER"], v2, cuv2, rgbtbl2, norm2)
			LK3D.SHADER_VERTID = (i * 3) + 2
			LK3D.SHADER_VERTINDEX = index[3][1]
			pcall(object["VERT_SHADER"], v3, cuv3, rgbtbl3, norm3)

			if (hasvshparameter and vsh_parameter[3]) or (not hasvshparameter) then -- vrgb
				rc1, gc1, bc1 = rgbtbl1[1], rgbtbl1[2], rgbtbl1[3]
				rc2, gc2, bc2 = rgbtbl2[1], rgbtbl2[2], rgbtbl2[3]
				rc3, gc3, bc3 = rgbtbl3[1], rgbtbl3[2], rgbtbl3[3]
			end

			if (hasvshparameter and vsh_parameter[2]) or (not hasvshparameter) then -- vuv
				uv1 = cuv1
				uv2 = cuv2
				uv3 = cuv3
			end
		else
			v1 = Vector(verts[index[1][1]])
			v2 = Vector(verts[index[2][1]])
			v3 = Vector(verts[index[3][1]])
		end


		--v1:Rotate(ang)
		--v1:Add(pos)

		--v2:Rotate(ang)
		--v2:Add(pos)

		--v3:Rotate(ang)
		--v3:Add(pos)

		--if doshader and not donorm then -- wtf was i smoking
			--norm = (v2 - v1):Cross(v3 - v1) -- re calculate, shader touches normals
			--norm:Normalize()
			--norm:Rotate(ang)
		--end

		if dobfculling then
			local p_n_c = m_obj * v1
			p_n_c:Sub(LK3D.CamPos)
			p_n_c:Normalize()

			if (norm:Dot(p_n_c:GetNormalized()) > 0) then
				triCullCount = triCullCount + 1
				continue
			end
		end


		if LK3D.DoDirLighting and not object["NO_SHADING"] then
			if object["SHADING_SMOOTH"] then -- gouraud shading
				local sn1 = Vector(s_norm[index[1][1]])
				local sn2 = Vector(s_norm[index[2][1]])
				local sn3 = Vector(s_norm[index[3][1]])
				sn1:Rotate(ang)
				sn2:Rotate(ang)
				sn3:Rotate(ang)


				local n1 = ((sn1:Dot(LK3D.SunDir) + 1) / 3) + 0.333
				local n2 = ((sn2:Dot(LK3D.SunDir) + 1) / 3) + 0.333
				local n3 = ((sn3:Dot(LK3D.SunDir) + 1) / 3) + 0.333


				rc1, gc1, bc1 = rc1 * n1, gc1 * n1, bc1 * n1
				rc2, gc2, bc2 = rc2 * n2, gc2 * n2, bc2 * n2
				rc3, gc3, bc3 = rc3 * n3, gc3 * n3, bc3 * n3
			else -- flat shading
				local ncol = ((norm:Dot(LK3D.SunDir) + 1) / 3) + 0.333

				rc1, gc1, bc1 = rc1 * ncol, gc1 * ncol, bc1 * ncol
				rc2, gc2, bc2 = rc2 * ncol, gc2 * ncol, bc2 * ncol
				rc3, gc3, bc3 = rc3 * ncol, gc3 * ncol, bc3 * ncol
			end
		end

		local lCount = LK3D.CurrUniv["lightcount"]
		local doLit = (lCount > 0 and (not object["NO_LIGHTING"]))
		local br, bg, bb = (doLit and (LK3D.AmbientCol.r / 255) or 1), (doLit and (LK3D.AmbientCol.g / 255) or 1), (doLit and (LK3D.AmbientCol.b / 255) or 1) -- war crimes


		local lVal1R, lVal2R, lVal3R = br, br, br
		local lVal1G, lVal2G, lVal3G = bg, bg, bg
		local lVal1B, lVal2B, lVal3B = bb, bb, bb


		if not object["NO_LIGHTING"] then
			local v1scl = v1 * scl
			local v2scl = v2 * scl
			local v3scl = v3 * scl

			for k, v in pairs(LK3D.CurrUniv["lights"]) do
				if lVal1R >= 1 and lVal1G >= 1 and lVal1B >= 1 and
					lVal2R >= 1 and lVal2G >= 1 and lVal2B >= 1 and
					lVal3R >= 1 and lVal3G >= 1 and lVal3B >= 1
				then
					break
				end

				if object["LIGHT_BLACKLIST"] and object["LIGHT_BLACKLIST"][k] == true then
					continue
				end

				local pos_l = Vector(v[1]) - pos
				local inten_l = v[2]
				local col_l = v[3]
				local sm = v[4]

				pos_l:Rotate(-ang)

				local v1d = v1scl:Distance(pos_l)
				local v2d = v2scl:Distance(pos_l)
				local v3d = v3scl:Distance(pos_l)

				local dc = (sm and inten_l ^ 2 or inten_l)
				if v1d > dc and v2d > dc and v3d > dc then
					continue
				end

				if sm then
					v1d = v1d ^ .5 -- pwr smooth
					v2d = v2d ^ .5
					v3d = v3d ^ .5
				end

				local vimv1d = (inten_l - v1d)
				local vimv2d = (inten_l - v2d)
				local vimv3d = (inten_l - v3d)
				pos_l:Rotate(ang)

				if object["NORM_LIGHT_AFFECT"] then -- if normals matter EXPENSIVE
					local v1r = Vector(v1scl)
					v1r:Rotate(ang)
					local v2r = Vector(v2scl)
					v2r:Rotate(ang)
					local v3r = Vector(v3scl)
					v3r:Rotate(ang)

					-- why do i even exist

					local lpr1 = (pos_l - v1r)
					lpr1:Normalize()
					local lpr2 = (pos_l - v2r)
					lpr2:Normalize()
					local lpr3 = (pos_l - v3r)
					lpr3:Normalize()

					if object["SHADING_SMOOTH"] then
						local sn1 = Vector(s_norm[index[1][1]])
						local sn2 = Vector(s_norm[index[2][1]])
						local sn3 = Vector(s_norm[index[3][1]])
						sn1:Rotate(ang)
						sn2:Rotate(ang)
						sn3:Rotate(ang)

						vimv1d = vimv1d * math_max(lpr1:Dot(sn1), 0)
						vimv2d = vimv2d * math_max(lpr2:Dot(sn2), 0)
						vimv3d = vimv3d * math_max(lpr3:Dot(sn3), 0)
					else
						vimv1d = vimv1d * math_max(lpr1:Dot(norm), 0)
						vimv2d = vimv2d * math_max(lpr2:Dot(norm), 0)
						vimv3d = vimv3d * math_max(lpr3:Dot(norm), 0)
					end
				end


				-- code rgb goodness
				--
				-- LIKE A NOOB

				--[[
				lVal1R = lVal1R + (col_l[1] * math_min(math_abs(math_max(vimv1d, 0)), 1))
				lVal1G = lVal1G + (col_l[2] * math_min(math_abs(math_max(vimv1d, 0)), 1))
				lVal1B = lVal1B + (col_l[3] * math_min(math_abs(math_max(vimv1d, 0)), 1))

				lVal2R = lVal2R + (col_l[1] * math_min(math_abs(math_max(vimv2d, 0)), 1))
				lVal2G = lVal2G + (col_l[2] * math_min(math_abs(math_max(vimv2d, 0)), 1))
				lVal2B = lVal2B + (col_l[3] * math_min(math_abs(math_max(vimv2d, 0)), 1))

				lVal3R = lVal3R + (col_l[1] * math_min(math_abs(math_max(vimv3d, 0)), 1))
				lVal3G = lVal3G + (col_l[2] * math_min(math_abs(math_max(vimv3d, 0)), 1))
				lVal3B = lVal3B + (col_l[3] * math_min(math_abs(math_max(vimv3d, 0)), 1))
				]]--

				-- dv1pc = math_abs(vimv1d < 0 and 0 or vimv1d)
				local dv1pc = vimv1d < 0 and 0 or vimv1d
				local dv1c = dv1pc > 1 and 1 or dv1pc
				lVal1R = lVal1R + col_l[1] * dv1c
				lVal1G = lVal1G + col_l[2] * dv1c
				lVal1B = lVal1B + col_l[3] * dv1c

				-- local dv2pc = math_abs(vimv2d < 0 and 0 or vimv2d)
				local dv2pc = vimv2d < 0 and 0 or vimv2d
				local dv2c = dv2pc > 1 and 1 or dv2pc
				lVal2R = lVal2R + col_l[1] * dv2c
				lVal2G = lVal2G + col_l[2] * dv2c
				lVal2B = lVal2B + col_l[3] * dv2c


				-- local dv3pc = math_abs(vimv3d < 0 and 0 or vimv3d)
				local dv3pc = vimv3d < 0 and 0 or vimv3d
				local dv3c = dv3pc > 1 and 1 or dv3pc
				lVal3R = lVal3R + col_l[1] * dv3c
				lVal3G = lVal3G + col_l[2] * dv3c
				lVal3B = lVal3B + col_l[3] * dv3c
			end


			--if lCount ~= 0 then
				-- lVal1R = (lVal1R < 0 and 0 or lVal1R) > 1 and 1 or (lVal1R < 0 and 0 or lVal1R)
				lVal1R = math_min(math_max(lVal1R, 0), 1)
				lVal1G = math_min(math_max(lVal1G, 0), 1)
				lVal1B = math_min(math_max(lVal1B, 0), 1)

				lVal2R = math_min(math_max(lVal2R, 0), 1)
				lVal2G = math_min(math_max(lVal2G, 0), 1)
				lVal2B = math_min(math_max(lVal2B, 0), 1)

				lVal3R = math_min(math_max(lVal3R, 0), 1)
				lVal3G = math_min(math_max(lVal3G, 0), 1)
				lVal3B = math_min(math_max(lVal3B, 0), 1)
			--end
		end

		if object["NORM_INVERT"] then
			mesh_Color(rc1 * lVal1R, gc1 * lVal1G, bc1 * lVal1B, 255)
			mesh_Position(v1)
			mesh_TexCoord(0, uv1[1], uv1[2])
			if dolightmap then
				mesh_TexCoord(1, lm_uv1[1], lm_uv1[2])
			end
			mesh_AdvanceVertex()

			mesh_Color(rc2 * lVal2R, gc2 * lVal2G, bc2 * lVal2B, 255)
			mesh_Position(v2)
			mesh_TexCoord(0, uv2[1], uv2[2])
			if dolightmap then
				mesh_TexCoord(1, lm_uv2[1], lm_uv2[2])
			end
			mesh_AdvanceVertex()

			mesh_Color(rc3 * lVal3R, gc3 * lVal3G, bc3 * lVal3B, 255)
			mesh_Position(v3)
			mesh_TexCoord(0, uv3[1], uv3[2])
			if dolightmap then
				mesh_TexCoord(1, lm_uv3[1], lm_uv3[2])
			end
			mesh_AdvanceVertex()
		else
			mesh_Color(rc3 * lVal3R, gc3 * lVal3G, bc3 * lVal3B, 255)
			mesh_Position(v3)
			mesh_TexCoord(0, uv3[1], uv3[2])
			if dolightmap then
				mesh_TexCoord(1, lm_uv3[1], lm_uv3[2])
			end
			mesh_AdvanceVertex()

			mesh_Color(rc2 * lVal2R, gc2 * lVal2G, bc2 * lVal2B, 255)
			mesh_Position(v2)
			mesh_TexCoord(0, uv2[1], uv2[2])
			if dolightmap then
				mesh_TexCoord(1, lm_uv2[1], lm_uv2[2])
			end
			mesh_AdvanceVertex()

			mesh_Color(rc1 * lVal1R, gc1 * lVal1G, bc1 * lVal1B, 255)
			mesh_Position(v1)
			mesh_TexCoord(0, uv1[1], uv1[2])
			if dolightmap then
				mesh_TexCoord(1, lm_uv1[1], lm_uv1[2])
			end
			mesh_AdvanceVertex()
		end
		vertCount = vertCount + 3
		triCount = triCount + 1
	end
	mesh_End()
	cam.PopModelMatrix()

	mdlCount = mdlCount + 1
end


local concat_friendly = {}
local head_str = "v("
local comma_str = ", "
local end_str = ")"
local patt_form = "%4.2f"
local function friendly_vstr(vec)
	concat_friendly[1] = head_str
	concat_friendly[2] = string.format(patt_form, vec[1])
	concat_friendly[3] = comma_str
	concat_friendly[4] = string.format(patt_form, vec[2])
	concat_friendly[5] = comma_str
	concat_friendly[6] = string.format(patt_form, vec[3])
	concat_friendly[7] = end_str

	return table.concat(concat_friendly, "")
end
local head_str_a = "a("
local patt_form_a = "%4.1f"
local function friendly_astr(ang)
	concat_friendly[1] = head_str_a
	concat_friendly[2] = string.format(patt_form_a, ang[1])
	concat_friendly[3] = comma_str
	concat_friendly[4] = string.format(patt_form_a, ang[2])
	concat_friendly[5] = comma_str
	concat_friendly[6] = string.format(patt_form_a, ang[3])
	concat_friendly[7] = end_str

	return table.concat(concat_friendly, "")
end

local function friendly_num(num)
	return string.format("%4.3f", num)
end


local col_G = Color(0, 255, 0, 255)
local do_tracebased_nfo = false
concommand.Add("lk3d_hwr_toggletracenfo", function()
	do_tracebased_nfo = not do_tracebased_nfo
	d_print("tracebased info now; " .. tostring(do_tracebased_nfo))
end)
local function renderInfo()
	if not LK3D.Debug then
		return
	end

	surface.SetDrawColor(255, 255, 255, 255)
	draw.SimpleText("LK3D " .. (LK3D.Version or "none..."), "BudgetLabel", 4, 0, col_G)
	draw.SimpleText(Renderer.PrettyName .. " renderer", "BudgetLabel", 4, 12, col_G)
	draw.SimpleText("SIZE   ; " .. ScrW() .. "x" .. ScrH(), "BudgetLabel", 4, 24, col_G)
	draw.SimpleText("CPOS   ; " .. friendly_vstr(LK3D.CamPos), "BudgetLabel", 4, 36, col_G)
	draw.SimpleText("CANG   ; " .. friendly_astr(LK3D.CamAng), "BudgetLabel", 4, 48, col_G)


	draw.SimpleText("VERTS  ; " .. vertCount, "BudgetLabel", 4, 60, col_G)
	draw.SimpleText("TRIS   ; " .. triCount, "BudgetLabel", 4, 72, col_G)
	draw.SimpleText("OBJS   ; " .. mdlCount, "BudgetLabel", 4, 84, col_G)
	draw.SimpleText("LIGHTS ; " .. LK3D.CurrUniv["lightcount"], "BudgetLabel", 4, 96, col_G)
	draw.SimpleText("POSCULL; " .. cullCount, "BudgetLabel", 4, 108, col_G)
	draw.SimpleText("NRMCULL; " .. triCullCount, "BudgetLabel", 4, 120, col_G)
	draw.SimpleText("PARTICL; " .. particleCount, "BudgetLabel", 4, 132, col_G)
	draw.SimpleText("CACHED ; " .. cachedCount, "BudgetLabel", 4, 144, col_G)


	if do_tracebased_nfo then
		LK3D.SetTraceReturnTable(true)
		LK3D.SetTraceOverrideNoTrace(true)
		LK3D.SetExpensiveTrace(true)
		local tr_world = LK3D.TraceRayScene(LK3D.CamPos, LK3D.CamAng:Forward(), false)
		if tr_world.obj then
			draw.SimpleText("OBJ_L  ; " .. tostring(tr_world.obj), "BudgetLabel", 4, 170, col_G)
			draw.SimpleText("MDL_L  ; " .. tostring(LK3D.CurrUniv["objects"][tr_world.obj].mdl), "BudgetLabel", 4, 184, col_G)
			draw.SimpleText("TRI_L  ; " .. tostring(tr_world.tri), "BudgetLabel", 4, 196, col_G)
			draw.SimpleText("UV_L   ; {" .. friendly_num(tr_world.uv[1]) .. ", " .. friendly_num(tr_world.uv[2]) .. "}", "BudgetLabel", 4, 208, col_G)
			draw.SimpleText("TEX_L  ; " .. tostring(LK3D.CurrUniv["objects"][tr_world.obj].mat), "BudgetLabel", 4, 220, col_G)
		else
			draw.SimpleText("OBJ_L  ; [none]", "BudgetLabel", 4, 170, col_G)
			draw.SimpleText("MDL_L  ; [none]", "BudgetLabel", 4, 184, col_G)
			draw.SimpleText("TRI_L  ; [none]", "BudgetLabel", 4, 196, col_G)
			draw.SimpleText("UV_L   ; {?, ?}", "BudgetLabel", 4, 208, col_G)
			draw.SimpleText("TEX_L  ; [none]", "BudgetLabel", 4, 220, col_G)
		end
		draw.SimpleText("POS_L  ; " .. friendly_vstr(tr_world.pos), "BudgetLabel", 4, 156, col_G)

		LK3D.SetExpensiveTrace(false)
		LK3D.SetTraceOverrideNoTrace(false)
		LK3D.SetTraceReturnTable(false)
	end

	vertCount = 0
	triCount = 0
	mdlCount = 0
	cullCount = 0
	triCullCount = 0
	particleCount = 0
	cachedCount = 0
end



local renderParticleEmitter = include("particles.lua")
local renderDebug = include("render_debug.lua")

-- this function should take the currently active universe and render all the objects in it to the active rendertarget on the camera position with the camera angles
function Renderer.Render()
	local crt = LK3D.CurrRenderTarget
	local rtw, rth = crt:Width(), crt:Height()
	local ow, oh = ScrW(), ScrH()
	render_SetViewPort(0, 0, rtw, rth)
	cam_Start2D()
	render_PushRenderTarget(crt)
	render_PushFilterMag(LK3D.FilterMode)
	render_PushFilterMin(LK3D.FilterMode)
		--cam_Start3D(LK3D.CamPos, LK3D.CamAng, LK3D.FOV, 0, 0, rtw, rth, 0.005, 10000)
		cam_Start({
			type = "3D",
			x = 0,
			y = 0,
			w = rtw,
			h = rth,
			aspect = rtw / rth,
			origin = LK3D.CamPos,
			angles = LK3D.CamAng,
			fov = LK3D.FOV,
			zfar = LK3D.FAR_Z,
			znear = LK3D.NEAR_Z,
			ortho = LK3D.Ortho and LK3D.OrthoParameters or nil
		})


		local hasSH = false
		local hasParams = false
		for k, v in pairs(LK3D.CurrUniv["objects"]) do
			if v["RENDER_NOGLOBAL"] then
				continue
			end

			if v["RENDER_PARAMS_AFTER"] then
				hasParams = true
				continue
			end

			if v["RENDER_PARAMS_PRE"] then
				pcall(v["RENDER_PARAMS_PRE"])
			end

			local fine, err = pcall(renderModel, v)
			if not fine then
				d_print("error while drawing model \"" .. v.mdl .. "\"; " .. err)
			end

			if v["RENDER_PARAMS_POST"] then
				pcall(v["RENDER_PARAMS_POST"])
			end

			if v["SHADOW_VOLUME"] then
				hasSH = true
			end
		end

		if hasParams then
			for k, v in pairs(LK3D.CurrUniv["objects"]) do
				if v["RENDER_NOGLOBAL"] then
					continue
				end

				if not v["RENDER_PARAMS_AFTER"] then
					continue
				end

				if v["RENDER_PARAMS_PRE"] then
					pcall(v["RENDER_PARAMS_PRE"])
				end

				local fine, err = pcall(renderModel, v)
				if not fine then
					d_print("error while drawing model \"" .. v.mdl .. "\"; " .. err)
				end

				if v["RENDER_PARAMS_POST"] then
					pcall(v["RENDER_PARAMS_POST"])
				end
			end
		end


		for k, v in pairs(LK3D.CurrUniv["particles"]) do
			local fine, err = pcall(renderParticleEmitter, v)
			if not fine then
				d_print("error while drawing particle emmitter of type \"" .. v.type .. "\"; " .. err)
			end
		end

		if LK3D.CurrUniv["debug_obj"] then
			renderDebug()
		end

		if hasSH then
			render_SetStencilEnable(true)
			render_SetStencilWriteMask(0xFF)
			render_SetStencilTestMask(0xFF)
			render_SetStencilReferenceValue(0)
			render_SetStencilCompareFunction(STENCIL_ALWAYS)
			render_SetStencilPassOperation(STENCIL_KEEP)
			render_SetStencilFailOperation(STENCIL_KEEP)
			render_SetStencilZFailOperation(STENCIL_KEEP)
			render_ClearStencil()

			render_OverrideDepthEnable(true, false)
			render_SetStencilReferenceValue(0)
			render_OverrideColorWriteEnable(true, false)
			for k, v in pairs(LK3D.CurrUniv["objects"]) do
				if v["RENDER_NOGLOBAL"] then
					continue
				end
				if v["SHADOW_VOLUME"] then
					renderShadows(v)
				end
			end
			render_OverrideColorWriteEnable(false)
			render_OverrideDepthEnable(false, false)

			render_SetStencilReferenceValue(0)
			render_SetStencilCompareFunction(STENCIL_NOTEQUAL)

			cam_End3D()
			surface.SetDrawColor(0, 0, 0, LK3D.ShadowAlpha or 196)
			surface.DrawRect(0, 0, ScrW(), ScrH())
			render_SetStencilEnable(false)
		else
			cam_End3D()
		end


	renderInfo()
	render_PopFilterMag()
	render_PopFilterMin()
	render_PopRenderTarget()
	cam_End2D()
	render_SetViewPort(0, 0, ow, oh)
end


Renderer.RT_Cache = Renderer.RT_Cache or {}
local function get_rt_copy(rt)
	if not Renderer.RT_Cache[rt:GetName()] then
		local mk_rt = GetRenderTarget("dc_" .. rt:GetName(), rt:Width(), rt:Height())
		Renderer.RT_Cache[rt:GetName()] = mk_rt
	end

	local n_rt = Renderer.RT_Cache[rt:GetName()]

	local ow, oh = ScrW(), ScrH()
	render_SetViewPort(0, 0, n_rt:Width(), n_rt:Height())
	cam_Start2D()
	render_PushRenderTarget(n_rt)
	render_PushFilterMag(LK3D.FilterMode)
	render_PushFilterMin(LK3D.FilterMode)
		render_OverrideDepthEnable(true, true)
			render_Clear(0, 0, 0, 0, true, true)
		render_OverrideDepthEnable(false)
	render_PopFilterMag()
	render_PopFilterMin()
	render_PopRenderTarget()
	cam_End2D()
	render_SetViewPort(0, 0, ow, oh)

	return Renderer.RT_Cache[rt:GetName()]
end



-- returns table of depth
function Renderer.RenderDepth()
	local crt = get_rt_copy(LK3D.CurrRenderTarget)
	local rtw, rth = crt:Width(), crt:Height()

	local ow, oh = ScrW(), ScrH()
	render_SetViewPort(0, 0, rtw, rth)
	cam_Start2D()
	render_PushRenderTarget(crt)
	render_PushFilterMag(LK3D.FilterMode)
	render_PushFilterMin(LK3D.FilterMode)

		local o_cp = LK3D.CamPos
		LK3D.CamPos = LK3D.CamPos
		render_SetWriteDepthToDestAlpha(true)
		--cam_Start3D(LK3D.CamPos, LK3D.CamAng, LK3D.FOV, 0, 0, rtw, rth, 0.005, 10000)
		cam_Start({
			type = "3D",
			x = 0,
			y = 0,
			w = rtw,
			h = rth,
			aspect = rtw / rth,
			origin = LK3D.CamPos,
			angles = LK3D.CamAng,
			fov = LK3D.FOV,
			zfar = LK3D.FAR_Z,
			znear = LK3D.NEAR_Z,
			ortho = LK3D.Ortho and LK3D.OrthoParameters or nil
		})
		for k, v in pairs(LK3D.CurrUniv["objects"]) do
			if v["RENDER_NOGLOBAL"] then
				continue
			end
			local fine, err = pcall(renderModel, v)
			if not fine then
				d_print("error while drawing model \"" .. v.mdl .. "\"; " .. err)
			end
		end

		for k, v in pairs(LK3D.CurrUniv["particles"]) do
			local fine, err = pcall(renderParticleEmitter, v)
			if not fine then
				d_print("error while drawing particle emmitter of type \"" .. v.type .. "\"; " .. err)
			end
		end

		cam_End3D()

		LK3D.CamPos = o_cp
		render_SetWriteDepthToDestAlpha(false)

	local arr_d = {}
	render_CapturePixels()
	for i = 0, (rtw * rth) - 1 do
		local x, y = (i % rtw), math_floor(i / rtw)
		local _, _, _, d = render_ReadPixel(x, y)
		d = (d == 0) and 255 or d
		arr_d[i] = d
	end



	render_PopFilterMag()
	render_PopFilterMin()
	render_PopRenderTarget()
	cam_End2D()
	render_SetViewPort(0, 0, ow, oh)


	return arr_d
end


-- this function should take the currently active universe and render an object from it to the active rendertarget
function Renderer.RenderObjectAlone(name)
	local crt = LK3D.CurrRenderTarget
	local rtw, rth = crt:Width(), crt:Height()
	local ow, oh = ScrW(), ScrH()
	local obj = LK3D.CurrUniv["objects"][name]
	if not obj then
		return
	end


	render_SetViewPort(0, 0, rtw, rth)
	cam_Start2D()
	render_PushRenderTarget(crt)
	render_PushFilterMag(LK3D.FilterMode)
	render_PushFilterMin(LK3D.FilterMode)
	cam_Start({
		type = "3D",
		x = 0,
		y = 0,
		w = rtw,
		h = rth,
		aspect = rtw / rth,
		origin = LK3D.CamPos,
		angles = LK3D.CamAng,
		fov = LK3D.FOV,
		zfar = LK3D.FAR_Z,
		znear = LK3D.NEAR_Z,
		ortho = LK3D.Ortho and LK3D.OrthoParameters or nil
	})
		if obj["RENDER_PARAMS_PRE"] then
			pcall(obj["RENDER_PARAMS_PRE"])
		end

		local fine, err = pcall(renderModel, obj)
		if not fine then
			d_print("error while drawing model \"" .. obj.mdl .. "\"; " .. err)
		end

		if obj["RENDER_PARAMS_POST"] then
			pcall(obj["RENDER_PARAMS_POST"])
		end

	cam_End3D()
	--renderInfo()
	render_PopFilterMag()
	render_PopFilterMin()
	render_PopRenderTarget()
	cam_End2D()
	render_SetViewPort(0, 0, ow, oh)
end

function Renderer.GetLightIntensity(pos, norm)
	local lr, lg, lb = light_mult_at_pos(pos, norm ~= nil, norm)
	return lr, lg, lb
end


local id = LK3D.DeclareRenderer(Renderer)
LK3D_RENDER_HARD = id