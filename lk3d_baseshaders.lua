LK3D = LK3D or {}
LK3D.Shaders = LK3D.Shaders or {}
-- misc. shaders i guess for stuff


function LK3D.SetObjectPrefabShader(obj, shader)
	if not shader then
		return
	end

	if string.lower(shader) == "none" then
		LK3D.SetObjectFlag(obj, "VERT_SH_PARAMS", nil)
		LK3D.SetObjectFlag(obj, "VERT_SHADER", nil)
		return
	end

	if not LK3D.CurrUniv["objects"][obj] then
		LK3D.New_D_Print("No object \"" .. obj .. "\"!", LK3D_SEVERITY_ERROR, "LK3D")
		return
	end


	if not LK3D.Shaders[shader] then
		LK3D.New_D_Print("No shader \"" .. shader .. "\"!", LK3D_SEVERITY_ERROR, "LK3D")
		return
	end

	LK3D.SetObjectFlag(obj, "VERT_SH_PARAMS", LK3D.Shaders[shader].sh_params)
	LK3D.SetObjectFlag(obj, "VERT_SHADER", LK3D.Shaders[shader].sh_func)
end

function LK3D.SetModelPrefabShader(obj, shader)
	LK3D.New_D_Print("Using deprecated function LK3D.SetModelPrefabShader(), use LK3D.SetObjectPrefabShader()", LK3D_SEVERITY_WARN, "LK3D")
	LK3D.SetObjectPrefabShader(obj, shader)
end


local function reflect(I, N) -- Reflects an incidence vector I about the normal N -- from https://github.com/Derpius/VisTrace/blob/master/Examples/StarfallEx/vistrace_laser.txt
	return I - 2 * N.Dot(N, I) * N
end


LK3D.Shaders["reflective"] = {
	sh_params = {
		[1] = false, -- vpos
		[2] = true, -- vuv
		[3] = false, -- vrgb
		[4] = true, -- shader obj ref
		[5] = true, -- vnorm
	},
	sh_func = function(vpos, vuv, vrgb, vnorm)
		local objref = LK3D.SHADER_OBJREF
		local vpos_c = vpos * objref.scl
		vpos_c:Rotate(objref.ang)
		vpos_c:Add(objref.pos)
		local v_dir = (vpos_c - LK3D.CamPos)
		v_dir:Normalize()

		-- reflect mapping
		local r = reflect(v_dir, vnorm)

		local m = 2 * math.sqrt(
			math.pow(r.x, 2) +
			math.pow(r.y, 2) +
			math.pow(r.z + 1, 2)
		)
		local u = r.x / m + .5
		local v = r.y / m + .5

		vuv[1] = u
		vuv[2] = v
	end
}


LK3D.Shaders["reflective_simple"] = {
	sh_params = {
		[1] = false, -- vpos
		[2] = true, -- vuv
		[3] = false, -- vrgb
		[4] = true, -- shader obj ref
		[5] = true, -- vnorm
	},
	sh_func = function(vpos, vuv, vrgb, vnorm)
		local objref = LK3D.SHADER_OBJREF
		local v_dir = (objref.pos - LK3D.CamPos)
		v_dir:Normalize()

		-- reflect mapping
		local r = reflect(v_dir, vnorm)

		local m = 2 * math.sqrt(
			math.pow(r.x, 2) +
			math.pow(r.y, 2) +
			math.pow(r.z + 1, 2)
		)
		local u = r.x / m + .5
		local v = r.y / m + .5

		vuv[1] = u
		vuv[2] = v
	end
}

LK3D.Shaders["specular"] = {
	sh_params = {
		[1] = false, -- vpos
		[2] = false, -- vuv
		[3] = true, -- vrgb
		[4] = true, -- shader obj ref
		[5] = true, -- vnorm
	},
	sh_func = function(vpos, vuv, vrgb, vnorm)
		local objref = LK3D.SHADER_OBJREF
		local vpos_c = vpos * objref.scl
		vpos_c:Rotate(objref.ang)
		vpos_c:Add(objref.pos)
		local v_dir = (vpos_c - LK3D.CamPos)
		v_dir:Normalize()


		local speci_add_r = 0
		local speci_add_g = 0
		local speci_add_b = 0

		for k, v in pairs(LK3D.CurrUniv["lights"]) do
			local light_dir_relat = (v[1] - objref.pos)
			light_dir_relat:Normalize()

			local d = objref.pos:DistToSqr(v[1]) * .5

			if d > 64 then
				continue
			end

			if vnorm:Dot(light_dir_relat) <= 0 then
				continue
			end

			local col_l = v[3]
			local inten_l = v[2]

			local sf = math.max(0, math.pow(vnorm:Dot(light_dir_relat), 48) / d)

			speci_add_r = speci_add_r + (sf * 96) * col_l[1] * inten_l
			speci_add_g = speci_add_g + (sf * 96) * col_l[2] * inten_l
			speci_add_b = speci_add_b + (sf * 96) * col_l[3] * inten_l
		end

		vrgb[1] = math.min(vrgb[1] + speci_add_r, 255)
		vrgb[2] = math.min(vrgb[2] + speci_add_g, 255)
		vrgb[3] = math.min(vrgb[3] + speci_add_b, 255)
	end
}


