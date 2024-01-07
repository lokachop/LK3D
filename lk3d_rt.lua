--[[
	lk3d_rt.lua

	in-engine raytracer for lk3d
	terribly coded by me, lokachop
	
	as per usual, please contact at Lokachop#5862 or lokachop@gmail.com
]]--

LK3D = LK3D or {}


local function rt_print(...)
	if not LK3D.Debug then
		return
	end

	MsgC(Color(100, 0, 255), "[LK3D:RAYTRACER]: ", Color(200, 100, 255), ..., "\n")
end

local g_div = 2
local wDiv, hDiv = 320, 180
local sWDiv, sHDiv = wDiv / g_div, hDiv / g_div

local FOV = 75
local math = math
local math_floor = math.floor
local math_tan = math.tan
local math_min = math.min
local math_max = math.max
local math_abs = math.abs

local dirTbl = {}
-- from https://www.youtube.com/watch?v=YSOBCp2mito
local function calculateForward()
	for y = 0, sHDiv do
		dirTbl[y] = {}
		for x = 0, wDiv do
			local coeff = math_tan((FOV / 2) * (3.1416 / 180)) * 2.71828;
			dirTbl[y][x] = Vector(
				1,
				((sWDiv - x) / (sWDiv - 1) - 0.5) * coeff,
				(coeff / sWDiv) * (sHDiv - y) - 0.5 * (coeff / sWDiv) * (sHDiv - 1)
			):GetNormalized()
		end
	end
end
calculateForward()


local ao_mdist = 0.075
local ao_itr = 4
local ao_st_delta = 1 / ((ao_itr * ao_itr) - 1)
local ao_itr2 = (ao_itr / 2)
local function ao_at_pos(pos, norm)
	local sub_var = 0
	local n_a = norm:Angle() + Angle(90, 90, 0)

	for i = 0, (ao_itr * ao_itr) - 1 do
		--local dx = (((i % ao_itr) - ao_itr2) / ao_itr2)
		--local dy = ((math.floor(i / ao_itr) - ao_itr2) / ao_itr2)


		--local n_c = Vector(norm)
		--n_c:Rotate(Angle(0, (dx * 90), (dy * 90) + (90 / ao_itr)))
		--local upc = n_a:Up() * dy
		--local ric = n_a:Right() * dx

		--upc:Add(ric)
		--upc:Normalize()

		local upc = n_a:Up() * ((math_floor(i / ao_itr) - ao_itr2) / ao_itr2) -- dy
		local ric = n_a:Forward() * (((i % ao_itr) - ao_itr2) / ao_itr2) -- dx

		upc:Add(ric)
		--ncopy:Add(ric)
		upc:Normalize()

		local ps = pos + (norm * .005)
		LK3D.DebugUtils.Line(ps, ps + (upc / 8), 2, Color(255, 128, 0))
		LK3D.DebugUtils.Cross(ps + (upc / 8), .025, 2, Color(0, 128, 255))

		local n_pos, _ = LK3D.TraceRayScene(ps, upc, true)


		local dc = n_pos:Distance(pos)
		if dc < ao_mdist then
			sub_var = sub_var + (ao_st_delta * math.abs(1 - dc))
		end
	end

	return math.abs(1 - sub_var)
end



local texPixels = {}
local function calculateTexPixels(nm)
	if not LK3D.Textures[nm] then
		return
	end

	if texPixels[nm] then
		return
	end

	rt_print("Capturing tex \"" .. nm .. "\"!")


	texPixels[nm] = {}
	local texRT = LK3D.Textures[nm].rt
	local rtw, rth = texRT:Width(), texRT:Height()
	render.PushRenderTarget(texRT)
		render.CapturePixels()
	render.PopRenderTarget()

	for i = 0, rtw * rth do
		local xc = math_floor(i % rtw)
		local yc = math_floor(i / rtw)

		local rr, rg, rb = render.ReadPixel(xc, yc)

		texPixels[nm][i] = {rr, rg, rb}
	end
end

local function getPxColor(tex, uv)
	if not texPixels[tex] then
		calculateTexPixels(tex)
	end

	local rt_m = LK3D.Textures[tex].rt
	local rtw = rt_m:Width()
	local ux, uy = math_floor(uv[1] * rt_m:Width()), math_floor(uv[2] * rt_m:Height())

	local idx = math_floor(ux + uy * rtw)
	local org = texPixels[tex][idx]
	return {org[1], org[2], org[3]}
end



local function calcLighting(tr)
	local tr_hp = tr.pos + (tr.norm * .0085)
	local tr_hp_nonorm = tr.pos

	local ac_r, ac_g, ac_b = 0, 0, 0
	for k, v in pairs(LK3D.CurrUniv["lights"]) do

		local pos_l = Vector(v[1])
		local inten_l = v[2]
		local col_l = v[3]
		local sm = v[4]

		local pd = tr_hp_nonorm:Distance(pos_l)
		if pd > (sm and inten_l ^ 2 or inten_l) then
			continue
		end

		if sm then
			pd = pd ^ .5
		end

		LK3D.SetTraceReturnTable(true)
		local dirc = (pos_l - tr_hp_nonorm):GetNormalized()
		local trCheck = LK3D.TraceRayScene(tr_hp, dirc, true, (sm and inten_l ^ 2 or inten_l) * 0.99)
		LK3D.SetTraceReturnTable(false)

		if trCheck.dist < (pd * .5) then
			continue
		end

		local vinv = (inten_l - pd)
		ac_r = ac_r + (col_l[1] * math_min(math_abs(math_max(vinv, 0)), 1))
		ac_g = ac_g + (col_l[2] * math_min(math_abs(math_max(vinv, 0)), 1))
		ac_b = ac_b + (col_l[3] * math_min(math_abs(math_max(vinv, 0)), 1))
	end

	ac_r = math_min(math_max(ac_r, 0), 1)
	ac_g = math_min(math_max(ac_g, 0), 1)
	ac_b = math_min(math_max(ac_b, 0), 1)

	return ac_r, ac_g, ac_b
