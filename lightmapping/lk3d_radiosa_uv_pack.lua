LK3D = LK3D or {}
LK3D.Radiosa = LK3D.Radiosa or {}

local math = math
local math_min = math.min
local math_max = math.max
local math_floor = math.floor



-- leaf packer thing, https://blackpawn.com/texts/lightmaps/default.html
local function newleaf(sx, sy, ox, oy)
	return {
		children = {},
		ox = ox or 0,
		oy = oy or 0,
		sx = sx,
		sy = sy,
		has_content = false,
	}
end

local function get_tri_table_bounding_box(triangles)
	local minU, minV = 1, 1
	local maxU, maxV = 0, 0


	for i = 1, #triangles do
		local tri = triangles[i]


		local bound_min_u = math_min(tri[1][1], tri[2][1], tri[3][1])
		local bound_min_v = math_min(tri[1][2], tri[2][2], tri[3][2])

		local bound_max_u = math_max(tri[1][1], tri[2][1], tri[3][1])
		local bound_max_v = math_max(tri[1][2], tri[2][2], tri[3][2])

		minU = bound_min_u < minU and bound_min_u or minU
		minV = bound_min_v < minV and bound_min_v or minV


		maxU = bound_max_u > maxU and bound_max_u or maxU
		maxV = bound_max_v > maxV and bound_max_v or maxV
	end


	local w = math_floor(maxU - minU) + LK3D.Radiosa.LIGHTMAP_TRI_PAD
	local h = math_floor(maxV - minV) + LK3D.Radiosa.LIGHTMAP_TRI_PAD
	return w, h, minU, minV
end


local function offset_tri_table(tris, ox, oy, minU, minV)
	local new = {}


	for i = 1, #tris do
		local tri = tris[i]
		--print("---PackMe---")
		--PrintTable(tri)

		new[i] = {
			{{ox + (tri[1][1] - minU), oy + (tri[1][2] - minV)}, tri[1][3]},
			{{ox + (tri[2][1] - minU), oy + (tri[2][2] - minV)}, tri[2][3]},
			{{ox + (tri[3][1] - minU), oy + (tri[3][2] - minV)}, tri[3][3]},
			tri[4]
		}
	end

	return new
end


