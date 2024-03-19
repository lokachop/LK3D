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
		has_tri = false,
	}
end

local function get_tri_table_bounding_box(triangles)
	local minU, minV = 1, 1
	local maxU, maxV = 0, 0


	for i = 1, #triangles do
		local tri = triangles[i]


		local bound_min_u = math_min(tri[1][1], uvtri[2][1], tri[3][1])
		local bound_min_v = math_min(tri[1][2], uvtri[2][2], tri[3][2])

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


	for i = 1, #triangles do
		local tri = triangles[i]
		new[i] = {
			{{ox + (tri[1][1] - minU), oy + (tri[1][2] - minV)}, tri[1][3]},
			{{ox + (tri[2][1] - minU), oy + (tri[2][2] - minV)}, tri[2][3]},
			{{ox + (tri[3][1] - minU), oy + (tri[3][2] - minV)}, tri[3][3]},
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
		if leaf.has_tri then
			return
		end

		local bound_w, bound_h, bound_min_w, bound_min_h = get_tri_table_bounding_box(tris)

		if leaf.sx < bound_w or leaf.sy < bound_h then
			return
		end

		if leaf.sx == bound_w and leaf.sy == bound_h then
			leaf.has_tri = true
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




function LK3D.Radiosa.PackUVs(uvs_to_pack)
	local w, h = LK3D.Radiosa.LIGHTMAP_RES, LK3D.Radiosa.LIGHTMAP_RES

	local tree = newleaf(w, h)
	tree.children[1] = newleaf(w, h)
	tree.children[2] = newleaf(0, 0)


	local packed_uvs = {}
	local fail = false

	for i = 1, #uvs_to_pack do
		local tri_tbl = uvs_to_pack[i]
		local ret = insert_into_leaf(tree, tri_tbl)

		if not ret then
			fail = true
			break
		end

		-- add each individual triangle
		for j = 1, #ret do
			local tri = ret[j]

			local uv1_ind = #packed_uvs + 1
			packed_uvs[uv1_ind] = {tri[1][1][1] / w, tri[1][1][2] / h}

			local uv2_ind = #packed_uvs + 1
			packed_uvs[uv2_ind] = {tri[2][1][1] / w, tri[2][1][2] / h}

			local uv3_ind = #packed_uvs + 1
			packed_uvs[uv3_ind] = {tri[3][1][1] / w, tri[3][1][2] / h}

			tri[1][2][3] = uv1_ind
			tri[2][2][3] = uv2_ind
			tri[3][2][3] = uv3_ind
		end
	end


	return packed_uvs, fail
end