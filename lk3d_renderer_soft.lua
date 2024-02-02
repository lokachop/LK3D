--[[
	lk3d_renderer_soft.lua

	LK3D software (surface.DrawPoly) renderer
	coded by lokachop
	"deprecated forever!"

	contact at Lokachop#5862 or lokachop@gmail.com
]]--

LK3D = LK3D or {}
local Renderer = {}
Renderer.PrettyName = "Software (vector)"



local function d_print(...)
	if not LK3D.Debug then
		return
	end

	MsgC(Color(255, 100, 100), "[Software renderer debug]: ", Color(200, 255, 200), ..., "\n")
end


local angp = Angle(LK3D.CamAng[1], 0, 0)
local angy = Angle(0, LK3D.CamAng[2], 0)
local angr = Angle(0, 0, LK3D.CamAng[3])

local function updateAngleCopies()
	angp = Angle(LK3D.CamAng[1], 0, 0)
	angy = Angle(0, LK3D.CamAng[2], 0)
	angr = Angle(0, 0, LK3D.CamAng[3] + 180)
end

local function snapVert(vert)
	vert:Mul(100)
	vert:SetUnpacked(math.floor(vert[1]), math.floor(vert[2]), math.floor(vert[3]))
	vert:Div(100)
end

local function transformToWorld(vert)
	vert:Sub(LK3D.CamPos)
	vert:Rotate(angr)
	vert:Rotate(angy)
	vert:Rotate(angp)
	snapVert(vert)
end

local pj_w = 0
local pj_h = 0
local function project(vert)
	local smaller = pj_w > pj_h and pj_h or pj_w
	local z = vert[1] * ((LK3D.FOV / 120) ^ 2)

	local x = ((smaller / 2) * (vert[2] / z)) + pj_w / 2
	local y = ((pj_h / 2) * (vert[3] / z)) + pj_h / 2
	return x, y
end




local vertCount = 0
local triCount = 0
local mdlCount = 0


local math = math
local math_min = math.min
local math_max = math.max

local function light_mult_at_pos(pos, dn, normal)
	local lVal1R, lVal1G, lVal1B = (LK3D.AmbientCol.r / 255), (LK3D.AmbientCol.g / 255), (LK3D.AmbientCol.b / 255)
	for k, v in pairs(LK3D.CurrUniv["lights"]) do
		if lVal1R >= 1 and lVal1G >= 1 and lVal1B >= 1 then
			break
		end


		local pos_l = v[1]
		local inten_l = v[2]
		local col_l = v[3]
		local sm = v[4]

		local dc = (sm and inten_l ^ 2 or inten_l)
		local pd = pos:Distance(pos_l)
		if pd > dc then
			continue
		end

		if sm then
			pd = pd ^ .5
		end
		local vimv1d = (inten_l - pd)
		if dn then
			local pos_loc = pos_l - pos
			pos_loc:Normalize()
			vimv1d = vimv1d * math_max(pos_loc:Dot(normal), 0)
		end

		-- dv1pc = math_abs(vimv1d < 0 and 0 or vimv1d)
		local dv1pc = vimv1d < 0 and 0 or vimv1d
		local dv1c = dv1pc > 1 and 1 or dv1pc
		lVal1R = lVal1R + col_l[1] * dv1c
		lVal1G = lVal1G + col_l[2] * dv1c
		lVal1B = lVal1B + col_l[3] * dv1c
	end


	lVal1R = math_min(math_max(lVal1R, 0), 1)
	lVal1G = math_min(math_max(lVal1G, 0), 1)
	lVal1B = math_min(math_max(lVal1B, 0), 1)

	return lVal1R, lVal1G, lVal1B
end