local function insert_into_leaf(leaf, tris)
	if (#leaf.children > 0) then
		local new_uv = insert_into_leaf(leaf.children[1], tris)
		if new_uv ~= nil then
			return new_uv
		end

		-- no room, insert second
		return insert_into_leaf(leaf.children[2], tris)
	else
		if leaf.has_content then
			return
		end

		local bound_w, bound_h, bound_min_w, bound_min_h = get_tri_table_bounding_box(tris)

		if leaf.sx < bound_w or leaf.sy < bound_h then
			return
		end

		if leaf.sx == bound_w and leaf.sy == bound_h then
			leaf.has_content = true
			return offset_tri_table(tris, leaf.ox, leaf.oy, bound_min_w, bound_min_h)
		end


		-- we have to split
		local dw = leaf.sx - bound_w
		local dh = leaf.sy - bound_h


		if dw > dh then -- if (the leafsize - bound_w) > (the leafsize - bound_h)
			leaf.children[1] = newleaf( -- left, stores og lightmap
				bound_w,
				leaf.sy,
				leaf.ox,
				leaf.oy
			)
			leaf.children[2] = newleaf( -- right
				dw,
				leaf.sy,
				leaf.ox + bound_w,
				leaf.oy
			)
		else
			leaf.children[1] = newleaf( -- up, stores lightmap
				leaf.sx,
				bound_h,
				leaf.ox,
				leaf.oy
			)
			leaf.children[2] = newleaf( -- down
				leaf.sx,
				dh,
				leaf.ox,
				leaf.oy + bound_h
			)
		end


		return insert_into_leaf(leaf.children[1], tris)
	end
end



local function getTriCenter(uv1, uv2, uv3)
	local uSum = uv1[1] + uv2[1] + uv3[1]
	local vSum = uv1[2] + uv2[2] + uv3[2]

	return {uSum / 3, vSum / 3}
end

local function getDirectionFromUV(uv, center)
	local uCalc = uv[1] - center[1]
	local vCalc = uv[2] - center[2]

	local len = math.sqrt(uCalc * uCalc + vCalc * vCalc)

	return {uCalc / len, vCalc / len}
end

local INSET_AMOUNT = (2048 / LK3D.Radiosa.LIGHTMAP_RES) * 0.005
local function getInsetUV(uv, center)
	local uDirCalc = uv[1] - center[1]
	local vDirCalc = uv[2] - center[2]

	local len = math.sqrt(uDirCalc * uDirCalc + vDirCalc * vDirCalc)
	uDirCalc = uDirCalc / len
	vDirCalc = vDirCalc / len

	uDirCalc = uDirCalc * INSET_AMOUNT
	vDirCalc = vDirCalc * INSET_AMOUNT

	return {uv[1] + uDirCalc, uv[2] + vDirCalc}
end


function LK3D.Radiosa.PackUVs(uvs_to_pack)
	local w, h = LK3D.Radiosa.LIGHTMAP_RES, LK3D.Radiosa.LIGHTMAP_RES

	local tree = newleaf(w, h)
	tree.children[1] = newleaf(w, h)
	tree.children[2] = newleaf(0, 0)


	local packed_uvs = {}
	local lightmap_uvs = {}
	local is_quad_DEBUG = {}
	local index_list = {}
	local fail = false

	--[[
	print("UVS to pack ; ", #uvs_to_pack)
	local trisToPack = 0
	for i = 1, #uvs_to_pack do
		local tri_tbl = uvs_to_pack[i]
		for j = 1, #tri_tbl do
			trisToPack = trisToPack + 1
		end
	end
	print("TRIS to pack; ", trisToPack)
	print("* 3         ; ", trisToPack * 3)
	]]--


	for i = 1, #uvs_to_pack do
		local tri_tbl = uvs_to_pack[i]
		local ret_tri_tbl = insert_into_leaf(tree, tri_tbl)

		if not ret_tri_tbl then
			fail = true
			break
		end

		-- add each individual triangle
		for j = 1, #ret_tri_tbl do
			local tri = ret_tri_tbl[j]

			if j == 2 then
				is_quad_DEBUG[#is_quad_DEBUG + 1] = true
			else
				is_quad_DEBUG[#is_quad_DEBUG + 1] = false
			end



			local uv1 = {tri[1][1][1] / w, tri[1][1][2] / h}
			local uv2 = {tri[2][1][1] / w, tri[2][1][2] / h}
			local uv3 = {tri[3][1][1] / w, tri[3][1][2] / h}

			-- Push the normals .5 into the center, avoids the bad exposed edges
			-- Bad, didn't fix anything
			--local uvCenter = getTriCenter(uv1, uv2, uv3)

			--local f_uv1 = getInsetUV(uv1, uvCenter)
			--local f_uv2 = getInsetUV(uv2, uvCenter)
			--local f_uv3 = getInsetUV(uv3, uvCenter)

			local uv1_ind = #packed_uvs + 1
			packed_uvs[uv1_ind] = uv1

			local uv2_ind = #packed_uvs + 1
			packed_uvs[uv2_ind] = uv2

			local uv3_ind = #packed_uvs + 1
			packed_uvs[uv3_ind] = uv3

			lightmap_uvs[#lightmap_uvs + 1] = {
				uv1_ind,
				uv2_ind,
				uv3_ind,
			}

			index_list[#lightmap_uvs] = tri[4]
		end
	end

	if fail then
		return
	end

	return packed_uvs, lightmap_uvs, is_quad_DEBUG, index_list
end


function LK3D.Radiosa.PushLightmapUVsToObject(object, packed_uvs, lightmap_uvs, index_list)
	local obj_ptr = LK3D.CurrUniv["objects"][object]
	if not obj_ptr then
		print("non object ", object)
		return
	end

	obj_ptr.lightmap_uvs = packed_uvs
	obj_ptr.limap_tex = "lightmap_test" .. LK3D.Radiosa.LIGHTMAP_RES

	local mdl = obj_ptr.mdl
	local mdlpointer = LK3D.Models[mdl]

	local indices = mdlpointer.indices

	

	for i = 1, #indices do
		local indexFixed = index_list[i]


		local index = indices[indexFixed]
		local indexLightmap = lightmap_uvs[i]


		index[1][3] = indexLightmap[1]
		index[2][3] = indexLightmap[2]
		index[3][3] = indexLightmap[3]

	end
end