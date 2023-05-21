-- Written by discord AI
include("lk3d_quaternion.lua")
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

LK3D_COLLVOLUME_AABB = 1
LK3D_COLLVOLUME_OBB = 2
LK3D_COLLVOLUME_SPHERE = 4
LK3D_COLLVOLUME_INVALID = 256

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
		static = false,
		bound_vol = LK3D_COLLVOLUME_OBB
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



--[[

-- https://github.com/Another-Ghost/3D-Collision-Detection-and-Resolution-Using-GJK-and-EPA/

local support_func_lut = {
	[LK3D_COLLVOLUME_OBB] = function(search_dir, pos, ang_matrix)
		local invr_ang = ang_matrix:GetInverse()
		local local_dir = transform.GetInvRotMatrix() * search_dir //find support in model space

		Vector3 result;
		result.x = (local_dir.x > 0) ? halfSizes.x : -halfSizes.x;
		result.y = (local_dir.y > 0) ? halfSizes.y : -halfSizes.y;
		result.z = (local_dir.z > 0) ? halfSizes.z : -halfSizes.z;

		return transform.GetRotMatrix() * result + transform.GetPosition(); //convert support to world space
	end
}

local function calculate_search_point(point, search_dir, obj1, obj2)
	local obj2_ang_matrix = obj2.ang:toMat3()
	local fine, ret = pcall(support_func_lut[obj2.bound_vol], search_dir, obj2.pos, obj2_ang_matrix)
	if not fine then
		print("LK3DPHYS BoundVolume error!", ret, obj2)
	end
	point.b = ret

	local obj1_ang_matrix = obj1.ang:toMat3()
	local fine, ret = pcall(support_func_lut[obj1.bound_vol], -search_dir, obj1.pos, obj1_ang_matrix)
	if not fine then
		print("LK3DPHYS BoundVolume error!", ret, obj1)
	end
	point.a = ret


	point.p = point.b - point.a
end

local function gjk_calculation(obj1, obj2, coll_nfo)
	coll_nfo.a = obj1
	coll_nfo.b = obj2

	local mtv = Vector()

	local obj1Pos = obj1.pos
	local obj2Pos = obj2.pos


	local a, b, c, d --Simplex: just a set of points (a is always most recently added)
	local search_dir = obj1Pos - obj2Pos --initial search direction between colliders

	--Get initial point for simplex
	--Point c;
	CalculateSearchPoint(c, search_dir, obj1, obj2);
	search_dir = -c.p; //search in direction of origin

	//Get second point for a line segment simplex
	//Point b;
	CalculateSearchPoint(b, search_dir, obj1, obj2);

	if (Vector3::Dot(b.p, search_dir) < 0) {
		return false;
	}//we didn't reach the origin, won't enclose it

	search_dir = Vector3::Cross(Vector3::Cross(c.p - b.p, -b.p), c.p - b.p); //search perpendicular to line segment towards origin
	if (search_dir == Vector3(0, 0, 0)) { //origin is on this line segment
		//Apparently any normal search vector will do?
		search_dir = Vector3::Cross(c.p - b.p, Vector3(1, 0, 0)); //normal with x-axis
		if (search_dir == Vector3(0, 0, 0))
			search_dir = Vector3::Cross(c.p - b.p, Vector3(0, 0, -1)); //normal with z-axis
	}
	int simp_dim = 2; //simplex dimension

	for (int iterations = 0; iterations < GJK_MAX_NUM_ITERATIONS; iterations++)
	{
		//Point a;
		CalculateSearchPoint(a, search_dir, obj1, obj2);

		if (Vector3::Dot(a.p, search_dir) < 0) {
			return false;
		}//we didn't reach the origin, won't enclose it

		simp_dim++;
		if (simp_dim == 3) {
			update_simplex3(a, b, c, d, simp_dim, search_dir);
		}
		else if (update_simplex4(a, b, c, d, simp_dim, search_dir)) {
			EPA(a, b, c, d, obj1, obj2, collisionInfo);
			return true;
		}
	}//endfor

	return false
end
]]--

local function detectCollision(obj1, obj2)
	local coll_nfo = {}


end

local function resolveCollision(obj1, obj2, coll)

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