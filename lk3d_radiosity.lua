LK3D = LK3D or {}
LK3D.LIGHTMAP_RES = (256 + 64 + 16) * .75 --2.5
LK3D.LIGHTMAP_TRISZ = 10 * .5 --1.75
LK3D.LIGHTMAP_TRIPAD = 5


-- idea for future:
-- mostly from: https://www.jmeiners.com/Hugo-Elias-Radiosity/
--
-- make 3 different universes (lol)
-- each univ can pack 16581375 diff values per pixel (255 * 255 * 255) [we can't use alpha sadly]
-- objectID univ
-- patchX univ
-- patchY univ
-- those universes are plenty to have 16581375 diff objects with a max lightmap resolution of 16581375x16581375 allowing table references for overbright
-- AWESOME
-- each object has a tbl for radiosity data
-- STRUCT
-- {
--		emmision = 0,
--		reflectance = 0,
-- 		incident = {, -- (sum of all light that a patch can see)
--				[1] = red,
--				[2] = green,
--				[3] = blue
--		}
--		excident = {
--				(incident_light[1] * reflectance) + emmision,
--				(incident_light[2] * reflectance) + emmision,
--				(incident_light[3] * reflectance) + emmision
--		}
-- }
-- also use hemicubes
-- lit objects can be just 1 single ptr for cheap

-- additive preset; buggy...
--[[
LK3D.RADIOSITY_STEPS = 5
LK3D.RADIOSITY_BUFFER_SZ = 256
LK3D.RADIOSITY_AVGCALC_DIV = 4
LK3D.RADIOSITY_FOV = 90
LK3D.RADIOSITY_MUL_CGATHER = 4
LK3D.RADIOSITY_POW_CGATHER = .95
LK3D.RADIOSITY_ADDITIVE_CALC = true
LK3D.RADIOSITY_LIGHTSCL_DIV = 12
LK3D.RADIOSITY_SCLMUL = 1
]]--

-- legacy
--[[
LK3D.RADIOSITY_DO_RT = false
LK3D.RADIOSITY_STEPS = 3
LK3D.RADIOSITY_BUFFER_SZ = 128
LK3D.RADIOSITY_AVGCALC_DIV = 4
LK3D.RADIOSITY_FOV = 120
LK3D.RADIOSITY_MUL_CGATHER = 196
LK3D.RADIOSITY_POW_CGATHER = .45
LK3D.RADIOSITY_ADDITIVE_CALC = false
LK3D.RADIOSITY_LIGHTSCL_DIV = 4
LK3D.RADIOSITY_SCLMUL = 1
LK3D.RADIOSITY_ROT_ITR = 3
]]--

-- test new
LK3D.RADIOSITY_DO_RT = false
LK3D.RADIOSITY_STEPS = 1
LK3D.RADIOSITY_BUFFER_SZ = 128
LK3D.RADIOSITY_AVGCALC_DIV = 4
LK3D.RADIOSITY_FOV = 90
LK3D.RADIOSITY_MUL_CGATHER = 196
LK3D.RADIOSITY_POW_CGATHER = .45
LK3D.RADIOSITY_ADDITIVE_CALC = false
LK3D.RADIOSITY_LIGHTSCL_DIV = 4
LK3D.RADIOSITY_SCLMUL = 1
LK3D.RADIOSITY_ROT_ITR = 3



--LK3D.RADIOSITY_DO_RT = true
--LK3D.RADIOSITY_SCLMUL = 1


local math = math
local math_Round = math.Round
local math_abs = math.abs
local math_min = math.min
local math_max = math.max
local math_floor = math.floor
local math_Clamp = math.Clamp


--[[
	lk3d_radiosity.lua

	LK3D bakeable radiosity (lightmapping!)
	held together by duct tape!

	Coded by Lokachop, contact at Lokachop#5862
]]--



local function copyUV(uv)
	return {uv[1], uv[2]}
end

local function copyTable(tblpointer)
	local new = {}
	for k, v in pairs(tblpointer) do
		if type(v) == "table" then
			new[k] = copyTable(v)
		elseif type(v) == "Vector" then
			new[k] = Vector(v)
		elseif type(v) == "Angle" then
			new[k] = Angle(v)
		else
			new[k] = v
		end
	end
	return new
end

-- returns a hash from a vector (string)
local concat_tbl_vert = {}
local concat_round = 4
local function hashVec(v)
	concat_tbl_vert[1] = "x"
	concat_tbl_vert[2] = math_Round(v[1], concat_round)
	concat_tbl_vert[3] = "y"
	concat_tbl_vert[4] = math_Round(v[2], concat_round)
	concat_tbl_vert[5] = "z"
	concat_tbl_vert[6] = math_Round(v[3], concat_round)

	return table.concat(concat_tbl_vert, "")
end

-- gets the tris of a mesh as a non tblptr table
-- (verts n uvs are copied)
local function getTriTable(obj)
	if not obj then
		return
	end

	if not LK3D.CurrUniv["objects"][obj] then
		return
	end

	local obj_ptr = LK3D.CurrUniv["objects"][obj]
	local mdl = obj_ptr.mdl

	if not LK3D.Models[mdl] then
		return
	end


	local mdlpointer = LK3D.Models[mdl]
	local verts = mdlpointer.verts
	local uvs = mdlpointer.uvs
	local uvs_lm = obj_ptr.lightmap_uvs
	local dolm = (uvs_lm ~= nil)

	local indices = mdlpointer.indices

	local tri_list_genned = {}
	for i = 1, #indices do
		local ind = indices[i]
		local v1 = Vector(verts[ind[1][1]]) -- lets copy aswell to be safe, even if slow
		local v2 = Vector(verts[ind[2][1]])
		local v3 = Vector(verts[ind[3][1]])

		local uv1 = copyUV(uvs[ind[1][2]]) -- same here
		local uv2 = copyUV(uvs[ind[2][2]])
		local uv3 = copyUV(uvs[ind[3][2]])

		local lm_uv1 = {0, 0}
		local lm_uv2 = {0, 0}
		local lm_uv3 = {0, 0}
		if dolm then
			lm_uv1 = copyUV(uvs_lm[ind[1][3]])
			lm_uv2 = copyUV(uvs_lm[ind[2][3]])
			lm_uv3 = copyUV(uvs_lm[ind[3][3]])
		end



		local norm = (v2 - v1):Cross(v3 - v1)
		norm:Normalize()

		tri_list_genned[#tri_list_genned + 1] = {
			{
				pos = v1,
				uv = uv1,
				ind_pos = ind[1][1],
				ind_uv = ind[1][2],
				ind_uv_lm = ind[1][3],
				norm = norm,
				hash_pos = hashVec(v1),
				lm_uv = lm_uv1,
			},
			{
				pos = v2,
				uv = uv2,
				ind_pos = ind[2][1],
				ind_uv = ind[2][2],
				ind_uv_lm = ind[2][3],
				norm = norm,
				hash_pos = hashVec(v2),
				lm_uv = lm_uv2,
			},
			{
				pos = v3,
				uv = uv3,
				ind_pos = ind[3][1],
				ind_uv = ind[3][2],
				ind_uv_lm = ind[3][3],
				norm = norm,
				hash_pos = hashVec(v3),
				lm_uv = lm_uv3,
			}
		}
	end

	return tri_list_genned
end


-- leaf packer thing, https://blackpawn.com/texts/lightmaps/default.html
local function uv_tri_size(uvtri)
	local bm_u = math_min(uvtri[1][1], uvtri[2][1], uvtri[3][1])
	local bm_v = math_min(uvtri[1][2], uvtri[2][2], uvtri[3][2])

	local bMa_u = math_max(uvtri[1][1], uvtri[2][1], uvtri[3][1])
	local bMa_v = math_max(uvtri[1][2], uvtri[2][2], uvtri[3][2])

	local w, h = math_floor(bMa_u - bm_u) + LK3D.LIGHTMAP_TRIPAD, math_floor(bMa_v - bm_v) + LK3D.LIGHTMAP_TRIPAD
	return w, h, bm_u, bm_v
end


local function newleaf(sx, sy, ox, oy)
	return {
		children = {},
		ox = ox or 0,
		oy = oy or 0,
		sx = sx,
		sy = sy,
		has_tri = false,
	}
end


local function insert_into_leaf(leaf, tri)
	if (#leaf.children > 0) then
		local new_uv = insert_into_leaf(leaf.children[1], tri)
		if new_uv ~= nil then
			return new_uv
		end

		-- no room, insert second
		return insert_into_leaf(leaf.children[2], tri)
	else
		if leaf.has_tri then
			return
		end

		local triw, trih, tri_minw, tri_minh = uv_tri_size(tri)

		if leaf.sx < triw or leaf.sy < trih then
			return
		end

		if leaf.sx == triw and leaf.sy == trih then
			leaf.has_tri = true
			return {
				{{leaf.ox + (tri[1][1] - tri_minw), leaf.oy + (tri[1][2] - tri_minh)}, tri[1][3]},
				{{leaf.ox + (tri[2][1] - tri_minw), leaf.oy + (tri[2][2] - tri_minh)}, tri[2][3]},
				{{leaf.ox + (tri[3][1] - tri_minw), leaf.oy + (tri[3][2] - tri_minh)}, tri[3][3]},
			}
		end


		-- we have to split
		local dw = leaf.sx - triw
		local dh = leaf.sy - trih


		if dw > dh then -- if (the leafsize - triw) > (the leafsize - trih)
			leaf.children[1] = newleaf( -- left, stores og lightmap
				triw,
				leaf.sy,
				leaf.ox,
				leaf.oy
			)
			leaf.children[2] = newleaf( -- right
				dw,
				leaf.sy,
				leaf.ox + triw,
				leaf.oy
			)
		else
			leaf.children[1] = newleaf( -- up, stores lightmap
				leaf.sx,
				trih,
				leaf.ox,
				leaf.oy
			)
			leaf.children[2] = newleaf( -- down
				leaf.sx,
				dh,
				leaf.ox,
				leaf.oy + trih
			)
		end


		return insert_into_leaf(leaf.children[1], tri)
	end
end


-- makes lightmap uvs from a object
-- packs them automatically given w, h
local lightmap_exist_univs = {}
local function makeLightMapUV(obj, w, h)
	if not obj then
		return
	end

	if (not w) or (not h) then
		return
	end

	if not lightmap_exist_univs[LK3D.CurrUniv["tag"]] then
		lightmap_exist_univs[LK3D.CurrUniv["tag"]] = {}
	end

	if lightmap_exist_univs[LK3D.CurrUniv["tag"]][obj] then
		return
	end

	local obj_ptr = LK3D.CurrUniv["objects"][obj]
	if not obj_ptr then
		return
	end
	local mdl = obj_ptr.mdl

	if not LK3D.Models[mdl] then
		return
	end


	local mdlpointer = LK3D.Models[mdl]
	local indices = mdlpointer.indices
	local verts = mdlpointer.verts

	local tri_count = #indices
	print(tri_count .. " tris...")

	local new_uvs = {}
	local uvs_to_pack_in_thing = {}

	for i = 1, #indices do
		local indice_1 = indices[i]

		local i1_v1 = verts[indice_1[1][1]] * obj_ptr.scl
		local i1_v2 = verts[indice_1[2][1]] * obj_ptr.scl
		local i1_v3 = verts[indice_1[3][1]] * obj_ptr.scl

		local norm_1 = (i1_v2 - i1_v1):Cross(i1_v3 - i1_v1)
		norm_1:Normalize()


		local ihalf = i
		local w_sub = (w - LK3D.LIGHTMAP_TRISZ)
		local sz_padded = (LK3D.LIGHTMAP_TRISZ + (LK3D.LIGHTMAP_TRIPAD + 1))

		local tri_xc = (ihalf * sz_padded) % w_sub

		local tri_yc = math_floor((ihalf * sz_padded) / w_sub) * sz_padded

		local tri_xc_psz = tri_xc + LK3D.LIGHTMAP_TRISZ
		local tri_yc_psz = tri_yc + LK3D.LIGHTMAP_TRISZ

		local u1_n, v1_n = tri_xc / w, tri_yc / h
		local u2_n, v2_n = tri_xc / w, tri_yc_psz / h
		local u3_n, v3_n = tri_xc_psz / w, tri_yc_psz / h



		-- https://web.archive.org/web/20071024115118/http://www.flipcode.org/cgi-bin/fcarticles.cgi?show=64423
		local dens = LK3D.LIGHTMAP_TRISZ
		if math_abs(norm_1[1]) > math_abs(norm_1[2]) and math_abs(norm_1[1]) > math_abs(norm_1[3]) then
			u1_n = i1_v1[3] * dens
			v1_n = -i1_v1[2] * dens

			u2_n = i1_v2[3] * dens
			v2_n = -i1_v2[2] * dens

			u3_n = i1_v3[3] * dens
			v3_n = -i1_v3[2] * dens
		elseif math_abs(norm_1[2]) > math_abs(norm_1[1]) and math_abs(norm_1[2]) > math_abs(norm_1[3]) then
			u1_n = i1_v1[1] * dens
			v1_n = -i1_v1[3] * dens

			u2_n = i1_v2[1] * dens
			v2_n = -i1_v2[3] * dens

			u3_n = i1_v3[1] * dens
			v3_n = -i1_v3[3] * dens
		else
			u1_n = i1_v1[1] * dens
			v1_n = -i1_v1[2] * dens

			u2_n = i1_v2[1] * dens
			v2_n = -i1_v2[2] * dens

			u3_n = i1_v3[1] * dens
			v3_n = -i1_v3[2] * dens
		end


		local min_u = math_floor(math_min(u1_n, u2_n, u3_n))
		local min_v = math_floor(math_min(v1_n, v2_n, v3_n))

		u1_n = (u1_n - min_u)
		v1_n = (v1_n - min_v)

		u2_n = (u2_n - min_u)
		v2_n = (v2_n - min_v)

		u3_n = (u3_n - min_u)
		v3_n = (v3_n - min_v)

		uvs_to_pack_in_thing[#uvs_to_pack_in_thing + 1] = {
			{u1_n, v1_n, indice_1[1]},
			{u2_n, v2_n, indice_1[2]},
			{u3_n, v3_n, indice_1[3]}
		}

		local uv1_ind = #new_uvs + 1
		new_uvs[#new_uvs + 1] = {
			u1_n, v1_n
		}

		local uv2_ind = #new_uvs + 1
		new_uvs[#new_uvs + 1] = {
			u2_n, v2_n
		}

		local uv3_ind = #new_uvs + 1
		new_uvs[#new_uvs + 1] = {
			u3_n, v3_n
		}

		-- uv lightmap is indice 3
		indice_1[1][3] = uv1_ind
		indice_1[2][3] = uv2_ind
		indice_1[3][3] = uv3_ind
	end

	-- https://blackpawn.com/texts/lightmaps/default.html
	local tree = newleaf(LK3D.LIGHTMAP_RES, LK3D.LIGHTMAP_RES)
	tree.children[1] = newleaf(LK3D.LIGHTMAP_RES, LK3D.LIGHTMAP_RES)
	tree.children[2] = newleaf(0, 0)
	local new_uvs_2 = {}
	local fail = false
	for k, v in ipairs(uvs_to_pack_in_thing) do
		local ret = insert_into_leaf(tree, v)

		if not ret then
			fail = true
			break
		end

		local uv1_ind = #new_uvs_2 + 1
		new_uvs_2[#new_uvs_2 + 1] = {ret[1][1][1] / w, ret[1][1][2] / h}

		local uv2_ind = #new_uvs_2 + 1
		new_uvs_2[#new_uvs_2 + 1] = {ret[2][1][1] / w, ret[2][1][2] / h}

		local uv3_ind = #new_uvs_2 + 1
		new_uvs_2[#new_uvs_2 + 1] = {ret[3][1][1] / w, ret[3][1][2] / h}

		ret[1][2][3] = uv1_ind
		ret[2][2][3] = uv2_ind
		ret[3][2][3] = uv3_ind
	end




	if not fail then
		obj_ptr["lightmap_uvs"] = new_uvs_2
	else
		obj_ptr["lightmap_uvs"] = new_uvs
	end

	lightmap_exist_univs[LK3D.CurrUniv["tag"]][obj] = true

	--n_makeLightMapUV(mdl, w, h)
end



-- point inside tri
-- https://stackoverflow.com/questions/2049582/how-to-determine-if-a-point-is-in-a-2d-triangle
local function uv_inside_tri(uv, uv1, uv2, uv3)
	local s = (uv1[1] - uv3[1]) * (uv[2] - uv3[2]) - (uv1[2] - uv3[2]) * (uv[1] - uv3[1])
	local t = (uv2[1] - uv1[1]) * (uv[2] - uv1[2]) - (uv2[2] - uv1[2]) * (uv[1] - uv1[1])

	if ((s < 0) ~= (t < 0) and s ~= 0 and t ~= 0) then
		return false
	end

	local d = (uv3[1] - uv2[1]) * (uv[2] - uv2[2]) - (uv3[2] - uv2[2]) * (uv[1] - uv2[1])

	return d == 0 or (d < 0) == (s + t <= 0)
end


-- builds a lookup table of any pixel inside of {sx, sy} as to which triangle it corresponds
local c_red = Color(255, 0, 0)
local c_yellow = Color(255, 255, 0)
local c_blue = Color(0, 128, 255)
local uv_tri_lookups = {}
local function buildTriUVLUT(obj, sx, sy)
	if not obj then
		return
	end

	if not sx then
		return
	end

	if not sy then
		return
	end

	if not uv_tri_lookups[LK3D.CurrUniv["tag"]] then
		uv_tri_lookups[LK3D.CurrUniv["tag"]] = {}
	end

	if uv_tri_lookups[LK3D.CurrUniv["tag"]][obj] then
		return
	end

	local obj_ptr = LK3D.CurrUniv["objects"][obj]
	if not obj_ptr then
		return
	end
	local mdl = obj_ptr.mdl

	if not LK3D.Models[mdl] then
		return
	end

	local tri_list_genned = getTriTable(obj)

	local uv_sz_c = (1 / LK3D.LIGHTMAP_RES)
	local tbl_ret = {}
	for i = 0, (sx * sy) - 1 do
		if (i % 512) == 0 then
			LK3D.RenderProcessingMessage("Radiosity generate tri table\n[" .. obj .. "]", (i / ((sx * sy) - 1)) * 100)
		end


		local xc = i % sx
		local yc = math_floor(i / sx)

		local uc = xc / sx
		local vc = yc / sy


		--local uvself = {uc, vc}
		local uv_list = {
			{uc, vc},
			{uc + uv_sz_c, vc},
			{uc - uv_sz_c, vc},
			{uc, vc + uv_sz_c},
			{uc, vc - uv_sz_c},

			{uc + uv_sz_c, vc + uv_sz_c},
			{uc - uv_sz_c, vc + uv_sz_c},
			{uc + uv_sz_c, vc - uv_sz_c},
			{uc - uv_sz_c, vc - uv_sz_c}
		}
		-- check if u, v is inside triangle if it is, assign and break
		local has = false
		for k, v in ipairs(tri_list_genned) do
			local uv1 = v[1].lm_uv
			local uv2 = v[2].lm_uv
			local uv3 = v[3].lm_uv

			for _, v2 in ipairs(uv_list) do
				local inside = uv_inside_tri(v2, uv1, uv2, uv3)
				if inside then
					tbl_ret[i] = k
					has = true
					break
				end
			end
		end
		if not has then
			tbl_ret[i] = 0 -- mark as 0 which we know is nothing
		end
	end
	print(LK3D.CurrUniv["tag"])
	print(obj)
	uv_tri_lookups[LK3D.CurrUniv["tag"]][obj] = tbl_ret
end



-- https://community.khronos.org/t/generate-lightmap-for-triangle-mesh/24335
local function texturi_to_world(obj, x, y, w, h)
	if not obj then
		return
	end

	local obj_ptr = LK3D.CurrUniv["objects"][obj]
	if not obj_ptr then
		return
	end

	local tri_lookup_idx = (x + (y * w))

	local realtag = LK3D.CurrUniv["tag"]
	if obj_ptr.ORIG_UNIV then
		realtag = obj_ptr.ORIG_UNIV
		obj_ptr = LK3D.UniverseRegistry[obj_ptr.ORIG_UNIV]["objects"][obj] -- hax hax hax
	end

	local tri = uv_tri_lookups[realtag][obj][tri_lookup_idx]

	if tri == 0 then
		return
	end

	local mdlpointer = LK3D.Models[obj_ptr.mdl]
	local verts = mdlpointer.verts
	local uvs = mdlpointer.uvs
	local lm_uvs = obj_ptr.lightmap_uvs
	local indices = mdlpointer.indices

	local the_tri_in_question = indices[tri]

	local v1 = verts[the_tri_in_question[1][1]] * obj_ptr.scl
	local v2 = verts[the_tri_in_question[2][1]] * obj_ptr.scl
	local v3 = verts[the_tri_in_question[3][1]] * obj_ptr.scl

	v1:Rotate(obj_ptr.ang)
	v1:Add(obj_ptr.pos)

	v2:Rotate(obj_ptr.ang)
	v2:Add(obj_ptr.pos)

	v3:Rotate(obj_ptr.ang)
	v3:Add(obj_ptr.pos)

	local tri_uv1 = lm_uvs[the_tri_in_question[1][3]]
	local tri_uv2 = lm_uvs[the_tri_in_question[2][3]]
	local tri_uv3 = lm_uvs[the_tri_in_question[3][3]]

	local t1 = {tri_uv1[1], tri_uv1[2]}
	local t2 = {tri_uv2[1], tri_uv2[2]}
	local t3 = {tri_uv3[1], tri_uv3[2]}

	local p = {x / w, y / h}

	local i = 1 / ((t2[2] - t1[2]) * (t3[1] - t1[1]) - (t2[1] - t1[1]) * (t3[2] - t1[2]))
	local s = i * ( (t3[1] - t1[1]) * (p[2] - t1[2]) - (t3[2] - t1[2]) * (p[1] - t1[1]))
	local t = i * (-(t2[1] - t1[1]) * (p[2] - t1[2]) + (t2[2] - t1[2]) * (p[1] - t1[1]))
	local vec = Vector(
		v1[1] + s * (v2[1] - v1[1]) + t * (v3[1] - v1[1]),
		v1[2] + s * (v2[2] - v1[2]) + t * (v3[2] - v1[2]),
		v1[3] + s * (v2[3] - v1[3]) + t * (v3[3] - v1[3])
	)

	local norm = (v2 - v1):Cross(v3 - v1)
	norm:Normalize()


	return vec, norm
end

local function calcLighting(pos, norm, obj)
	local ac_r, ac_g, ac_b = 0, 0, 0
	for k, v in pairs(LK3D.CurrUniv["lights"]) do
		local pos_l = Vector(v[1])
		local inten_l = v[2]
		local col_l = v[3]
		local sm = v[4]

		local pd = pos:Distance(pos_l)
		if pd > (sm and inten_l ^ 2 or inten_l) then
			continue
		end

		if sm then
			pd = pd ^ .5
		end

		local pos_start = (pos + norm * .001)
		LK3D.SetTraceReturnTable(true)
		local dir_trace = (pos_start - pos_l):GetNormalized()
		local dist_trace = sm and inten_l ^ 2 or inten_l
		local tr_check = LK3D.TraceRayScene(pos_start, dir_trace, true, dist_trace)
		LK3D.SetTraceReturnTable(false)

		local tr_fract = tr_check.dist / dist_trace
		if tr_fract < 1 then
			continue
		end

		local vinv = (inten_l - pd)
		ac_r = ac_r + (col_l[1] * math_min(math_abs(math_max(vinv, 0)), 1))
		ac_g = ac_g + (col_l[2] * math_min(math_abs(math_max(vinv, 0)), 1))
		ac_b = ac_b + (col_l[3] * math_min(math_abs(math_max(vinv, 0)), 1))
	end

	ac_r = math_min(math_max(ac_r, 0), 1)
	ac_g = math_min(math_max(ac_g, 0), 1)
	ac_b = math_min(math_max(ac_b, 0), 1)

	return ac_r, ac_g, ac_b
end


local radios_rt = GetRenderTarget("lk3d_radiosity_buffer_avg_" .. LK3D.RADIOSITY_BUFFER_SZ, LK3D.RADIOSITY_BUFFER_SZ, LK3D.RADIOSITY_BUFFER_SZ)
local universeCloneRadiosity = LK3D.NewUniverse("lk3d_radiosity_clone")
local objects_to_lightmap = {}



-- clones the active universe to radiosity while adding white boxes to where the lights are
-- make sure to add box and inverted normal box
-- every other texture should be black, we use this to render n average colour
local sorted_objects_render = {}
local function cloneUnivToRadioUniv()
	local last_univ = LK3D.CurrUniv

	LK3D.PushUniverse(universeCloneRadiosity)
		LK3D.WipeUniverse()
		sorted_objects_render = {}

		for k, v in pairs(last_univ["objects"]) do
			if v.RENDER_NOGLOBAL then
				continue
			end

			if v.NO_RADIOSITY then
				continue
			end



			LK3D.AddModelToUniverse(k, v.mdl)
			LK3D.SetModelPosAng(k, v.pos * LK3D.RADIOSITY_SCLMUL, v.ang)
			LK3D.SetModelScale(k, v.scl * LK3D.RADIOSITY_SCLMUL)
			LK3D.SetModelMat(k, v.mat)
			LK3D.SetModelFlag(k, "NO_SHADING", true)
			LK3D.SetModelFlag(k, "NO_LIGHTING", true)
			LK3D.SetModelCol(k, v.col)
			LK3D.SetModelFlag(k, "CONSTANT", true)
			LK3D.SetModelFlag(k, "ORIG_UNIV", last_univ["tag"])
			LK3D.SetModelFlag(k, "lightmap_uvs", v.lightmap_uvs)

			if v.RADIOSITY_LIT then
				LK3D.SetModelCol(k, Color(255, 255, 255))
			end


			if not objects_to_lightmap[k] then
				LK3D.SetModelCol(k, Color(0, 0, 0))
				LK3D.SetModelMat(k, "white")
			end

			if not LK3D.RADIOSITY_DO_RT then
				local idx_inv = k .. "_lm_inv"
				LK3D.AddModelToUniverse(idx_inv, v.mdl)
				LK3D.SetModelPosAng(idx_inv, v.pos * LK3D.RADIOSITY_SCLMUL, v.ang)
				LK3D.SetModelScale(idx_inv, v.scl * LK3D.RADIOSITY_SCLMUL)
				LK3D.SetModelMat(idx_inv, "white")
				LK3D.SetModelFlag(idx_inv, "NO_SHADING", true)
				LK3D.SetModelFlag(idx_inv, "NO_LIGHTING", true)
				LK3D.SetModelCol(idx_inv, Color(0, 0, 0))
				LK3D.SetModelFlag(idx_inv, "CONSTANT", true)
				LK3D.SetModelFlag(idx_inv, "NORM_INVERT", true)
				LK3D.SetModelFlag(idx_inv, "NO_TRACE", true)
				LK3D.SetModelFlag(idx_inv, "ORIG_UNIV", last_univ["tag"])
			end

			local lm_idx = "lightmap_object_" .. k .. "_res_" .. LK3D.LIGHTMAP_RES .. "_copy"
			if LK3D.Textures[lm_idx] ~= nil then
				LK3D.SetModelFlag(k, "limap_tex", lm_idx)
			end
		end

		local l_mul = 1


		if not LK3D.RADIOSITY_DO_RT then
			for k, v in pairs(last_univ["lights"]) do
				local inten_h = v[2] / LK3D.RADIOSITY_LIGHTSCL_DIV


				local lr_c, lg_c, lb_c = math.Clamp(v[3][1] * 255 * l_mul, 0, 255), math.Clamp(v[3][2] * 255 * l_mul, 0, 255), math.Clamp(v[3][3] * 255 * l_mul, 0, 255)
				local l_c = Color(lr_c, lg_c, lb_c)

				local idx = k .. "_in"
				LK3D.AddModelToUniverse(idx, "sphere_simple")
				LK3D.SetModelPosAng(idx, v[1] * LK3D.RADIOSITY_SCLMUL, Angle(0, 45, 45))
				LK3D.SetModelScale(idx, Vector(inten_h, inten_h, inten_h) * LK3D.RADIOSITY_SCLMUL)
				LK3D.SetModelFlag(idx, "NO_SHADING", true)
				LK3D.SetModelFlag(idx, "NO_LIGHTING", true)
				LK3D.SetModelFlag(idx, "NO_TRACE", true)
				LK3D.SetModelFlag(idx, "CONSTANT", true)
				LK3D.SetModelFlag(idx, "NORM_INVERT", true)
				LK3D.SetModelCol(idx, Color(255, 0, 0))
				LK3D.SetModelFlag(idx, "RENDER_PARAMETRI_AFTER", true)
				LK3D.SetModelFlag(idx, "RENDER_PARAMETRI_PRE", function()
					render.SetStencilEnable(true)
					render.SetStencilWriteMask(0xFF)
					render.SetStencilTestMask(0xFF)
					render.SetStencilReferenceValue(0)
					render.SetStencilCompareFunction(STENCIL_ALWAYS)
					render.SetStencilPassOperation(STENCIL_KEEP)
					render.SetStencilFailOperation(STENCIL_KEEP)
					render.SetStencilZFailOperation(STENCIL_KEEP)
					render.ClearStencil()

					render.SetStencilReferenceValue(1)
					render.SetStencilPassOperation(STENCIL_KEEP)
					render.SetStencilFailOperation(STENCIL_KEEP)
					render.SetStencilZFailOperation(STENCIL_INCR)
					render.OverrideDepthEnable(true, false)
					render.OverrideColorWriteEnable(true, false)
				end)
				LK3D.SetModelFlag(idx, "RENDER_PARAMETRI_POST", function()
					render.OverrideDepthEnable(false, false)
					render.OverrideColorWriteEnable(false, false)
				end)
				LK3D.SetModelHide(idx, true)



				idx = k .. "_out"
				LK3D.AddModelToUniverse(idx, "sphere_simple")
				LK3D.SetModelPosAng(idx, v[1] * LK3D.RADIOSITY_SCLMUL, Angle(0, 45, 45))
				LK3D.SetModelScale(idx, Vector(inten_h, inten_h, inten_h) * LK3D.RADIOSITY_SCLMUL)
				LK3D.SetModelFlag(idx, "NO_SHADING", true)
				LK3D.SetModelFlag(idx, "NO_LIGHTING", true)
				LK3D.SetModelFlag(idx, "NO_TRACE", true)
				LK3D.SetModelFlag(idx, "CONSTANT", true)
				LK3D.SetModelCol(idx, Color(0, 255, 0))

				LK3D.SetModelFlag(idx, "RENDER_PARAMETRI_AFTER", true)
				LK3D.SetModelFlag(idx, "RENDER_PARAMETRI_PRE", function()
					render.SetStencilReferenceValue(1)
					render.SetStencilPassOperation(STENCIL_KEEP)
					render.SetStencilFailOperation(STENCIL_KEEP)
					render.SetStencilZFailOperation(STENCIL_DECRSAT)
					render.OverrideDepthEnable(true, false)
					render.OverrideColorWriteEnable(true, false)
				end)
				LK3D.SetModelFlag(idx, "RENDER_PARAMETRI_POST", function()
					render.OverrideColorWriteEnable(false, false)

					render.SetStencilReferenceValue(1)
					render.SetStencilCompareFunction(STENCIL_EQUAL)
					render.ClearBuffersObeyStencil(lr_c, lg_c, lb_c, 255)


					render.SetStencilEnable(false)
					render.OverrideDepthEnable(false, false)
				end)
				LK3D.SetModelHide(idx, true)


				idx = k .. "_also"
				LK3D.AddModelToUniverse(idx, "sphere_simple")
				LK3D.SetModelPosAng(idx, v[1] * LK3D.RADIOSITY_SCLMUL, Angle(0, 45, 45))
				LK3D.SetModelScale(idx, Vector(inten_h, inten_h, inten_h) * LK3D.RADIOSITY_SCLMUL)
				LK3D.SetModelFlag(idx, "NO_SHADING", true)
				LK3D.SetModelFlag(idx, "NO_LIGHTING", true)
				LK3D.SetModelFlag(idx, "NO_TRACE", true)
				LK3D.SetModelFlag(idx, "CONSTANT", true)
				LK3D.SetModelCol(idx, l_c)


				idx = k .. "_invr_also"
				LK3D.AddModelToUniverse(idx, "sphere_simple")
				LK3D.SetModelPosAng(idx, v[1] * LK3D.RADIOSITY_SCLMUL, Angle(0, 45, 45))
				LK3D.SetModelScale(idx, Vector(inten_h, inten_h, inten_h) * LK3D.RADIOSITY_SCLMUL)
				LK3D.SetModelFlag(idx, "NO_SHADING", true)
				LK3D.SetModelFlag(idx, "NO_LIGHTING", true)
				LK3D.SetModelFlag(idx, "NO_TRACE", true)
				LK3D.SetModelFlag(idx, "CONSTANT", true)
				LK3D.SetModelFlag(idx, "NORM_INVERT", true)
				LK3D.SetModelCol(idx, l_c)

				sorted_objects_render[#sorted_objects_render + 1] = {k .. "_in", k .. "_out"}
			end
		else
			for k, v in pairs(last_univ["lights"]) do
				--{pos or Vector(0, 0, 0), intensity or 2, col and {col.r / 255, col.g / 255, col.b / 255} or {1, 1, 1}, (smooth == true) and true or false}
				LK3D.AddLight(k, v[1] * LK3D.RADIOSITY_SCLMUL, v[2] * LK3D.RADIOSITY_SCLMUL, Color(v[3][1] * 255, v[3][2] * 255, v[3][3] * 255), v[4])
			end
		end


	LK3D.PopUniverse()
end


local function setRadiosaTexturesPost()
	local last_univ = LK3D.CurrUniv
	LK3D.PushUniverse(universeCloneRadiosity)
		for k, v in pairs(last_univ["objects"]) do
			if v.RENDER_NOGLOBAL then
				continue
			end

			if v.NO_RADIOSITY then
				continue
			end

			local lm_idx = "lightmap_object_" .. k .. "_res_" .. LK3D.LIGHTMAP_RES .. "_copy"
			if LK3D.Textures[lm_idx] ~= nil then
				LK3D.SetModelFlag(k, "limap_tex", lm_idx)
			end
		end
	LK3D.PopUniverse()
end


local capt_r, capt_g, capt_b = 0, 0, 0
local radios_rt_sz_div_avg = LK3D.RADIOSITY_BUFFER_SZ / LK3D.RADIOSITY_AVGCALC_DIV
local function blur_the_rt()
	render.CapturePixels()

	-- get true average
	local count = (radios_rt_sz_div_avg * radios_rt_sz_div_avg) - 1
	for i = 0, count do
		local xc = (i % radios_rt_sz_div_avg) * LK3D.RADIOSITY_AVGCALC_DIV
		local yc = math.floor(i / radios_rt_sz_div_avg) * LK3D.RADIOSITY_AVGCALC_DIV
		local r_r, r_g, r_b = render.ReadPixel(xc, yc)
		capt_r = capt_r + r_r
		capt_g = capt_g + r_g
		capt_b = capt_b + r_b
	end
	capt_r = math.pow((capt_r / count) * LK3D.RADIOSITY_MUL_CGATHER, LK3D.RADIOSITY_POW_CGATHER)
	capt_g = math.pow((capt_g / count) * LK3D.RADIOSITY_MUL_CGATHER, LK3D.RADIOSITY_POW_CGATHER)
	capt_b = math.pow((capt_b / count) * LK3D.RADIOSITY_MUL_CGATHER, LK3D.RADIOSITY_POW_CGATHER)
end

local function get_lighting_via_cam(pos, norm)
	local buff_r, buff_g, buff_b = 0, 0, 0
	for i = 1, LK3D.RADIOSITY_ROT_ITR do
		LK3D.PushRenderTarget(radios_rt)
			LK3D.RenderClear(0, 0, 0)
			LK3D.SetCamPos(pos)
			local angCam = norm:Angle()

			local delta = (i - 1) / (LK3D.RADIOSITY_ROT_ITR - 1)
			angCam:RotateAroundAxis(norm, delta * 360)

			LK3D.SetCamAng(angCam)
			local last = LK3D.FOV
			LK3D.SetFOV(LK3D.RADIOSITY_FOV)
			LK3D.RenderActiveUniverse()

			for k, v in ipairs(sorted_objects_render) do
				LK3D.RenderObject(v[1])
				LK3D.RenderObject(v[2])
			end

			LK3D.RenderQuick(blur_the_rt)
		LK3D.PopRenderTarget()
		LK3D.SetFOV(last)

		buff_r = buff_r + capt_r
		buff_g = buff_g + capt_g
		buff_b = buff_b + capt_b
	end

	buff_r = buff_r / LK3D.RADIOSITY_ROT_ITR
	buff_g = buff_g / LK3D.RADIOSITY_ROT_ITR
	buff_b = buff_b / LK3D.RADIOSITY_ROT_ITR

	return buff_r / 255, buff_g / 255, buff_b / 255
end

local both_lut = {
	1, 1, 2, 2,
	3, 3, 3, 3
}
local offsets = {
	{-1, 0}, {1, 0}, {0, -1}, {0, 1},
	{-1, 1}, {1, 1}, {1, -1}, {-1, -1}
}

local function expandBorders(object, pixa_buff, bad_pixels)
	pixa_buff = pixa_buff or {}
	local pixa_to_update = {}

	for i = 0, (LK3D.LIGHTMAP_RES * LK3D.LIGHTMAP_RES) - 1 do
		-- avoid crashing ur game
		if (i % 128) == 0 then
			local the_rt = render.GetRenderTarget()
			LK3D.RenderProcessingMessage("Radiosity expand borders\n[" .. object .. "]", (i / ((LK3D.LIGHTMAP_RES * LK3D.LIGHTMAP_RES) - 1)) * 100, function()
				render.DrawTextureToScreenRect(the_rt, 0, (12 * 24) * (ScrH() / 512), 512, 512)
			end)
		end

		if not bad_pixels[i] then
			continue
		end


		local xc = i % LK3D.LIGHTMAP_RES
		local yc = math_floor(i / LK3D.LIGHTMAP_RES)

		local nearby_accum_r = 0
		local nearby_accum_g = 0
		local nearby_accum_b = 0
		local found = false


		-- https://shaderbits.com/blog/uv-dilation/
		for k, v in ipairs(offsets) do
			local p_offx = math_Clamp(xc + v[1], 0, LK3D.LIGHTMAP_RES - 1)
			local p_offy = math_Clamp(yc + v[2], 0, LK3D.LIGHTMAP_RES - 1)

			local both_lut_v = both_lut[k]
			if both_lut_v == 3 then
				if (p_offx == xc) and (p_offy == yc) then
					continue
				end
			elseif both_lut_v == 2 then
				if (p_offy == yc) then
					continue
				end
			else
				if (p_offx == xc) then
					continue
				end
			end

			local id = (p_offx + (p_offy * LK3D.LIGHTMAP_RES))
			if bad_pixels[id] then
				continue
			end


			if not pixa_buff[id] then
				local r_r, r_g, r_b = render.ReadPixel(p_offx, p_offy)

				pixa_buff[id] = {r_r, r_g, r_b}
			end
			local pb = pixa_buff[id]
			nearby_accum_r = pb[1]
			nearby_accum_g = pb[2]
			nearby_accum_b = pb[3]

			found = true
			break
		end

		if found then
			surface.SetDrawColor(nearby_accum_r, nearby_accum_g, nearby_accum_b, 255)
			surface.DrawRect(xc, yc, 1, 1)
			local idex = xc + (yc * LK3D.LIGHTMAP_RES)
			pixa_to_update[#pixa_to_update + 1] = {idex, nearby_accum_r, nearby_accum_g, nearby_accum_b}
		end
	end

	for k, v in ipairs(pixa_to_update) do
		local vid = v[1]
		pixa_buff[vid] = {v[2], v[3], v[4]}
		bad_pixels[vid] = nil
	end
end


local function getLMTexNames(object)
	return "lightmap_object_" .. object .. "_res_" .. LK3D.LIGHTMAP_RES .. "_orig", "lightmap_object_" .. object .. "_res_" .. LK3D.LIGHTMAP_RES .. "_copy"
end

local function lightmapInit()
	for k, v in pairs(objects_to_lightmap) do
		local obj_ptr = LK3D.CurrUniv["objects"][k]
		if not obj_ptr then
			return
		end

		makeLightMapUV(k, LK3D.LIGHTMAP_RES, LK3D.LIGHTMAP_RES)
		buildTriUVLUT(k, LK3D.LIGHTMAP_RES, LK3D.LIGHTMAP_RES)

		local idx_orig, idx_cpy = getLMTexNames(k)
		LK3D.DeclareTextureFromFunc(idx_orig, LK3D.LIGHTMAP_RES, LK3D.LIGHTMAP_RES, function()
			if obj_ptr.RADIOSITY_LIT then
				render.Clear(255, 255, 255, 255)
			else
				render.Clear(0, 0, 0, 255)
			end
		end)

		LK3D.DeclareTextureFromFunc(idx_cpy, LK3D.LIGHTMAP_RES, LK3D.LIGHTMAP_RES, function()
			if obj_ptr.RADIOSITY_LIT then
				render.Clear(255, 255, 255, 255)
			else
				render.Clear(0, 0, 0, 255)
			end
		end)
	end

	cloneUnivToRadioUniv()
end



local o_temp_pixelvals = {}
local function lightmapCalcObject(object)
	local idx_orig = getLMTexNames(object)
	local obj_ptr = LK3D.CurrUniv["objects"][object]

	if obj_ptr.RADIOSITY_LIT then
		return
	end



	o_temp_pixelvals[object] = o_temp_pixelvals[object] or {}
	LK3D.UpdateTexture(idx_orig, function()
		local ow, oh = ScrW(), ScrH()


		local bad_pixels = {}
		local o_lr, o_lg, o_lb = LK3D.GetLightIntensity(obj_ptr.pos)
		LK3D.PushUniverse(universeCloneRadiosity)
		for i = 0, (LK3D.LIGHTMAP_RES * LK3D.LIGHTMAP_RES) - 1 do
			local xc = i % LK3D.LIGHTMAP_RES
			local yc = math_floor(i / LK3D.LIGHTMAP_RES)

			local pos_c, norm_c = texturi_to_world(object, xc, yc, LK3D.LIGHTMAP_RES, LK3D.LIGHTMAP_RES)

			local lr, lg, lb
			if pos_c == nil then
				bad_pixels[i] = true
				lr, lg, lb = o_lr, o_lg, o_lb
			else

				if LK3D.RADIOSITY_DO_RT then
					--local c = HSVToColor(tri_c, ((tri_c % 2) == 0) and 1 or .5, 1)
					--lr, lg, lb = c.r / 255, c.g / 255, c.b / 255
					--lr, lg, lb = LK3D.GetLightIntensity(pos_c)
					lr, lg, lb = calcLighting(pos_c, norm_c)
					--lr, lg, lb = o_lr, o_lg, o_lb
				else
					lr, lg, lb = get_lighting_via_cam(pos_c, norm_c)
				end
			end



			if LK3D.RADIOSITY_ADDITIVE_CALC then
				local fr, fg, fb
				if o_temp_pixelvals[object][i] then
					fr = math.min(o_temp_pixelvals[object][i][1] + (lr * 255), 255)
					fg = math.min(o_temp_pixelvals[object][i][2] + (lg * 255), 255)
					fb = math.min(o_temp_pixelvals[object][i][3] + (lb * 255), 255)
				else
					fr = math.min(lr * 255, 255)
					fg = math.min(lg * 255, 255)
					fb = math.min(lb * 255, 255)
				end


				o_temp_pixelvals[object][i] = {
					fr,
					fg,
					fb
				}
				render.SetViewPort(xc, yc, 1, 1)
				render.Clear(fr, fg, fb, 255)

				--surface.SetDrawColor(fr, fg, fb)-- additive
				--surface.DrawRect(xc, yc, 1, 1)
			else
				--surface.SetDrawColor(lr * 255, lg * 255, lb * 255)
				--surface.DrawRect(xc, yc, 1, 1)

				render.SetViewPort(xc, yc, 1, 1)
				render.Clear(lr * 255, lg * 255, lb * 255, 255)
			end


			if (i % 128) == 0 then
				local the_rt = render.GetRenderTarget()
				LK3D.RenderProcessingMessage("Radiosity calculate light\n[" .. object .. "]", (i / ((LK3D.LIGHTMAP_RES * LK3D.LIGHTMAP_RES) - 1)) * 100, function()
					render.DrawTextureToScreenRect(the_rt, 0, 288 * (ScrH() / 512), 512, 512)
					render.DrawTextureToScreenRect(radios_rt, 288 * (ScrH() / 512) * 2, 288 * (ScrH() / 512), 512, 512)
				end)
			end
		end
		LK3D.PopUniverse()

		render.SetViewPort(0, 0, ow, oh)

		local pixa_buff = {}
		for _ = 1, LK3D.LIGHTMAP_TRIPAD do
			render.CapturePixels()
			expandBorders(object, pixa_buff, bad_pixels)
		end
	end)
end


local function lightmapStep()
	if not LK3D.RADIOSITY_DO_RT then
		setRadiosaTexturesPost()
	end

	-- calc lightmapping
	for k, v in pairs(objects_to_lightmap) do
		local obj_ptr = LK3D.CurrUniv["objects"][k]
		if not obj_ptr then
			return
		end

		lightmapCalcObject(k)
	end

	-- copy texture
	for k, v in pairs(objects_to_lightmap) do
		local idx_orig, idx_cpy = getLMTexNames(k)

		LK3D.CopyTexture(idx_orig, idx_cpy)
	end
end

local function lightmapFinalize()
	for k, v in pairs(objects_to_lightmap) do
		local obj_ptr = LK3D.CurrUniv["objects"][k]
		if not obj_ptr then
			return
		end

		local idx_orig = getLMTexNames(k)

		obj_ptr.limap_tex = idx_orig
	end

	objects_to_lightmap = {}
end



function LK3D.SetLightmapped(object)
	objects_to_lightmap[object] = true
end


-- lightmaps all of the objects with radiosity
function LK3D.CommitLightmapping()
	if LK3D.RADIOSITY_DO_RT then
		lightmapInit()
		lightmapStep()
		lightmapFinalize()
	else
		lightmapInit()

		local last_dbg = LK3D.Debug
		LK3D.Debug = false
		for i = 1, LK3D.RADIOSITY_STEPS do
			lightmapStep()
		end
		LK3D.Debug = last_dbg

		lightmapFinalize()
	end
end


function LK3D.PackTest()
	LK3D.DeclareTextureFromFunc("packtest", LK3D.LIGHTMAP_RES, LK3D.LIGHTMAP_RES, function()
		render.Clear(0, 0, 0, 255)
		local tree = newleaf(LK3D.LIGHTMAP_RES, LK3D.LIGHTMAP_RES)
		tree.children[1] = newleaf(LK3D.LIGHTMAP_RES, LK3D.LIGHTMAP_RES)
		tree.children[2] = newleaf(0, 0)
		local faketris = {}
		for i = 1, 128 do
			faketris[#faketris + 1] = {
				{0, 0},
				{math.random(8, 24), 0},
				{math.random(8, 24), math.random(8, 24)}
			}
		end

		for k, v in pairs(faketris) do
			local ret = insert_into_leaf(tree, v)

			if not ret then
				print("EPIC FAIL")
				break
			end

			surface.SetDrawColor(HSVToColor((k / 128) * 360, 1, 1))
			draw.NoTexture()
			surface.DrawPoly({
				{
					x = ret[1][1][1],
					y = ret[1][1][2],
				},
				{
					x = ret[2][1][1],
					y = ret[2][1][2],
				},
				{
					x = ret[3][1][1],
					y = ret[3][1][2],
				}
			})
		end
	end)
end




file.CreateDir("lk3d/lightmap_temp")
file.CreateDir("lk3d/lightmap_temp/" .. engine.ActiveGamemode())
local targ_temp = "lk3d/lightmap_temp/" .. engine.ActiveGamemode() .. "/"
local function makeLightmapTexLegacy(f_pointer_temp, tw, th, tag, obj_idx)
	local lm_tex_idx = "lightmap_" .. tag .. "_" .. obj_idx
	LK3D.DeclareTextureFromFunc(lm_tex_idx, tw, th, function()
		render.Clear(64, 255, 64, 255)
		for i = 0, (tw * th) - 1 do
			if (i % 1024) == 0 then
				LK3D.RenderProcessingMessage("Load radiosity...\n[" .. obj_idx .. "]", (i / ((tw * th) - 1)) * 100)
			end


			local xc = (i % tw)
			local yc = math.floor(i / tw)


			local r = f_pointer_temp:ReadByte()
			local g = f_pointer_temp:ReadByte()
			local b = f_pointer_temp:ReadByte()

			render.SetViewPort(xc, yc, 1, 1)
			render.Clear(r, g, b, 255)
		end
		render.SetViewPort(0, 0, tw, th)
	end)
end




local lastAccumChange = CurTime()
local lightmapAccum = 0
local matDontDeleteArchive = {}

function RecomputeTestWhyIsThisBroken()
	matDontDeleteArchive["dd_uni_lobby"]["lobby_wait"]:Recompute()
end

local function loadLightmapObject(data, tag, obj_idx)
	if CurTime() > lastAccumChange then
		lightmapAccum = 0
	end
	lastAccumChange = CurTime() + 2
	lightmapAccum = lightmapAccum + 1
	if not data then
		LK3D.New_D_Print("Attempting to load lightmap with no data!", 4, "Radiosity")
		return
	end

	file.Write(targ_temp .. "temp1.txt", util.Decompress(data))


	local f_pointer_temp = file.Open(targ_temp .. "temp1.txt", "rb", "DATA")
	local header = f_pointer_temp:Read(4)
	if header ~= "LKLM" then
		LK3D.New_D_Print("Failure decoding LKLM file! (start header no match)", 4, "Radiosity")
		f_pointer_temp:Close()
		return
	end

	local tw = f_pointer_temp:ReadULong()
	local th = f_pointer_temp:ReadULong()

	local lm_tex_idx = "lightmap_" .. tag .. "_" .. obj_idx .. "_" .. tw .. "_" .. th
	LK3D.DeclareTextureFromFunc(lm_tex_idx, tw, th, function()
		render.Clear(255, 0, 0, 255)
	end)

	local thing_path = targ_temp .. tag .. "_" .. obj_idx .. "_" .. tw .. "_" .. th .. ".png"
	local png_data_writer = file.Open(thing_path, "wb", "DATA")

	--print("---" .. obj_idx .. "---")
	local chunkCount = f_pointer_temp:ReadULong()
	--print("chunks: " .. chunkCount)
	for i = 1, chunkCount do
		local lengthRead = f_pointer_temp:ReadULong()
		png_data_writer:Write(f_pointer_temp:Read(lengthRead))
	end
	png_data_writer:Close()

	--local png_data_length = f_pointer_temp:ReadDouble()
	--local png_data = f_pointer_temp:Read(png_data_length)
	--file.Write(thing_path, png_data)

	local read_post_verif = f_pointer_temp:Read(3)
	if read_post_verif ~= "DNE" then
		LK3D.New_D_Print("Failure decoding LKLM file! (colour DNE fail)", 4, "Radiosity")
		f_pointer_temp:Close()
		return
	end

	if not matDontDeleteArchive[tag] then
		matDontDeleteArchive[tag] = {}
	end

	matDontDeleteArchive[tag][obj_idx] = Material("../data/" .. thing_path, "ignorez nocull")
	timer.Simple(0, function()
		LK3D.DeclareTextureFromFunc(lm_tex_idx, tw, th, function()
			render.Clear(64, 0, 96, 255)
			surface.SetMaterial(matDontDeleteArchive[tag][obj_idx])
			surface.SetDrawColor(255, 255, 255, 255)
			surface.DrawTexturedRect(0, 0, tw, th)
		end)
		-- file.Delete(thing_path, "DATA") -- this breaks lightmapping
	end)

	local lm_uvs = {}
	local tri_count = f_pointer_temp:ReadULong()
	for i = 1, tri_count do
		lm_uvs[#lm_uvs + 1] = {
			math.Round(f_pointer_temp:ReadDouble(), 8),
			math.Round(f_pointer_temp:ReadDouble(), 8)
		}
		lm_uvs[#lm_uvs + 1] = {
			math.Round(f_pointer_temp:ReadDouble(), 8),
			math.Round(f_pointer_temp:ReadDouble(), 8)
		}
		lm_uvs[#lm_uvs + 1] = {
			math.Round(f_pointer_temp:ReadDouble(), 8),
			math.Round(f_pointer_temp:ReadDouble(), 8)
		}
	end

	read_post_verif = f_pointer_temp:Read(3)
	if read_post_verif ~= "DNE" then
		LK3D.New_D_Print("Failure decoding LKLM file! (lm_uv DNE fail)", 4, "Radiosity")
		f_pointer_temp:Close()
		return
	end

	local obj_ptr = LK3D.CurrUniv["objects"][obj_idx]
	local mdlinfo = LK3D.Models[obj_ptr.mdl]
	local indices = mdlinfo.indices

	local index_count = f_pointer_temp:ReadULong()
	for i = 1, index_count do
		indices[i][1][3] = f_pointer_temp:ReadULong()
		indices[i][2][3] = f_pointer_temp:ReadULong()
		indices[i][3][3] = f_pointer_temp:ReadULong()
	end

	read_post_verif = f_pointer_temp:Read(3)
	if read_post_verif ~= "DNE" then
		LK3D.New_D_Print("Failure decoding LKLM file! (index_lm DNE fail)", 4, "Radiosity")
		f_pointer_temp:Close()
		return
	end

	local read_header_end = f_pointer_temp:Read(4)
	f_pointer_temp:Close()
	if read_header_end ~= "LKLM" then
		LK3D.New_D_Print("Failure decoding LKLM file! (end header fail)", 4, "Radiosity")
		return
	end



	LK3D.CurrUniv["objects"][obj_idx].limap_tex = lm_tex_idx
	LK3D.CurrUniv["objects"][obj_idx].lightmap_uvs = lm_uvs
	--lightmap_uvs
end


function LK3D.LoadLightmapFromFile(obj_idx)
	local tag = LK3D.CurrUniv["tag"]
	if not tag then
		LK3D.New_D_Print("Attempting to load lightmap on universe with no tag!", 4, "Radiosity")
		return
	end

	local obj_check = LK3D.CurrUniv["objects"][obj_idx]
	if not obj_check then
		LK3D.New_D_Print("Attempting to load lightmap for non-existing object \"" .. obj_idx .. "\"!", 4, "Radiosity")
		return
	end


	local fcontents = LK3D.ReadFileFromLKPack("lightmaps/" .. tag .. "/" .. obj_idx .. ".llm")
	if not fcontents then
		LK3D.New_D_Print("Attempting to load missing lightmap from LKPack! (" .. tag .. "): [" .. obj_idx .. "]", 4, "Radiosity")
		return
	end

	loadLightmapObject(fcontents, tag, obj_idx)
	LK3D.New_D_Print("Loaded lightmap for \"" .. obj_idx .. "\" from LKPack successfully!", 2, "Radiosity")
end




-- a more simplistic file format, less compressed than others
local function exportLightmapObject(obj, obj_id) -- this exports it as custom file lightmap
	local tag = LK3D.CurrUniv["tag"]
	local targ_folder = "lk3d/lightmap_export/" .. engine.ActiveGamemode() .. "/" .. tag .. "/"

	file.Write(targ_folder .. obj_id .. "_temp.txt", "temp")
	local f_pointer_temp = file.Open(targ_folder .. obj_id .. "_temp.txt", "wb", "DATA")

	local lm_t = obj.limap_tex

	local tex_p = LK3D.Textures[lm_t]
	local tw, th = tex_p.rt:Width(), tex_p.rt:Height()

	f_pointer_temp:Write("LKLM") -- lklm header LKLightMap
	f_pointer_temp:WriteULong(tw)
	f_pointer_temp:WriteULong(th)


	-- lets capture with png instead
	local ow, oh = ScrW(), ScrH()
	render.SetViewPort(0, 0, tw, th)
	render.PushRenderTarget(tex_p.rt)
		local png_data = render.Capture({
			format = "png",
			alpha = true,
			x = 0,
			y = 0,
			w = tw,
			h = th,
		})
	render.PopRenderTarget()
	render.SetViewPort(0, 0, ow, oh)

	-- write data temporarily
	file.Write("lk3d/lightmap_temp/export_png.png", png_data)

	local f_pointer_pngDat = file.Open("lk3d/lightmap_temp/export_png.png", "rb", "DATA")

	local length_png_data = #png_data
	print("---" .. obj_id .. "---")
	print(length_png_data)

	local chunkSz = 16384
	local chunkCount = math.ceil(length_png_data / chunkSz)
	chunkCount = math.max(chunkCount, 1)
	print(chunkCount .. " chunks...")
	-- split into chunks
	f_pointer_temp:WriteULong(chunkCount)
	local lengthAccum = length_png_data
	for i = 1, chunkCount do
		local lengthCurr = math.min(lengthAccum, chunkSz)
		lengthAccum = lengthAccum - chunkSz
		print("chunk º" .. i .. ": " .. lengthCurr)


		f_pointer_temp:WriteULong(lengthCurr)
		f_pointer_temp:Write(f_pointer_pngDat:Read(lengthCurr))
	end

	f_pointer_pngDat:Close()

	--[[
	local tex_arr = LK3D.GetTexturePixelArray(lm_t, true) -- we want it inlined
	-- now write pixel data, dont bother with rle, let lzma do the magic
	local pxcount = tw * th
	for i = 1, pxcount do
		local pixel = tex_arr[i]

		f_pointer_temp:WriteByte(pixel[1])
		f_pointer_temp:WriteByte(pixel[2])
		f_pointer_temp:WriteByte(pixel[3]) -- dont sotre alpha idiot
	end
	]]--
	f_pointer_temp:Write("DNE") -- done


	local object_uvs = {}
	local tri_list = getTriTable(obj_id)

	for k2, v2 in ipairs(tri_list) do
		object_uvs[#object_uvs + 1] = {
			copyUV(v2[1].lm_uv),
			copyUV(v2[2].lm_uv),
			copyUV(v2[3].lm_uv),
		}
	end

	local tri_count = #object_uvs
	f_pointer_temp:WriteULong(tri_count)
	for i = 1, tri_count do
		local uv_dat = object_uvs[i][1]
		f_pointer_temp:WriteDouble(uv_dat[1])
		f_pointer_temp:WriteDouble(uv_dat[2])
		uv_dat = object_uvs[i][2]
		f_pointer_temp:WriteDouble(uv_dat[1])
		f_pointer_temp:WriteDouble(uv_dat[2])
		uv_dat = object_uvs[i][3]
		f_pointer_temp:WriteDouble(uv_dat[1])
		f_pointer_temp:WriteDouble(uv_dat[2])
	end
	f_pointer_temp:Write("DNE") -- done

	-- indices to lm uvs [idx 3 on model]
	local mdlinfo = LK3D.Models[obj.mdl]
	local indices = mdlinfo.indices

	local index_count = #indices -- each index is a tri so each thing holds 3
	f_pointer_temp:WriteULong(index_count)
	for i = 1, index_count do
		local index = indices[i]
		f_pointer_temp:WriteULong(index[1][3])
		f_pointer_temp:WriteULong(index[2][3])
		f_pointer_temp:WriteULong(index[3][3])
	end
	f_pointer_temp:Write("DNE") -- done


	f_pointer_temp:Write("LKLM") -- header end
	f_pointer_temp:Close()

	file.Write(targ_folder .. obj_id .. ".llm.txt", util.Compress(file.Read(targ_folder .. obj_id .. "_temp.txt", "DATA")))
	file.Delete(targ_folder .. obj_id .. "_temp.txt", "DATA")
end

-- exports all of the lightmaps from the curr univ along with their object lightmap uvs
file.CreateDir("lk3d/lightmap_export")
file.CreateDir("lk3d/lightmap_export/" .. engine.ActiveGamemode())
function LK3D.ExportLightmaps()
	if not LK3D.CurrUniv["tag"] then
		LK3D.New_D_Print("Attempting to export lightmaps for a universe without a tag!", 4, "Radiosity")
		return
	end

	local tag = LK3D.CurrUniv["tag"]
	local targ_folder = "lk3d/lightmap_export/" .. engine.ActiveGamemode() .. "/" .. tag .. "/"
	file.CreateDir(targ_folder)

	for k, v in pairs(LK3D.CurrUniv["objects"]) do
		local lm_tex = v.limap_tex
		if not lm_tex then -- object not lightmapped
			continue
		end

		exportLightmapObject(v, k)
	end

	LK3D.New_D_Print("Exported lightmaps for universe \"" .. tag .. "\"!", 2, "Radiosity")
end