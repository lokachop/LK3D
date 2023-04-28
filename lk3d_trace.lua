LK3D = LK3D or {}
-----------------------------
-- Trace system, SLOW!
-----------------------------
-- TODO: Convex hull algorithm (https://github.com/haroldserrano/ConvexHullAlgorithm/blob/Development/ComputingConvexHull/ComputingConvexHull/ConvexHullAlgorithm.cpp)
-- mesh -> cHull with no blender



local math = math
local math_abs = math.abs
local math_min = math.min
local math_max = math.max
local math_floor = math.floor
local DBL_EPSILON = 2.2204460492503131e-16



-- from https://github.com/excessive/cpml/blob/master/modules/intersect.lua
local function ray_triangle(dir, pos, tri, backface_cull, obj, uvs)
	local tri1 = obj.tmatrix * tri[1]  -- copy the vector so we can do stuff FAST
	local tri2 = obj.tmatrix * tri[2]
	local tri3 = obj.tmatrix * tri[3]

	-- opti; dont make new objects
	tri2:Sub(tri1)
	tri3:Sub(tri1)
	local h = dir:Cross(tri3)
	local a = h:Dot(tri2)

	-- if a is negative, ray hits the backface
	if backface_cull and a < 0 then
		return false
	end

	-- if a is too close to 0, ray does not intersect triangle
	if math_abs(a) <= DBL_EPSILON then
		return false
	end

	local f = 1 / a
	--local s = pos - tri1
	tri1:Sub(pos) -- make tri1 into S
	tri1:Negate()
	--local u = s:Dot(h) * f
	local u = tri1:Dot(h) * f

	-- ray does not intersect triangle
	if u < 0 or u > 1 then
		return false
	end

	--local q = s:Cross(tri2)
	local q = tri1:Cross(tri2)
	local v = dir:Dot(q) * f

	-- ray does not intersect triangle
	if v < 0 or u + v > 1 then
		return false
	end

	-- at this stage we can compute t to find out where
	-- the intersection point is on the line
	local t = q:Dot(tri3) * f

	-- return position of intersection and distance from ray origin
	if t >= DBL_EPSILON then
		if LK3D.DoExpensiveTrace then
			local u1 = uvs[1][1]
			local v1 = uvs[1][2]

			local u2 = uvs[2][1]
			local v2 = uvs[2][2]

			local u3 = uvs[3][1]
			local v3 = uvs[3][2]

			local w = (1 - u - v)

			local uc = (w * u1) + (u * u2) + (v * u3)
			local vc = (w * v1) + (u * v2) + (v * v3)

			return pos + dir * t, t, {uc, vc}
		else
			return pos + dir * t, t
		end
	end

	-- ray does not intersect triangle
	return false
end

-- https://github.com/excessive/cpml/blob/master/modules/intersect.lua
local function ray_aabb(pos, dir, aabb)
	dir:Normalize()
	local dirfrac = Vector(
		1 / dir[1],
		1 / dir[2],
		1 / dir[3]
	)

	local t1 = (aabb[1][1] - pos[1]) * dirfrac[1]
	local t2 = (aabb[2][1] - pos[1]) * dirfrac[1]
	local t3 = (aabb[1][2] - pos[2]) * dirfrac[2]
	local t4 = (aabb[2][2] - pos[2]) * dirfrac[2]
	local t5 = (aabb[1][3] - pos[3]) * dirfrac[3]
	local t6 = (aabb[2][3] - pos[3]) * dirfrac[3]

	local tmin = math_max(math_max(math_min(t1, t2), math_min(t3, t4)), math_min(t5, t6))
	local tmax = math_min(math_min(math_max(t1, t2), math_max(t3, t4)), math_max(t5, t6))

	-- ray is intersecting AABB, but whole AABB is behind us
	if tmax < 0 then
		return false
	end

	-- ray does not intersect AABB
	if tmin > tmax then
		return false
	end

	-- Return collision point and distance from ray origin
	return pos + dir * tmin, tmin
end

LK3D.New_D_Print("Generating triangle list!", 2, "TraceSystem")
-- make triangle list for each model
LK3D.TraceTriangleList = {}
LK3D.TraceTriangleUVs = {}
LK3D.TraceTriangleAABBs = {}

function LK3D.GenTrList(k)
	LK3D.TraceTriangleList[k] = {}
	LK3D.TraceTriangleUVs[k] = {}

	local tblindex = LK3D.TraceTriangleList[k]
	local uvIdx = LK3D.TraceTriangleUVs[k]

	local mdlinfo = LK3D.Models[k]
	if not mdlinfo then
		LK3D.New_D_Print("Model \"" .. k .. "\" doesnt exist, PANIC!", 5, "TraceSystem")
		return
	end

	local verts = mdlinfo.verts
	local uvs = mdlinfo.uvs
	local ind = mdlinfo.indices

	for i = 1, #ind do
		local index = ind[i]
		v1 = Vector(verts[index[1][1]])
		v2 = Vector(verts[index[2][1]])
		v3 = Vector(verts[index[3][1]])

		local norm = (v2 - v1):Cross(v3 - v1)
		norm:Normalize()


		local uv1 = uvs[index[1][2]]
		local uv2 = uvs[index[2][2]]
		local uv3 = uvs[index[3][2]]

		uvIdx[#uvIdx + 1] = {uv1, uv2, uv3}
		tblindex[#tblindex + 1] = {v1, v2, v3, norm}
	end
	LK3D.New_D_Print("Generated tris for \"" .. k .. "\"!", 1, "TraceSystem")
end

for k, v in pairs(LK3D.Models) do
	LK3D.GenTrList(k)
end

function LK3D.GenAABB(k)
	local nfo = LK3D.Models[k]
	if not nfo then
		print("no nfo for " .. k)
		return
	end
	LK3D.TraceTriangleAABBs[k] = {Vector(0, 0, 0), Vector(0, 0, 0)}
	local tbl_idx = LK3D.TraceTriangleAABBs[k]

	local verts = nfo.verts
	for i = 1, #verts do
		local ve = verts[i]
		-- x
		tbl_idx[1].x = (ve.x < tbl_idx[1].x) and ve.x or tbl_idx[1].x -- mins
		tbl_idx[2].x = (ve.x > tbl_idx[2].x) and ve.x or tbl_idx[2].x -- maxs
		-- y
		tbl_idx[1].y = (ve.y < tbl_idx[1].y) and ve.y or tbl_idx[1].y -- mins
		tbl_idx[2].y = (ve.y > tbl_idx[2].y) and ve.y or tbl_idx[2].y -- maxs
		-- z
		tbl_idx[1].z = (ve.z < tbl_idx[1].z) and ve.z or tbl_idx[1].z -- mins
		tbl_idx[2].z = (ve.z > tbl_idx[2].z) and ve.z or tbl_idx[2].z -- maxs
	end
	LK3D.New_D_Print("Generated AABBs for \"" .. k .. "\"!", 1, "TraceSystem")
end


for k, v in pairs(LK3D.Models) do
	LK3D.GenAABB(k)
end

-- https://stackoverflow.com/questions/6053522/how-to-recalculate-axis-aligned-bounding-box-after-translate-rotate/
function LK3D.GetRecalcAABB(obj)
	if not LK3D.TraceTriangleAABBs[obj.mdl] then
		LK3D.GenTrList(obj.mdl)
		LK3D.GenAABB(obj.mdl)
	end
	local aabb_org = LK3D.TraceTriangleAABBs[obj.mdl]
	local mins = aabb_org[1] * obj.scl -- this copies the vec
	local maxs = aabb_org[2] * obj.scl
	local mat_ang = Matrix()
	mat_ang:SetAngles(obj.ang)

	local n_aab = {Vector(0, 0, 0), Vector(0, 0, 0)}
	--[[
	for r = 0, (3 * 3) - 1 do
		local i, j = (r % 3) + 1, (math_floor(r / 3)) + 1
		--a = M[i][j] * A.min[j]
		local a = mat_ang:GetField(i, j) * mins[j] -- ????
		--b = M[i][j] * A.max[j]
		local b = mat_ang:GetField(i, j) * maxs[j]

		--B.min[i] += a < b ? a : b
		n_aab[1][i] = n_aab[1][i] + ((a < b) and a or b)
		--B.max[i] += a < b ? b : a
		n_aab[2][i] = n_aab[2][i] + ((a < b) and b or a)
	end
	]]--


	-- 9 times unrolled loop
	-- 1
	--local i, j = 1, 1
	local a = mat_ang:GetField(1, 1) * mins[1] -- ????
	local b = mat_ang:GetField(1, 1) * maxs[1]
	n_aab[1][1] = n_aab[1][1] + ((a < b) and a or b)
	n_aab[2][1] = n_aab[2][1] + ((a < b) and b or a)

	-- 2
	--i, j = 2, 1
	a = mat_ang:GetField(2, 1) * mins[1] -- ????
	b = mat_ang:GetField(2, 1) * maxs[1]
	n_aab[1][2] = n_aab[1][2] + ((a < b) and a or b)
	n_aab[2][2] = n_aab[2][2] + ((a < b) and b or a)

	-- 3
	--i, j = 3, 1
	a = mat_ang:GetField(3, 1) * mins[1] -- ????
	b = mat_ang:GetField(3, 1) * maxs[1]
	n_aab[1][3] = n_aab[1][3] + ((a < b) and a or b)
	n_aab[2][3] = n_aab[2][3] + ((a < b) and b or a)

	-- 4
	--i, j = 1, 2
	a = mat_ang:GetField(1, 2) * mins[2] -- ????
	b = mat_ang:GetField(1, 2) * maxs[2]
	n_aab[1][1] = n_aab[1][1] + ((a < b) and a or b)
	n_aab[2][1] = n_aab[2][1] + ((a < b) and b or a)

	-- 5
	--i, j = 2, 2
	a = mat_ang:GetField(2, 2) * mins[2] -- ????
	b = mat_ang:GetField(2, 2) * maxs[2]
	n_aab[1][2] = n_aab[1][2] + ((a < b) and a or b)
	n_aab[2][2] = n_aab[2][2] + ((a < b) and b or a)

	-- 6
	--i, j = 3, 2
	a = mat_ang:GetField(3, 2) * mins[2] -- ????
	b = mat_ang:GetField(3, 2) * maxs[2]
	n_aab[1][3] = n_aab[1][3] + ((a < b) and a or b)
	n_aab[2][3] = n_aab[2][3] + ((a < b) and b or a)

	-- 7
	--i, j = 1, 3
	a = mat_ang:GetField(1, 3) * mins[3] -- ????
	b = mat_ang:GetField(1, 3) * maxs[3]
	n_aab[1][1] = n_aab[1][1] + ((a < b) and a or b)
	n_aab[2][1] = n_aab[2][1] + ((a < b) and b or a)

	-- 8
	--i, j = 2, 3
	a = mat_ang:GetField(2, 3) * mins[3] -- ????
	b = mat_ang:GetField(2, 3) * maxs[3]
	n_aab[1][2] = n_aab[1][2] + ((a < b) and a or b)
	n_aab[2][2] = n_aab[2][2] + ((a < b) and b or a)

	-- 9
	--i, j = 3, 3
	a = mat_ang:GetField(3, 3) * mins[3] -- ????
	b = mat_ang:GetField(3, 3) * maxs[3]
	n_aab[1][3] = n_aab[1][3] + ((a < b) and a or b)
	n_aab[2][3] = n_aab[2][3] + ((a < b) and b or a)

	-- unrolled loops are awful but they are FAST

	n_aab[1]:Add(obj.pos)
	n_aab[2]:Add(obj.pos)

	return n_aab
end

local function traceRayObj(pos, dir, obj, bfcull)
	local triList = LK3D.TraceTriangleList[obj.mdl]
	local uref = LK3D.TraceTriangleUVs[obj.mdl]
	if not triList then
		LK3D.New_D_Print("Triangle list doesnt exist for \"" .. obj.mdl .. "\"!", 4, "TraceSystem")
		return
	end

	local lo_pos, lo_norm, lo_dist, lo_uv, lo_tri = pos + (dir * 1000000), dir, math.huge, {0, 0}, 1
	for i = 1, #triList do
		local ref = triList[i]

		local posget, dist, uv
		if LK3D.DoExpensiveTrace then
			posget, dist, uv = ray_triangle(dir, pos, ref, not bfcull, obj, uref[i])
		else
			posget, dist = ray_triangle(dir, pos, ref, not bfcull, obj)
		end

		if posget and (dist < lo_dist) then
			local norm = Vector(ref[4])
			norm:Rotate(obj.ang)
			lo_norm = norm
			lo_pos = posget
			lo_dist = dist
			lo_uv = uv
			lo_tri = i
		end
	end

	return lo_pos, lo_norm, lo_dist, lo_uv, lo_tri
end

function LK3D.TraceRayModel(pos, dir, name, bfcull)
	local obj = LK3D.CurrUniv["objects"][name]
	if not obj then
		LK3D.New_D_Print(name .. " does not exist!", 4, "TraceSystem")
		return
	end

	return traceRayObj(pos, dir, obj, bfcull)
end


LK3D.SUPER_OPTI_TR = false -- this breaks a lot of stuff USE AT OWN RISK
function LK3D.TraceRayScene(pos, dir, bfcull, dist)
	local possib_objs = {}
	local lo_tr = dist or math.huge
	local tr_obj = nil
	local tr_min = nil
	for k, v in pairs(LK3D.CurrUniv["objects"]) do
		if not LK3D.TraceOverrideNoTrace and v["NO_TRACE"] then
			continue
		end

		if not v["NO_VW_CULLING"] and ((v.pos - pos):Dot(dir) < 0) then
			continue
		end

		local _, dist_get = ray_aabb(pos, dir, LK3D.GetRecalcAABB(v))

		if not LK3D.SUPER_OPTI_TR then
			if dist_get ~= nil then
				possib_objs[#possib_objs + 1] = v
			end
		else
			if (dist_get ~= nil) and dist_get < lo_tr then
				if dist_get < 0 then
					tr_min = v
				else
					lo_tr = dist_get
					tr_obj = v
				end
			end
		end
	end

	if not LK3D.SUPER_OPTI_TR then
		local dist_ret = dist or math.huge
		local pos_ret = pos + (dir * (dist or math.huge))
		local norm_ret = dir
		local uv_ret = {0, 0}
		local closest_obj = nil
		local tri_ret = 0

		for k, v in ipairs(possib_objs) do
			local pos_get, norm_get, dist_get, uv_get, tri_get = traceRayObj(pos, dir, v, bfcull)

			if dist_get <= dist_ret then
				dist_ret = dist_get
				pos_ret = pos_get
				norm_ret = norm_get
				uv_ret = uv_get
				closest_obj = v.name
				tri_ret = tri_get
			end
		end

		if LK3D.TraceReturnTable then
			return {
				obj = closest_obj,
				dist = dist_ret,
				pos = pos_ret,
				norm = norm_ret,
				uv = uv_ret,
				tri = tri_ret,
			}
		else
			return pos_ret, norm_ret, dist_ret, uv_ret
		end
	else
		if tr_obj then
			return traceRayObj(pos, dir, tr_obj, bfcull)
		elseif tr_min then
			return traceRayObj(pos, dir, tr_min, bfcull)
		else
			return pos + (dir * (dist or 1000000000)), dir, math.huge
		end
	end
end
