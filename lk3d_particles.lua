LK3D = LK3D or {}

-----------------------------
-- Particle system
-----------------------------

LK3D.Particles = LK3D.Particles or {}
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

function LK3D.AddParticleEmmiter(name, typeg, prop)
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

function LK3D.UpdateParticleEmmiterProp(name, key, val)
	local pe = LK3D.CurrUniv["particles"][name]
	if not pe then
		return
	end
	pe.prop[key] = val
end

function LK3D.RemoveActiveParticles(name)
	local pe = LK3D.CurrUniv["particles"][name]
	if not pe then
		return
	end

	pe.activeParticles = {}
end

function LK3D.RemoveParticleEmmiter(name)
	if LK3D.CurrUniv["particles"][name] then
		LK3D.CurrUniv["particles"][name] = nil
	end
end


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