LK3D = LK3D or {}
LK3D.LIGHTMAP_RES = (256 + 64 + 16) * 1.75 --2.5 -- .75
LK3D.LIGHTMAP_TRISZ = 10 * 1.75 --1.75 -- .5
LK3D.LIGHTMAP_TRIPAD = 5
LK3D.LIGHTMAP_AUTO_EXPORT = true -- auto export when done

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
--		emmision = {r, g, b},
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
-- test new
LK3D.RADIOSITY_DO_RT = false
LK3D.RADIOSITY_STEPS = 1
LK3D.RADIOSITY_BUFFER_SZ = 96
LK3D.RADIOSITY_FOV = 90
LK3D.RADIOSITY_LIGHTSCL_DIV = 12
LK3D.RADIOSITY_REFLECTANCE = .9
LK3D.RADIOSITY_MUL_EMMISIVE_START = .75
LK3D.RADIOSITY_MUL_RENDER = 96

-- prolly unused
LK3D.RADIOSITY_SPACING = 4
LK3D.RADIOSITY_ACCURACY = .5


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

	LK3D.New_D_Print("Generating lightmap UVs for object \"" .. obj .. "\"", LK3D_SEVERITY_DEBUG, "Radiosity")

	local mdlpointer = LK3D.Models[mdl]
	local indices = mdlpointer.indices
	local verts = mdlpointer.verts

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

local objectMatTexArrays = {}
local objectPatchInfo = {}
local function initializePatch(idx, obj, isLight, x, y)
	if not objectPatchInfo[idx] then
		objectPatchInfo[idx] = {}
	end

	if not objectPatchInfo[idx][x] then
		objectPatchInfo[idx][x] = {}
	end

	local hasMat = false
	local texArr = {}
	local matW, matH = 0, 0
	if obj.mat ~= nil then
		if not objectMatTexArrays[obj.mat] then
			LK3D.New_D_Print("Making tex array for radiosity material \"" .. obj.mat .. "\"", LK3D_SEVERITY_DEBUG, "Radiosity")
			-- we can grab texture now
			local matData = LK3D.Textures[obj.mat]
			matW = matData.rt:Width()
			matH = matData.rt:Height()

			objectMatTexArrays[obj.mat] = {
				tw = matW,
				th = matH,
				data = LK3D.GetTexturePixelArray(obj.mat)
			}
		end

		local texData = objectMatTexArrays[obj.mat]
		matW = texData.tw
		matH = texData.th
		texArr = texData.data

		hasMat = true
	end

	local emmR, emmG, emmB = 0, 0, 0
	if isLight then
		emmR = obj[3][1] * obj[2]
		emmG = obj[3][2] * obj[2]
		emmB = obj[3][3] * obj[2]
	elseif obj["RADIOSITY_LIT"] then
		emmR = obj.col.r / 255
		emmG = obj.col.g / 255
		emmB = obj.col.b / 255

		-- mul it by textre if we have
		if hasMat then
			local sx = x / LK3D.LIGHTMAP_RES
			local sy = y / LK3D.LIGHTMAP_RES

			sx = math.floor(sx * (matW - 1))
			sy = math.floor(sy * (matH - 1))

			local contentsTex = texArr[sx][sy]

			if contentsTex then
				emmR = emmR * (contentsTex[1] / 255)
				emmG = emmG * (contentsTex[2] / 255)
				emmB = emmB * (contentsTex[3] / 255)
			end
		end
	end

	emmR = emmR * LK3D.RADIOSITY_MUL_EMMISIVE_START
	emmG = emmG * LK3D.RADIOSITY_MUL_EMMISIVE_START
	emmB = emmB * LK3D.RADIOSITY_MUL_EMMISIVE_START



	local reflR, reflG, reflB = 1, 1, 1
	if hasMat then
		-- scale it to closest
		local sx = x / LK3D.LIGHTMAP_RES
		local sy = y / LK3D.LIGHTMAP_RES

		sx = math.floor(sx * (matW - 1))
		sy = math.floor(sy * (matH - 1))

		local contentsTex = texArr[sx][sy]

		if contentsTex then
			reflR = reflR * (contentsTex[1] / 255)
			reflG = reflG * (contentsTex[2] / 255)
			reflB = reflB * (contentsTex[3] / 255)
		end
	end

	local col = obj.col
	if col then
		reflR = reflR * (col.r / 255)
		reflG = reflG * (col.g / 255)
		reflB = reflB * (col.b / 255)
	end

	reflR = reflR * LK3D.RADIOSITY_REFLECTANCE
	reflG = reflG * LK3D.RADIOSITY_REFLECTANCE
	reflB = reflB * LK3D.RADIOSITY_REFLECTANCE

	-- make a new patch
	local patch = {
		emmision = {emmR, emmG, emmB},
		reflectance = {reflR, reflG, reflB},
		incident = {0, 0, 0},  -- (sum of all light that a patch can see)
		excident = {
			emmR,
			emmG,
			emmB
		},
	}
	objectPatchInfo[idx][x][y] = patch
end

local function initializePatchFull(idx, obj, isLight)
	LK3D.New_D_Print("Initializing full patch info for \"" .. idx .. "\"", LK3D_SEVERITY_DEBUG, "Radiosity")
	if not objectPatchInfo[idx] then
		objectPatchInfo[idx] = {}
	end

	for x = 0, LK3D.LIGHTMAP_RES do
		objectPatchInfo[idx][x] = {}
		for y = 0, LK3D.LIGHTMAP_RES do
			initializePatch(idx, obj, isLight, x, y)
		end
	end
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
local uv_tri_lookups = {}
local function buildTriLUTAndPatches(obj, sx, sy)
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

	LK3D.New_D_Print("Calculating tri LUT and patches for object \"" .. obj .. "\"", LK3D_SEVERITY_DEBUG, "Radiosity")
	local uv_sz_c = (1 / LK3D.LIGHTMAP_RES)
	local tbl_ret = {}
	for i = 0, (sx * sy) - 1 do
		if (i % 512) == 0 then
			LK3D.RenderProcessingMessage("[Radiosity]\nGenerate tri LUT and patches\n[" .. obj .. "]", (i / ((sx * sy) - 1)) * 100)
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

					-- also initialize patches
					initializePatch(obj, obj_ptr, false, xc, yc)
					break
				end
			end
		end
		if not has then
			tbl_ret[i] = 0 -- mark as 0 which we know is nothing
		end
	end
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

local universeRadiosityObjID = LK3D.NewUniverse("lk3d_radiosity_objID")
local universeRadiosityPtrX = LK3D.NewUniverse("lk3d_radiosity_ptrX")
local universeRadiosityPtrY = LK3D.NewUniverse("lk3d_radiosity_ptrY")

