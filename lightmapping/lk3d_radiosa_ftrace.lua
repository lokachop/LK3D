LK3D = LK3D or {}
LK3D.Radiosa = LK3D.Radiosa or {}

local WORLD_MAX_SIZE_X = 32768 -- i doubt anyone will be lightmapping worlds bigger than this
local WORLD_MAX_SIZE_Y = 32768
local WORLD_MAX_SIZE_Z = 32768
local NODE_SIZE = 1

local BIG = 1e30
local DDA_MAX_ITR = 64 + 32

local BACKFACE_CULL = false
local EPSILON = 2.2204460492503131e-16





local math = math
local math_abs = math.abs
local math_floor = math.floor
local math_min = math.min
local math_max = math.max


local FTraceWorld = {}
local function clearFTraceWorld()
	FTraceWorld = {
		nodes = {},
		triangleRegistry = {},
	}
end
clearFTraceWorld()


local h_MaxX = WORLD_MAX_SIZE_X * .5
local h_MaxY = WORLD_MAX_SIZE_Y * .5
local h_MaxZ = WORLD_MAX_SIZE_Z * .5
local h_NodeSize = NODE_SIZE * .5
local q_NodeSize = NODE_SIZE * .25


local m_nxy = WORLD_MAX_SIZE_X * WORLD_MAX_SIZE_Y
local function nodePosToIndex(nx, ny, nz)
	return nx + (ny * WORLD_MAX_SIZE_X) + (nz * m_nxy)
end

local function nodeIndexToNodePos(index)
	local nx = index % WORLD_MAX_SIZE_X
	local ny = math_floor(index / WORLD_MAX_SIZE_X) % WORLD_MAX_SIZE_Y
	local nz = math_floor(math_floor(index / WORLD_MAX_SIZE_X) / WORLD_MAX_SIZE_Y) % WORLD_MAX_SIZE_Z

	return nx, ny, nz
end

local function addNode(nx, ny, nz)
	local posIndex = nodePosToIndex(nx, ny, nz)
	FTraceWorld.nodes[posIndex] = {}
	return FTraceWorld.nodes[posIndex]
end

local function getNodeByNodePos(nx, ny, nz)
	local posIndex = nodePosToIndex(nx, ny, nz)
	return FTraceWorld.nodes[posIndex]
end

local function getNodeByNodePos_Fast(nx, ny, nz)
	return FTraceWorld.nodes[nx + (ny * WORLD_MAX_SIZE_X) + (nz * m_nxy)]
end

local function posToNodePos(vec)
	local nx = h_MaxX + math_floor(vec[1] / NODE_SIZE)
	local ny = h_MaxY + math_floor(vec[2] / NODE_SIZE)
	local nz = h_MaxZ + math_floor(vec[3] / NODE_SIZE)

	return nx, ny, nz
end


local function posToNodePos_Fast1(vec) -- only works with nodeSize 1
	return h_MaxX + math_floor(vec[1]), h_MaxY + math_floor(vec[2]), h_MaxZ + math_floor(vec[3])
end



local function nodePosToPos(nx, ny, nz)
	local rx = (nx - h_MaxX) * NODE_SIZE
	local ry = (ny - h_MaxY) * NODE_SIZE
	local rz = (nz - h_MaxZ) * NODE_SIZE

	return Vector(rx, ry, rz)
end


local function getNodeByPos(vec)
	return getNodeByNodePos(posToNodePos(vec))
end

local function addNodeByPos(vec)
	addNode(posToNodePos(vec))
end

