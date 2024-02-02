--[[
	lk3d_renderer_hard2.lua

	LK3D hardware2 (mesh. functions) renderer
	coded by lokachop

	this is a very light and limited renderer, designed for static (cached) scenes with colourlit objects & lightmaps (DeepDive!)
	it also should be more stable than the normal hardware renderer

	DO NOT USE FOR:
		shadowvolume scenes
		dynamic light scenes




	TODO:
		<> Basic rendering of meshes (non-textured)
			- Mesh construction helper func.
			- Render with matrices to avoid rebuilding
			- We don't really care much about vertex lighting, but we should be able to bake it


	contact at Lokachop#5862 or lokachop@gmail.com
]]--

LK3D = LK3D or {}
local Renderer = {}

Renderer.PrettyName = "Hardware2 (mesh)"

local function light_mult_at_pos(pos, dn, normal, blacklist)
	local lVal1R, lVal1G, lVal1B = (LK3D.AmbientCol.r / 255), (LK3D.AmbientCol.g / 255), (LK3D.AmbientCol.b / 255)

	local dobl = (blacklist ~= nil)
	for k, v in pairs(LK3D.CurrUniv["lights"]) do
		if lVal1R >= 1 and lVal1G >= 1 and lVal1B >= 1 then
			break
		end

		if dobl and blacklist[k] == true then
			continue
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
			vimv1d = vimv1d * math.max(pos_loc:Dot(normal), 0)
		end

		-- dv1pc = math_abs(vimv1d < 0 and 0 or vimv1d)
		local dv1pc = vimv1d < 0 and 0 or vimv1d
		local dv1c = dv1pc > 1 and 1 or dv1pc
		lVal1R = lVal1R + col_l[1] * dv1c
		lVal1G = lVal1G + col_l[2] * dv1c
		lVal1B = lVal1B + col_l[3] * dv1c
	end


	lVal1R = math.min(math.max(lVal1R, 0), 1)
	lVal1G = math.min(math.max(lVal1G, 0), 1)
	lVal1B = math.min(math.max(lVal1B, 0), 1)

	return lVal1R, lVal1G, lVal1B
end



local ScreenSzStack = {}
local function insScreenSz()
	ScreenSzStack[#ScreenSzStack + 1] = {ScrW(), ScrH()}
end

local function popScreenSz()
	local val = table.remove(ScreenSzStack, 1)
	return val[1], val[2]
end


local function begin3DView()
	insScreenSz()
	local crt = LK3D.CurrRenderTarget
	local rtw, rth = crt:Width(), crt:Height()
	render.SetViewPort(0, 0, rtw, rth)
	cam.Start2D()
	render.PushRenderTarget(crt)
	render.PushFilterMag(LK3D.FilterMode)
	render.PushFilterMin(LK3D.FilterMode)
		cam.Start({
			type = "3D",
			x = 0,
			y = 0,
			w = rtw,
			h = rth,
			aspect = rtw / rth,
			origin = LK3D.CamPos,
			angles = LK3D.CamAng,
			fov = LK3D.FOV,
			zfar = LK3D.FAR_Z,
			znear = LK3D.NEAR_Z,
			ortho = LK3D.Ortho and LK3D.OrthoParameters or nil
		})

end

local function end3DView()
	local ow, oh = popScreenSz()
		cam.End3D()
	render.PopFilterMag()
	render.PopFilterMin()
	render.PopRenderTarget()
	cam.End2D()
	render.SetViewPort(0, 0, ow, oh)
end

local function buildMesh(obj)
	local mdlinfo = LK3D.Models[object.mdl]
	if not mdlinfo then
		return
	end

	local verts = mdlinfo.verts
	local uvs = mdlinfo.uvs
	local lightmap_uvs = object.lightmap_uvs
	local dolightmap = (lightmap_uvs ~= nil) and true or false
	local ind = mdlinfo.indices
	local normals = mdlinfo.normals
	local s_norm = mdlinfo.s_normals

end





local function renderModel(obj)

end


local function shouldRender(obj)
	if obj["RENDER_NOGLOBAL"] then
		return false
	end

	return true
end



-- this function should take the currently active universe and render all the objects in it to the active rendertarget on the camera position with the camera angles
function Renderer.Render()
	local currUniv = LK3D.CurrUniv

	begin3DView()
	for k, v in pairs(currUniv["objects"]) do
		if not shouldRender(v) then
			continue
		end

		local fine, err = pcall(renderModel, v)
		if not fine then
			LK3D.New_D_Print("Error rendering model \"" .. k .. "\" on universe \"" .. currUniv.tag .. "\": " .. err, LK3D_SEVERITY_ERROR, "Hardware2")
			break
		end
	end
	end3DView()
end



local id = LK3D.DeclareRenderer(Renderer)
LK3D_RENDER_HARD2 = id