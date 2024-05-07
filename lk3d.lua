--[[--
## Base LK3D functions
---

This holds all of the other stuff that doesn't really fit into anything else  
]]
-- @module lk3d



--[[
	lk3d.lua

	lokachop's 3D library
	coded by lokachop!
	"The worst lib ever made!"

	please contact at lokachop (formerly Lokachop#5862) or lokachop@gmail.com
	repo is available at https://github.com/lokachop/LK3D
]]--
LK3D = LK3D or {}
LK3D.Debug = true
concommand.Add("lk3d_toggledebug", function()
	LK3D.Debug = not LK3D.Debug
	print("Debug is now: " .. (LK3D.Debug and "on" or "off"))
end)
LK3D.Version = "1.5 'Cyan Line'"

function LK3D.D_Print(...)
	if not LK3D.Debug then
		return
	end

	if LK3D.New_D_Print then
		LK3D.New_D_Print("Using deprecated function \"LK3D.D_Print()\", use \"LK3D.New_D_Print\" instead...", LK3D_SERVERITY_WARN, "LK3D")
		LK3D.New_D_Print(..., LK3D_SEVERITY_INFO, "DPRINT")
		return
	end

	MsgC(Color(100, 255, 100), "[LK3D]: ", Color(200, 255, 200), ..., "\n")
end

LK3D.D_Print("Loading LK3D!")

include("lk3d_notiflogger.lua")
include("lk3d_dumps.lua")

LK3D.DEF_UNIVERSE = {["lk3d"] = true, ["objects"] = {}, ["lights"] = {}, ["lightcount"] = 0, ["particles"] = {}, ["physics"] = {}}
LK3D.DEF_RT = GetRenderTarget("lk3d_fallback_rt", 800, 600)


-- non custom params

LK3D.Ortho = false
LK3D.WireFrame = false
-- Sun
LK3D.DoDirLighting = (LK3D.DoDirLighting ~= nil) and LK3D.DoDirLighting or true
LK3D.SunDir = Vector(0.75, 1, 1)
LK3D.SunDir:Normalize()


-- custom params

--- Parameters
-- @section parameters

--- Texture filter mode
LK3D.FilterMode = LK3D.FilterMode or TEXFILTER.POINT

--- Lightmap upscale filter mode
LK3D.LightmapFilterMode = LK3D.LightmapFilterMode or TEXFILTER.POINT
--- Lightmap upscale amount
LK3D.LightmapUpscale = LK3D.LightmapUpscale or 1

--- Whether to divide animation frame rate by frame count
LK3D.AnimFrameDiv = (LK3D.AnimFrameDiv ~= nil) and LK3D.AnimFrameDiv or false

--- Shadow volume alpha value (Hardware1 renderer only)
LK3D.ShadowAlpha = LK3D.ShadowAlpha or 196
--- Distance to extrude shadow volumes (Hardware1 renderer only)
LK3D.ShadowExtrude = LK3D.ShadowExtrude or 20

--- End
-- @section end


LK3D.AmbientCol = Color(0, 0, 0)
LK3D.ActiveRenderer = 2 -- this should always be the hardware renderer
LK3D.Renderers = LK3D.Renderers or {}
local lastRendererID = 0

--- Declares a new renderer
-- @internal
-- @tparam table renderer Renderer data
function LK3D.DeclareRenderer(renderer)
	lastRendererID = lastRendererID + 1
	LK3D.Renderers[lastRendererID] = renderer

	return lastRendererID
end

-- Universes
include("lk3d_universes.lua")


-- Lighting
include("lk3d_lights.lua")


-- RenderTarget
include("lk3d_rendertarget.lua")


-- Camera
include("lk3d_camera.lua")


-- RT Utils
include("lk3d_rt_utils.lua")


-- Objects
include("lk3d_objects.lua")


include("renderers/renderer_soft/lk3d_renderer_soft.lua")
include("renderers/renderer_hard/lk3d_renderer_hard.lua")
include("renderers/renderer_hard2/lk3d_renderer_hard2.lua")
include("renderers/renderer_soft2/lk3d_renderer_soft2.lua")

LK3D.ActiveRenderer = LK3D_RENDER_HARD or LK3D.ActiveRenderer

--- Sets the active renderer
-- @tparam number rid Renderer ID
-- @usage LK3D.SetRenderer(LK3D_RENDER_HARD) -- sets to hw renderer
function LK3D.SetRenderer(rid)
	if not LK3D.Renderers[rid] then
		LK3D.New_D_Print("No renderer with id " .. rid .. "!", LK3D_SERVERITY_ERROR, "LK3D")
		return
	end

	LK3D.ActiveRenderer = rid
end

function LK3D.SetWireFrame(doWireframe)
	LK3D.WireFrame = doWireframe
end

--- Sets whether to render in wireframe mode
-- @tparam bool doWireframe Whether or not to render in wireframe
-- @usage LK3D.SetWireframe(true) -- render wireframe
function LK3D.SetWireframe(doWireframe)
	LK3D.WireFrame = doWireframe
end

--- Sets the ambient color
-- @tparam color col Ambient color
-- @usage LK3D.SetAmbientCol(Color(255, 0, 0)) -- ugly preset
function LK3D.SetAmbientCol(col)
	LK3D.AmbientCol = col
end

--- Sets the direction of the sun, for shading
-- @tparam vector vec Direction the sun should point at
-- @usage LK3D.SetSunDir(Vector(0.75, 1, 1)) -- this is normalized internally
function LK3D.SetSunDir(vec)
	LK3D.SunDir = vec
	LK3D.SunDir:Normalize()
end

--- Sets whether or not we should do directional shading
-- @tparam bool flag Whether or not we should do directional shading
-- @usage LK3D.SetDoDirLighting(false) -- no weird shading by default
function LK3D.SetDoDirLighting(flag)
	LK3D.DoDirLighting = flag
end

--- Sets the texture filter mode
-- @tparam number filtermode [Texture filter mode constant](https://wiki.facepunch.com/gmod/Enums/TEXFILTER)
-- @usage LK3D.SetFilterMode(TEXFILTER.POINT)
function LK3D.SetFilterMode(filtermode)
	LK3D.FilterMode = filtermode
end


--- Renders the active universe to the active RT
-- @usage LK3D.RenderActiveUniverse()
function LK3D.RenderActiveUniverse()
	local fine, err = pcall(LK3D.Renderers[LK3D.ActiveRenderer].Render)
	if not fine then
		LK3D.New_D_Print("Error while rendering the whole scene using the \"" .. LK3D.Renderers[LK3D.ActiveRenderer].PrettyName .. "\" renderer; " .. err, LK3D_SERVERITY_FATAL, "LK3D")
	end
end

--- Renders the depth buffer of the active universe and returns it
-- @treturn table Depth array, as a sequential table **starting at 0**
-- @usage local depthArray = LK3D.RenderActiveDepthArray()
-- local depthTopLeft = depthArray[0]
function LK3D.RenderActiveDepthArray()
	local fine, arr = pcall(LK3D.Renderers[LK3D.ActiveRenderer].RenderDepth)
	if not fine then
		LK3D.New_D_Print("Error while rendering depth using the \"" .. LK3D.Renderers[LK3D.ActiveRenderer].PrettyName .. "\" renderer; " .. arr, LK3D_SERVERITY_ERROR, "LK3D")
		return
	end

	return arr
end

--- Renders a single object from the active universe
-- @tparam string obj Index tag of the object
-- @usage LK3D.RenderObject("loka_pc")
function LK3D.RenderObject(obj)
	local fine, err = pcall(LK3D.Renderers[LK3D.ActiveRenderer].RenderObjectAlone, obj)
	if not fine then
		LK3D.New_D_Print("Error while rendering an object using the \"" .. LK3D.Renderers[LK3D.ActiveRenderer].PrettyName .. "\" renderer; " .. err, LK3D_SERVERITY_ERROR, "LK3D")
	end
end



local function startToScreenView()
	local crt = LK3D.CurrRenderTarget
	local rtw, rth = crt:Width(), crt:Height()

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
		ortho = LK3D.Ortho and LK3D.OrthoParams or nil
	})

