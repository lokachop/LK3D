-- Written by discord AI

-- Physics engine constants
local GRAVITY = Vector(0, 0, -9.81)
local FIXED_TIME_STEP = .01
local RESTITUTION = (GRAVITY.z * FIXED_TIME_STEP)

-- Physics engine state
local currTime = os.clock()
local accumulator = 0


local function v_abs(vec)
	return Vector(math.abs(vec[1]), math.abs(vec[2]), math.abs(vec[3]))
end

local function sign(x)
	return (x < 0) and -1 or 1
end

-- Add a physics body to the universe
function LK3D.AddPhysicsBodyToUniv(name)
	if not LK3D.CurrUniv["physics"] then
		LK3D.CurrUniv["physics"] = {}
	end

	local body = {
		pos = Vector(0, 0, 0),
		ang = Quaternion.new(0, 0, 0, 1),
		scl = Vector(1, 1, 1),
		vel = Vector(0, 0, 0),
		angvel = Vector(0, 0, 0),
		mass = 1, -- in kg
		static = false
	}

	-- Compute the inertia tensor
	local halfExtents = body.scl * 0.5
	local mass = body.mass
	local ixx = (1 / 12) * mass * (halfExtents.y^2 + halfExtents.z^2)
	local iyy = (1 / 12) * mass * (halfExtents.x^2 + halfExtents.z^2)
	local izz = (1 / 12) * mass * (halfExtents.x^2 + halfExtents.y^2)
	body.inertiaTensor = Matrix({
		{ixx, 0, 0, 0},
		{0, iyy, 0, 0},
		{0, 0, izz, 0},
		{0, 0, 0, 1}
	})

	LK3D.CurrUniv["physics"][name] = body

	LK3D.New_D_Print("Added physics body \"" .. name .. "\"", 2, "Physics")
end


function LK3D.SetPhysicsBodyStatic(name, bool)
	LK3D.CurrUniv["physics"][name].static = bool
end

function LK3D.SetPhysicsBodyMass(name, n_mass)
	LK3D.CurrUniv["physics"][name].mass = n_mass

	-- Compute the inertia tensor
	local halfExtents = LK3D.CurrUniv["physics"][name].scl * 0.5
	local ixx = (1 / 12) * n_mass * (halfExtents.y^2 + halfExtents.z^2)
	local iyy = (1 / 12) * n_mass * (halfExtents.x^2 + halfExtents.z^2)
	local izz = (1 / 12) * n_mass * (halfExtents.x^2 + halfExtents.y^2)
	LK3D.CurrUniv["physics"][name].inertiaTensor = Matrix({
		{ixx, 0, 0, 0},
		{0, iyy, 0, 0},
		{0, 0, izz, 0},
		{0, 0, 0, 1}
	})
end

function LK3D.HaltPhysicsMotion(name)
	LK3D.CurrUniv["physics"][name].vel = Vector(0, 0, 0)
end

function LK3D.HaltPhysicsAngMotion(name)
	LK3D.CurrUniv["physics"][name].angvel = Vector(0, 0, 0)
end


function LK3D.SetPhysicsBodyAngMotion(name, n_angvel)
	LK3D.CurrUniv["physics"][name].angvel = n_angvel
end

function LK3D.SetPhysicsBodyPos(name, n_pos)
	LK3D.CurrUniv["physics"][name].pos = n_pos
end

function LK3D.SetPhysicsBodyAng(name, n_ang)
	LK3D.CurrUniv["physics"][name].ang = Quaternion.fromAngle(n_ang)
end

function LK3D.SetPhysicsBodyPosAng(name, n_pos, n_ang)
	LK3D.CurrUniv["physics"][name].pos = n_pos
	LK3D.CurrUniv["physics"][name].ang = Quaternion.fromAngle(n_ang)
end