LK3D.Shaders["norm_vis"] = {
	sh_params = {
		[1] = false, -- vpos
		[2] = false, -- vuv
		[3] = true, -- vrgb
		[4] = true, -- shader obj ref
		[5] = true, -- vnorm
	},
	sh_func = function(vpos, vuv, vrgb, vnorm)
		local objref = LK3D.SHADER_OBJREF
		local v_nrot = Vector(vnorm)
		v_nrot:Rotate(-objref.ang)


		vrgb[1] = (v_nrot[1] + 1) * 128
		vrgb[2] = (v_nrot[2] + 1) * 128
		vrgb[3] = (v_nrot[3] + 1) * 128
	end
}



LK3D.Shaders["norm_vis_rot"] = {
	sh_params = {
		[1] = false, -- vpos
		[2] = false, -- vuv
		[3] = true, -- vrgb
		[4] = false, -- shader obj ref
		[5] = true, -- vnorm
	},
	sh_func = function(vpos, vuv, vrgb, vnorm)
		vrgb[1] = (vnorm[1] + 1) * 128
		vrgb[2] = (vnorm[2] + 1) * 128
		vrgb[3] = (vnorm[3] + 1) * 128
	end
}





LK3D.Shaders["norm_screenspace"] = {
	sh_params = {
		[1] = false, -- vpos
		[2] = false, -- vuv
		[3] = true, -- vrgb
		[4] = true, -- shader obj ref
		[5] = true, -- vnorm
	},
	sh_func = function(vpos, vuv, vrgb, vnorm)
		local objref = LK3D.SHADER_OBJREF
		local v_dir = (objref.pos - LK3D.CamPos)
		v_dir:Normalize()

		local v_nrot = Vector(vnorm)
		v_nrot:Rotate(-v_dir:Angle())


		vrgb[1] = (v_nrot[1] + 1) * 128
		vrgb[2] = (v_nrot[2] + 1) * 128
		vrgb[3] = (v_nrot[3] + 1) * 128
	end
}

LK3D.Shaders["norm_screenspace_rot"] = {
	sh_params = {
		[1] = false, -- vpos
		[2] = false, -- vuv
		[3] = true, -- vrgb
		[4] = false, -- shader obj ref
		[5] = true, -- vnorm
	},
	sh_func = function(vpos, vuv, vrgb, vnorm)
		local v_nrot = Vector(vnorm)
		v_nrot:Rotate(Angle(0, -LK3D.CamAng[2], 0))
		v_nrot:Rotate(Angle(-LK3D.CamAng[1], 0, 0))
		v_nrot:Normalize()


		vrgb[1] = (v_nrot[1] + 1) * 128
		vrgb[2] = (v_nrot[2] + 1) * 128
		vrgb[3] = (v_nrot[3] + 1) * 128
	end
}


LK3D.Shaders["world_pos"] = {
	sh_params = {
		[1] = true, -- vpos
		[2] = false, -- vuv
		[3] = true, -- vrgb
		[4] = true, -- shader obj ref
		[5] = false, -- vnorm
	},
	sh_func = function(vpos, vuv, vrgb, vnorm)
		local obj_nfo = LK3D.SHADER_OBJREF
		local vp_world = Vector(vpos)
		vp_world = obj_nfo.tmatrix * vp_world


		vrgb[1] = (vp_world[1] + 8) * 15
		vrgb[2] = (vp_world[2] + 8) * 15
		vrgb[3] = (vp_world[3] + 8) * 15

		vrgb[1] = math.max(math.min(vrgb[1], 255), 0)
		vrgb[2] = math.max(math.min(vrgb[2], 255), 0)
		vrgb[3] = math.max(math.min(vrgb[3], 255), 0)
	end
}

