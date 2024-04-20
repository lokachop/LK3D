LK3D = LK3D or {}

-----------------------------
-- Benchmarking
-----------------------------
local function b_print(...)
	MsgC(Color(100, 255, 255), "[LK3D:BENCHMARK]: ", Color(200, 255, 255), ..., "\n")
end


local function makeLitPlane()
	LK3D.AddObjectToUniverse("plane_hd", "plane_hp")
	LK3D.SetObjectPos("plane_hd", Vector(0, 0, 0))
	LK3D.SetObjectScale("plane_hd", Vector(1, 1, 1))
	LK3D.SetObjectCol("plane_hd", Color(255, 255, 255))
	LK3D.SetObjectAng("plane_hd", Angle(0, 0, 90))
	--LK3D.SetObjectFlag("plane_hd", "NO_VW_CULLING", true)

	LK3D.AddLight("light1_test", Vector(0, .225, 0), 0.6, Color(255, 0, 0))
	LK3D.AddLight("light2_test", Vector(.225, -.225, 0), 0.6, Color(0, 255, 0))
	LK3D.AddLight("light3_test", Vector(-.225, -.225, 0), 0.6, Color(0, 0, 255))
end

local function makeHell(shaded, lit, opti)
	local det = 8
	for i = 0, (det * det) - 1 do
		local x = (i % det) - (det / 2)
		local y = math.floor(i / det) - (det / 2)

		local nm = "plyhell_" .. i
		local col = HSVToColor((i / (det * det)) * 360, 1, 1)

		LK3D.AddObjectToUniverse(nm, "playeropti")
		LK3D.SetObjectPos(nm, Vector(x / (det * .5), y / (det * .5), 0))
		LK3D.SetObjectScale(nm, Vector(.005, .005, .005))
		LK3D.SetObjectCol(nm, col)
		LK3D.SetObjectFlag(nm, "NO_SHADING", not shaded)
		LK3D.SetObjectFlag(nm, "NO_LIGHTING", not lit)
		LK3D.SetObjectFlag(nm, "CONSTANT", opti or false)
	end
end

local function makeEmitter(lit)
	LK3D.AddParticleEmitter("test1", "white", {
		pos = Vector(0, 0, 0),
		part_sz = .025,
		max = 200,
		rate = 0.05, -- delta per insert in curtime
		inserts = 2, -- particles to insert per delta
		pos_off_min = Vector(0, 0, 0),
		pos_off_max = Vector(0, 0, 0),
		vel_off_min = Vector(-0.45, -0.45, 1), -- vel offsets
		vel_off_max = Vector(0.45, 0.45, 2), -- vel offsets
		rotate_range = {-8, 8}, -- rate as to which to rotate in DEGREES
		grav = 3.2, -- gravity
		lit = lit,
		active = true,
	})
end

local function bm_time()
	return CurTime() - LK3D.BenchmarkStageStart
end

local function boring_renderfunc()
	LK3D.SetCamPos(Vector(math.cos(bm_time() * .85), math.sin(bm_time() * .5) * 1.25, math.sin(bm_time() * 2) * .25 + .5))
	LK3D.SetCamAng((Vector(0, 0, 0) - LK3D.CamPos):Angle() + Angle(0, math.sin(bm_time() * 1) * 35,  0))
	LK3D.RenderActiveUniverse()
end

LK3D.Benchmarking = false
LK3D.BenchmarkStart = CurTime()
LK3D.BenchmarkStageStart = CurTime()
function LK3D.BeginBenchmark()
	if LK3D.Benchmarking then
		return
	end
	b_print("Starting benchmark!")

	LK3D.BenchmarkStart = CurTime()
	LK3D.BenchmarkStageStart = CurTime()
	LK3D.Benchmarking = true
