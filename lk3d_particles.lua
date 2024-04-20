--[[--
## Manages the particle system
---

Module to declare new particles or create / modify / delete particle emitters on the active universe   
]]
-- @module particles
LK3D = LK3D or {}
LK3D.Particles = LK3D.Particles or {}



--- Declares a new particle type
-- @tparam string name Name of the particle type
-- @tparam table proptbl Table of particle settings  
-- @usage -- Generic example with all property parameters  
--  LK3D.DeclareParticle("snow_square", {
--	  life = 12,
--	  mat = "white",
--  })
function LK3D.DeclareParticle(name, proptbl)
	LK3D.Particles[name] = {
		life = proptbl.life or 2,
		mat = proptbl.mat or "fail",
		islkmat = proptbl.islkmat or true
	}

	LK3D.New_D_Print("Declared particle \"" .. name .. "\"", LK3D_SEVERITY_INFO, "Particles")
end

LK3D.DeclareParticle("fail", {
	life = 2,
	mat = "fail",
	islkmat = true
})

LK3D.DeclareParticle("white", {
	life = 2,
	mat = "white",
	islkmat = true
})

--- Adds a particle emitter to the active universe
-- @tparam string name Name of the particle emitter
-- @tparam string typeg Name of the particle type
-- @tparam table prop Struct holding all of the data for the particle emitter, refer to the usage
-- @usage -- Simple snow particles, extract from PONR
-- LK3D.AddParticleEmitter("snow_emitter", "snow", {
-- 	start_col = {255, 255, 255}, -- start col
-- 	end_col = {255, 255, 255}, -- end cos
-- 	pos = Vector(0, 0, 0), -- position in world space of the emitter
-- 	part_sz = .1, -- start size
-- 	end_sz = .0, -- end size
-- 	max = 200, -- max particle count
-- 	rate = 0.05, -- delta per insert in curtime
-- 	inserts = 1, -- particles to insert per delta
-- 	pos_off_min = Vector(-6.25, -6.25, 8), -- start position offsets
-- 	pos_off_max = Vector(6.25, 6.25, 8.5),
-- 	vel_off_min = Vector(-1.5, -1.5, -10), -- vel offsets
-- 	vel_off_max = Vector(1.5, 1.5, -10.5),
-- 	rotate_range = {-12, 12}, -- rate as to which to rotate in DEGREES
-- 	grav = 0, -- gravity
-- 	lit = true,
-- 	active = true,
-- })
-- 
function LK3D.AddParticleEmitter(name, typeg, prop)
	if prop.start_col and prop.start_col.r then
		local oc = prop.start_col
		prop.start_col = {oc.r, oc.g, oc.b}
	end

	if prop.end_col and prop.end_col.r then
		local oc = prop.end_col
		prop.end_col = {oc.r, oc.g, oc.b}
	end

	LK3D.CurrUniv["particles"][name] = {
		type = typeg,
		prop = prop,
		activeParticles = {}
	}
end

--- Updates a property on the particle emitter
-- @tparam string name Name of the particle emitter
-- @tparam string key Parameter to set on the properties
-- @param val Value to set the parameter to
-- @usage LK3D.UpdateParticleEmitterProp("snow_emitter", "pos", Vector(0, 0, 16))
function LK3D.UpdateParticleEmitterProp(name, key, val)
	local pe = LK3D.CurrUniv["particles"][name]
	if not pe then
		return
	end
	pe.prop[key] = val
end

--- Removes all active particles from a particle emitter
-- @tparam string name Name of the particle emitter
-- @usage LK3D.RemoveActiveParticles("snow_emitter")
function LK3D.RemoveActiveParticles(name)
	local pe = LK3D.CurrUniv["particles"][name]
	if not pe then
		return
	end

	pe.activeParticles = {}
end

--- Removes a particle emitter from the active universe
-- @tparam string name Name of the particle emitter
-- @usage LK3D.RemoveParticleEmitter("snow_emitter")
function LK3D.RemoveParticleEmitter(name)
	if LK3D.CurrUniv["particles"][name] then
		LK3D.CurrUniv["particles"][name] = nil
	end
end


--- Updates all particle emitters on the active universe
-- @usage -- On your think hook
-- LK3D.UpdateParticles()
function LK3D.UpdateParticles()
	for k, v in pairs(LK3D.CurrUniv["particles"]) do
		local prop = v.prop
		local typeData = LK3D.Particles[v.type]

		if CurTime() > (v.nextInsert or 0) and prop.active then
			local xcp_m, xcp_M = prop.pos_off_min[1], prop.pos_off_max[1]
			local ycp_m, ycp_M = prop.pos_off_min[2], prop.pos_off_max[2]
			local zcp_m, zcp_M = prop.pos_off_min[3], prop.pos_off_max[3]

			local xcv_m, xcv_M = prop.vel_off_min[1], prop.vel_off_max[1]
			local ycv_m, ycv_M = prop.vel_off_min[2], prop.vel_off_max[2]
			local zcv_m, zcv_M = prop.vel_off_min[3], prop.vel_off_max[3]

			for i = 1, prop.inserts do
				if #v.activeParticles < prop.max then  -- older particles always delete first so we can use #
					table.insert(v.activeParticles, 1, {
						orig_pos = prop.pos,
						pos_start = Vector(math.Rand(xcp_m, xcp_M), math.Rand(ycp_m, ycp_M), math.Rand(zcp_m, zcp_M)),
						vel_start = Vector(math.Rand(xcv_m, xcv_M), math.Rand(ycv_m, ycv_M), math.Rand(zcv_m, zcv_M)),
						start = CurTime(),
						acc = acc,
						grav = prop.grav,
						rot_mult = math.Rand(prop.rotate_range[1], prop.rotate_range[2])
					})
				else
					break
				end
			end
			v.nextInsert = CurTime() + prop.rate
		end


		local remPost = false
		for partK, part in ipairs(v.activeParticles) do
			if remPost then
				v.activeParticles[partK] = nil
				continue
			end

			if not typeData then
				return
			end

			local expLife = part.start + typeData.life
			if CurTime() >= expLife then
				v.activeParticles[partK] = nil
				remPost = true
			end
		end
	end
end