local objects_to_lightmap = {}


local HP_DMULT = 16
local function packRGB(int)
	int = int * HP_DMULT
	local r = bit.band(bit.rshift(int, 16), 255)
	local g = bit.band(bit.rshift(int,  8), 255)
	local b = bit.band(bit.rshift(int,  0), 255)

	return r, g, b
end

local function unpackRGB(r, g, b)
	local var = (bit.lshift(r, 16) + bit.lshift(g, 8) + b)

	return math.floor(var / HP_DMULT)
end

local function intSnap(int, base)
	local bh = (base * .5)
	return math.floor((int + bh) - ((int + bh) % base))
end

local LP_ST_SZ = 16
local LP_SZ_INV = 256 / LP_ST_SZ
local function packRGB_LP(int)
	local b = (int % LP_ST_SZ) * LP_SZ_INV
	local g = math.floor(int / LP_ST_SZ) * LP_SZ_INV
	local r = math.floor(math.floor(int / LP_ST_SZ) / LP_ST_SZ) * LP_SZ_INV
	return intSnap(r, LP_SZ_INV), intSnap(g, LP_SZ_INV), intSnap(b, LP_SZ_INV)
end

local function unpackRGB_LP(r, g, b)
	local bs1 = intSnap(b, LP_SZ_INV) / LP_SZ_INV
	local bs2 = (intSnap(g, LP_SZ_INV) / LP_SZ_INV) * LP_ST_SZ
	local bs3 = (intSnap(r, LP_SZ_INV) / LP_SZ_INV) * LP_ST_SZ * LP_ST_SZ
	return math.floor(bs1 + bs2 + bs3)
end


--[[
-- quick test
for i = 1, 512 do
	local r, g, b = packRGB_LP(i)

	if b > 128 then
		b = b - 4
	end
	local out = unpackRGB_LP(r, g, b)


	--print(i, intSnap(i, 16))
	print(i, out)
	if i ~= out then
		error("neq error")
	end
end
]]--

-- clones univ to input universe
-- provide material to set all objects to that material
-- or provide inverse lut (["ObjectName"] = 1) to do colouring
local function cloneUniverseRadiosity(univ, cont)
	LK3D.New_D_Print("Cloning universe \"" .. univ["tag"] .. "\" for radiosity...", LK3D_SEVERITY_DEBUG, "Radiosity")
	local prevUniv = LK3D.CurrUniv

	local mat = type(cont) == "string" and cont or "white"
	local tblRef = type(cont) == "table" and cont or nil

	LK3D.PushUniverse(univ)
		LK3D.WipeUniverse()
		for k, v in pairs(prevUniv["objects"]) do
			if v.RENDER_NOGLOBAL then
				continue
			end
			if v.NO_RADIOSITY then
				continue
			end

			LK3D.AddModelToUniverse(k, v.mdl)
			LK3D.SetModelPosAng(k, v.pos, v.ang)
			LK3D.SetModelScale(k, v.scl)
			LK3D.SetModelMat(k, mat)
			LK3D.SetModelFlag(k, "NO_SHADING", true)
			LK3D.SetModelFlag(k, "NO_LIGHTING", true)
			if tblRef and tblRef[k] then
				local indexObj = tblRef[k]
				local pr, pg, pb = packRGB_LP(indexObj)
				LK3D.SetModelCol(k, Color(pr, pg, pb))
			elseif tblRef then
				LK3D.SetModelCol(k, Color(0, 0, 0))
			else
				LK3D.SetModelCol(k, Color(255, 255, 255))
			end
			LK3D.SetModelFlag(k, "CONSTANT", true)
			LK3D.SetModelFlag(k, "ORIG_UNIV", prevUniv["tag"])
			if objects_to_lightmap[k] then
				LK3D.SetModelFlag(k, "lightmap_uvs", v.lightmap_uvs)
				LK3D.SetModelFlag(k, "UV_USE_LIGHTMAP", true)
			end


			local idx_inv = k .. "_lm_inv"
			LK3D.AddModelToUniverse(idx_inv, v.mdl)
			LK3D.SetModelPosAng(idx_inv, v.pos, v.ang)
			LK3D.SetModelScale(idx_inv, v.scl)
			LK3D.SetModelMat(idx_inv, "white")
			LK3D.SetModelFlag(idx_inv, "NO_SHADING", true)
			LK3D.SetModelFlag(idx_inv, "NO_LIGHTING", true)
			LK3D.SetModelCol(idx_inv, Color(0, 0, 0))
			LK3D.SetModelFlag(idx_inv, "CONSTANT", true)
			LK3D.SetModelFlag(idx_inv, "NORM_INVERT", true)
			LK3D.SetModelFlag(idx_inv, "NO_TRACE", true)
			LK3D.SetModelFlag(idx_inv, "ORIG_UNIV", prevUniv["tag"])
		end


		for k, v in pairs(prevUniv["lights"]) do
			local inten_h = v[2] / LK3D.RADIOSITY_LIGHTSCL_DIV
			local inten_vec = Vector(inten_h, inten_h, inten_h)

			local liIdxCol = Color(255, 255, 255)
			if tblRef and tblRef[k] then
				local indexObj = tblRef[k]
				local pr, pg, pb = packRGB_LP(indexObj)
				liIdxCol = Color(pr, pg, pb)
			else
				liIdxCol = Color(0, 0, 0)
			end

			local idx = k .. "_also"
			LK3D.AddModelToUniverse(idx, "sphere_simple")
			LK3D.SetModelPosAng(idx, v[1], Angle(0, 45, 45))
			LK3D.SetModelScale(idx, inten_vec)
			LK3D.SetModelFlag(idx, "NO_SHADING", true)
			LK3D.SetModelFlag(idx, "NO_LIGHTING", true)
			LK3D.SetModelFlag(idx, "NO_TRACE", true)
			LK3D.SetModelFlag(idx, "CONSTANT", true)
			LK3D.SetModelMat(idx, "white")
			LK3D.SetModelCol(idx, liIdxCol)


			idx = k .. "_invr_also"
			LK3D.AddModelToUniverse(idx, "sphere_simple")
			LK3D.SetModelPosAng(idx, v[1], Angle(0, 45, 45))
			LK3D.SetModelScale(idx, inten_vec)
			LK3D.SetModelFlag(idx, "NO_SHADING", true)
			LK3D.SetModelFlag(idx, "NO_LIGHTING", true)
			LK3D.SetModelFlag(idx, "NO_TRACE", true)
			LK3D.SetModelFlag(idx, "CONSTANT", true)
			LK3D.SetModelFlag(idx, "NORM_INVERT", true)
			LK3D.SetModelMat(idx, "white")
			LK3D.SetModelCol(idx, liIdxCol)
		end
	LK3D.PopUniverse()