LK3D.Shaders["world_pos_local"] = {
	sh_params = {
		[1] = true, -- vpos
		[2] = false, -- vuv
		[3] = true, -- vrgb
		[4] = false, -- shader obj ref
		[5] = false, -- vnorm
	},
	sh_func = function(vpos, vuv, vrgb, vnorm)
		local obj_nfo = LK3D.SHADER_OBJREF
		local vp_world = Vector(vpos)
		vp_world = obj_nfo.tmatrix * vp_world
		vp_world:Sub(LK3D.CamPos)


		vrgb[1] = (vp_world[1] + 8) * 15
		vrgb[2] = (vp_world[2] + 8) * 15
		vrgb[3] = (vp_world[3] + 8) * 15

		vrgb[1] = math.max(math.min(vrgb[1], 255), 0)
		vrgb[2] = math.max(math.min(vrgb[2], 255), 0)
		vrgb[3] = math.max(math.min(vrgb[3], 255), 0)
	end
}





LK3D.Shaders["vert_col"] = {
	sh_params = {
		[1] = false, -- vpos
		[2] = false, -- vuv
		[3] = true, -- vrgb
		[4] = false, -- shader obj ref
		[5] = true, -- vnorm
	},
	sh_func = function(vpos, vuv, vrgb, vnorm)
		local ctr = LK3D.SHADER_VERTINDEX
		local c = HSVToColor(ctr * 1, 1, 1)

		vrgb[1] = c.r
		vrgb[2] = c.g
		vrgb[3] = c.b
	end
}



local rnd = 0
local rnd2 = 0
LK3D.Shaders["ps1"] = {
	sh_params = {
		[1] = true, -- vpos
		[2] = true, -- vuv
		[3] = false, -- vrgb
		[4] = true, -- shader obj ref
		[5] = false, -- vnorm
	},
	sh_func = function(vpos, vuv, vrgb, vnorm)
		local objref = LK3D.SHADER_OBJREF
		local r_pos = Vector(vpos)

		local pf = Vector(objref.pos)
		pf[1] = math.Round(pf[1] / objref.scl[1], rnd2)
		pf[2] = math.Round(pf[2] / objref.scl[2], rnd2)
		pf[3] = math.Round(pf[3] / objref.scl[3], rnd2)


		local af = Angle(objref.ang)
		af[1] = math.Round(af[1], rnd2)
		af[2] = math.Round(af[2], rnd2)
		af[3] = math.Round(af[3], rnd2)

		r_pos:Rotate(af)
		r_pos:Add(pf)

		r_pos[1] = math.Round(r_pos[1], rnd)
		r_pos[2] = math.Round(r_pos[2], rnd)
		r_pos[3] = math.Round(r_pos[3], rnd)

		r_pos:Sub(pf)
		r_pos:Rotate(-af)

		vpos[1] = r_pos[1]
		vpos[2] = r_pos[2]
		vpos[3] = r_pos[3]
		vpos = vpos * objref.scl

		--vuv[1] = math.Round(vuv[1], 2)
		--vuv[2] = math.Round(vuv[2], 2)
	end
}


LK3D.Shaders["reflective_screen_rot"] = {
	sh_params = {
		[1] = false, -- vpos
		[2] = true, -- vuv
		[3] = false, -- vrgb
		[4] = false, -- shader obj ref
		[5] = true, -- vnorm
	},
	sh_func = function(vpos, vuv, vrgb, vnorm)
		local v_nrot = Vector(vnorm)
		v_nrot:Rotate(Angle(0, -LK3D.CamAng[2], 0))
		v_nrot:Rotate(Angle(-LK3D.CamAng[1], 0, 0))
		v_nrot:Normalize()

		vuv[1] = .5 + math.abs(v_nrot[1])
		vuv[2] = math.abs(v_nrot[2] * .5 + .5)
	end
}



LK3D.Shaders["depth"] = {
	sh_params = {
		[1] = true, -- vpos
		[2] = false, -- vuv
		[3] = true, -- vrgb
		[4] = true, -- shader obj ref
		[5] = false, -- vnorm
	},
	sh_func = function(vpos, vuv, vrgb, vnorm)
		local objref = LK3D.SHADER_OBJREF
		local vertpos = Vector(vpos)

		local worldPos = objref["tmatrix"] * vertpos
		local camPos = WorldToLocal(worldPos, Angle(0, 0, 0), LK3D.CamPos, LK3D.CamAng)
		local dVal = math.min(math.max(camPos[1] / (objref.DEPTH_SH_DIST or 16), 0), 1)

		vrgb[1] = dVal * 255
		vrgb[2] = dVal * 255
		vrgb[3] = dVal * 255
	end
}