function LK3D.SetPhysicsBodyScl(name, n_scl)
	LK3D.CurrUniv["physics"][name].scl = n_scl

	-- Compute the inertia tensor
	local halfExtents = n_scl * 0.5
	local mass = LK3D.CurrUniv["physics"][name].mass
	local ixx = (1 / 12) * mass * (halfExtents.y^2 + halfExtents.z^2)
	local iyy = (1 / 12) * mass * (halfExtents.x^2 + halfExtents.z^2)
	local izz = (1 / 12) * mass * (halfExtents.x^2 + halfExtents.y^2)
	LK3D.CurrUniv["physics"][name].inertiaTensor = Matrix({
		{ixx, 0, 0, 0},
		{0, iyy, 0, 0},
		{0, 0, izz, 0},
		{0, 0, 0, 1}
	})
end

local objecti = {}
function LK3D.DebugRenderPhysicsObjects()
	for k, v in pairs(LK3D.CurrUniv["physics"]) do
		if not LK3D.CurrUniv["objects"][k] then
			LK3D.AddModelToUniverse(k, "cube_nuv")
			LK3D.SetModelMat(k, "wireframe_fake")
			LK3D.SetModelPosAng(k, v.pos, v.ang:toAngle()) -- ang is a quat, translate back to ang!
			LK3D.SetModelScale(k, v.scl)
			LK3D.SetModelFlag(k, "NO_SHADING", false)
			LK3D.SetModelFlag(k, "NO_LIGHTING", true)
			LK3D.SetModelFlag(k, "CONSTANT", false)
			LK3D.SetModelFlag(k, "SHADING_SMOOTH", true)
			objecti[k] = true
		end
		LK3D.SetModelPosAng(k, v.pos, v.ang:toAngle())
	end

	for k, v in pairs(objecti) do
		if LK3D.CurrUniv["physics"][k] == nil then
			LK3D.RemoveModelFromUniverse(k)
			objecti[k] = nil
		end
	end
end




local function matrix_dot(mat, vec)
	local x = mat:GetField(1, 1) * vec.x + mat:GetField(1, 2) * vec.y + mat:GetField(1, 3) * vec.z
	local y = mat:GetField(2, 1) * vec.x + mat:GetField(2, 2) * vec.y + mat:GetField(2, 3) * vec.z
	local z = mat:GetField(3, 1) * vec.x + mat:GetField(3, 2) * vec.y + mat:GetField(3, 3) * vec.z

	return Vector(x, y, z)
end


function getAxes(obj1, obj2)
	local axisList = {}

	-- Calculate axis vectors for object 1
	local obj1_ang_mat = obj1.ang:toMat3()
	local obj1_pos = obj1.pos
	table.insert(axisList, (Matrix(obj1_ang_mat) * Vector(1, 0, 0)):GetNormalized())
	table.insert(axisList, (Matrix(obj1_ang_mat) * Vector(0, 1, 0)):GetNormalized())
	table.insert(axisList, (Matrix(obj1_ang_mat) * Vector(0, 0, 1)):GetNormalized())
	LK3D.DebugUtils.Line(obj1_pos, obj1_pos + axisList[1] * .15, 16, Color(255, 0, 0))
	LK3D.DebugUtils.Line(obj1_pos, obj1_pos + axisList[2] * .15, 16, Color(0, 255, 0))
	LK3D.DebugUtils.Line(obj1_pos, obj1_pos + axisList[3] * .15, 16, Color(0, 0, 255))


	-- Calculate axis vectors for object 2
	local obj2_ang_mat = obj2.ang:toMat3()
	local obj2_pos = obj2.pos
	table.insert(axisList, (Matrix(obj2_ang_mat) * Vector(1, 0, 0)):GetNormalized())
	table.insert(axisList, (Matrix(obj2_ang_mat) * Vector(0, 1, 0)):GetNormalized())
	table.insert(axisList, (Matrix(obj2_ang_mat) * Vector(0, 0, 1)):GetNormalized())

	LK3D.DebugUtils.Line(obj2_pos, obj2_pos + axisList[4] * .15, 16, Color(255, 128, 128))
	LK3D.DebugUtils.Line(obj2_pos, obj2_pos + axisList[5] * .15, 16, Color(128, 255, 128))
	LK3D.DebugUtils.Line(obj2_pos, obj2_pos + axisList[6] * .15, 16, Color(128, 128, 255))



	-- Calculate edge vectors and cross-products for both objects
	local edges1 = {
		(Matrix(obj2_ang_mat) * Vector(1, 0, 0)):GetNormalized(),
		(Matrix(obj2_ang_mat) * Vector(0, 1, 0)):GetNormalized(),
		(Matrix(obj2_ang_mat) * Vector(0, 0, 1)):GetNormalized(),
	}

	local edges2 = {
		(Matrix(obj2_ang_mat) * Vector(1, 0, 0)):GetNormalized(),
		(Matrix(obj2_ang_mat) * Vector(0, 1, 0)):GetNormalized(),
		(Matrix(obj2_ang_mat) * Vector(0, 0, 1)):GetNormalized(),
	}
	table.insert(axisList, edges1[1]:Cross(edges2[1]):GetNormalized())
	table.insert(axisList, edges1[1]:Cross(edges2[2]):GetNormalized())
	table.insert(axisList, edges1[1]:Cross(edges2[3]):GetNormalized())
	table.insert(axisList, edges1[2]:Cross(edges2[1]):GetNormalized())
	table.insert(axisList, edges1[2]:Cross(edges2[2]):GetNormalized())
	table.insert(axisList, edges1[2]:Cross(edges2[3]):GetNormalized())
	table.insert(axisList, edges1[3]:Cross(edges2[1]):GetNormalized())
	table.insert(axisList, edges1[3]:Cross(edges2[2]):GetNormalized())
	table.insert(axisList, edges1[3]:Cross(edges2[3]):GetNormalized())

	for k, v in ipairs(axisList) do
		LK3D.DebugUtils.Line(Vector(0, 0, 4), Vector(0, 0, 4) + v, 32, Color(0, 255, 255))
	end

	return axisList