local function addTrisFromModel(tblpointer, object)
	local mdlinfo = LK3D.Models[object.mdl]
	local verts = mdlinfo.verts
	local uvs = mdlinfo.uvs
	local normals = mdlinfo.normals
	local s_norm = mdlinfo.s_normals

	local mat = object.mat
	local col = object.col
	local scl = object.scl

	local pos = object.pos
	local ang = object.ang
	mdlCount = mdlCount + 1

	local r, g, b = col.r, col.g, col.b


	local doshader = object["VERT_SHADER"] ~= nil

	local rc1, gc1, bc1 = r, g, b
	local rc2, gc2, bc2 = r, g, b
	local rc3, gc3, bc3 = r, g, b
	LK3D.SHADER_OBJREF = object

	if (not object["NO_VW_CULLING"]) and ((pos - LK3D.CamPos):Dot(LK3D.CamAng:Forward()) < 0) then
		return
	end


	for k, v in pairs(mdlinfo.indices) do

		local v1, v2, v3
		local uv1, uv2, uv3 = uvs[v[1][2]], uvs[v[2][2]], uvs[v[3][2]]
		if doshader then
			v1 = Vector(verts[v[1][1]])
			v2 = Vector(verts[v[2][1]])
			v3 = Vector(verts[v[3][1]])

			local norm = normals[k]:GetNormalized()
			norm:Rotate(ang)

			local norm1, norm2, norm3
			if object["SHADER_NO_SMOOTHNORM"] then -- normal
				norm1, norm2, norm3 = norm, norm, norm
			else
				local sn1 = Vector(s_norm[v[1][1]] or normals[k])
				local sn2 = Vector(s_norm[v[2][1]] or normals[k])
				local sn3 = Vector(s_norm[v[3][1]] or normals[k])
				sn1:Rotate(ang)
				sn2:Rotate(ang)
				sn3:Rotate(ang)
				norm1, norm2, norm3 = sn1, sn2, sn3
			end

			local cuv1 = {uv1[1], uv1[2]}
			local cuv2 = {uv2[1], uv2[2]}
			local cuv3 = {uv3[1], uv3[2]}



			local rgbtbl1 = {rc1, gc1, bc1}
			local rgbtbl2 = {rc2, gc2, bc2}
			local rgbtbl3 = {rc3, gc3, bc3}


			LK3D.SHADER_VERTID = k * 3
			pcall(object["VERT_SHADER"], v1, cuv1, rgbtbl1, norm1)
			LK3D.SHADER_VERTID = (k * 3) + 1
			pcall(object["VERT_SHADER"], v2, cuv2, rgbtbl2, norm2)
			LK3D.SHADER_VERTID = (k * 3) + 2
			pcall(object["VERT_SHADER"], v3, cuv3, rgbtbl3, norm3)


			rc1, gc1, bc1 = rgbtbl1[1], rgbtbl1[2], rgbtbl1[3]
			rc2, gc2, bc2 = rgbtbl2[1], rgbtbl2[2], rgbtbl2[3]
			rc3, gc3, bc3 = rgbtbl3[1], rgbtbl3[2], rgbtbl3[3]

			uv1 = cuv1
			uv2 = cuv2
			uv3 = cuv3

			v1 = v1 * scl
			v2 = v2 * scl
			v3 = v3 * scl
		else
			v1 = verts[v[1][1]] * scl
			v2 = verts[v[2][1]] * scl
			v3 = verts[v[3][1]] * scl
		end

		v1:Rotate(ang)
		v2:Rotate(ang)
		v3:Rotate(ang)

		v1:Add(pos)
		vertCount = vertCount + 1
		v2:Add(pos)
		vertCount = vertCount + 1
		v3:Add(pos)
		vertCount = vertCount + 1

		local avp = (v1 + v2 + v3) / 3

		local lr, lg, lb = 1, 1, 1

		if not object["NO_LIGHTING"] then
			lr, lg, lb = light_mult_at_pos(avp)
		end


		--rc1, gc1, bc1 = rc1 * lr, gc1 * lg, bc1 * lb
		--rc2, gc2, bc2 = rc2 * lr, gc2 * lg, bc2 * lb
		--rc3, gc3, bc3 = rc3 * lr, gc3 * lg, bc3 * lb

		--rc1, rc2, rc3 = 255 * lr, 255 * lr, 255 * lr
		--gc1, gc2, gc3 = 255 * lg, 255 * lg, 255 * lg
		--bc1, bc2, bc3 = 255 * lb, 255 * lb, 255 * lb



		tblpointer[#tblpointer + 1] = {v1, uv1, v2, uv2, v3, uv3, {rc1 * lr, gc1 * lg, bc1 * lb, rc2 * lr, gc2 * lg, bc2 * lb, rc3 * lr, gc3 * lg, bc3 * lb}, mat, object["NO_SHADING"] and true or false}
	end
end





local col_G = Color(0, 255, 0, 255)
local function renderInfo()
	if not LK3D.Debug then
		return
	end

	surface.SetDrawColor(255, 255, 255, 255)
	draw.SimpleText(Renderer.PrettyName .. " renderer", "BudgetLabel", 0, 0, col_G)
	draw.SimpleText("VRT; " .. vertCount, "BudgetLabel", 0, 12, col_G)
	draw.SimpleText("TRI; " .. triCount, "BudgetLabel", 0, 24, col_G)
	draw.SimpleText("MDL; " .. mdlCount, "BudgetLabel", 0, 36, col_G)

	vertCount = 0
	triCount = 0
	mdlCount = 0
end





local function t_tri(x0, y0, u0, v0, x1, y1, u1, v1, x2, y2, u2, v2)
	if LK3D.WireFrame then
		surface.DrawLine(x0, y0, x1, y1)
		surface.DrawLine(x1, y1, x2, y2)
		surface.DrawLine(x2, y2, x0, y0)
		return
	end

	local tri = {
		{x = x0, y = y0, u = u0, v = v0},
		{x = x1, y = y1, u = u1, v = v1},
		{x = x2, y = y2, u = u2, v = v2},
	}

	surface.DrawPoly(tri)
end

local function render_tris(tblpointer)
	draw.NoTexture()
	local psort_tris = {}
	for k, v in ipairs(tblpointer) do
		local w1 = v[1]
		local w2 = v[3]
		local w3 = v[5]

		local norm = (w2 - w1):Cross(w3 - w1)
		norm:Normalize()

		transformToWorld(w1)
		transformToWorld(w2)
		transformToWorld(w3)

		if w1[1] < -.25 or w2[1] < -.25 or w3[1] < -.25 then
			continue
		end

		w1[1] = w1[1] < .0 and .0 or w1[1]
		w2[1] = w2[1] < .0 and .0 or w2[1]
		w3[1] = w3[1] < .0 and .0 or w3[1]

		local az = (w1.x + w2.x + w3.x) * .3333

		psort_tris[#psort_tris + 1] = {w1, v[2], w2, v[4], w3, v[6], az, v[7], v[8], norm, v[9]}
		triCount = triCount + 1
	end

	table.sort(psort_tris, function(a, b)
		return a[7] > b[7]
	end)

	local lastmat = nil

	for k, v in ipairs(psort_tris) do
		local ncol = ((LK3D.DoDirLighting and not v[11]) and ((v[10]:Dot(LK3D.SunDir) + 1) * .3333) + 0.333 or 1)
		local rc, gc, bc = (v[8][1] + v[8][4] + v[8][7]) * .3333, (v[8][2] + v[8][5] + v[8][8]) * .3333, (v[8][3] + v[8][6] + v[8][9]) * .3333

		surface.SetDrawColor(rc * ncol, gc * ncol, bc * ncol)

		if lastmat ~= v[9] then
			surface.SetMaterial(LK3D.Textures[v[9]].mat)
			lastmat = v[9]
		end

		local p1x, p1y = project(v[1])
		local p2x, p2y = project(v[3])
		local p3x, p3y = project(v[5])


		--t_tri(p1x, p1y, v[2][1], v[2][2], p2x, p2y, v[4][1], v[4][2], p3x, p3y, v[6][1], v[6][2])
		t_tri(p3x, p3y, v[6][1], v[6][2],
		p2x, p2y, v[4][1], v[4][2],
		p1x, p1y, v[2][1], v[2][2])
	end
end


-- this function should take the currently active universe and render all the objects in it to the active rendertarget on the camera position with the camera angles
function Renderer.Render()
	updateAngleCopies()

	local crt = LK3D.CurrRenderTarget
	local rtw, rth = crt:Width(), crt:Height()
	local ow, oh = ScrW(), ScrH()

	pj_w = rtw
	pj_h = rth


	render.SetViewPort(0, 0, rtw, rth)
	cam.Start2D()
	render.PushRenderTarget(crt)
	render.PushFilterMag(LK3D.FilterMode)
	render.PushFilterMin(LK3D.FilterMode)

		local g_tris = {}
		for k, v in pairs(LK3D.CurrUniv["objects"]) do
			if v["RENDER_NOGLOBAL"] then
				continue
			end
			addTrisFromModel(g_tris, v)
		end

		render_tris(g_tris)

		renderInfo()
	render.PopFilterMag()
	render.PopFilterMin()
	render.PopRenderTarget()
	cam.End2D()
	render.SetViewPort(0, 0, ow, oh)
end


-- this function should render a standalone object on its pos and ang, given name in universe
function Renderer.RenderObjectAlone(obj)
	updateAngleCopies()

	local crt = LK3D.CurrRenderTarget
	local rtw, rth = crt:Width(), crt:Height()
	local ow, oh = ScrW(), ScrH()


	render.SetViewPort(0, 0, rtw, rth)
	cam.Start2D()
	render.PushRenderTarget(crt)
		local g_tris = {}
		if LK3D.CurrUniv["objects"][obj] then
			addTrisFromModel(g_tris, LK3D.CurrUniv["objects"][obj])
			render_tris(g_tris)
		end
	render.PopRenderTarget()
	cam.End2D()
	render.SetViewPort(0, 0, ow, oh)
end


function Renderer.GetLightIntensity(pos, norm)
	local lr, lg, lb = light_mult_at_pos(pos, norm ~= nil, norm)
	return lr, lg, lb
end


local id = LK3D.DeclareRenderer(Renderer)
LK3D_RENDER_SOFT = id