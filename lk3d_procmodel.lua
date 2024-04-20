--[[--
## Procedural models for basic shapes
---

Module that generates simple procedural models of simple shapes  
Currently only spheres, cylinders, planes & cubemarched models are implemented   
]]
-- @module procmodel
LK3D = LK3D or {}

local function dec(n, deci)
	local pow = 10 ^ deci
	return math.floor(n * pow) / pow
end

local pi2 = math.pi * 2
local pi = math.pi


--- Declares a procedural sphere model
-- @tparam string name LK3D model name
-- @tparam number coli Longitude steps
-- @tparam number rowi Latitude steps
-- @tparam ?number szx X Size
-- @tparam ?number szy Y Size
-- @tparam ?number uvm UV map scale
-- @tparam ?bool invert whether we should invert the faces or not
-- @usage LK3D.DeclareProcSphere("simple_ball", 8, 6, 1, 1, 1, false)
function LK3D.DeclareProcSphere(name, coli, rowi, szx, szy, uvm, invert)
	local mdat = {}
	mdat["verts"] = {}
	mdat["indices"] = {}
	mdat["uvs"] = {}

	uvm = uvm or 1
	szx = szx or 1
	szy = szy or szx

	for y = 0, coli do
		for x = 0, rowi do
			local dy = y / coli
			local dx = x / rowi

			local sx, sy = math.sin(dx * pi2) * szx, math.cos(dx * pi2) * szx

			local dym = dec(math.sin(dy * pi), 3)
			local subm = -math.cos(dy * pi)

			local vc = Vector(sx * dym, subm * szy, sy * dym)

			if (x % (rowi + 1)) == 0 then
				local prevI = mdat["verts"][#mdat["verts"] - rowi]
				if prevI then
					for i = 0, rowi do
						local cind1 = (#mdat["verts"] + 1) + i
						local cind5 = (#mdat["verts"]) + i


						local cind2 = (#mdat["verts"] - rowi + i) + 0
						local cind3 = (#mdat["verts"] - rowi + i) + 1

						mdat["indices"][#mdat["indices"] + 1] = {
							{cind1, cind1},
							{cind2, cind2},
							{cind3, cind3},
						}
						mdat["indices"][#mdat["indices"] + 1] = {
							{cind5, cind5},
							{cind2, cind2},
							{cind1, cind1},
						}
					end

				end
			end


			mdat["verts"][#mdat["verts"] + 1] = vc
			mdat["uvs"][#mdat["uvs"] + 1] = {dx * uvm, dy * uvm}
		end
	end
	LK3D.Models[name] = mdat
	LK3D.GenerateNormals(LK3D.Models[name], invert)


	local mdldat = LK3D.Models[name]
	local verts = mdldat.verts
	local ind = mdldat.indices

	for i = 1, #ind do
		local index = ind[i]

		local v1 = Vector(verts[index[1][1]])
		local v2 = Vector(verts[index[2][1]])
		local v3 = Vector(verts[index[3][1]])

		-- sphere?
		-- free smooth normals!

		v1:Normalize()
		v2:Normalize()
		v3:Normalize()
		if invert then
			v1 = -v1
			v2 = -v2
			v3 = -v3
		end

		mdldat.s_normals[index[1][1]] = v1
		mdldat.s_normals[index[2][1]] = v2
		mdldat.s_normals[index[3][1]] = v3
	end
end

LK3D.DeclareProcSphere("sphere_simple", 8, 8, 1, 1)


function normal_calc_cyl(vert_pos)
	local vn = Vector(vert_pos)
	vn.z = 0
	vn:Normalize()
	return vn
end

function normal_calc_cyl_cap(vert_pos)
	local vn = Vector(vert_pos)
	vn.x = 0
	vn.y = 0
	vn:Normalize()
	return vn
end


--- Declares a procedural cylinder model
-- @tparam string name LK3D model name
-- @tparam number cyl_itr Side count
-- @usage LK3D.DeclareProcCylinder("the_tube", 12)
function LK3D.DeclareProcCylinder(name, cyl_itr)
	local mdat = {}
	mdat["verts"] = {}
	mdat["indices"] = {}
	mdat["uvs"] = {}

	local m_verts = mdat["verts"]
	local m_uvs = mdat["uvs"]
	local m_indc = mdat["indices"]

	local caps = {}

	for i = 0, (cyl_itr - 1) do
		local mv_indx = #m_verts


		--o--o
		--|  |
		--x--o
		local idelta_1 = ((i % cyl_itr) / cyl_itr)
		local idelta_2 = (((i + 1) % cyl_itr) / cyl_itr)


		local mod_var = idelta_1 * pi2
		local xc = math.sin(mod_var)
		local yc = math.cos(mod_var)
		local vert_p1 = (Vector(xc, yc, 1))
		m_verts[mv_indx + 1] = vert_p1
		m_uvs[mv_indx + 1] = {0, 0}


		--o--o
		--|  |
		--o--x
		mod_var = idelta_1 * pi2
		xc = math.sin(mod_var)
		yc = math.cos(mod_var)
		local vert_p2 = (Vector(xc, yc, -1))
		m_verts[mv_indx + 2] = vert_p2
		m_uvs[mv_indx + 2] = {0, 1}

		--0--x
		--|  |
		--o--o
		mod_var = idelta_2 * pi2
		xc = math.sin(mod_var)
		yc = math.cos(mod_var)
		local vert_p3 = (Vector(xc, yc, -1))
		m_verts[mv_indx + 3] = vert_p3
		m_uvs[mv_indx + 3] = {1, 1}

		--x--o
		--|  |
		--o--o
		mod_var = idelta_2 * pi2
		xc = math.sin(mod_var)
		yc = math.cos(mod_var)
		local vert_p4 = (Vector(xc, yc, 1))
		m_verts[mv_indx + 4] = vert_p4
		m_uvs[mv_indx + 4] = {1, 0}

		--\--|
		-- \ |
		--  \|
		m_indc[#m_indc + 1] = {
			{mv_indx + 2, mv_indx + 2},
			{mv_indx + 1, mv_indx + 1},
			{mv_indx + 4, mv_indx + 4},
		}

		--|\
		--| \
		--|__\
		m_indc[#m_indc + 1] = {
			{mv_indx + 2, mv_indx + 2},
			{mv_indx + 4, mv_indx + 4},
			{mv_indx + 3, mv_indx + 3},
		}








		-- CAPS
		local vert_top = Vector(0, 0, 1) -- 0
		m_verts[mv_indx + 5] = vert_top
		m_uvs[mv_indx + 5] = {.5, .5}

		local vert_bottom = Vector(0, 0, -1) -- 0m
		m_verts[mv_indx + 6] = vert_bottom
		m_uvs[mv_indx + 6] = {.5, .5}



		mod_var = idelta_1 * pi2
		xc = math.sin(mod_var)
		yc = math.cos(mod_var)
		local vert_p7 = (Vector(xc, yc, 1))
		m_verts[mv_indx + 7] = vert_p7
		m_uvs[mv_indx + 7] = {0, 0}


		--o--o
		--|  |
		--o--x
		mod_var = idelta_1 * pi2
		xc = math.sin(mod_var)
		yc = math.cos(mod_var)
		local vert_p8 = (Vector(xc, yc, -1))
		m_verts[mv_indx + 8] = vert_p8
		m_uvs[mv_indx + 8] = {0, 1}



		--0--x
		--|  |
		--o--o
		mod_var = idelta_2 * pi2
		xc = math.sin(mod_var)
		yc = math.cos(mod_var)
		local vert_p9 = (Vector(xc, yc, -1))
		m_verts[mv_indx + 9] = vert_p9
		m_uvs[mv_indx + 9] = {1, 1}

		--x--o
		--|  |
		--o--o
		mod_var = idelta_2 * pi2
		xc = math.sin(mod_var)
		yc = math.cos(mod_var)
		local vert_p10 = (Vector(xc, yc, 1))
		m_verts[mv_indx + 10] = vert_p10
		m_uvs[mv_indx + 10] = {1, 0}

		caps[#m_indc + 1] = true
		m_indc[#m_indc + 1] = {
			{mv_indx + 8, mv_indx + 8},
			{mv_indx + 9, mv_indx + 9},
			{mv_indx + 6, mv_indx + 6},
		}


		caps[#m_indc + 1] = true
		m_indc[#m_indc + 1] = {
			{mv_indx + 7, mv_indx + 7},
			{mv_indx + 5, mv_indx + 5},
			{mv_indx + 10, mv_indx + 10},
		}
	end


	--local opti_mdat = LK3D.GetOptimizedModelTable(mdat)


	LK3D.Models[name] = mdat
	LK3D.GenerateNormals(LK3D.Models[name])


	local mdldat = LK3D.Models[name]
	local verts = mdldat.verts
	local ind = mdldat.indices

	for i = 1, #ind do
		local index = ind[i]

		local v1 = Vector(verts[index[1][1]])
		local v2 = Vector(verts[index[2][1]])
		local v3 = Vector(verts[index[3][1]])

		local nc1 = caps[i] and normal_calc_cyl_cap(v1) or normal_calc_cyl(v1)
		local nc2 = caps[i] and normal_calc_cyl_cap(v2) or normal_calc_cyl(v2)
		local nc3 = caps[i] and normal_calc_cyl_cap(v3) or normal_calc_cyl(v3)

		mdldat.s_normals[index[1][1]] = Vector(nc1)
		mdldat.s_normals[index[2][1]] = Vector(nc2)
		mdldat.s_normals[index[3][1]] = Vector(nc3)
	end
end

local t_ccat = {}
local string_sep = ":"
local function hashPos(v)
	t_ccat = {}
	t_ccat[1] = "["
	t_ccat[2] = math.Round(v[1], 4)
	t_ccat[3] = math.Round(v[2], 4)
	t_ccat[4] = math.Round(v[3], 4)


	return table.concat(t_ccat, string_sep)
end



--- Declares a procedural plane model
-- @tparam string name LK3D model name
-- @tparam number psx X Size
-- @tparam number psy Y Size
-- @tparam number itrx X Vertex count
-- @tparam number itry Y Vertex count
-- @tparam function distortfunc Distort function for altering positions, refer to usage
-- @usage LK3D.DeclareProcPlane("cool_terrain", 8, 8, 16, 16, function(x, y)
--	 local spx = LK3D.Simplex2D(x, y, 5623)
--	 return Vector(x, spx, y)
-- end)
function LK3D.DeclareProcPlane(name, psx, psy, itrx, itry, distortfunc)
	local mdat = {}
	mdat["verts"] = {}
	mdat["indices"] = {}
	mdat["uvs"] = {}

	local m_verts = mdat["verts"]
	local m_uvs = mdat["uvs"]
	local m_indc = mdat["indices"]

	local p_hash_lookup = {}

	local delta = 1 / itrx
	for i = 0, (itrx * itry) - 1 do
		local xcr = (i % itrx) / itrx
		local ycr = math.floor(i / itrx) / itry

		local xc = xcr - ((itrx / 2) / itrx)
		local yc = ycr - (math.floor(itry / 2) / itry)

		local cvx = Vector(xc * psx, 0, yc * psy)

		local cvxpx = Vector((xc + delta) * psx, 0, yc * psy)
		local cvxpy = Vector(xc * psx, 0, (yc + delta) * psy)

		local cvxpxy = Vector((xc + delta) * psx, 0, (yc + delta) * psy)

		local hx1 = hashPos(cvx)
		local lu = p_hash_lookup[hx1]
		if not lu then
			p_hash_lookup[hx1] = #m_verts + 1
			if distortfunc then
				cvx = distortfunc(xc, yc) * Vector(psx, 1, psy)
			end

			m_verts[#m_verts + 1] = cvx
			m_uvs[#m_uvs + 1] = {xcr, ycr}

			lu = p_hash_lookup[hx1]
		end

		local hy1 = hashPos(cvxpx)
		local lu_ox = p_hash_lookup[hy1]
		if not lu_ox then
			p_hash_lookup[hy1] = #m_verts + 1
			if distortfunc then
				cvxpx = distortfunc(xc + delta, yc) * Vector(psx, 1, psy)
			end

			m_verts[#m_verts + 1] = cvxpx
			m_uvs[#m_uvs + 1] = {xcr + delta, ycr}

			lu_ox = p_hash_lookup[hy1]
		end

		local hx2 = hashPos(cvxpy)
		local lu_oy = p_hash_lookup[hx2]
		if not lu_oy then
			p_hash_lookup[hx2] = #m_verts + 1
			if distortfunc then
				cvxpy = distortfunc(xc, yc + delta) * Vector(psx, 1, psy)
			end

			m_verts[#m_verts + 1] = cvxpy
			m_uvs[#m_uvs + 1] = {xcr, ycr + delta}

			lu_oy = p_hash_lookup[hx2]
		end

		local hy2 = hashPos(cvxpxy)
		local lu_ox_oy = p_hash_lookup[hy2]
		if not lu_ox_oy then
			p_hash_lookup[hy2] = #m_verts + 1
			if distortfunc then
				cvxpxy = distortfunc(xc + delta, yc + delta) * Vector(psx, 1, psy)
			end

			m_verts[#m_verts + 1] = cvxpxy
			m_uvs[#m_uvs + 1] = {xcr + delta, ycr + delta}

			lu_ox_oy = p_hash_lookup[hy2]
		end

		m_indc[#m_indc + 1] = {
			{lu_oy, lu_oy},
			{lu_ox, lu_ox},
			{lu, lu},
		}

		m_indc[#m_indc + 1] = {
			{lu_oy, lu_oy},
			{lu_ox_oy, lu_ox_oy},
			{lu_ox, lu_ox},
		}
	end

	LK3D.Models[name] = mdat
	LK3D.GenerateNormals(LK3D.Models[name])
end


-- marching cubes!
include("lk3d_marchinglut.lua")


local iso_val_march = 0
local function interp_march(ev1, valv1, ev2, valv2)
	return ev1 + (iso_val_march - valv1) * (ev2 - ev1) / (valv2 - valv1)
end

-- (iso_val_march - valv1) * (ev2 - ev1) / (valv2 - valv1)
-- https://polycoding.net/marching-cubes/part-1/

--- Declares a [cubemarched](https://en.wikipedia.org/wiki/Marching_cubes) model
-- @tparam string name LK3D model name
-- @tparam number detail Detail level of the model
-- @tparam vector sz Scale of the model
-- @tparam function func SDF function for the model
-- @usage -- if you don't know what an SDF is, this is a good read, https://jamie-wong.com/2016/07/15/ray-marching-signed-distance-functions/
-- -- in this case, i used the sphere SDF from https://iquilezles.org/articles/distfunctions/
-- -- also UVs aren't implemented properly on this
-- LK3D.DeclareCubeMarchModel("sphere_marched", 4, Vector(1, 1, 1), function(pos)
-- 	 return pos:Length() - .7
-- end)
function LK3D.DeclareCubeMarchModel(name, detail, sz, func)
	local marchcube_lut = LK3D.GetMarchingCubeLUT()
	local edge_connection_lut = LK3D.GetMarchingCubeEdgeLUT()

	local mdat = {}
	mdat["verts"] = {}
	mdat["indices"] = {}
	mdat["uvs"] = {}

	local verts = mdat["verts"]
	local indices = mdat["indices"]
	local uvs = mdat["uvs"]


	local detail_itr = detail * detail * detail
	local detailhalf = detail / 2


	local delta_x = (sz[1] / detail) * 2
	local delta_y = (sz[2] / detail) * 2
	local delta_z = (sz[3] / detail) * 2

	for i = 0, detail_itr - 1 do
		local xc = ((i % detail) - detailhalf) / detailhalf
		local yc = (math.floor((i % (detail * detail)) / detail) - detailhalf) / detailhalf
		local zc = (math.floor(i / (detail * detail)) - detailhalf) / detailhalf


		local sz_x = xc * sz[1]
		local sz_y = yc * sz[2]
		local sz_z = zc * sz[3]

		-- top left align, calc if inside or outside
		local v7 = func(Vector(sz_x, sz_y, sz_z))
		local v6 = func(Vector(sz_x + delta_x, sz_y, sz_z))

		local v3 = func(Vector(sz_x, sz_y + delta_y, sz_z))
		local v2 = func(Vector(sz_x + delta_x, sz_y + delta_y, sz_z))


		local v4 = func(Vector(sz_x, sz_y, sz_z + delta_z))
		local v5 = func(Vector(sz_x + delta_x, sz_y, sz_z + delta_z))

		local v0 = func(Vector(sz_x, sz_y + delta_y, sz_z + delta_z))
		local v1 = func(Vector(sz_x + delta_x, sz_y + delta_y, sz_z + delta_z))

		local cubeindex = 0
		cubeindex = cubeindex + ((v0 < iso_val_march) and 1   or 0)
		cubeindex = cubeindex + ((v1 < iso_val_march) and 2   or 0)
		cubeindex = cubeindex + ((v2 < iso_val_march) and 4   or 0)
		cubeindex = cubeindex + ((v3 < iso_val_march) and 8   or 0)
		cubeindex = cubeindex + ((v4 < iso_val_march) and 16  or 0)
		cubeindex = cubeindex + ((v5 < iso_val_march) and 32  or 0)
		cubeindex = cubeindex + ((v6 < iso_val_march) and 64  or 0)
		cubeindex = cubeindex + ((v7 < iso_val_march) and 128 or 0)

		if (cubeindex == 0) or (cubeindex == 255) then -- skip fancy math
			continue
		end

		local cube_values = {
			v0,
			v1,
			v2,
			v3,
			v4,
			v5,
			v6,
			v7
		}

		local corner_offsets_new = {
			Vector(sz_x, sz_y + delta_y, sz_z + delta_z), -- v0
			Vector(sz_x + delta_x, sz_y + delta_y, sz_z + delta_z), -- v1
			Vector(sz_x + delta_x, sz_y + delta_y, sz_z), -- v2
			Vector(sz_x, sz_y + delta_y, sz_z), -- v3
			Vector(sz_x, sz_y, sz_z + delta_z), -- v4
			Vector(sz_x + delta_x, sz_y, sz_z + delta_z), -- v5
			Vector(sz_x + delta_x, sz_y, sz_z), -- v6
			Vector(sz_x, sz_y, sz_z)  -- v7
		}

		local edge_lookup = marchcube_lut[cubeindex + 1] -- arrays are base 1 in lua

		-- build the triangles unoptimized

		for j = 1, 16, 3 do
			local ind1 = edge_lookup[j]
			if ind1 == -1 then
				break
			end
			local ind2 = edge_lookup[j + 1]
			local ind3 = edge_lookup[j + 2]

			local e00 = edge_connection_lut[ind1 + 1][1] + 1
			local e01 = edge_connection_lut[ind1 + 1][2] + 1

			local e10 = edge_connection_lut[ind2 + 1][1] + 1
			local e11 = edge_connection_lut[ind2 + 1][2] + 1

			local e20 = edge_connection_lut[ind3 + 1][1] + 1
			local e21 = edge_connection_lut[ind3 + 1][2] + 1

			local vc1 = interp_march(corner_offsets_new[e00], cube_values[e00], corner_offsets_new[e01], cube_values[e01])
			local vc2 = interp_march(corner_offsets_new[e10], cube_values[e10], corner_offsets_new[e11], cube_values[e11])
			local vc3 = interp_march(corner_offsets_new[e20], cube_values[e20], corner_offsets_new[e21], cube_values[e21])

			local id1 = #verts + 1
			verts[id1] = vc1
			uvs[id1] = {vc1[1], vc1[2]}

			local id2 = #verts + 1
			verts[id2] = vc2
			uvs[id2] = {vc2[1], vc2[2]}

			local id3 = #verts + 1
			verts[id3] = vc3
			uvs[id3] = {vc3[1], vc3[2]}

			indices[#indices + 1] = {
				{id1, id1},
				{id2, id2},
				{id3, id3},
			}
		end
	end

	local opti_mdat = LK3D.GetOptimizedModelTable(mdat)
	LK3D.Models[name] = opti_mdat
	LK3D.GenerateNormals(LK3D.Models[name])
end


LK3D.DeclareCubeMarchModel("march_test", 8, Vector(1, 1, 1), function(pos)
	return pos:Length() - .8
end)