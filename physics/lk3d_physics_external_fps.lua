--[[--
## Pure-lua physics engine, powered by [FPS](https://github.com/0x1ED1CE/FPS)
---

Module that simulates rigidbody physics on the client completely without using any source-engine features  
This internally just binds to [Free Physics Solver](https://github.com/0x1ED1CE/FPS), translating GMod types into its format & viceversa    
It also currently only simulates boxes, although convex mesh support might be added at some point  
]]
-- @module physics
LK3D = LK3D or {}
--[[
	LK3D physics (External)
	This module translates LK3D physics calls into FPS (https://github.com/0x1ED1CE/FPS) calls
]]--

local fps = include("external/fps/init.lua")

local function initPhysicsWorld(univ)
	if univ["physics_fps"] then
		return
	end

	local world = fps.world.new()
	local solver = fps.solvers.rigid
	world:add_solver(solver)

	univ["physics_fps"] = world

	univ["physics_objects"] = {}
	univ["physics_colliders"] = {}

	return univ["physics_fps"]
end

local function getPhysicsWorld(univ)
	return univ["physics_fps"]
end

local function addBodyToWorld(body)
	local pUniv = getPhysicsWorld(LK3D.CurrUniv)
	if not pUniv then
		pUniv = initPhysicsWorld(LK3D.CurrUniv)
	end

	pUniv:add_body(body)
end

local function removeBodyFromWorld(body)
	local pUniv = getPhysicsWorld(LK3D.CurrUniv)
	if not pUniv then
		pUniv = initPhysicsWorld(LK3D.CurrUniv)
	end

	pUniv:remove_body(body)
end


local BOX_VERTS = {
	 1,  1, -1,
	 1, -1, -1,
	 1,  1,  1,
	 1, -1,  1,
	-1,  1, -1,
	-1, -1, -1,
	-1,  1,  1,
	-1, -1,  1,
}

local BOX_FACES = {
	5, 3, 1,
	3, 8, 4,
	7, 6, 8,
	2, 8, 6,
	1, 4, 2,
	5, 2, 6,
	5, 7, 3,
	3, 7, 8,
	7, 5, 6,
	2, 4, 8,
	1, 3, 4,
	5, 1, 2,
}



local function getBoxShape(size)
	local recalculatedVertices = {}
	for i = 1, #BOX_VERTS, 3 do
		recalculatedVertices[i] = BOX_VERTS[i] * size[1]
		recalculatedVertices[i + 1] = BOX_VERTS[i + 1] * size[2]
		recalculatedVertices[i + 2] = BOX_VERTS[i + 2] * size[3]
	end


	local recalculatedFaces = {}
	for i = 1, #BOX_FACES, 3 do
		recalculatedFaces[i] = BOX_FACES[i]
		recalculatedFaces[i + 1] = BOX_FACES[i + 1]
		recalculatedFaces[i + 2] = BOX_FACES[i + 2]
	end

	return fps.shape.new(recalculatedVertices, BOX_FACES)
end

local function getBoxCollider(size)
	local coll = fps.collider.new()
	coll:set_shape(getBoxShape(size))
	coll:set_restitution(0.55)
	--coll:set_friction(0.5)

	return coll
end

--- Sets the gravity of the active universe
-- @tparam vector grav Gravity
-- @usage LK3D.SetUnivGravity(Vector(0, 0, -100)) -- downwards gravity
function LK3D.SetUnivGravity(grav)
	local pUniv = getPhysicsWorld(LK3D.CurrUniv)
	if not pUniv then
		pUniv = initPhysicsWorld(LK3D.CurrUniv)
	end


	pUniv:set_gravity(grav[1], grav[2], grav[3])
end

--- Gets the gravity of the active universe
-- @treturn vector Gravity of the active universe, nil if the physics universe is not initialized
-- @usage local grav = LK3D.SetUnivGravity()
function LK3D.GetUnivGravity()
	local pUniv = getPhysicsWorld(LK3D.CurrUniv)
	if not pUniv then
		pUniv = initPhysicsWorld(LK3D.CurrUniv)
	end


	local gx, gy, gz = pUniv:get_gravity()
	return Vector(gx, gy, gz)
end

--- Gets a physics body by name
-- @internal
-- @tparam string name Index name of the physics body
-- @treturn table PhysicsBody, nil if not found
-- @usage local physObj = LK3D.GetPhysicsBodyFromName("phys_lk")
function LK3D.GetPhysicsBodyFromName(name)
	if not LK3D.CurrUniv["physics_objects"] then
		return
	end

	return LK3D.CurrUniv["physics_objects"][name]
end

--- Gets the collider of the physics body by name
-- @internal
-- @tparam string name Index name of the physics body
-- @treturn table PhysicsCollider, nil if not found
-- @usage local physObj = LK3D.GetPhysicsColliderFromName("phys_lk")
function LK3D.GetPhysicsColliderFromName(name)
	if not LK3D.CurrUniv["physics_colliders"] then
		return
	end

	return LK3D.CurrUniv["physics_colliders"][name]
end

--- Adds a physics body to the active universe
-- @tparam string name Index name of the physics body
-- @usage LK3D.AddPhysicsBodyToUniv("phys_lk")
function LK3D.AddPhysicsBodyToUniv(name)
	if not getPhysicsWorld(LK3D.CurrUniv) then
		pUniv = initPhysicsWorld(LK3D.CurrUniv)
	end

	local body = fps.body.new()
	body._lkScale = Vector(1, 1, 1)


	local coll = getBoxCollider(Vector(1, 1, 1))
	coll:set_density(1)
	body:add_collider(coll)
	body:set_responsive(true)

	LK3D.CurrUniv["physics_objects"][name] = body
	LK3D.CurrUniv["physics_colliders"][name] = coll

	addBodyToWorld(body)
end

--- Sets whether a physics body is static or not
-- @tparam string name Index name of the physics body
-- @tparam bool static Whether the physics body should be static or not
-- @usage LK3D.SetPhysicsBodyStatic("phys_lk_floor", true)
function LK3D.SetPhysicsBodyStatic(name, static)
	local body = LK3D.GetPhysicsBodyFromName(name)
	if not body then
		return
	end

	body:set_static(static)
end

--- Gets whether a physics body is static or not
-- @tparam string name Index name of the physics body
-- @treturn bool Whether the physics body is static or not, nil if not found
-- @usage local static = LK3D.GetPhysicsBodyStatic("phys_lk_floor")
function LK3D.GetPhysicsBodyStatic(name)
	local body = LK3D.GetPhysicsBodyFromName(name)
	if not body then
		return
	end

	return body.static
end

--- Sets the mass of the physics body
-- @tparam string name Index name of the physics body
-- @tparam number mass Mass to set the physics body to
-- @usage LK3D.SetPhysicsBodyMass("phys_lk", 16)
function LK3D.SetPhysicsBodyMass(name, mass)
	local coll = LK3D.GetPhysicsColliderFromName(name)
	if not coll then
		return
	end

	coll:set_density(mass)
end

--- Gets the mass of the physics body
-- @tparam string name Index name of the physics body
-- @treturn number Mass of the physics body, nil if not found
-- @usage local mass = LK3D.GetPhysicsBodyMass("phys_lk")
function LK3D.GetPhysicsBodyMass(name)
	local body = LK3D.GetPhysicsBodyFromName(name)
	if not body then
		return
	end

	return body:get_mass()
end

--- Sets the position of the physics body
-- @tparam string name Index name of the physics body
-- @tparam vector pos Position to set the physics body to
-- @usage LK3D.SetPhysicsBodyPos("phys_lk_floor", Vector(0, 0, -4))
function LK3D.SetPhysicsBodyPos(name, pos)
	local body = LK3D.GetPhysicsBodyFromName(name)
	if not body then
		return
	end


	body:set_position(pos[1], pos[2], pos[3])
end

--- Gets the position of the physics body
-- @tparam string name Index name of the physics body
-- @treturn vector Position of the physics body, nil if not found
-- @usage local bPos = LK3D.GetPhysicsBodyPos("phys_lk")
function LK3D.GetPhysicsBodyPos(name)
	local body = LK3D.GetPhysicsBodyFromName(name)
	if not body then
		return
	end

	return body:get_position()
end

--- Sets the angle of the physics body
-- @tparam string name Index name of the physics body
-- @tparam angle ang Angle to set the physics body to
-- @usage LK3D.SetPhysicsBodyAng("phys_lk_floor", Angle(25, 0, 0))
function LK3D.SetPhysicsBodyAng(name, ang)
	local body = LK3D.GetPhysicsBodyFromName(name)
	if not body then
		return
	end

	local matAng = Matrix()
	matAng:SetAngles(ang)

	local m1x1, m2x1, m3x1, m4x1,
		  m1x2, m2x2, m3x2, m4x2,
		  m1x3, m2x3, m3x3, m4x3,
		  m1x4, m2x4, m3x4, m4x4 = matAng:Unpack() --fps.matrix4.from_euler(ang[1], ang[2], ang[3])

	local pX, pY, pZ = body:get_position()
	--mat[ 4] = pX
	--mat[ 8] = pY
	--mat[12] = pZ

	body:set_transform(
		m1x1, m2x1, m3x1, pX,
		m1x2, m2x2, m3x2, pY,
		m1x3, m2x3, m3x3, pZ,
		m1x4, m2x4, m3x4, m4x4
	)
end

--- Gets the angle of the physics body  
-- @warning This function is currently unimplemented
-- @tparam string name Index name of the physics body
-- @treturn nil nothing, unimplemented
-- @usage local nothing = LK3D.GetPhysicsBodyAng("phys_lk")
function LK3D.GetPhysicsBodyAng(name)
	local body = LK3D.GetPhysicsBodyFromName(name)
	if not body then
		return
	end

	return
end

--- Sets the transform matrix of the physics body
-- @tparam string name Index name of the physics body
-- @tparam matrix mat Transform [VMatrix](https://wiki.facepunch.com/gmod/VMatrix)
-- @usage local matTransform = Matrix()
-- matTransform:SetTranslation(Vector(0, 0, 4))
-- matTransform:SetAngles(Angle(45, 25, 15))
-- LK3D.SetPhysicsBodyMatrix("phys_lk", matTransform)
function LK3D.SetPhysicsBodyMatrix(name, mat)
	local body = LK3D.GetPhysicsBodyFromName(name)
	if not body then
		return
	end

	body:set_transform(
		mat:GetField(1, 1), mat:GetField(2, 1), mat:GetField(3, 1), mat:GetField(4, 1),
		mat:GetField(1, 2), mat:GetField(2, 2), mat:GetField(3, 2), mat:GetField(4, 2),
		mat:GetField(1, 3), mat:GetField(2, 3), mat:GetField(3, 3), mat:GetField(4, 3),
		mat:GetField(1, 4), mat:GetField(2, 4), mat:GetField(3, 4), mat:GetField(4, 4)
	)
end

--- Gets the transform matrix of the physics body
-- @tparam string name Index name of the physics body
-- @treturn matrix Transform matrix of the physics body
-- @usage local matTransform = LK3D.GetPhysicsBodyMatrix("phys_lk")
function LK3D.GetPhysicsBodyMatrix(name)
	local body = LK3D.GetPhysicsBodyFromName(name)
	if not body then
		return
	end

	local m1x1, m2x1, m3x1, m4x1,
		  m1x2, m2x2, m3x2, m4x2,
		  m1x3, m2x3, m3x3, m4x3,
		  m1x4, m2x4, m3x4, m4x4 = body:get_transform()


	return Matrix({
		{m1x1, m2x1, m3x1, m4x1},
		{m1x2, m2x2, m3x2, m4x2},
		{m1x3, m2x3, m3x3, m4x3},
		{m1x4, m2x4, m3x4, m4x4},
	})
end



--- Sets the position and angle of the physics body
-- @tparam string name Index name of the physics body
-- @tparam vector pos Position to set the physics body to
-- @tparam angle ang Angle to set the physics body to
-- @usage LK3D.SetPhysicsBodyPosAng("phys_lk", Vector(0, 0, 4), Angle(45, 25, 15))
function LK3D.SetPhysicsBodyPosAng(name, pos, ang)
	LK3D.SetPhysicsBodyPos(name, pos)
	LK3D.SetPhysicsBodyAng(name, ang)
end

--- Sets the scale of the physics body
-- @tparam string name Index name of the physics body
-- @tparam vector scl Scale to set the physics body to
-- @usage LK3D.SetPhysicsBodyScl("phys_lk_floor", Vector(16, 16, 1)) -- large objects are buggy on FPS, avoid this
function LK3D.SetPhysicsBodyScl(name, scl)
	local coll = LK3D.GetPhysicsColliderFromName(name)
	if not coll then
		return
	end

	local body = LK3D.GetPhysicsBodyFromName(name)
	if not body then
		return
	end

	--local newShape = getBoxShape(scl)
	--coll:set_shape(newShape)
	coll:set_size(scl[1], scl[2], scl[3])


	--body:update_mass()
	--body:update_boundary()


	body._lkScale = scl
end

--- Gets the scale of the physics body
-- @tparam string name Index name of the physics body
-- @treturn vector Scale of the physics body
-- @usage local scl = LK3D.GetPhysicsBodyScl("phys_lk_floor")
function LK3D.GetPhysicsBodyScl(name)
	local body = LK3D.GetPhysicsBodyFromName(name)
	if not body then
		return
	end

	return body._lkScale
end


--- Sets the velocity of the physics body
-- @tparam string name Index name of the physics body
-- @tparam vector vel Velocity to set the physics body to
-- @usage LK3D.SetPhysicsBodyVel("phys_lk", Vector(0, 0, 4)) -- up
function LK3D.SetPhysicsBodyVel(name, vel)
	local body = LK3D.GetPhysicsBodyFromName(name)
	if not body then
		return
	end


	body:set_velocity(vel[1], vel[2], vel[3])
end

--- Gets the AABB of the physics body
-- @tparam string name Index name of the physics body
-- @treturn table AABB table, refer to usage
-- @usage local aabb = LK3D.GetPhysicsBodyBoundary("phys_lk")
-- local mins = aabb[1]
-- local maxs = aabb[2]
function LK3D.GetPhysicsBodyBoundary(name)
	local body = LK3D.GetPhysicsBodyFromName(name)
	if not body then
		return
	end

	local bounds = body.boundary

	return {
		Vector(bounds[1], bounds[2], bounds[3]),
		Vector(bounds[4], bounds[5], bounds[6])
	}
end


--- Removes a physics body from the active universe
-- @tparam string name Index name of the physics body
-- @usage LK3D.RemovePhysicsBodyFromUniv("phys_lk")
function LK3D.RemovePhysicsBodyFromUniv(name)
	if not getPhysicsWorld(LK3D.CurrUniv) then
		initPhysicsWorld(LK3D.CurrUniv)
	end
	local body = LK3D.GetPhysicsBodyFromName(name)
	if not body then
		return
	end

	removeBodyFromWorld(body)
end

local function drawDebugAABB(aabb)
	LK3D.DebugUtils.Cross(aabb[1], .15, .05, Color(255, 0, 0))
	LK3D.DebugUtils.Cross(aabb[2], .15, .05, Color(0, 255, 0))

	LK3D.DebugUtils.Line(aabb[1], Vector(aabb[1].x, aabb[1].y, aabb[2].z), .05, Color(255, 255, 0))
	LK3D.DebugUtils.Line(aabb[1], Vector(aabb[1].x, aabb[2].y, aabb[1].z), .05, Color(255, 255, 0))
	LK3D.DebugUtils.Line(aabb[1], Vector(aabb[2].x, aabb[1].y, aabb[1].z), .05, Color(255, 255, 0))

	LK3D.DebugUtils.Line(aabb[2], Vector(aabb[2].x, aabb[2].y, aabb[1].z), .05, Color(255, 255, 0))
	LK3D.DebugUtils.Line(aabb[2], Vector(aabb[2].x, aabb[1].y, aabb[2].z), .05, Color(255, 255, 0))
	LK3D.DebugUtils.Line(aabb[2], Vector(aabb[1].x, aabb[2].y, aabb[2].z), .05, Color(255, 255, 0))

	LK3D.DebugUtils.Line(Vector(aabb[2].x, aabb[1].y, aabb[1].z), Vector(aabb[2].x, aabb[2].y, aabb[1].z), .05, Color(255, 255, 0))
	LK3D.DebugUtils.Line(Vector(aabb[2].x, aabb[1].y, aabb[1].z), Vector(aabb[2].x, aabb[1].y, aabb[2].z), .05, Color(255, 255, 0))

	LK3D.DebugUtils.Line(Vector(aabb[1].x, aabb[2].y, aabb[1].z), Vector(aabb[1].x, aabb[2].y, aabb[2].z), .05, Color(255, 255, 0))
	LK3D.DebugUtils.Line(Vector(aabb[1].x, aabb[2].y, aabb[1].z), Vector(aabb[2].x, aabb[2].y, aabb[1].z), .05, Color(255, 255, 0))

	LK3D.DebugUtils.Line(Vector(aabb[1].x, aabb[2].y, aabb[2].z), Vector(aabb[1].x, aabb[1].y, aabb[2].z), .05, Color(255, 255, 0))
	LK3D.DebugUtils.Line(Vector(aabb[1].x, aabb[1].y, aabb[2].z), Vector(aabb[2].x, aabb[1].y, aabb[2].z), .05, Color(255, 255, 0))
end




local debugObjects = {}
function LK3D.DebugRenderPhysicsObjects()
	for k, v in pairs(LK3D.CurrUniv["physics_objects"]) do
		if LK3D.GetPhysicsBodyStatic(k) then
			continue
		end


		if not LK3D.CurrUniv["objects"][k] then
			LK3D.AddObjectToUniverse(k, "cube_nuv")
			LK3D.SetObjectMat(k, "checker")
			LK3D.SetObjectPosAng(k, Vector(0, 0, 0), Angle(0, 0, 0))
			LK3D.SetObjectScale(k, LK3D.GetPhysicsBodyScl(k) * 0.5)
			LK3D.SetObjectFlag(k, "NO_SHADING", true)
			LK3D.SetObjectFlag(k, "NO_LIGHTING", true)
			LK3D.SetObjectFlag(k, "CONSTANT", true)
			LK3D.SetObjectFlag(k, "SHADING_SMOOTH", false)
			LK3D.SetObjectFlag(k, "COL_LIT", true)


			--LK3D.PushObjectAnims(k, "acube")
			--LK3D.SetObjectAnim(k, "wiggle")
			--LK3D.SetObjectAnimRate(k, .15)


			debugObjects[k] = true
		end

		local mat = LK3D.GetPhysicsBodyMatrix(k)


		LK3D.SetObjectPosAng(k, mat:GetTranslation(), mat:GetAngles())
		--local bounds = LK3D.GetPhysicsBodyBoundary(k)
		--drawDebugAABB(bounds)
	end

	for k, v in pairs(debugObjects) do
		if LK3D.CurrUniv["physics_objects"][k] == nil then
			LK3D.RemoveObjectFromUniverse(k)
			debugObjects[k] = nil
		end
	end
end





local physItr = 5
function LK3D.PhysicsThink()
	local dt = 1 / 600--FrameTime() * .25

	local pWorld = getPhysicsWorld(LK3D.CurrUniv)
	if not pWorld then
		return
	end

	for i = 1, physItr do
		pWorld:step(dt / physItr)
	end
end