end
local g_len = 6
local stages = {
	{
		name = "Generic Scene Shaded",
		len = g_len,
		func_init = function()
			LK3D.AddObjectToUniverse("cube_bm", "submarine_vis")
			LK3D.SetObjectPos("cube_bm", Vector(0, 0, 0))
			LK3D.SetObjectScale("cube_bm", Vector(1, 1, 1))
			LK3D.SetObjectFlag("cube_bm", "NO_VW_CULLING", true)
			LK3D.SetObjectAng("cube_bm", Angle(0, 0, 90))
			LK3D.SetObjectMat("cube_bm", "submarine_metal_new2")

			for i = 1, 4 do
				local nm = "plydummy" .. i
				LK3D.AddObjectToUniverse(nm, "playeropti")
				LK3D.SetObjectScale(nm, Vector(.01, .01, .01))
				LK3D.SetObjectPos(nm, Vector(1, -2 + (i / 2), 0))
				LK3D.SetObjectCol(nm, HSVToColor(i / 4 * 360, 1, 1))
			end
		end,
		func_think = function()
			--LK3D.SetObjectAng("cube_bm", Angle(0, CurTime() * 60, CurTime() * 40))
		end,
		func_render = function()
			LK3D.SetCamPos(Vector(0, -1, math.sin(bm_time() * 2) * .5 + .5))
			LK3D.SetCamAng((Vector(0, 0, .5) - LK3D.CamPos):Angle() + Angle(0, math.sin(bm_time() * .5) * 180,  0))
			LK3D.RenderActiveUniverse()
		end
	},
	{
		name = "Generic Scene Lit Shaded",
		len = g_len,
		func_init = function()
			LK3D.AddObjectToUniverse("cube_bm", "submarine_vis")
			LK3D.SetObjectPos("cube_bm", Vector(0, 0, 0))
			LK3D.SetObjectScale("cube_bm", Vector(1, 1, 1))
			LK3D.SetObjectFlag("cube_bm", "NO_VW_CULLING", true)
			LK3D.SetObjectAng("cube_bm", Angle(0, 0, 90))
			LK3D.SetObjectMat("cube_bm", "submarine_metal_new2")

			for i = 1, 4 do
				local nm = "plydummy" .. i
				LK3D.AddObjectToUniverse(nm, "playeropti")
				LK3D.SetObjectScale(nm, Vector(.01, .01, .01))
				LK3D.SetObjectPos(nm, Vector(1, -2 + (i / 2), 0))
				LK3D.SetObjectCol(nm, HSVToColor(i / 4 * 360, 1, 1))
			end

			for i = 1, 8 do
				LK3D.AddLight("li_test" .. i, Vector(0, -3.75 + (i / 1.4), .5), 1.65, HSVToColor(i / 8 * 360, 1, 1))
			end

			LK3D.AddParticleEmitter("test1", "white", {
				pos = Vector(0, -2, .5),
				part_sz = .035,
				max = 200,
				rate = 0.05, -- delta per insert in curtime
				inserts = 2, -- particles to insert per delta
				pos_off_min = Vector(0, 0, 0),
				pos_off_max = Vector(0, 0, 0),
				vel_off_min = Vector(0.85, -0.45, -0.45), -- vel offsets
				vel_off_max = Vector(1.35, 0.45, 0.45), -- vel offsets
				rotate_range = {-8, 8}, -- rate as to which to rotate in DEGREES
				grav = 1.2, -- gravity
				grav_constant = false,
				lit = true,
				active = true,
			})
			LK3D.AddParticleEmitter("test2", "white", {
				pos = Vector(0, 0, .15),
				part_sz = .035,
				max = 200,
				rate = 0.1, -- delta per insert in curtime
				inserts = 1, -- particles to insert per delta
				pos_off_min = Vector(-0.15, -0.15, -0.15),
				pos_off_max = Vector(0.15, 0.15, 0.15),
				vel_off_min = Vector(-0.15, -0.15, -0.15), -- vel offsets
				vel_off_max = Vector(0.15, 0.15, 0.15), -- vel offsets
				rotate_range = {-8, 8}, -- rate as to which to rotate in DEGREES
				grav = -.5, -- gravity
				grav_constant = true,
				lit = true,
				active = true,
				start_col = Color(255, 255, 255),
				end_col = Color(0, 0, 0)
			})
		end,
		func_think = function()
			--LK3D.SetObjectAng("cube_bm", Angle(0, CurTime() * 60, CurTime() * 40))
			LK3D.UpdateParticles()
		end,
		func_render = function()
			LK3D.SetCamPos(Vector(0, -1, math.sin(bm_time() * 2) * .5 + .5))
			LK3D.SetCamAng((Vector(0, 0, .5) - LK3D.CamPos):Angle() + Angle(0, math.sin(bm_time() * .5) * 180,  0))
			LK3D.RenderActiveUniverse()
		end
	},
	{
		name = "TraceSystem Generic Scene",
		len = g_len,
		func_init = function()
			LK3D.AddObjectToUniverse("cube_bm", "submarine_vis")
			LK3D.SetObjectPos("cube_bm", Vector(0, 0, 0))
			LK3D.SetObjectScale("cube_bm", Vector(1, 1, 1))
			LK3D.SetObjectFlag("cube_bm", "NO_VW_CULLING", true)
			LK3D.SetObjectAng("cube_bm", Angle(0, 0, 90))
			LK3D.SetObjectMat("cube_bm", "submarine_metal_new2")

			for i = 1, 4 do
				local nm = "plydummy" .. i
				LK3D.AddObjectToUniverse(nm, "playeropti")
				LK3D.SetObjectScale(nm, Vector(.01, .01, .01))
				LK3D.SetObjectPos(nm, Vector(1, -2 + (i / 2), 0))
				LK3D.SetObjectCol(nm, HSVToColor(i / 4 * 360, 1, 1))
			end

			for i = 1, 8 do
				LK3D.AddLight("li_test" .. i, Vector(0, -3.75 + (i / 1.4), .5), 1.65, HSVToColor(i / 8 * 360, 1, 1))
			end

			LK3D.AddObjectToUniverse("beam", "cube_nuv")
			LK3D.SetObjectPos("beam", Vector(0, 0, 0))
			LK3D.SetObjectScale("beam", Vector(.25, .25, .25))
			LK3D.SetObjectFlag("beam", "NO_VW_CULLING", true)
			LK3D.SetObjectAng("beam", Angle(0, 0, 90))
			LK3D.SetObjectMat("beam", "fail")
			LK3D.SetObjectFlag("beam", "NO_TRACE", true)

			LK3D.AddObjectToUniverse("hitpos", "cube_nuv")
			LK3D.SetObjectPos("hitpos", Vector(0, 0, 0))
			LK3D.SetObjectScale("hitpos", Vector(.25, .25, .25))
			LK3D.SetObjectFlag("hitpos", "NO_VW_CULLING", true)
			LK3D.SetObjectAng("hitpos", Angle(0, 0, 90))
			LK3D.SetObjectMat("hitpos", "fail")
			LK3D.SetObjectFlag("hitpos", "NO_TRACE", true)

		end,
		func_think = function()
			--LK3D.SetObjectAng("cube_bm", Angle(0, CurTime() * 60, CurTime() * 40))
			local pos_trace, norm_trace = LK3D.TraceRayScene(Vector(0, 0, .5), Vector(math.sin(bm_time() * .5), math.cos(bm_time() * .5), 0))
			LK3D.SetObjectPos("beam", LerpVector(.5, Vector(0, 0, .5), pos_trace))
			LK3D.SetObjectAng("beam", (pos_trace - Vector(0, 0, .5)):Angle() + Angle(0, 0, 90))
			LK3D.SetObjectScale("beam", Vector(Vector(0, 0, .5):Distance(pos_trace) / 2, .015, .015))

			LK3D.SetObjectPos("hitpos", pos_trace + norm_trace * .15)
		end,
		func_render = function()
			LK3D.SetCamPos(Vector(0, 0, .65))
			LK3D.SetCamAng(Vector(math.sin(bm_time() * .5), math.cos(bm_time() * .5), 0):Angle())
			LK3D.RenderActiveUniverse()
		end
	},
	{
		name = "Lit Plane (Static)",
		len = g_len,
		func_init = function()
			makeLitPlane()
		end,
		func_think = function()
		end,
		func_render = boring_renderfunc
	},
	{
		name = "Lit Plane (Dynamic)",
		len = g_len,
		func_init = function()
			makeLitPlane()
		end,
		func_think = function()
			LK3D.UpdateLightPos("light1_test", Vector(0, .225 + math.sin(bm_time() * .75) * .35, .35 + math.sin(bm_time() * 2) * .35))
			LK3D.UpdateLightPos("light2_test", Vector(0 + math.cos(bm_time() * .924) * .425, .225, 0))
		end,
		func_render = boring_renderfunc
	},
	{
		name = "Lit Scene (Static)",
		len = g_len,
		func_init = function()
			makeLitPlane()

			LK3D.AddObjectToUniverse("cube_bm", "playeropti")
			LK3D.SetObjectPos("cube_bm", Vector(0, 0, 0))
			LK3D.SetObjectScale("cube_bm", Vector(.01, .01, .01))
		end,
		func_think = function()
		end,
		func_render = boring_renderfunc
	},
	{
		name = "Lit Scene (Dynamic)",
		len = g_len,
		func_init = function()
			makeLitPlane()

			LK3D.AddObjectToUniverse("cube_bm", "playeropti")
			LK3D.SetObjectPos("cube_bm", Vector(0, 0, 0))
			LK3D.SetObjectScale("cube_bm", Vector(.01, .01, .01))
			LK3D.SetObjectCol("cube_bm", Color(255, 255, 255))
		end,
		func_think = function()
			LK3D.SetObjectPos("cube_bm", Vector(0, 0, math.abs(math.sin(bm_time() * 8) * .25)))
			LK3D.SetObjectAng("cube_bm", Angle(0, 90 + (bm_time() * 512), 0))
		end,
		func_render = boring_renderfunc
	},
	{
		name = "Fullbright Polygon Hell",
		len = g_len,
		func_init = function()
			LK3D.AddObjectToUniverse("plane_hd", "plane_hp")
			LK3D.SetObjectPos("plane_hd", Vector(0, 0, 0))
			LK3D.SetObjectScale("plane_hd", Vector(1, 1, 1))
			LK3D.SetObjectCol("plane_hd", Color(255, 255, 255))
			LK3D.SetObjectAng("plane_hd", Angle(0, 0, 90))
			--LK3D.SetObjectFlag("plane_hd", "NO_VW_CULLING", true)

			makeHell(false, false)
		end,
		func_think = function()
		end,
		func_render = boring_renderfunc
	},
	{
		name = "Shaded Polygon Hell",
		len = g_len,
		func_init = function()
			LK3D.AddObjectToUniverse("plane_hd", "plane_hp")
			LK3D.SetObjectPos("plane_hd", Vector(0, 0, 0))
			LK3D.SetObjectScale("plane_hd", Vector(1, 1, 1))
			LK3D.SetObjectCol("plane_hd", Color(255, 255, 255))
			LK3D.SetObjectAng("plane_hd", Angle(0, 0, 90))
			--LK3D.SetObjectFlag("plane_hd", "NO_VW_CULLING", true)

			makeHell(true, false)
		end,
		func_think = function()
		end,
		func_render = boring_renderfunc
	},
	{
		name = "Lit Shaded Polygon Hell",
		len = g_len,
		func_init = function()
			makeLitPlane()
			makeHell(true, true)
		end,
		func_think = function()
		end,
		func_render = boring_renderfunc
	},
	{
		name = "Optimized Polygon Hell",
		len = g_len,
		func_init = function()
			makeLitPlane()
			makeHell(true, true, true)
		end,
		func_think = function()
		end,
		func_render = boring_renderfunc
	},
	{
		name = "Unlit Particle",
		len = g_len,
		func_init = function()
			makeLitPlane()
			makeEmitter(false)
		end,
		func_think = function()
			LK3D.UpdateParticles()
		end,
		func_render = boring_renderfunc
	},
	{
		name = "Lit Particle",
		len = g_len,
		func_init = function()
			makeLitPlane()
			makeEmitter(true)
		end,
		func_think = function()
			LK3D.UpdateParticles()
		end,
		func_render = boring_renderfunc
	},
	{
		name = "Unlit Particle Lit Shaded Polygon Hell",
		len = g_len,
		func_init = function()
			makeLitPlane()
			makeHell(true, true)
			makeEmitter(false)
		end,
		func_think = function()
			LK3D.UpdateParticles()
		end,
		func_render = boring_renderfunc
	},
	{
		name = "Lit Particle Lit Shaded Polygon Hell",
		len = g_len,
		func_init = function()
			makeLitPlane()
			makeHell(true, true)
			makeEmitter(true)
		end,
		func_think = function()
			LK3D.UpdateParticles()
		end,
		func_render = boring_renderfunc
	},
	{
		name = "Shader VPOS",
		len = g_len,
		func_init = function()
			LK3D.AddObjectToUniverse("plane_hd", "plane_hp")
			LK3D.SetObjectPos("plane_hd", Vector(0, 0, 0))
			LK3D.SetObjectScale("plane_hd", Vector(1, 1, 1))
			LK3D.SetObjectCol("plane_hd", Color(255, 255, 255))
			LK3D.SetObjectAng("plane_hd", Angle(0, 0, 90))
			LK3D.SetObjectFlag("plane_hd", "NO_BF_CULLING", true)

			LK3D.SetObjectFlag("plane_hd", "VERT_SH_PARAMS", {
				[1] = true, -- vpos
				[2] = false, -- vuv
				[3] = false, -- vrgb
				[4] = false, -- shader obj ref
			})
			LK3D.SetObjectFlag("plane_hd", "VERT_SHADER", function(vpos)
				vpos[2] = vpos[2] + (math.sin(math.Distance(vpos[1] * 4, vpos[3] * 4, 0, 0) + (bm_time() * 4)) / 8)
			end)
		end,
		func_think = function()
			LK3D.UpdateParticles()
		end,
		func_render = boring_renderfunc
	},
	{
		name = "Shader VUV",
		len = g_len,
		func_init = function()
			LK3D.AddObjectToUniverse("plane_hd", "plane_hp")
			LK3D.SetObjectPos("plane_hd", Vector(0, 0, 0))
			LK3D.SetObjectScale("plane_hd", Vector(1, 1, 1))
			LK3D.SetObjectCol("plane_hd", Color(255, 255, 255))
			LK3D.SetObjectAng("plane_hd", Angle(0, 0, 90))
			LK3D.SetObjectFlag("plane_hd", "NO_BF_CULLING", true)
			LK3D.SetObjectMat("plane_hd", "fail")

			LK3D.SetObjectFlag("plane_hd", "VERT_SH_PARAMS", {
				[1] = false, -- vpos
				[2] = true, -- vuv
				[3] = false, -- vrgb
				[4] = false, -- shader obj ref
			})
			LK3D.SetObjectFlag("plane_hd", "VERT_SHADER", function(vpos, vuv)
				vuv[1] = vuv[1] + math.sin(bm_time() * 1)
				vuv[2] = vuv[2] + math.cos(bm_time() * 1)
			end)
		end,
		func_think = function()
			LK3D.UpdateParticles()
		end,
		func_render = boring_renderfunc
	},
	{
		name = "Shader VRGB",
		len = g_len,
		func_init = function()
			LK3D.AddObjectToUniverse("plane_hd", "plane_hp")
			LK3D.SetObjectPos("plane_hd", Vector(0, 0, 0))
			LK3D.SetObjectScale("plane_hd", Vector(1, 1, 1))
			LK3D.SetObjectCol("plane_hd", Color(255, 255, 255))
			LK3D.SetObjectAng("plane_hd", Angle(0, 0, 90))
			LK3D.SetObjectFlag("plane_hd", "NO_BF_CULLING", true)
			LK3D.SetObjectMat("plane_hd", "white")

			LK3D.SetObjectFlag("plane_hd", "VERT_SH_PARAMS", {
				[1] = false, -- vpos
				[2] = false, -- vuv
				[3] = true, -- vrgb
				[4] = false, -- shader obj ref
			})
			LK3D.SetObjectFlag("plane_hd", "VERT_SHADER", function(vpos, vuv, vrgb)
				vrgb[1] = (math.sin((vpos[1] * 1) + bm_time()) + 1) * 128
				vrgb[2] = (math.sin((vpos[3] * 1) + bm_time()) + 1) * 128
				vrgb[3] = 0
			end)
		end,
		func_think = function()
			LK3D.UpdateParticles()
		end,
		func_render = boring_renderfunc
	},
	{
		name = "Multi Shader",
		len = g_len,
		func_init = function()
			LK3D.AddObjectToUniverse("plane_hd", "plane_hp")
			LK3D.SetObjectPos("plane_hd", Vector(0, 0, 0))
			LK3D.SetObjectScale("plane_hd", Vector(1, 1, 1))
			LK3D.SetObjectCol("plane_hd", Color(255, 255, 255))
			LK3D.SetObjectAng("plane_hd", Angle(0, 0, 90))
			LK3D.SetObjectFlag("plane_hd", "NO_BF_CULLING", true)
			LK3D.SetObjectMat("plane_hd", "fail")

			LK3D.SetObjectFlag("plane_hd", "VERT_SH_PARAMS", {
				[1] = true, -- vpos
				[2] = true, -- vuv
				[3] = true, -- vrgb
				[4] = false, -- shader obj ref
			})
			LK3D.SetObjectFlag("plane_hd", "VERT_SHADER", function(vpos, vuv, vrgb)
				vpos[2] = vpos[2] + (math.sin(math.Distance(vpos[1] * 4, vpos[3] * 4, 0, 0) + (bm_time() * 4)) / 8)

				vuv[1] = vuv[1] + math.sin(bm_time() * 1)
				vuv[2] = vuv[2] + math.cos(bm_time() * 1)

				vrgb[1] = (math.sin((vpos[1] * 1) + bm_time()) + 1) * 128
				vrgb[2] = (math.sin((vpos[3] * 1) + bm_time()) + 1) * 128
				vrgb[3] = 0
			end)
		end,
		func_think = function()
			LK3D.UpdateParticles()
		end,
		func_render = boring_renderfunc
	},
	{
		name = "Shadowed Simple Sun (Static)",
		len = g_len,
		func_init = function()
			LK3D.AddObjectToUniverse("plane_hd", "plane_hp")
			LK3D.SetObjectPos("plane_hd", Vector(0, 0, 0))
			LK3D.SetObjectScale("plane_hd", Vector(1, 1, 1))
			LK3D.SetObjectCol("plane_hd", Color(255, 255, 255))
			LK3D.SetObjectAng("plane_hd", Angle(0, 0, 90))


			LK3D.AddObjectToUniverse("cube_sh", "cube")
			LK3D.SetObjectPos("cube_sh", Vector(0, 0, .2))
			LK3D.SetObjectScale("cube_sh", Vector(.1, .1, .1))
			LK3D.SetObjectFlag("cube_sh", "SHADOW_VOLUME", true)
			LK3D.SetObjectFlag("cube_sh", "SHADOW_DOSUN", true)
		end,
		func_think = function()
		end,
		func_render = boring_renderfunc
	},
	{
		name = "Shadowed Simple Sun (Dynamic)",
		len = g_len,
		func_init = function()
			LK3D.AddObjectToUniverse("plane_hd", "plane_hp")
			LK3D.SetObjectPos("plane_hd", Vector(0, 0, 0))
			LK3D.SetObjectScale("plane_hd", Vector(1, 1, 1))
			LK3D.SetObjectCol("plane_hd", Color(255, 255, 255))
			LK3D.SetObjectAng("plane_hd", Angle(0, 0, 90))


			LK3D.AddObjectToUniverse("cube_sh", "cube")
			LK3D.SetObjectPos("cube_sh", Vector(0, 0, .2))
			LK3D.SetObjectScale("cube_sh", Vector(.1, .1, .1))
			LK3D.SetObjectFlag("cube_sh", "SHADOW_VOLUME", true)
			LK3D.SetObjectFlag("cube_sh", "SHADOW_DOSUN", true)
		end,
		func_think = function()
			LK3D.SetObjectAng("cube_sh", Angle(bm_time() * 32, 0, bm_time() * 96))
		end,
		func_render = boring_renderfunc
	},
	{
		name = "Shadowed Simple Point (Static)",
		len = g_len,
		func_init = function()
			LK3D.AddObjectToUniverse("plane_hd", "plane_hp")
			LK3D.SetObjectPos("plane_hd", Vector(0, 0, 0))
			LK3D.SetObjectScale("plane_hd", Vector(1, 1, 1))
			LK3D.SetObjectCol("plane_hd", Color(255, 255, 255))
			LK3D.SetObjectAng("plane_hd", Angle(0, 0, 90))


			LK3D.AddObjectToUniverse("cube_sh", "cube")
			LK3D.SetObjectPos("cube_sh", Vector(0, 0, .2))
			LK3D.SetObjectScale("cube_sh", Vector(.1, .1, .1))
			LK3D.SetObjectFlag("cube_sh", "SHADOW_VOLUME", true)
			LK3D.SetObjectFlag("cube_sh", "NO_SHADING", true)


			LK3D.AddLight("light1_test", Vector(0, 0, .5), 1.3, Color(255, 255, 255), true)
			LK3D.AddObjectToUniverse("cube_lightref", "cube_nuv")
			LK3D.SetObjectFlag("cube_lightref", "NO_SHADING", true)
			LK3D.SetObjectFlag("cube_lightref", "NO_LIGHTING", true)
			LK3D.SetObjectMat("cube_lightref", "white")
			LK3D.SetObjectScale("cube_lightref", Vector(.025, .025, .025))
			LK3D.SetObjectCol("cube_lightref", Color(245, 240, 196))
			LK3D.SetObjectFlag("cube_lightref", "CONSTANT", true)
			LK3D.SetObjectPos("cube_lightref", Vector(0, 0, .5))
		end,
		func_think = function()
		end,
		func_render = boring_renderfunc
	},
	{
		name = "Shadowed Simple Point (Dynamic)",
		len = g_len,
		func_init = function()
			LK3D.AddObjectToUniverse("plane_hd", "plane_hp")
			LK3D.SetObjectPos("plane_hd", Vector(0, 0, 0))
			LK3D.SetObjectScale("plane_hd", Vector(1, 1, 1))
			LK3D.SetObjectCol("plane_hd", Color(255, 255, 255))
			LK3D.SetObjectAng("plane_hd", Angle(0, 0, 90))


			LK3D.AddObjectToUniverse("cube_sh", "cube")
			LK3D.SetObjectPos("cube_sh", Vector(0, 0, .2))
			LK3D.SetObjectScale("cube_sh", Vector(.1, .1, .1))
			LK3D.SetObjectFlag("cube_sh", "SHADOW_VOLUME", true)
			LK3D.SetObjectFlag("cube_sh", "NO_SHADING", true)


			LK3D.AddLight("light1_test", Vector(0, 0, .5), 1.3, Color(255, 255, 255), true)
			LK3D.AddObjectToUniverse("cube_lightref", "cube_nuv")
			LK3D.SetObjectFlag("cube_lightref", "NO_SHADING", true)
			LK3D.SetObjectFlag("cube_lightref", "NO_LIGHTING", true)
			LK3D.SetObjectMat("cube_lightref", "white")
			LK3D.SetObjectScale("cube_lightref", Vector(.025, .025, .025))
			LK3D.SetObjectCol("cube_lightref", Color(245, 240, 196))
			LK3D.SetObjectFlag("cube_lightref", "CONSTANT", true)
			LK3D.SetObjectPos("cube_lightref", Vector(0, 0, .5))
		end,
		func_think = function()
			local lp = Vector(math.sin(bm_time() * 0.55) * .75, math.cos(bm_time() * 1.24) * .75, .5)
			LK3D.SetObjectAng("cube_sh", Angle(bm_time() * 32, 0, bm_time() * 96))
			LK3D.UpdateLightPos("light1_test", lp)
			LK3D.SetObjectPos("cube_lightref", lp)
		end,
		func_render = boring_renderfunc
	},
	{
		name = "Shadowed Complex Sun (Static)",
		len = g_len,
		func_init = function()
			LK3D.AddObjectToUniverse("plane_hd", "plane_hp")
			LK3D.SetObjectPos("plane_hd", Vector(0, 0, 0))
			LK3D.SetObjectScale("plane_hd", Vector(1, 1, 1))
			LK3D.SetObjectCol("plane_hd", Color(255, 255, 255))
			LK3D.SetObjectAng("plane_hd", Angle(0, 0, 90))


			LK3D.AddObjectToUniverse("cube_sh", "playeropti")
			LK3D.SetObjectPos("cube_sh", Vector(0, 0, 0))
			LK3D.SetObjectScale("cube_sh", Vector(.0075, .0075, .0075))
			LK3D.SetObjectFlag("cube_sh", "SHADOW_VOLUME", true)
			LK3D.SetObjectFlag("cube_sh", "SHADOW_DOSUN", true)
		end,
		func_think = function()
		end,
		func_render = boring_renderfunc
	},
	{
		name = "Shadowed Complex Sun (Dynamic)",
		len = g_len,
		func_init = function()
			LK3D.AddObjectToUniverse("plane_hd", "plane_hp")
			LK3D.SetObjectPos("plane_hd", Vector(0, 0, 0))
			LK3D.SetObjectScale("plane_hd", Vector(1, 1, 1))
			LK3D.SetObjectCol("plane_hd", Color(255, 255, 255))
			LK3D.SetObjectAng("plane_hd", Angle(0, 0, 90))


			LK3D.AddObjectToUniverse("cube_sh", "playeropti")
			LK3D.SetObjectPos("cube_sh", Vector(0, 0, 0))
			LK3D.SetObjectScale("cube_sh", Vector(.0075, .0075, .0075))
			LK3D.SetObjectFlag("cube_sh", "SHADOW_VOLUME", true)
			LK3D.SetObjectFlag("cube_sh", "SHADOW_DOSUN", true)
		end,
		func_think = function()
			LK3D.SetObjectPos("cube_sh", Vector(0, 0, math.abs(math.sin(bm_time() * 8) * .25)))
			LK3D.SetObjectAng("cube_sh", Angle(0, 90 + (bm_time() * 512), 0))
		end,
		func_render = boring_renderfunc
	},
	{
		name = "Shadowed Complex Point (Static)",
		len = g_len,
		func_init = function()
			LK3D.AddObjectToUniverse("plane_hd", "plane_hp")
			LK3D.SetObjectPos("plane_hd", Vector(0, 0, 0))
			LK3D.SetObjectScale("plane_hd", Vector(1, 1, 1))
			LK3D.SetObjectCol("plane_hd", Color(255, 255, 255))
			LK3D.SetObjectAng("plane_hd", Angle(0, 0, 90))


			LK3D.AddObjectToUniverse("cube_sh", "playeropti")
			LK3D.SetObjectPos("cube_sh", Vector(0, 0, 0))
			LK3D.SetObjectScale("cube_sh", Vector(.0075, .0075, .0075))
			LK3D.SetObjectFlag("cube_sh", "SHADOW_VOLUME", true)
			LK3D.SetObjectFlag("cube_sh", "NO_SHADING", true)


			LK3D.AddLight("light1_test", Vector(0, 0, .75), 1.3, Color(255, 255, 255), true)
			LK3D.AddObjectToUniverse("cube_lightref", "cube_nuv")
			LK3D.SetObjectFlag("cube_lightref", "NO_SHADING", true)
			LK3D.SetObjectFlag("cube_lightref", "NO_LIGHTING", true)
			LK3D.SetObjectMat("cube_lightref", "white")
			LK3D.SetObjectScale("cube_lightref", Vector(.025, .025, .025))
			LK3D.SetObjectCol("cube_lightref", Color(245, 240, 196))
			LK3D.SetObjectFlag("cube_lightref", "CONSTANT", true)
			LK3D.SetObjectPos("cube_lightref", Vector(0, 0, .75))
		end,
		func_think = function()
		end,
		func_render = boring_renderfunc
	},
	{
		name = "Shadowed Complex Point (Dynamic)",
		len = g_len,
		func_init = function()
			LK3D.AddObjectToUniverse("plane_hd", "plane_hp")
			LK3D.SetObjectPos("plane_hd", Vector(0, 0, 0))
			LK3D.SetObjectScale("plane_hd", Vector(1, 1, 1))
			LK3D.SetObjectCol("plane_hd", Color(255, 255, 255))
			LK3D.SetObjectAng("plane_hd", Angle(0, 0, 90))


			LK3D.AddObjectToUniverse("cube_sh", "playeropti")
			LK3D.SetObjectPos("cube_sh", Vector(0, 0, 0))
			LK3D.SetObjectScale("cube_sh", Vector(.0075, .0075, .0075))
			LK3D.SetObjectFlag("cube_sh", "SHADOW_VOLUME", true)
			LK3D.SetObjectFlag("cube_sh", "NO_SHADING", true)


			LK3D.AddLight("light1_test", Vector(0, 0, .75), 1.3, Color(255, 255, 255), true)
			LK3D.AddObjectToUniverse("cube_lightref", "cube_nuv")
			LK3D.SetObjectFlag("cube_lightref", "NO_SHADING", true)
			LK3D.SetObjectFlag("cube_lightref", "NO_LIGHTING", true)
			LK3D.SetObjectMat("cube_lightref", "white")
			LK3D.SetObjectScale("cube_lightref", Vector(.025, .025, .025))
			LK3D.SetObjectCol("cube_lightref", Color(245, 240, 196))
			LK3D.SetObjectFlag("cube_lightref", "CONSTANT", true)
			LK3D.SetObjectPos("cube_lightref", Vector(0, 0, .75))
		end,
		func_think = function()
			LK3D.SetObjectPos("cube_sh", Vector(0, 0, math.abs(math.sin(bm_time() * 8) * .25)))
			LK3D.SetObjectAng("cube_sh", Angle(0, 90 + (bm_time() * 512), 0))


			local lp = Vector(math.sin(bm_time() * 0.55) * .75, math.cos(bm_time() * 1.24) * .75, .75)
			LK3D.UpdateLightPos("light1_test", lp)
			LK3D.SetObjectPos("cube_lightref", lp)
		end,
		func_render = boring_renderfunc
	},

	{
		name = "Shadowed Complex Point (Static Z-Pass)",
		len = 12,
		func_init = function()
			LK3D.AddObjectToUniverse("plane_hd", "plane_hp")
			LK3D.SetObjectPos("plane_hd", Vector(0, 0, 0))
			LK3D.SetObjectScale("plane_hd", Vector(1, 1, 1))
			LK3D.SetObjectCol("plane_hd", Color(255, 255, 255))
			LK3D.SetObjectAng("plane_hd", Angle(0, 0, 90))


			LK3D.AddObjectToUniverse("cube_sh", "playeropti")
			LK3D.SetObjectPos("cube_sh", Vector(0, 0, 0))
			LK3D.SetObjectScale("cube_sh", Vector(.0075, .0075, .0075))
			LK3D.SetObjectFlag("cube_sh", "SHADOW_VOLUME", true)
			LK3D.SetObjectFlag("cube_sh", "SHADOW_ZPASS", true)
			LK3D.SetObjectFlag("cube_sh", "NO_SHADING", true)


			LK3D.AddLight("light1_test", Vector(0, 0, .75), 1.3, Color(255, 255, 255), true)
			LK3D.AddObjectToUniverse("cube_lightref", "cube_nuv")
			LK3D.SetObjectFlag("cube_lightref", "NO_SHADING", true)
			LK3D.SetObjectFlag("cube_lightref", "NO_LIGHTING", true)
			LK3D.SetObjectMat("cube_lightref", "white")
			LK3D.SetObjectScale("cube_lightref", Vector(.025, .025, .025))
			LK3D.SetObjectCol("cube_lightref", Color(245, 240, 196))
			LK3D.SetObjectFlag("cube_lightref", "CONSTANT", true)
			LK3D.SetObjectPos("cube_lightref", Vector(0, 0, .75))
		end,
		func_think = function()
		end,
		func_render = boring_renderfunc
	},
	{
		name = "Shadowed Complex Point (Dynamic Z-Pass)",
		len = 12,
		func_init = function()
			LK3D.AddObjectToUniverse("plane_hd", "plane_hp")
			LK3D.SetObjectPos("plane_hd", Vector(0, 0, 0))
			LK3D.SetObjectScale("plane_hd", Vector(1, 1, 1))
			LK3D.SetObjectCol("plane_hd", Color(255, 255, 255))
			LK3D.SetObjectAng("plane_hd", Angle(0, 0, 90))


			LK3D.AddObjectToUniverse("cube_sh", "playeropti")
			LK3D.SetObjectPos("cube_sh", Vector(0, 0, 0))
			LK3D.SetObjectScale("cube_sh", Vector(.0075, .0075, .0075))
			LK3D.SetObjectFlag("cube_sh", "SHADOW_VOLUME", true)
			LK3D.SetObjectFlag("cube_sh", "SHADOW_ZPASS", true)
			LK3D.SetObjectFlag("cube_sh", "NO_SHADING", true)


			LK3D.AddLight("light1_test", Vector(0, 0, .75), 1.3, Color(255, 255, 255), true)
			LK3D.AddObjectToUniverse("cube_lightref", "cube_nuv")
			LK3D.SetObjectFlag("cube_lightref", "NO_SHADING", true)
			LK3D.SetObjectFlag("cube_lightref", "NO_LIGHTING", true)
			LK3D.SetObjectMat("cube_lightref", "white")
			LK3D.SetObjectScale("cube_lightref", Vector(.025, .025, .025))
			LK3D.SetObjectCol("cube_lightref", Color(245, 240, 196))
			LK3D.SetObjectFlag("cube_lightref", "CONSTANT", true)
			LK3D.SetObjectPos("cube_lightref", Vector(0, 0, .75))
		end,
		func_think = function()
			LK3D.SetObjectPos("cube_sh", Vector(0, 0, math.abs(math.sin(bm_time() * 8) * .25)))
			LK3D.SetObjectAng("cube_sh", Angle(0, 90 + (bm_time() * 512), 0))


			local lp = Vector(math.sin(bm_time() * 0.55) * .75, math.cos(bm_time() * 1.24) * .75, .75)
			LK3D.UpdateLightPos("light1_test", lp)
			LK3D.SetObjectPos("cube_lightref", lp)
		end,
		func_render = boring_renderfunc
	},
}