end


local objectIndexTable = {}
local inverseObjectIndexTable = {}
local objectIsLightTable = {}
local function generateObjectIndexTable()
	LK3D.New_D_Print("Generating object index table...", LK3D_SEVERITY_DEBUG, "Radiosity")
	local last = 4 -- fix col select issue

	for k, v in pairs(objects_to_lightmap) do
		objectIndexTable[last] = k
		inverseObjectIndexTable[k] = last
		last = last + 1
	end

	-- lights too
	for k, v in pairs(LK3D.CurrUniv["lights"]) do
		objectIndexTable[last] = k
		inverseObjectIndexTable[k] = last
		objectIsLightTable[k] = true

		initializePatchFull(k, v, true)

		last = last + 1
	end
end

local function cloneUniverses()
	generateObjectIndexTable()

	cloneUniverseRadiosity(universeRadiosityObjID, inverseObjectIndexTable)

	local matIndexX = "lk3d_radiosity_ptrPosX_" .. LK3D.LIGHTMAP_RES
	cloneUniverseRadiosity(universeRadiosityPtrX, matIndexX)

	local matIndexY = "lk3d_radiosity_ptrPosY_" .. LK3D.LIGHTMAP_RES
	cloneUniverseRadiosity(universeRadiosityPtrY, matIndexY)
end

local radios_rt_up = GetRenderTarget("lk3d_radiosity_buffer_up_" .. LK3D.RADIOSITY_BUFFER_SZ, LK3D.RADIOSITY_BUFFER_SZ, LK3D.RADIOSITY_BUFFER_SZ)
local radios_rt_fw = GetRenderTarget("lk3d_radiosity_buffer_fw_" .. LK3D.RADIOSITY_BUFFER_SZ, LK3D.RADIOSITY_BUFFER_SZ, LK3D.RADIOSITY_BUFFER_SZ)
local radios_rt_le = GetRenderTarget("lk3d_radiosity_buffer_le_" .. LK3D.RADIOSITY_BUFFER_SZ, LK3D.RADIOSITY_BUFFER_SZ, LK3D.RADIOSITY_BUFFER_SZ)
local radios_rt_ri = GetRenderTarget("lk3d_radiosity_buffer_ri_" .. LK3D.RADIOSITY_BUFFER_SZ, LK3D.RADIOSITY_BUFFER_SZ, LK3D.RADIOSITY_BUFFER_SZ)
local radios_rt_dw = GetRenderTarget("lk3d_radiosity_buffer_dw_" .. LK3D.RADIOSITY_BUFFER_SZ, LK3D.RADIOSITY_BUFFER_SZ, LK3D.RADIOSITY_BUFFER_SZ)


-- renders the hemicube to the rendertarget buffers independent of anything else
-- TAKES: pos (cam pos), dir (cam dir)
-- this renders 6 views
local function renderHemicube(pos, dir)
	local old_pos, old_ang = LK3D.CamPos, LK3D.CamAng
	local old_dbg = LK3D.Debug
	LK3D.Debug = false
	LK3D.SetCamPos(pos)
	LK3D.SetFOV(LK3D.RADIOSITY_FOV)
	-- up
	LK3D.PushRenderTarget(radios_rt_up)
		LK3D.RenderClear(0, 0, 0)
		local mat_up = Matrix()
		mat_up:SetAngles(dir:Angle())
		mat_up:Rotate(Angle(-90, 0, 0))

		LK3D.SetCamAng(mat_up:GetAngles())
		LK3D.RenderActiveUniverse()
	LK3D.PopRenderTarget()

	-- forward
	LK3D.PushRenderTarget(radios_rt_fw)
		LK3D.RenderClear(0, 0, 0)
		LK3D.SetCamAng(dir:Angle())
		LK3D.RenderActiveUniverse()
	LK3D.PopRenderTarget()

	-- left
	LK3D.PushRenderTarget(radios_rt_le)
		LK3D.RenderClear(0, 0, 0)
		local mat_le = Matrix()
		mat_le:SetAngles(dir:Angle())
		mat_le:Rotate(Angle(0, 90, 0))

		LK3D.SetCamAng(mat_le:GetAngles())
		LK3D.RenderActiveUniverse()
	LK3D.PopRenderTarget()

	-- right
	LK3D.PushRenderTarget(radios_rt_ri)
		LK3D.RenderClear(0, 0, 0)
		local mat_ri = Matrix()
		mat_ri:SetAngles(dir:Angle())
		mat_ri:Rotate(Angle(0, -90, 0))

		LK3D.SetCamAng(mat_ri:GetAngles())
		LK3D.RenderActiveUniverse()
	LK3D.PopRenderTarget()

	-- down
	LK3D.PushRenderTarget(radios_rt_dw)
		LK3D.RenderClear(0, 0, 0)
		local mat_dw = Matrix()
		mat_dw:SetAngles(dir:Angle())
		mat_dw:Rotate(Angle(90, 0, 0))

		LK3D.SetCamAng(mat_dw:GetAngles())
		LK3D.RenderActiveUniverse()
	LK3D.PopRenderTarget()

	LK3D.SetCamPos(old_pos)
	LK3D.SetCamAng(old_ang)
	LK3D.Debug = old_dbg
end

local function renderHemicubeRTsTest(x, y)
	local rtSz = 256
	render.DrawTextureToScreenRect(radios_rt_up, x       , y - rtSz, rtSz, rtSz)
	render.DrawTextureToScreenRect(radios_rt_fw, x       , y       , rtSz, rtSz)
	render.DrawTextureToScreenRect(radios_rt_le, x - rtSz, y       , rtSz, rtSz)
	render.DrawTextureToScreenRect(radios_rt_ri, x + rtSz, y       , rtSz, rtSz)
	render.DrawTextureToScreenRect(radios_rt_dw, x       , y + rtSz, rtSz, rtSz)
end