end

--- Converts a position to screen coords
-- @tparam vector pos Pos to convert to screen coords
-- @treturn table The [ToScreenData](https://wiki.facepunch.com/gmod/Structures/ToScreenData)
-- @usage local scrData = LK3D.ToScreen(Vector(0, 16, 0))
-- print(scrData.x, scrData.y)
function LK3D.ToScreen(pos)
	startToScreenView()
		local data = pos:ToScreen()
	cam.End3D()

	return data
end

--- Converts a list of positions to screen coords
-- @tparam table positions Sequential table of positions
-- @treturn table A table of [ToScreenData](https://wiki.facepunch.com/gmod/Structures/ToScreenData)
-- @usage local scrDataArray = LK3D.ToScreen({Vector(0, 16, 0), Vector(4, 16, 0)})
-- print(scrDataArray[1].x, scrDataArray[1].y)
-- print(scrDataArray[2].x, scrDataArray[2].y)
function LK3D.ToScreenArray(positions)
	local dataRet = {}

	startToScreenView()
		for k, v in ipairs(positions) do
			dataRet[k] = v:ToScreen()
		end
	cam.End3D()

	return dataRet
end

-- this uses render.Spin() to render a helpful message over how we're processing sutff
local rt_nfo = GetRenderTarget("lk3d_processing_rt2", ScrW(), ScrH())
local REAL_W, REAL_H = ScrW(), ScrH()


--- Renders a informational processing message, to avoid the game freezing  
-- **Only use this when computing a lot of stuff**
-- @tparam string message Message to write at the top left
-- @tparam number prog Progress processing, 0 - 100
-- @tparam ?function xtrarender Extra rendering function to render more stuff ontop
-- @usage for i = 1, 51200000 do
--   LK3D.RenderProcessingMessage("doing stuff", (i / 51200000) * 100)
-- end
function LK3D.RenderProcessingMessage(message, prog, xtrarender)
	local last_rt = nil
	if render.GetRenderTarget() ~= nil then
		last_rt = render.GetRenderTarget()
		render.PopRenderTarget()
	end


	local ow, oh = ScrW(), ScrH()
	render.SetViewPort(0, 0, REAL_W, REAL_H)
	cam.Start2D()
	render.PushRenderTarget(rt_nfo)
		render.SetColorMaterialIgnoreZ()
		draw.NoTexture()

		local proc_mat = LK3D.GetTextureByIndex("lk3d_processing")
		if proc_mat then
			surface.SetDrawColor(255, 255, 255, 255)
			surface.SetMaterial(proc_mat.mat)
			surface.DrawTexturedRectUV(0, 0, ScrW(), ScrH(), 0, 0, (ScrW() / ScrH()) * 8, 8)
		else
			surface.SetDrawColor(57, 104, 57)
			surface.DrawRect(0, 0, ScrW(), ScrH())
		end

		local m_scl = Matrix()
		m_scl:SetTranslation(Vector(8, 0))
		m_scl:SetScale(Vector(4, 4))
		cam.PushModelMatrix(m_scl)
			draw.SimpleText("LK3D Processing...", "BudgetLabel", 0, 0, Color(255, 160, 76), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		cam.PopModelMatrix()

		m_scl = Matrix()
		m_scl:SetTranslation(Vector(8, 12 * 4))
		m_scl:SetScale(Vector(4, 4))
		cam.PushModelMatrix(m_scl)
			draw.SimpleText("Please wait...", "BudgetLabel", 0, 0, Color(255, 160, 76), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		cam.PopModelMatrix()

		if message then
			surface.SetDrawColor(64, 84, 200)

			m_scl = Matrix()
			m_scl:SetTranslation(Vector(8, 32 * 4))
			m_scl:SetScale(Vector(4, 4))
			cam.PushModelMatrix(m_scl)
				draw.DrawText(message, "BudgetLabel", 0, 0, Color(64, 84, 200), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			cam.PopModelMatrix()
		end

		if prog then
			m_scl = Matrix()
			m_scl:SetTranslation(Vector(8, ScrH() - 120))
			m_scl:SetScale(Vector(8, 8))
			cam.PushModelMatrix(m_scl)
				draw.DrawText(string.format("%05.2f%%", prog), "BudgetLabel", 0, 0, Color(200, 84, 240), TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
			cam.PopModelMatrix()
		end


		if xtrarender then
			pcall(xtrarender)
		end
	render.PopRenderTarget()

	render.DrawTextureToScreen(rt_nfo)
	render.Spin()

	cam.End2D()
	render.SetViewPort(0, 0, ow, oh)

	if last_rt ~= nil then
		render.PushRenderTarget(last_rt)
	end
end






include("lk3d_lkpack.lua") -- lkpack first
include("lk3d_modelutils.lua")


include("lk3d_procmodel.lua")
include("lk3d_models.lua")
include("lk3d_textures.lua")

LK3D.ModelInitExtra = LK3D.ModelInitExtra or {}
for k, v in pairs(LK3D.ModelInitExtra) do
	local fine, err = pcall(v) -- fix extern model init load issues
	if not fine then
		LK3D.New_D_Print("LK3D ModelInitExtra error! [" .. k .. "]; " .. err, LK3D_SEVERITY_ERROR, "LK3D")
	end
end

include("lk3d_noise.lua")
include("lk3d_particles.lua")
include("lk3d_debugutils.lua")
include("lk3d_trace.lua")
include("lk3d_bmark.lua")
include("lk3d_rt.lua")
include("lk3d_proctex.lua")
--include("lk3d_physics.lua") -- mostly deprecated by FPS, might recontinue later though since FPS seems a bit buggy currently
include("physics/lk3d_physics_external_fps.lua")
include("lk3d_sceneexport.lua")
include("lk3d_musisynth.lua")
include("lk3d_modelviewer.lua")
include("lk3d_univ_explorer.lua")
include("lk3d_baseshaders.lua")
include("lk3d_radiosity.lua")
include("lightmapping/lk3d_radiosa_main.lua")


include("lk3d_skeleton.lua")
include("lk3d_intro.lua")
include("lk3d_changelog.lua")
include("lk3d_about.lua")

include("lk3d_docs_utils.lua") -- for docs

-- todo surface2d (3d mesh. based 2d lib for lk3d)
LK3D.New_D_Print("LK3D fully loaded!", LK3D_SEVERITY_INFO, "LK3D")