local univBenchmark = LK3D.NewUniverse("lk3d_uni_bmark")
local rtBenchmark = GetRenderTarget("rt_benchmark", 320, 180)
local currStage = 0
local nextStage = CurTime()
local renderCount = 0
local renderTimeTotal = 0
local prevTm = SysTime()
local prevSunDir = LK3D.SunDir
local g_renderCount = 0
local g_renderTimeTotal = 0
function LK3D.BenchmarkThink()
	if not LK3D.Benchmarking then
		return
	end

	LK3D.PushUniverse(univBenchmark)
	if CurTime() > nextStage then
		currStage = currStage + 1
		if currStage > #stages then
			b_print("Average rendertime; " .. (renderTimeTotal / renderCount) * 1000 .. "ms")
			b_print("Done benchmarking!")
			b_print("Global average rendertime; " .. (g_renderTimeTotal / g_renderCount) * 1000 .. "ms")
			LK3D.Benchmarking = false
			return
		end

		LK3D.WipeUniverse()
		local stage_dat = stages[currStage]
		b_print("Average rendertime; " .. (renderTimeTotal / renderCount) * 1000 .. "ms")
		renderTimeTotal = 0
		renderCount = 0


		b_print("--==STAGE " .. currStage .. "==--")
		b_print(stage_dat.name)
		pcall(stage_dat.func_init)

		nextStage = CurTime() + stage_dat.len
		lastLen = stage_dat.len

		LK3D.BenchmarkStageStart = CurTime()
		LK3D.SunDir = prevSunDir
		prevSunDir = LK3D.SunDir
	end

	local stage_dat = stages[currStage]
	if not stage_dat then
		return
	end
	pcall(stage_dat.func_think)
	LK3D.PopUniverse()