local TEMP_comp_radios_rt_up = GetRenderTarget("lk3d_radiosity_TEMPbuffer_up_" .. LK3D.RADIOSITY_BUFFER_SZ, LK3D.RADIOSITY_BUFFER_SZ, LK3D.RADIOSITY_BUFFER_SZ)
local TEMP_comp_radios_rt_fw = GetRenderTarget("lk3d_radiosity_TEMPbuffer_fw_" .. LK3D.RADIOSITY_BUFFER_SZ, LK3D.RADIOSITY_BUFFER_SZ, LK3D.RADIOSITY_BUFFER_SZ)
local TEMP_comp_radios_rt_le = GetRenderTarget("lk3d_radiosity_TEMPbuffer_le_" .. LK3D.RADIOSITY_BUFFER_SZ, LK3D.RADIOSITY_BUFFER_SZ, LK3D.RADIOSITY_BUFFER_SZ)
local TEMP_comp_radios_rt_ri = GetRenderTarget("lk3d_radiosity_TEMPbuffer_ri_" .. LK3D.RADIOSITY_BUFFER_SZ, LK3D.RADIOSITY_BUFFER_SZ, LK3D.RADIOSITY_BUFFER_SZ)
local TEMP_comp_radios_rt_dw = GetRenderTarget("lk3d_radiosity_TEMPbuffer_dw_" .. LK3D.RADIOSITY_BUFFER_SZ, LK3D.RADIOSITY_BUFFER_SZ, LK3D.RADIOSITY_BUFFER_SZ)

local function renderHemicubeRTsTest2(x, y)
	local rtSz = LK3D.RADIOSITY_BUFFER_SZ
	render.DrawTextureToScreenRect(TEMP_comp_radios_rt_up, x       , y - rtSz, rtSz, rtSz)
	render.DrawTextureToScreenRect(TEMP_comp_radios_rt_fw, x       , y       , rtSz, rtSz)
	render.DrawTextureToScreenRect(TEMP_comp_radios_rt_le, x - rtSz, y       , rtSz, rtSz)
	render.DrawTextureToScreenRect(TEMP_comp_radios_rt_ri, x + rtSz, y       , rtSz, rtSz)
	render.DrawTextureToScreenRect(TEMP_comp_radios_rt_dw, x       , y + rtSz, rtSz, rtSz)
end



local multTbl_up = {}
local multTbl_fw = {}
local multTbl_le = {}
local multTbl_ri = {}
local multTbl_dw = {}

local function calcDirLocal(x, y)
	local tanMul = math.tan(90 / 2 * math.pi / 180)

	local pX = (2 * ((x + 0.5) / LK3D.RADIOSITY_BUFFER_SZ) - 1) * tanMul
	local pY = 1 - 2 * ((y + 0.5) / LK3D.RADIOSITY_BUFFER_SZ) * tanMul
	local dirCalc = Vector(pX, pY, -1)
	dirCalc:Normalize()

	return dirCalc
end

local function calcMultTbl(tbl, ang)
	local sum = 0
	for x = 0, LK3D.RADIOSITY_BUFFER_SZ do -- double loop here is alright since precalc
		tbl[x] = {}
		for y = 0, LK3D.RADIOSITY_BUFFER_SZ do
			local dirCalc = calcDirLocal(y, x)
			local dotDiff = -Vector(0, 0, 1):Dot(dirCalc)
			dotDiff = math.max(dotDiff, 0)

			local dirNonLocal = Vector(dirCalc)
			dirNonLocal:Rotate(-ang)
			dirNonLocal:Normalize()

			local dotDiffGlobal = -Vector(0, 0, 1):Dot(dirNonLocal)
			dotDiffGlobal = math.max(dotDiffGlobal, 0)

			sum = sum + (dotDiff * dotDiffGlobal)
			tbl[x][y] = (dotDiff * dotDiffGlobal)
		end
	end

	return sum
end



local function normalizeMap(sum, tbl)
	for x = 0, LK3D.RADIOSITY_BUFFER_SZ do
		for y = 0, LK3D.RADIOSITY_BUFFER_SZ do
			tbl[x][y] = tbl[x][y] / sum
		end
	end
end

local function normalizeMaps(sum)
	normalizeMap(sum, multTbl_up)
	normalizeMap(sum, multTbl_fw)
	normalizeMap(sum, multTbl_le)
	normalizeMap(sum, multTbl_ri)
	normalizeMap(sum, multTbl_dw)
end


local function renderMultiplierToRT(tbl, rt)
	LK3D.PushRenderTarget(rt)
		LK3D.RenderQuick(function()
			for x = 0, LK3D.RADIOSITY_BUFFER_SZ do
				for y = 0, LK3D.RADIOSITY_BUFFER_SZ do
					local contA = tbl[x]
					if not contA then
						return
					end

					local contB = contA[y]
					if not contB then
						return
					end

					local colCalc = contB * 255000
					surface.SetDrawColor(colCalc, colCalc, colCalc)
					surface.DrawRect(x, y, 1, 1)
				end
			end
		end)
	LK3D.PopRenderTarget()
end

local compensSum = 0
local function calcMultiplierTables()
	compensSum = 0
	-- up
	compensSum = compensSum + calcMultTbl(multTbl_up, Angle(-90, 0, 0))
	-- forward
	compensSum = compensSum + calcMultTbl(multTbl_fw, Angle(0, 0, 0))
	-- left
	compensSum = compensSum + calcMultTbl(multTbl_le, Angle(0, 0, -90))
	-- right
	compensSum = compensSum + calcMultTbl(multTbl_ri, Angle(0, 0, 90))
	-- down
	compensSum = compensSum + calcMultTbl(multTbl_dw, Angle(90, 0, 0))

	-- now normalize
	--normalizeMaps(compensSum) -- this breaks the light bouncing around? bad tutorial

	renderMultiplierToRT(multTbl_up, TEMP_comp_radios_rt_up)
	renderMultiplierToRT(multTbl_fw, TEMP_comp_radios_rt_fw)
	renderMultiplierToRT(multTbl_ri, TEMP_comp_radios_rt_ri)
	renderMultiplierToRT(multTbl_le, TEMP_comp_radios_rt_le)
	renderMultiplierToRT(multTbl_dw, TEMP_comp_radios_rt_dw)
end
calcMultiplierTables()