end

local function calcCol(tr)
	--local dcalc = math.min(math.max(pos_trace:Distance(pos) * 4, 0), 255)

	local cret = {0, 0, 0}
	if tr.obj then
		local htex = LK3D.CurrUniv["objects"][tr.obj].mat

		cret = getPxColor(htex, tr.uv)
	else

	end

	--cret[1] = cret[1] / 255
	--cret[2] = cret[2] / 255
	--cret[3] = cret[3] / 255
	--local ncol = Vector(uv[1] * 255, uv[2] * 255, 0) --Vector((norm[1] + 1) * 128, (norm[2] + 1) * 128, (norm[3] + 1) * 128)


	local lr, lg, lb = calcLighting(tr)
	cret[1] = cret[1] * math.pow(lr, .45)
	cret[2] = cret[2] * math.pow(lg, .45)
	cret[3] = cret[3] * math.pow(lb, .45)

	--cret[1] = math.pow(cret[1], .45) * 255
	--cret[2] = math.pow(cret[2], .45) * 255
	--cret[3] = math.pow(cret[3], .45) * 255

	--local aoc = ao_at_pos(tr.pos, tr.norm)
	--cret[1] = cret[1] * aoc
	--cret[2] = cret[2] * aoc
	--cret[3] = cret[3] * aoc

	return cret --{lr * 255, lg * 255, lb * 255}-- * aoc
end



LK3D.Raytracing = false
local rt_itr = 12
local rt_raytrace = GetRenderTarget("rt_lk3d_raytracer_" .. g_div, wDiv, hDiv)
local currpx = 0
local rt_pos = LK3D.CamPos
local rt_ang = LK3D.CamAng
local targ_univ = ""
function LK3D.RaytraceThink()
	if not LK3D.Raytracing then
		return
	end

	if not LK3D.UniverseRegistry[targ_univ] then
		return
	end

	if currpx > (sWDiv * sHDiv) then
		LK3D.Raytracing = false
		return
	end

	LK3D.PushUniverse(LK3D.UniverseRegistry[targ_univ])
	render.PushRenderTarget(rt_raytrace)
	local ow, oh = ScrW(), ScrH()
	for i = currpx, currpx + rt_itr do

		local x = (i % sWDiv)
		local y = math_floor(i / sWDiv)

		local dir = Vector(dirTbl[y][x])
		dir:Rotate(rt_ang)

		LK3D.SetExpensiveTrace(true)
		LK3D.SetTraceReturnTable(true)
		local trdat = LK3D.TraceRayScene(rt_pos, dir)
		LK3D.SetTraceReturnTable(false)
		LK3D.SetExpensiveTrace(false)

		local ccalc = calcCol(trdat)

		render.SetViewPort(x * g_div, y * g_div, g_div, g_div)
		render.Clear(ccalc[1], ccalc[2], ccalc[3], 255)
		render.SetViewPort(0, 0, ow, oh)
	end
	render.PopRenderTarget()
	LK3D.PopUniverse()

	currpx = currpx + rt_itr
	print(currpx .. " / " .. (sWDiv * sHDiv))
end

concommand.Add("LK3D_raytraceCurrent", function(ply, cmd, args, argstr)
	if LK3D.Raytracing then
		return
	end

	if not args[1] then
		LK3D.New_D_Print("LK3D_raytraceCurrent (universeName)", LK3D_SEVERITY_WARN, "Base")
		return
	end

	if LK3D.UniverseRegistry[args[1]] == nil then
		LK3D.New_D_Print("TargetUniverse \"" .. args[1] .. "\" doesnt exist!", LK3D_SEVERITY_WARN, "Base")
		return
	end

	targ_univ = args[1]

	rt_pos = LocalPlayer():EyePos() / 100
	rt_ang = LocalPlayer():EyeAngles()
	currpx = 0
	calculateForward()
	LK3D.Raytracing = true
	LK3D.New_D_Print("raytracing from curr pos!", LK3D_SEVERITY_INFO, "Base")
end)





local fr_scale = 2
concommand.Add("LK3D_ShowRTRender", function()
	local fr = vgui.Create("DFrame")
	fr:SetSize((wDiv * fr_scale) + 32, (hDiv * fr_scale) + 32)
	fr:Center()
	fr:MakePopup()

	local pn = vgui.Create("DPanel", fr)
	pn:Dock(FILL)

	local tex = GetRenderTarget("rt_lk3d_raytracer_" .. g_div, wDiv, hDiv)

	local mat = LK3D.RTToMaterial(tex)
	function pn:Paint(w, h)
		surface.SetDrawColor(255, 255, 255)
		surface.SetMaterial(mat)
		render.PushFilterMin(TEXFILTER.POINT)
		render.PushFilterMag(TEXFILTER.POINT)
		surface.DrawTexturedRect(0, 0, w, h)
		render.PopFilterMag()
		render.PopFilterMin()
	end
end)