local function addTriToNode(node, regIndex)
	node[#node + 1] = regIndex
end


local function addTriToRegistry(tri)
	FTraceWorld.triangleRegistry[#FTraceWorld.triangleRegistry + 1] = tri
	return #FTraceWorld.triangleRegistry
end

local function getTriFromRegistry(regIndex)
	return FTraceWorld.triangleRegistry[regIndex]
end


local vec_add_half = Vector(h_NodeSize, h_NodeSize, h_NodeSize)
local vec_add_quarter = Vector(q_NodeSize, q_NodeSize, q_NodeSize)
local function addTriangleToFTraceWorld(tri, regIndex)
	local v1 = tri[1]
	local v2 = tri[2]
	local v3 = tri[3]

	local min = Vector(math_min(v1[1], v2[1], v3[1]), math_min(v1[2], v2[2], v3[2]), math_min(v1[3], v2[3], v3[3]))
	local max = Vector(math_max(v1[1], v2[1], v3[1]), math_max(v1[2], v2[2], v3[2]), math_max(v1[3], v2[3], v3[3]))

	min = min + vec_add_quarter
	max = max + vec_add_half

	local nx_min, ny_min, nz_min = posToNodePos(min)
	local nx_max, ny_max, nz_max = posToNodePos(max)
	--nx_min = nx_min - 1
	--ny_min = ny_min - 1
	--nz_min = nz_min - 1

	--nx_max = nx_max + 1
	--ny_max = ny_max + 1
	--nz_max = nz_max + 1


	-- Horribly slow but we're not doing too much!
	for nx = nx_min, nx_max do
		for ny = ny_min, ny_max do
			for nz = nz_min, nz_max do
				local node = getNodeByNodePos(nx, ny, nz)
				if not node then
					node = addNode(nx, ny, nz)
				end

				addTriToNode(node, regIndex)
			end
		end
	end
end

local function getObjectTriangleList(objptr)
	local model = objptr.mdl
	local objMatrix = objptr.tmatrix

	local mdlInfo = LK3D.Models[model]

	local verts = mdlInfo.verts
	local indices = mdlInfo.indices

	local ret_tris = {}

	for i = 1, #indices do
		local index = indices[i]


		local v1 = verts[index[1][1]] * 1
		local v2 = verts[index[2][1]] * 1
		local v3 = verts[index[3][1]] * 1

		v1:Mul(objMatrix)
		v2:Mul(objMatrix)
		v3:Mul(objMatrix)

		ret_tris[#ret_tris + 1] = {v1, v2, v3}
	end

	return ret_tris
end

local function addObjectToFTraceWorld(objptr)
	local tris = getObjectTriangleList(objptr)

	for i = 1, #tris do
		local tri = tris[i]
		local regIndex = addTriToRegistry(tri)


		addTriangleToFTraceWorld(tris[i], regIndex)
	end
end

function LK3D.Radiosa.FTraceSetupScene(univ)
	clearFTraceWorld()

	univ = univ or LK3D.CurrUniv

	local objects = univ["objects"]
	for k, v in pairs(objects) do
		addObjectToFTraceWorld(v)
	end
end




function LK3D.Radiosa.FTraceDebugGetWorld()
	return FTraceWorld
end

function LK3D.Radiosa.FTraceDebugGetPosFromNodePos(nx, ny, nz)
	return nodePosToPos(nx, ny, nz)
end


function LK3D.Radiosa.FTraceDebugGetPosFromNodeIndex(index)
	return nodePosToPos(nodeIndexToNodePos(index))
end


local function ray_triangle(ro, rd, v1, v2, v3)
	local tri1 = v1 * 1  -- copy the vector so we can do stuff FAST
	local tri2 = v2 * 1
	local tri3 = v3 * 1

	-- opti; dont make new objects
	tri2:Sub(tri1)
	tri3:Sub(tri1)
	local h = rd.Cross(rd, tri3)
	local a = h.Dot(h, tri2)

	-- if a is negative, ray hits the backface
	if BACKFACE_CULL and a < 0 then
		return false
	end

	-- if a is too close to 0, ray does not intersect triangle
	if math_abs(a) <= EPSILON then
		return false
	end

	local f = 1 / a
	--local s = ro - tri1
	tri1:Sub(ro) -- make tri1 into S
	tri1:Negate()
	--local u = s:Dot(h) * f
	local u = tri1:Dot(h) * f

	-- ray does not intersect triangle
	if u < 0 or u > 1 then
		return false
	end

	local q = tri1.Cross(tri1, tri2)
	local v = rd.Dot(rd, q) * f

	-- ray does not intersect triangle
	if v < 0 or u + v > 1 then
		return false
	end

	-- at this stage we can compute t to find out where
	-- the intersection point is on the line
	local t = q.Dot(q, tri3) * f

	-- return position of intersection and distance from ray origin
	if t >= EPSILON then
		return ro + rd * t, t
	end

	-- ray does not intersect triangle
	return false
end



local function raycastNodeTriangles(node, ro, rd)
	local hit = false
	local hitPos = Vector(0, 0, 0)
	local hitDist = BIG

	local triCount = #node

	for i = 1, triCount do
		local triIndex = node[i]
		local tri = FTraceWorld.triangleRegistry[triIndex]

		local pos, dist = ray_triangle(ro, rd, tri[1], tri[2], tri[3])

		if pos ~= false and dist < hitDist then
			hit = true
			hitPos = pos
			hitDist = dist
		end
	end

	return hit, hitPos, hitDist
end


-- Uses https://lodev.org/cgtutor/raycasting.html to DDA on the node grid
local deltaDistX = 0
local deltaDistY = 0
local deltaDistZ = 0


local _add_pX = .5 + h_MaxX
local _add_pY = .5 + h_MaxY
local _add_pZ = .5 + h_MaxZ
local _node_size_inv = 1 / NODE_SIZE
function LK3D.Radiosa.FTraceTraceLine(from, to)
	local rayDir = to - from
	--rayDir:Normalize()

	--local rdX, rdY, rdZ = rayDir:Unpack()
	local rdX = rayDir[1]
	local rdY = rayDir[2]
	local rdZ = rayDir[3]

	--local pX, pY, pZ = from:Unpack()
	local pX = (from[1] * _node_size_inv) + _add_pX
	local pY = (from[2] * _node_size_inv) + _add_pY
	local pZ = (from[3] * _node_size_inv) + _add_pZ

	--local nX, nY, nZ = posToNodePos_Fast1(from)
	local nX = h_MaxX + math_floor(from[1])
	local nY = h_MaxY + math_floor(from[2])
	local nZ = h_MaxZ + math_floor(from[3])

	local sideDistX = 0
	local sideDistY = 0
	local sideDistZ = 0


	deltaDistX = math_abs(1 / rdX)
	deltaDistY = math_abs(1 / rdY)
	deltaDistZ = math_abs(1 / rdZ)

	local stepX = 0
	local stepY = 0
	local stepZ = 0

	--local hit = false -- Not needed
	--local side = 0

	if rdX < 0 then
		stepX = -1
		sideDistX = (pX - nX) * deltaDistX
	else
		stepX = 1
		sideDistX = (nX + 1 - pX) * deltaDistX
	end

	if rdY < 0 then
		stepY = -1
		sideDistY = (pY - nY) * deltaDistY
	else
		stepY = 1
		sideDistY = (nY + 1 - pY) * deltaDistY
	end

	if rdZ < 0 then
		stepZ = -1
		sideDistZ = (pZ - nZ) * deltaDistZ
	else
		stepZ = 1
		sideDistZ = (nZ + 1 - pZ) * deltaDistZ
	end


	local hit = false
	local hitSide = 0
	local hitPos = Vector(0, 0, 0)
	local hitDist = from:Distance(to)
	local guessedDist = BIG

	for i = 1, DDA_MAX_ITR do
		--local node = getNodeByNodePos_Fast(nX, nY, nZ)
		local node = FTraceWorld.nodes[nX + (nY * WORLD_MAX_SIZE_X) + (nZ * m_nxy)]

		if node then
			local tr_hit, tr_hitPos, tr_hitDist = raycastNodeTriangles(node, from, rayDir)

			if tr_hit == true and tr_hitDist < hitDist then
				hit = true
				hitPos = tr_hitPos
				hitDist = tr_hitDist
			end
		end


		if hitSide == 1 then
			guessedDist = sideDistX - deltaDistX
		elseif hitSide == 2 then
			guessedDist = sideDistY - deltaDistY
		else
			guessedDist = sideDistZ - deltaDistZ
		end

		if guessedDist > hitDist then -- we're too far, so we won't hit anything
			break
		end


		if sideDistX < sideDistY then
			if sideDistX < sideDistZ then
				sideDistX = sideDistX + deltaDistX
				nX = nX + stepX
				hitSide = 1
			else
				sideDistZ = sideDistZ + deltaDistZ
				nZ = nZ + stepZ
				hitSide = 3
			end
		else
			if sideDistY < sideDistZ then
				sideDistY = sideDistY + deltaDistY
				nY = nY + stepY
				hitSide = 2
			else
				sideDistZ = sideDistZ + deltaDistZ
				nZ = nZ + stepZ
				hitSide = 3
			end
		end
	end

	return hit, hitPos, hitDist, nX, nY, nZ
end