end

-- https://dyn4j.org/2010/01/sat/
local function projectAxis(verts, axis)
	local min = math.huge --axis:Dot(verts[1])
	local max = -math.huge --min

	if axis:Length() < .001 then
		return {min, max}
	end

	for k, v in ipairs(verts) do -- we have to project the 4 verts
		local p = axis:Dot(v)

		if p < min then
			min = p
		end

		if p > max then
			max = p
		end
	end

	return {min, max}
end

local normal_list_obb_ang = {
	Vector(1, 0, 0):Angle(),
	Vector(-1, 0, 0):Angle(),
	Vector(0, 1, 0):Angle(),
	Vector(0, -1, 0):Angle(),
	Vector(0, 0, 1):Angle(),
	Vector(0, 0, -1):Angle(),
}

local function obb_get_quads(obj)
	local r_matrix = obj.ang:toMat3()
	local scl = obj.scl
	local pos = obj.pos
	local quads = {}

	for k, v in ipairs(normal_list_obb_ang) do
		quads[#quads + 1] = Vector(-1, -1, 0)
		quads[#quads]:Rotate(v)
		quads[#quads] = (Matrix(r_matrix) * (quads[#quads])) * scl + pos

		quads[#quads + 1] = Vector(1, -1, 0)
		quads[#quads]:Rotate(v)
		quads[#quads] = (Matrix(r_matrix) * (quads[#quads])) * scl + pos

		quads[#quads + 1] = Vector(-1, 1, 0)
		quads[#quads]:Rotate(v)
		quads[#quads] = (Matrix(r_matrix) * (quads[#quads])) * scl + pos

		quads[#quads + 1] = Vector(1, 1, 0)
		quads[#quads]:Rotate(v)
		quads[#quads] = (Matrix(r_matrix) * (quads[#quads])) * scl + pos
	end

	return quads
end

local function obb_get_verts(obj)
	local true_mat = Matrix()
	true_mat:SetAngles(obj.ang:toAngle())
	true_mat:SetTranslation(obj.pos)
	true_mat:SetScale(obj.scl)
	return {
		true_mat * Vector( 1,  1,  1),
		true_mat * Vector(-1,  1,  1),
		true_mat * Vector( 1, -1,  1),
		true_mat * Vector(-1, -1,  1),
		true_mat * Vector( 1,  1, -1),
		true_mat * Vector(-1,  1, -1),
		true_mat * Vector( 1, -1, -1),
		true_mat * Vector(-1, -1, -1),
	}
end


-- https://gamedev.stackexchange.com/questions/44500/how-many-and-which-axes-to-use-for-3d-obb-collision-with-sat
local function intersectsWhenProjected(obj1, obj2, axis)
	local o1_verts = obb_get_verts(obj1)
	local o2_verts = obb_get_verts(obj2)


	local o1_min = math.huge
	local o1_max = -math.huge
	local o2_min = math.huge
	local o2_max = -math.huge


	for i = 1, 8 do -- 8 verts in cube
		local o1_dist = o1_verts[i]:Dot(axis)
		o1_min = (o1_dist < o1_min) and o1_dist or o1_min
		o1_max = (o1_dist > o1_max) and o1_dist or o1_max

		local o2_dist = o2_verts[i]:Dot(axis)
		o2_min = (o2_dist < o2_min) and o2_dist or o2_min
		o2_max = (o2_dist > o2_max) and o2_dist or o2_max
	end


	local long_span = math.max(o1_max, o2_max) - math.min(o1_min, o2_min)
	local sum_span = o1_max - o1_min + o2_max - o2_min

	return long_span <= sum_span, long_span, sum_span
end

-- https://github.com/ValentinChCloud/SAT-lua/blob/master/SAT.lua
local function line_overlap(a_min, a_max, b_min, b_max)
	return math.max(0, math.min(a_max, b_max) - math.max(a_min, b_min))
end


local function detectCollision(obj1, obj2)
	local halfExtents1 = obj1.scl * .5
	local halfExtents2 = obj2.scl * .5
	local fullExtents1 = obj1.scl
	local fullExtents2 = obj2.scl
	local rotationMatrix1 = obj1.ang:toMat3()
	local rotationMatrix2 = obj2.ang:toMat3()

	local position1 = obj1.pos
	local position2 = obj2.pos

	local all_axis = getAxes(obj1, obj2)

	local smallest_delta = math.huge
	local normal = nil
	for k, v in ipairs(all_axis) do
		if v:Length() < .001 then
			print("v_len_toolow")
			continue
		end

		local intersects, long, sum = intersectsWhenProjected(obj1, obj2, v)
		if not intersects then
			print("FAIL!")
			return
		end

		local delta = sum - long
		if delta < smallest_delta then
			smallest_delta = delta
			normal = v
		end
	end
	print("we overlapping now")
	print(smallest_delta, normal)


	return {
		normal = normal,
		depth = smallest_delta,
		point = normal,
	}
end

local function mat_TransformInertiaTensor(mat, vec)
	local x = vec.x
	local y = vec.y
	local z = vec.z

	return Matrix({
		{mat:GetField(1, 1) + y*y + z*z, mat:GetField(1, 2) - x*y, mat:GetField(1, 3) - x*z, 0},
		{mat:GetField(2, 1) - x*y, mat:GetField(2, 2) + x*x + z*z, mat:GetField(2, 3) - y*z, 0},
		{mat:GetField(3, 1) - x*z, mat:GetField(3, 2) - y*z, mat:GetField(3, 3) + x*x + y*y, 0},
		{0, 0, 0, 1}
	})
end


-- Resolve a collision between two physics bodies
function resolveCollision(obj1, obj2, collision)
	local normal = collision.normal
	local r1 = collision.point - obj1.pos
	local r2 = collision.point - obj2.pos
	local v1 = obj1.vel + obj1.angvel:Cross(r1)
	local v2 = obj2.vel + obj2.angvel:Cross(r2)

	print(collision.point)
	LK3D.DebugUtils.Cross(collision.point, .05, 24, Color(255, 0, 0))
	LK3D.DebugUtils.Cross(obj1.pos, .05, 24, Color(0, 255, 0))
	LK3D.DebugUtils.Cross(obj2.pos, .05, 24, Color(0, 0, 255))
	LK3D.DebugUtils.Line(collision.point, collision.point + (normal * .1), 16, Color(255, 0, 255))

	local relativeVelocity = v2 - v1
	print("rv  ;", relativeVelocity)
	print("norm;", normal)
	local normalVelocity = relativeVelocity:Dot(normal)

	if (normalVelocity < 0) then
		-- No collision, objects are moving away from each other
		return
	end

	print("nv  ; ", normalVelocity)

	-- Compute impulse scalar
	local impulseScalar = (-(1 + RESTITUTION) * normalVelocity)
	impulseScalar = impulseScalar * obj1.mass + impulseScalar * obj2.mass
	local r1CrossN = r1:Cross(normal)
	local r2CrossN = r2:Cross(normal)
	impulseScalar = impulseScalar + ((obj1.angvel:Cross(r1CrossN)):Dot(normal) +
									(obj2.angvel:Cross(r2CrossN)):Dot(normal))
	impulseScalar = impulseScalar / (r1:LengthSqr() + r2:LengthSqr() + r1CrossN:LengthSqr() + r2CrossN:LengthSqr())
	impulseScalar = impulseScalar * collision.depth
	print("is  ; ", impulseScalar)
	print("cd  ; ", collision.depth)

	-- Apply impulse
	local impulse = normal * impulseScalar

	if not obj1.static then
		obj1.vel = obj1.vel - impulse / obj1.mass
		local sub_imat_1 = mat_TransformInertiaTensor(obj1.inertiaTensor, r1CrossN:Cross(impulse))
		obj1.angvel = obj1.angvel - Vector(sub_imat_1:GetField(1, 1), sub_imat_1:GetField(2, 1), sub_imat_1:GetField(3, 1))
	end

	if not obj2.static then
		obj2.vel = obj2.vel + impulse / obj2.mass
		local sub_imat_2 = mat_TransformInertiaTensor(obj2.inertiaTensor, r2CrossN:Cross(impulse))
		obj2.angvel = obj2.angvel - Vector(sub_imat_2:GetField(1, 1), sub_imat_2:GetField(2, 1), sub_imat_2:GetField(3, 1))
	end

	LK3D.New_D_Print("Resolved collision between \"" .. "a" .. "\" and \"" .. "b" .. "\"", 2, "Physics")
end

local function mat_mul(mat, x)
	return Matrix({
		{mat:GetField(1, 1) * x, mat:GetField(1, 2) * x, mat:GetField(1, 3) * x, mat:GetField(1, 4) * x},
		{mat:GetField(2, 1) * x, mat:GetField(2, 2) * x, mat:GetField(2, 3) * x, mat:GetField(2, 4) * x},
		{mat:GetField(3, 1) * x, mat:GetField(3, 2) * x, mat:GetField(3, 3) * x, mat:GetField(3, 4) * x},
		{mat:GetField(4, 1) * x, mat:GetField(4, 2) * x, mat:GetField(4, 3) * x, mat:GetField(4, 4) * x}
	})
end


local function v_tomat3(vec)
	return Matrix({
		{vec[1], 0, 0, 0},
		{0, vec[2], 0, 0},
		{0, 0, vec[3], 0},
		{0, 0, 0, 1}
	})
end

local function v_to_matrix_angvel(vec)
	return Matrix({
		{0, -vec.z, vec.y, 0},
		{vec.z, 0, -vec.x, 0},
		{-vec.y, vec.x, 0, 0},
		{0, 0, 0, 0}
	})
end

-- Update the positions and rotations of all physics bodies
function LK3D.PhysicsThink()
	local dt = FIXED_TIME_STEP

	local univ = LK3D.CurrUniv["physics"]
	for name1, body1 in pairs(univ) do
		if body1.static then
			continue
		end

		-- Integrate velocity
		if not body1.static then
			body1.vel = body1.vel + GRAVITY * dt
			body1.pos = body1.pos + body1.vel * dt
		end

		-- Integrate angular velocity
		local angularVelocity = v_to_matrix_angvel(body1.angvel * dt)
		local ang = Quaternion.fromRotationMatrix(angularVelocity) * body1.ang
		--print(body1.ang)
		--print(ang)
		--print(angularVelocity)
		--body1.ang = ang

		-- Detect and resolve collisions
		for name2, body2 in pairs(univ) do
			if (name1 ~= name2) then
				local collision = detectCollision(body1, body2)
				if (collision) then
					resolveCollision(body1, body2, collision)
				end
			end
		end
	end
end