end

function LK3D.BenchmarkRender()
	if not LK3D.Benchmarking then
		return
	end


	LK3D.PushUniverse(univBenchmark)
		LK3D.PushRenderTarget(rtBenchmark)
			LK3D.SetRenderer(LK3D_RENDER_HARD)
			LK3D.RenderClear(12, 12, 16)
			local stage_dat = stages[currStage]
			if not stage_dat then
				return
			end
			pcall(stage_dat.func_render)

			renderTimeTotal = renderTimeTotal + (SysTime() - prevTm)
			g_renderTimeTotal = g_renderTimeTotal + (SysTime() - prevTm)

			renderCount = renderCount + 1
			g_renderCount = g_renderCount + 1
			prevTm = SysTime()
		LK3D.PopRenderTarget()
	LK3D.PopUniverse()

	LK3D.UpdateRtEz(rtBenchmark, function()
		draw.SimpleText("[" .. currStage .. "/" .. #stages .. "]: " .. stage_dat.name, "BudgetLabel", ScrW() / 2, ScrH() / 2, Color(0, 128, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText(math.Round(math.abs(stage_dat.len - (nextStage - CurTime())), 1)  .. "s/" .. stage_dat.len .. "s", "BudgetLabel", ScrW(), 0, Color(0, 128, 255, 255), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
		draw.SimpleText(math.Round((renderTimeTotal / renderCount) * 1000, 3) .. "ms AVG", "BudgetLabel", ScrW(), 12, Color(0, 128, 255, 255), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

	end)

	cam.Start2D()
	local w, h = rtBenchmark:Width(), rtBenchmark:Height()
	render.DrawTextureToScreenRect(rtBenchmark, (ScrW() / 2) - w / 2, (ScrH() / 2) - h / 2, w, h)
	cam.End2D()
end

concommand.Add("lk3d_benchmark", function()
	LK3D.BeginBenchmark()
end)