local patchesToUpdate = {}
local function updatePatches()
	for i = 1, #patchesToUpdate do
		local patch = patchesToUpdate[i]

		local incidentSelf = patch.incident
		local reflectanceSelf = patch.reflectance
		local emmisionSelf = patch.emmision

		patch.excident = {
			(incidentSelf[1] * reflectanceSelf[1]) + emmisionSelf[1],
			(incidentSelf[2] * reflectanceSelf[2]) + emmisionSelf[2],
			(incidentSelf[3] * reflectanceSelf[3]) + emmisionSelf[3],
		}

		if (i % 1024) == 0 then
			LK3D.RenderProcessingMessage("Radiosity update patches", (i / #patchesToUpdate) * 100)
		end
	end

	patchesToUpdate = {} -- clrear the registry
end


local function initPatchWhileTracing(objName, xc, yc)
	local isLight = false
	local obj = LK3D.CurrUniv["objects"][objName]
	if obj == nil then
		obj = LK3D.CurrUniv["lights"][objName]
		isLight = true
	end

	initializePatch(objName, obj, isLight, xc, yc)
end


local function renderMulFromPatch(patch)
	local pI = patch.incident
	return math.min(pI[1] * LK3D.RADIOSITY_MUL_RENDER, 1), math.min(pI[2] * LK3D.RADIOSITY_MUL_RENDER, 1), math.min(pI[3] * LK3D.RADIOSITY_MUL_RENDER, 1)
end

-- gets the lighting of a single radiosity patch
-- renders 3 hemicube passes (15 renders)
-- and uses pointers to gather all of the info
local function updatePatch(pos, norm, patch)
	LK3D.PushUniverse(universeRadiosityObjID)
		renderHemicube(pos, norm)
	LK3D.PopUniverse()

	local objDatas = {}
	objDatas[0] = LK3D.GetTexturePixelArrayFromRT(radios_rt_up, true)
	objDatas[1] = LK3D.GetTexturePixelArrayFromRT(radios_rt_fw, true)
	objDatas[2] = LK3D.GetTexturePixelArrayFromRT(radios_rt_le, true)
	objDatas[3] = LK3D.GetTexturePixelArrayFromRT(radios_rt_ri, true)
	objDatas[4] = LK3D.GetTexturePixelArrayFromRT(radios_rt_dw, true)


	LK3D.PushUniverse(universeRadiosityPtrX)
		renderHemicube(pos, norm)
	LK3D.PopUniverse()

	local ptrXDatas = {}
	ptrXDatas[0] = LK3D.GetTexturePixelArrayFromRT(radios_rt_up, true)
	ptrXDatas[1] = LK3D.GetTexturePixelArrayFromRT(radios_rt_fw, true)
	ptrXDatas[2] = LK3D.GetTexturePixelArrayFromRT(radios_rt_le, true)
	ptrXDatas[3] = LK3D.GetTexturePixelArrayFromRT(radios_rt_ri, true)
	ptrXDatas[4] = LK3D.GetTexturePixelArrayFromRT(radios_rt_dw, true)


	LK3D.PushUniverse(universeRadiosityPtrY)
		renderHemicube(pos, norm)
	LK3D.PopUniverse()

	local ptrYDatas = {}
	ptrYDatas[0] = LK3D.GetTexturePixelArrayFromRT(radios_rt_up, true)
	ptrYDatas[1] = LK3D.GetTexturePixelArrayFromRT(radios_rt_fw, true)
	ptrYDatas[2] = LK3D.GetTexturePixelArrayFromRT(radios_rt_le, true)
	ptrYDatas[3] = LK3D.GetTexturePixelArrayFromRT(radios_rt_ri, true)
	ptrYDatas[4] = LK3D.GetTexturePixelArrayFromRT(radios_rt_dw, true)


	local multTbls = {}
	multTbls[0] = multTbl_up
	multTbls[1] = multTbl_fw
	multTbls[2] = multTbl_le
	multTbls[3] = multTbl_ri
	multTbls[4] = multTbl_dw


	-- all buffers obtained
	-- do stuff now
	-- big loop
	local incidentR, incidentG, incidentB = 0, 0, 0
	local bigVal = (LK3D.RADIOSITY_BUFFER_SZ * LK3D.RADIOSITY_BUFFER_SZ) - 1
	local totalRealPixels = bigVal * 3
	for i = 0, (bigVal * 5) - 1 do
		local iMod = (i % bigVal) + 1
		local xcP = (iMod % LK3D.RADIOSITY_BUFFER_SZ)
		local ycP = math.floor(iMod / LK3D.RADIOSITY_BUFFER_SZ) % LK3D.RADIOSITY_BUFFER_SZ



		local idxPtr = math.floor(i / bigVal)
		idxPtr = math.min(idxPtr, 4)

		local objData = objDatas[idxPtr]
		local ptrXData = ptrXDatas[idxPtr]
		local ptrYData = ptrYDatas[idxPtr]
		local multTbl = multTbls[idxPtr]

		local objCont = objData[iMod]

		if (objCont[1] == 0) and (objCont[2] == 0) and (objCont[3] == 0) then
			continue
		end

		local objID = unpackRGB_LP(objCont[1], objCont[2], objCont[3])

		if objID == 0 then
			continue
		end

		local objName = objectIndexTable[objID]
		if not objName then
			if objID ~= 0 then
				print("No objName, ", objID)
			end
			continue
		end

		if not ptrXData then
			continue
		end

		if not ptrYData then
			continue
		end

		local ptrXCont = ptrXData[iMod]
		if not ptrXCont then
			continue
		end
		local xc = unpackRGB_LP(ptrXCont[1], ptrXCont[2], ptrXCont[3])

		local ptrYCont = ptrYData[iMod]
		if not ptrYCont then
			continue
		end
		local yc = unpackRGB_LP(ptrYCont[1], ptrYCont[2], ptrYCont[3])


		local objPatches = objectPatchInfo[objName]
		if not objPatches then
			continue
		end

		-- dynamically add patches if they dont exist
		-- this is totally not a terrible hack
		local patchInfoPre = objPatches[xc]
		if not patchInfoPre then
			initPatchWhileTracing(objName, xc, yc)
			patchInfoPre = objPatches[xc]

			if not patchInfoPre then
				continue
			end
		end

		local patchInfo = patchInfoPre[yc]
		if not patchInfo then
			initPatchWhileTracing(objName, xc, yc)
			patchInfo = patchInfoPre[yc]

			if not patchInfo then
				continue
			end
		end

		local currMultPre = multTbl[xcP]
		if not currMultPre then
			continue
		end
		local currMult = currMultPre[ycP]
		local otherExcident = patchInfo.excident

		if otherExcident[1] == 0 and otherExcident[2] == 0 and otherExcident[3] == 0 then
			continue
		end

		incidentR = incidentR + otherExcident[1] * currMult
		incidentG = incidentG + otherExcident[2] * currMult
		incidentB = incidentB + otherExcident[3] * currMult
	end

	local outR = incidentR / totalRealPixels * LK3D.RADIOSITY_MUL_RENDER
	local outG = incidentG / totalRealPixels * LK3D.RADIOSITY_MUL_RENDER
	local outB = incidentB / totalRealPixels * LK3D.RADIOSITY_MUL_RENDER

	patch.incident = {
		incidentR / totalRealPixels,
		incidentG / totalRealPixels,
		incidentB / totalRealPixels,
	}

	-- clean up
	patchesToUpdate[#patchesToUpdate + 1] = patch
	objDatas[0] = nil
	objDatas[1] = nil
	objDatas[2] = nil
	objDatas[3] = nil
	objDatas[4] = nil
	objDatas = nil

	ptrXDatas[0] = nil
	ptrXDatas[1] = nil
	ptrXDatas[2] = nil
	ptrXDatas[3] = nil
	ptrXDatas[4] = nil
	ptrXDatas = nil

	ptrYDatas[0] = nil
	ptrYDatas[1] = nil
	ptrYDatas[2] = nil
	ptrYDatas[3] = nil
	ptrYDatas[4] = nil
	ptrYDatas = nil


	return math.min(outR, 1), math.min(outG, 1), math.min(outB, 1)
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

-- generates lightmap textures for the x and y offsets
-- we can reuse those everywhere since its general
-- we only need custom objID colours and those dont require textures
local function generateLightmapPtrTextures()
	local res = LK3D.LIGHTMAP_RES

	LK3D.DeclareTextureFromFunc("lk3d_radiosity_ptrPosX_" .. res, res, res, function()
		local ow, oh = ScrW(), ScrH()
		for i = 0, (res * res) do
			local xc = i % res
			local yc = math.floor(i / res)

			local cr, cg, cb = packRGB_LP(xc)
			render.SetViewPort(xc, yc, 1, 1)
			render.Clear(cr, cg, cb, 255)
		end

		render.SetViewPort(0, 0, ow, oh)
	end)

	LK3D.DeclareTextureFromFunc("lk3d_radiosity_ptrPosY_" .. res, res, res, function()
		local ow, oh = ScrW(), ScrH()
		for i = 0, (res * res) do
			local xc = i % res
			local yc = math.floor(i / res)

			local cr, cg, cb = packRGB_LP(yc)
			render.SetViewPort(xc, yc, 1, 1)
			render.Clear(cr, cg, cb, 255)
		end

		render.SetViewPort(0, 0, ow, oh)
	end)
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
		buildTriLUTAndPatches(k, LK3D.LIGHTMAP_RES, LK3D.LIGHTMAP_RES)

		local prevFilter = LK3D.FilterMode
		LK3D.SetFilterMode(LK3D.LightmapFilterMode)
		local idx_orig = getLMTexNames(k)
		LK3D.DeclareTextureFromFunc(idx_orig, LK3D.LIGHTMAP_RES, LK3D.LIGHTMAP_RES, function()
			if obj_ptr.RADIOSITY_LIT then
				render.Clear(255, 255, 255, 255)
			else
				render.Clear(0, 0, 0, 255)
			end
		end)
		LK3D.SetFilterMode(prevFilter)

	end

	generateLightmapPtrTextures()
	cloneUniverses()
end


local function  ratio2(a, b)
	if (a == 0) and (b == 0) then
		return 1
	end
	if (a == 0) or (b == 0) then
		return 0
	end

	if (a > b) then
		return b / a
	else
		return a / b
	end
end

local function ratio4(a, b, c, d)
	local q1 = ratio2(a, b)
	local q2 = ratio2(c, d)

	if (q1 < q2) then
		return q1
	else
		return q2
	end
end


-- renturns mixed patch
local function mixPatches(a, b)
	local aEmmision = a.emmision
	local bEmmision = b.emmision

	local aReflectance = a.reflectance
	local bReflectance = b.reflectance

	local aIncident = a.incident
	local bIncident = b.incident

	return {
		emmision = {
			(aEmmision[1] + bEmmision[1]) * .5,
			(aEmmision[2] + bEmmision[2]) * .5,
			(aEmmision[3] + bEmmision[3]) * .5
		},
		reflectance = {
			(aReflectance[1] + bReflectance[1]) * .5,
			(aReflectance[2] + bReflectance[2]) * .5,
			(aReflectance[3] + bReflectance[3]) * .5
		},
		incident = {
			(aIncident[1] + bIncident[1]) * .5,
			(aIncident[2] + bIncident[2]) * .5,
			(aIncident[3] + bIncident[3]) * .5,
		},
		excident = {0, 0, 0},
	}
end

local function mixPatchesIncidentOnly(a, b)
	local aIncident = a.incident
	local bIncident = b.incident

	return (aIncident[1] + bIncident[1]) * .5, (aIncident[2] + bIncident[2]) * .5, (aIncident[3] + bIncident[3]) * .5
end

local function renderMulFromIncidents(ir, ig, ib)
	return math.min(ir * LK3D.RADIOSITY_MUL_RENDER, 1), math.min(ig * LK3D.RADIOSITY_MUL_RENDER, 1), math.min(ib * LK3D.RADIOSITY_MUL_RENDER, 1)
end

local o_temp_pixelvals = {}
local function lightmapCalcObject(object)
	local idx_orig = getLMTexNames(object)
	local obj_ptr = LK3D.CurrUniv["objects"][object]

	if obj_ptr.RADIOSITY_LIT then
		return
	end

	local patches = objectPatchInfo[object]

	o_temp_pixelvals[object] = o_temp_pixelvals[object] or {}
	LK3D.UpdateTexture(idx_orig, function()
		local ow, oh = ScrW(), ScrH()

		local bad_pixels = {}
		local o_lr, o_lg, o_lb = LK3D.GetLightIntensity(obj_ptr.pos)
		LK3D.PushUniverse(universeRadiosityObjID)
		for i = 0, (LK3D.LIGHTMAP_RES * LK3D.LIGHTMAP_RES) - 1 do
			local xc = i % LK3D.LIGHTMAP_RES
			local yc = math_floor(i / LK3D.LIGHTMAP_RES)

			local pos_c, norm_c = texturi_to_world(object, xc, yc, LK3D.LIGHTMAP_RES, LK3D.LIGHTMAP_RES)
			local isValidPatch = (pos_c ~= nil) and (patches[xc] ~= nil) and (patches[xc][yc] ~= nil)
			local lr, lg, lb
			if isValidPatch then
				lr, lg, lb = updatePatch(pos_c, norm_c, patches[xc][yc])
			else
				bad_pixels[i] = true
				lr, lg, lb = o_lr, o_lg, o_lb
			end

			render.SetViewPort(xc, yc, 1, 1)
			render.Clear(lr * 255, lg * 255, lb * 255, 255)

			if (i % 24) == 0 then
				local the_rt = render.GetRenderTarget()
				LK3D.RenderProcessingMessage("Radiosity calculate light\n[" .. object .. "]", (i / ((LK3D.LIGHTMAP_RES * LK3D.LIGHTMAP_RES) - 1)) * 100, function()
					render.DrawTextureToScreenRect(the_rt, 0, 288, 512, 512)
					renderHemicubeRTsTest(ScrW() * .5, ScrH() * .5)
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
	-- calc lightmapping
	for k, v in pairs(objects_to_lightmap) do
		local obj_ptr = LK3D.CurrUniv["objects"][k]
		if not obj_ptr then
			return
		end

		LK3D.New_D_Print("Calculating lightmaps for object \"" .. k .. "\"", LK3D_SEVERITY_DEBUG, "Radiosity")
		lightmapCalcObject(k)
	end

	updatePatches() -- update patches
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
		LK3D.New_D_Print("Lightmap commit..", LK3D_SEVERITY_INFO, "Radiosity")
		LK3D.New_D_Print(LK3D.RADIOSITY_STEPS .. " steps..", LK3D_SEVERITY_INFO, "Radiosity")

		lightmapInit()

		local last_dbg = LK3D.Debug
		LK3D.Debug = false
		for i = 1, LK3D.RADIOSITY_STEPS do
			LK3D.New_D_Print("Lightmap step " .. i .. "/" .. LK3D.RADIOSITY_STEPS, LK3D_SEVERITY_INFO, "Radiosity")
			lightmapStep()
		end
		LK3D.Debug = last_dbg

		lightmapFinalize()
		if not LK3D.LIGHTMAP_AUTO_EXPORT then
			LK3D.New_D_Print("Lightmap done! Please export with \"lk3d_exportlightmaps " .. LK3D.CurrUniv["tag"] .. "\"", LK3D_SEVERITY_INFO, "Radiosity")
		else
			LK3D.New_D_Print("Lightmap done! Automatically exporting...", LK3D_SEVERITY_INFO, "Radiosity")
			LK3D.ExportLightmaps()
		end
	end
end

file.CreateDir("lk3d/lightmap_temp")
file.CreateDir("lk3d/lightmap_temp/" .. engine.ActiveGamemode())
local targ_temp = "lk3d/lightmap_temp/" .. engine.ActiveGamemode() .. "/"
local lastAccumChange = CurTime()
local lightmapAccum = 0
local matDontDeleteArchive = {}


local function loadLightmapObject(data, tag, obj_idx)
	if CurTime() > lastAccumChange then
		lightmapAccum = 0
	end
	lastAccumChange = CurTime() + 2
	lightmapAccum = lightmapAccum + 1
	if not data then
		LK3D.New_D_Print("Attempting to load lightmap with no data!", LK3D_SEVERITY_ERROR, "Radiosity")
		return
	end

	file.Write(targ_temp .. "temp1.txt", util.Decompress(data))


	local f_pointer_temp = file.Open(targ_temp .. "temp1.txt", "rb", "DATA")
	local header = f_pointer_temp:Read(4)
	if header ~= "LKLM" then
		LK3D.New_D_Print("Failure decoding LKLM file! (start header no match)", LK3D_SEVERITY_ERROR, "Radiosity")
		f_pointer_temp:Close()
		return
	end

	local tw = f_pointer_temp:ReadULong() * LK3D.LightmapUpscale
	local th = f_pointer_temp:ReadULong() * LK3D.LightmapUpscale


	local prevFilter = LK3D.FilterMode
	LK3D.SetFilterMode(LK3D.LightmapFilterMode)
	local lm_tex_idx = "lightmap_" .. tag .. "_" .. obj_idx .. "_" .. tw .. "_" .. th
	LK3D.DeclareTextureFromFunc(lm_tex_idx, tw, th, function()
		render.Clear(4, 32, 8, 255)
		draw.SimpleText("Lightmap Load, Stage1", "BudgetLabel", 0, 0, Color(16, 255, 32))
	end)
	LK3D.SetFilterMode(prevFilter)

	local thing_path = targ_temp .. tag .. "_" .. obj_idx .. "_" .. tw .. "_" .. th .. ".png"
	local png_data_writer = file.Open(thing_path, "wb", "DATA")

	local chunkCount = f_pointer_temp:ReadULong()
	for i = 1, chunkCount do
		local lengthRead = f_pointer_temp:ReadULong()
		png_data_writer:Write(f_pointer_temp:Read(lengthRead))
	end
	png_data_writer:Close()

	local read_post_verif = f_pointer_temp:Read(3)
	if read_post_verif ~= "DNE" then
		LK3D.New_D_Print("Failure decoding LKLM file! (colour DNE fail)", LK3D_SEVERITY_ERROR, "Radiosity")
		f_pointer_temp:Close()
		return
	end

	if not matDontDeleteArchive[tag] then
		matDontDeleteArchive[tag] = {}
	end

	--matDontDeleteArchive[tag][obj_idx] = Material("../data/" .. thing_path, "ignorez nocull") -- actually load it
	timer.Simple(2, function() -- wait abit before loading
		local _lmMat = Material("../data/" .. thing_path, "ignorez nocull")

		local prevFilter = LK3D.FilterMode
		LK3D.SetFilterMode(LK3D.LightmapFilterMode)
		LK3D.DeclareTextureFromFunc(lm_tex_idx, tw, th, function()
			render.Clear(4, 8, 32, 255)
			draw.SimpleText("Lightmap Load, Stage2", "BudgetLabel", 0, 0, Color(16, 32, 255))

			surface.SetMaterial(_lmMat)
			surface.SetDrawColor(255, 255, 255, 255)
			surface.DrawTexturedRect(0, 0, tw, th)
		end)
		LK3D.SetFilterMode(prevFilter)
		--file.Delete(thing_path, "DATA") -- this breaks lightmapping
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
		LK3D.New_D_Print("Failure decoding LKLM file! (lm_uv DNE fail)", LK3D_SEVERITY_ERROR, "Radiosity")
		f_pointer_temp:Close()
		return
	end

	local obj_ptr = LK3D.CurrUniv["objects"][obj_idx]
	local mdlinfo = LK3D.Models[obj_ptr.mdl]
	if not mdlinfo then
		LK3D.New_D_Print("Model \"" .. obj_ptr.mdl .. "\" doesnt exist!", LK3D_SEVERITY_ERROR, "Radiosity")
		return
	end

	local indices = mdlinfo.indices

	local index_count = f_pointer_temp:ReadULong()
	for i = 1, index_count do
		indices[i][1][3] = f_pointer_temp:ReadULong()
		indices[i][2][3] = f_pointer_temp:ReadULong()
		indices[i][3][3] = f_pointer_temp:ReadULong()
	end

	read_post_verif = f_pointer_temp:Read(3)
	if read_post_verif ~= "DNE" then
		LK3D.New_D_Print("Failure decoding LKLM file! (index_lm DNE fail)", LK3D_SEVERITY_ERROR, "Radiosity")
		f_pointer_temp:Close()
		return
	end

	local read_header_end = f_pointer_temp:Read(4)
	f_pointer_temp:Close()
	if read_header_end ~= "LKLM" then
		LK3D.New_D_Print("Failure decoding LKLM file! (end header fail)", LK3D_SEVERITY_ERROR, "Radiosity")
		return
	end



	LK3D.CurrUniv["objects"][obj_idx].limap_tex = lm_tex_idx
	LK3D.CurrUniv["objects"][obj_idx].lightmap_uvs = lm_uvs
	--lightmap_uvs
end

LK3D_LIGHTMAP_HAVE_WE_CLEARED_GLOBAL = LK3D_LIGHTMAP_HAVE_WE_CLEARED_GLOBAL or false
local function recursiveClearCache(base)
	local files, dirs = file.Find(base .. "/*.png", "LUA")

	for k, v in ipairs(files) do
		-- now delete
		local fPath = base .. "/" .. v
		file.Delete(fPath)
		LK3D.New_D_Print("Deleted PNG cache file \"" .. fPath .. "\"", LK3D_SEVERITY_DEBUG, "Radiosity")
	end

	for k, v in ipairs(dirs) do
		-- empty child folders
		recursiveClearCache(base .. "/" .. v)
	end
end

function LK3D.ClearLightmapCache()
	if LK3D_LIGHTMAP_HAVE_WE_CLEARED_GLOBAL then
		return
	end
	LK3D_LIGHTMAP_HAVE_WE_CLEARED_GLOBAL = true

	LK3D.New_D_Print("Clearing lightmap PNG cache!", LK3D_SEVERITY_DEBUG, "Radiosity")
	local root = "lk3d/lightmap_temp/"
	recursiveClearCache(root)

	LK3D.New_D_Print("Cleared lightmap PNG cache successfully!", LK3D_SEVERITY_DEBUG, "Radiosity")
end

function LK3D.LoadLightmapFromFile(obj_idx)
	LK3D.ClearLightmapCache() -- attempt to clear cache first

	local tag = LK3D.CurrUniv["tag"]
	if not tag then
		LK3D.New_D_Print("Attempting to load lightmap on universe with no tag!", LK3D_SEVERITY_ERROR, "Radiosity")
		return
	end

	local obj_check = LK3D.CurrUniv["objects"][obj_idx]
	if not obj_check then
		LK3D.New_D_Print("Attempting to load lightmap for non-existing object \"" .. obj_idx .. "\"!", LK3D_SEVERITY_ERROR, "Radiosity")
		return
	end


	local fcontents = LK3D.ReadFileFromLKPack("lightmaps/" .. tag .. "/" .. obj_idx .. ".llm")
	if not fcontents then
		LK3D.New_D_Print("Attempting to load missing lightmap from LKPack! (" .. tag .. "): [" .. obj_idx .. "]", LK3D_SEVERITY_ERROR, "Radiosity")
		return
	end

	loadLightmapObject(fcontents, tag, obj_idx)
	LK3D.New_D_Print("Loaded lightmap for \"" .. obj_idx .. "\" from LKPack successfully!", LK3D_SEVERITY_INFO, "Radiosity")
end




-- a more simplistic file format, less compressed than others
local function exportLightmapObject(obj, obj_id) -- this exports it as custom file lightmap
	LK3D.New_D_Print("Exporting lightmap for object \"" .. obj_id .. "\"", LK3D_SEVERITY_DEBUG, "Radiosity")

	local tag = LK3D.CurrUniv["tag"]
	local targ_folder = "lk3d/lightmap_export/" .. engine.ActiveGamemode() .. "/" .. tag .. "/"

	file.Write(targ_folder .. obj_id .. "_temp.txt", "temp")
	local f_pointer_temp = file.Open(targ_folder .. obj_id .. "_temp.txt", "wb", "DATA")

	local lm_t = obj.limap_tex

	local tex_p = LK3D.Textures[lm_t]
	local tw, th = tex_p.rt:Width(), tex_p.rt:Height()
	LK3D.New_D_Print("Lightmap resolution is " .. tw .. "x" .. th, LK3D_SEVERITY_DEBUG, "Radiosity")

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

	local chunkSz = 16384
	local chunkCount = math.ceil(length_png_data / chunkSz)
	chunkCount = math.max(chunkCount, 1)
	LK3D.New_D_Print("File will have " .. chunkCount .. " PNGChunks...", LK3D_SEVERITY_DEBUG, "Radiosity")

	-- split into chunks
	f_pointer_temp:WriteULong(chunkCount)
	local lengthAccum = length_png_data
	for i = 1, chunkCount do
		local lengthCurr = math.min(lengthAccum, chunkSz)
		lengthAccum = lengthAccum - chunkSz
		LK3D.New_D_Print("Chunk º" .. i .. "; Length " .. lengthCurr, LK3D_SEVERITY_DEBUG, "Radiosity")


		f_pointer_temp:WriteULong(lengthCurr)
		f_pointer_temp:Write(f_pointer_pngDat:Read(lengthCurr))
	end
	f_pointer_pngDat:Close()
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
		LK3D.New_D_Print("Attempting to export lightmaps for a universe without a tag!", LK3D_SEVERITY_ERROR, "Radiosity")
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

	LK3D.New_D_Print("Exported lightmaps for universe \"" .. tag .. "\"!", LK3D_SEVERITY_INFO, "Radiosity")
	LK3D.New_D_Print("Lightmaps are located at \"data/" .. targ_folder .. "\"", LK3D_SEVERITY_INFO, "Radiosity")
end

concommand.Add("lk3d_exportlightmaps", function(ply, cmd, args)
	if not args[1] then
		LK3D.New_D_Print("Usage: lk3d_exportlightmaps <universeName>", LK3D_SEVERITY_WARN, "Radiosity")
		return
	end

	local univ = LK3D.UniverseRegistry[args[1]]
	if univ == nil then
		LK3D.New_D_Print("Target Universe \"" .. args[1] .. "\" doesnt exist!", LK3D_SEVERITY_WARN, "Radiosity")
		return
	end

	LK3D.PushUniverse(univ)
		LK3D.ExportLightmaps()
	LK3D.PopUniverse()
end)