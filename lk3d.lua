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
LK3D.Version = "1.4 'Teal Triangle'"

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


LK3D.CamPos = Vector(0, 0, 0)
LK3D.CamAng = Angle(0, 0, 0)
LK3D.WireFrame = false
LK3D.FOV = 90
LK3D.SunDir = Vector(0.75, 1, 1)
LK3D.SunDir:Normalize()

LK3D.DoDirLighting = true
LK3D.Ortho = false

LK3D.FAR_Z = 200
LK3D.NEAR_Z = .05

LK3D.SHADOW_EXTRUDE = 20

LK3D.DoExpensiveTrace = false
LK3D.TraceReturnTable = false
LK3D.TraceOverrideNoTrace = false

LK3D.FilterMode = LK3D.FilterMode or TEXFILTER.POINT

LK3D.LightmapFilterMode = LK3D.LightmapFilterMode or TEXFILTER.POINT
LK3D.LightmapUpscale = LK3D.LightmapUpscale or 1

LK3D.ShadowAlpha = LK3D.ShadowAlpha or 196

LK3D.AnimFrameDiv = LK3D.AnimFrameDiv ~= nil and LK3D.AnimFrameDiv or false

LK3D.AmbientCol = Color(0, 0, 0)
LK3D.OrthoParameters = {
	left = 1,
	right = -1,
	top = 1,
	bottom = -1
}

LK3D.ActiveRenderer = 2 -- this should always be the hardware renderer

LK3D.Renderers = LK3D.Renderers or {}
local lastRendererID = 0
function LK3D.DeclareRenderer(renderer)
	lastRendererID = lastRendererID + 1
	LK3D.Renderers[lastRendererID] = renderer

	return lastRendererID
end

include("renderers/renderer_soft/lk3d_renderer_soft.lua")
include("renderers/renderer_hard/lk3d_renderer_hard.lua")
include("renderers/renderer_hard2/lk3d_renderer_hard2.lua")
include("renderers/renderer_soft2/lk3d_renderer_soft2.lua")

LK3D.ActiveRenderer = LK3D_RENDER_HARD or LK3D.ActiveRenderer


function LK3D.SetRenderer(rid)
	if not LK3D.Renderers[rid] then
		LK3D.New_D_Print("No renderer with id " .. rid .. "!", LK3D_SERVERITY_ERROR, "LK3D")
		return
	end

	LK3D.ActiveRenderer = rid
end

function LK3D.SetWireFrame(flag)
	LK3D.WireFrame = flag
end

function LK3D.SetFOV(num)
	LK3D.FOV = num
end

function LK3D.SetAmbientCol(col)
	LK3D.AmbientCol = col
end

function LK3D.SetSunDir(vec)
	LK3D.SunDir = vec
	LK3D.SunDir:Normalize()
end

function LK3D.SetDoDirLighting(flag)
	LK3D.DoDirLighting = flag
end

function LK3D.SetOrtho(flag)
	LK3D.Ortho = flag
end

function LK3D.SetOrthoParameters(tbl)
	LK3D.OrthoParameters = tbl
end

function LK3D.SetExpensiveTrace(bool)
	LK3D.DoExpensiveTrace = bool
end

function LK3D.SetTraceReturnTable(bool)
	LK3D.TraceReturnTable = bool
end

function LK3D.SetTraceOverrideNoTrace(bool)
	LK3D.TraceOverrideNoTrace = bool
end


function LK3D.SetFilterMode(filtermode)
	LK3D.FilterMode = filtermode
end

-----------------------------
-- Universes
-----------------------------
include("lk3d_universes.lua")

-----------------------------
-- Lighting
-----------------------------
include("lk3d_lights.lua")

-----------------------------
-- RenderTarget
-----------------------------
include("lk3d_rendertarget.lua")

-----------------------------
-- Camera
-----------------------------
include("lk3d_camera.lua")

-----------------------------
-- RT Utils
-----------------------------
include("lk3d_rt_utils.lua")

-----------------------------
-- Objects
-----------------------------
include("lk3d_objects.lua")




-- renderer should draw the whole scene, z sorted
function LK3D.RenderActiveUniverse()
	local fine, err = pcall(LK3D.Renderers[LK3D.ActiveRenderer].Render)
	if not fine then
		LK3D.New_D_Print("Error while rendering the whole scene using the \"" .. LK3D.Renderers[LK3D.ActiveRenderer].PrettyName .. "\" renderer; " .. err, LK3D_SERVERITY_FATAL, "LK3D")
	end
end

-- renderer should return a table with depth on screen
function LK3D.RenderActiveDepthArray()
	local fine, arr = pcall(LK3D.Renderers[LK3D.ActiveRenderer].RenderDepth)
	if not fine then
		LK3D.New_D_Print("Error while rendering depth using the \"" .. LK3D.Renderers[LK3D.ActiveRenderer].PrettyName .. "\" renderer; " .. arr, LK3D_SERVERITY_ERROR, "LK3D")
		return
	end

	return arr
end


-- renderer should render an object alone without clearing
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
		ortho = LK3D.Ortho and LK3D.OrthoParameters or nil
	})

end

function LK3D.ToScreen(pos)
	startToScreenView()
		local data = pos:ToScreen()
	cam.End3D()

	return data
end

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
include("lk3d_skeleton.lua")
include("lk3d_intro.lua")
include("lk3d_changelog.lua")
include("lk3d_about.lua")
-- todo surface2d (3d mesh. based 2d lib for lk3d)
LK3D.New_D_Print("LK3D fully loaded!", LK3D_SEVERITY_INFO, "LK3D")