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
LK3D.Version = "1.3 \'Green Square\'"

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

LK3D.Const = {}
LK3D.Const.DEF_UNIVERSE = {["lk3d"] = true, ["objects"] = {}, ["lights"] = {}, ["lightcount"] = 0, ["particles"] = {}, ["physics"] = {}}
LK3D.Const.DEF_RT = GetRenderTarget("lk3d_fallback_rt", 800, 600)


LK3D.CamPos = Vector(0, 0, 0)
LK3D.CamAng = Angle(0, 0, 0)
LK3D.WireFrame = false
LK3D.FOV = 90
LK3D.SunDir = Vector(0.75, 1, 1)
LK3D.SunDir:Normalize()
LK3D.ScreenWait = 1 / 60
LK3D.DoDirLighting = true
LK3D.Ortho = false
LK3D.FAR_Z = 200
LK3D.NEAR_Z = .05
LK3D.SHADOW_EXTRUDE = 20
LK3D.DoExpensiveTrace = false
LK3D.TraceReturnTable = false
LK3D.TraceOverrideNoTrace = false
LK3D.FilterMode = TEXFILTER.POINT
LK3D.MatRefresh = 0
LK3D.AmbientCol = Color(0, 0, 0)
LK3D.OrthoParameters = {
	left = 1,
	right = -1,
	top = 1,
	bottom = -1
}

LK3D.CurrUniv = LK3D.Const.DEF_UNIVERSE
LK3D.UniverseStack = {}

LK3D.CurrRenderTarget = LK3D.Const.DEF_RT
LK3D.RenderTargetStack = {}

LK3D.ActiveRenderer = 2 -- this should always be the hardware renderer

LK3D.Renderers = LK3D.Renderers or {}
--include("lk3d_fileparser.lua") -- new fileparser!

local lastRendererID = 0
function LK3D.DeclareRenderer(renderer)
	lastRendererID = lastRendererID + 1
	LK3D.Renderers[lastRendererID] = renderer

	return lastRendererID
end

include("lk3d_renderer_soft.lua")
include("lk3d_renderer_hard.lua")
include("lk3d_renderer_hard2.lua")

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
LK3D.UniverseRegistry = LK3D.UniverseRegistry or {}
function LK3D.NewUniverse(tag)
	if not tag then
		LK3D.New_D_Print("Calling LK3D.NewUniverse without a tag, universe will not work with baked radiosity...", LK3D_SERVERITY_WARN, "LK3D")
		return {["lk3d"] = true, ["objects"] = {}, ["lights"] = {}, ["lightcount"] = 0, ["particles"] = {}, ["physics"] = {}}
	else
		LK3D.New_D_Print("Created universe with tag \"" .. tostring(tag) .. "\"", LK3D_SEVERITY_INFO, "LK3D")
		local tabl = {["lk3d"] = true, ["objects"] = {}, ["lights"] = {}, ["lightcount"] = 0, ["particles"] = {}, ["physics"] = {}, ["tag"] = tag}
		LK3D.UniverseRegistry[tag] = tabl
		return tabl
	end
end

function LK3D.UniverseSetAtr(uni, k, v)
	uni[k] = v
end

function LK3D.UniverseGet(uni, k)
	return uni[k]
end

function LK3D.PushUniverse(uni)
	LK3D.UniverseStack[#LK3D.UniverseStack + 1] = LK3D.CurrUniv
	LK3D.CurrUniv = uni
end

function LK3D.PopUniverse()
	LK3D.CurrUniv = LK3D.UniverseStack[#LK3D.UniverseStack] or LK3D.Const.DEF_UNIVERSE
	LK3D.UniverseStack[#LK3D.UniverseStack] = nil
end

function LK3D.WipeUniverse()
	LK3D.CurrUniv["objects"] = {}
	LK3D.CurrUniv["lights"] = {}
	LK3D.CurrUniv["lightcount"] = 0
	LK3D.CurrUniv["particles"] = {}
	LK3D.CurrUniv["physics"] = {}
end



-----------------------------
-- Lighting
-----------------------------

function LK3D.AddLight(index, pos, intensity, col, smooth)
	LK3D.CurrUniv["lights"][index] = {pos or Vector(0, 0, 0), intensity or 2, col and {col.r / 255, col.g / 255, col.b / 255} or {1, 1, 1}, (smooth == true) and true or false}
	LK3D.CurrUniv["lightcount"] = LK3D.CurrUniv["lightcount"] + 1
end

function LK3D.RemoveLight(index)
	if not LK3D.CurrUniv["lights"][index] then
		return
	end

	LK3D.CurrUniv["lights"][index] = nil
	LK3D.CurrUniv["lightcount"] = LK3D.CurrUniv["lightcount"] - 1
end

function LK3D.UpdateLightPos(index, pos)
	if not LK3D.CurrUniv["lights"][index] then
		return
	end
	LK3D.CurrUniv["lights"][index][1] = pos
end

function LK3D.UpdateLightSmooth(index, smooth)
	if not LK3D.CurrUniv["lights"][index] then
		return
	end
	LK3D.CurrUniv["lights"][index][4] = smooth
end

function LK3D.UpdateLightIntensity(index, intensity)
	if not LK3D.CurrUniv["lights"][index] then
		return
	end

	LK3D.CurrUniv["lights"][index][2] = intensity
end

function LK3D.UpdateLightColour(index, col)
	if not LK3D.CurrUniv["lights"][index] then
		return
	end

	LK3D.CurrUniv["lights"][index][3] = col
end

function LK3D.UpdateLight(index, pos, intensity, col)
	if not LK3D.CurrUniv["lights"][index] then
		return
	end
	local pp = LK3D.CurrUniv["lights"][index][1]
	local pi = LK3D.CurrUniv["lights"][index][2]
	local pc = LK3D.CurrUniv["lights"][index][3]

	LK3D.CurrUniv["lights"][index] = {pos and pos or pp, intensity and intensity or pi, col and col or pc}
end


function LK3D.PushRenderTarget(rt)
	LK3D.RenderTargetStack[#LK3D.RenderTargetStack + 1] = LK3D.CurrRenderTarget
	LK3D.CurrRenderTarget = rt
end

function LK3D.PopRenderTarget()
	LK3D.CurrRenderTarget = LK3D.RenderTargetStack[#LK3D.RenderTargetStack] or LK3D.Const.DEF_RT
	LK3D.RenderTargetStack[#LK3D.RenderTargetStack] = nil
end


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

-- renderer should return light value at pos with optional norm
function LK3D.GetLightIntensity(pos, norm)
	local fine, ret, rg, rb = pcall(LK3D.Renderers[LK3D.ActiveRenderer].GetLightIntensity, pos, norm)
	if not fine then
		LK3D.New_D_Print("Error while getting light intensity using the \"" .. LK3D.Renderers[LK3D.ActiveRenderer].PrettyName .. "\" renderer; " .. ret, LK3D_SERVERITY_ERROR, "LK3D")
		return
	end
	return ret, rg, rb
end


-- this should clear the renderer (erase) with rgb colour
function LK3D.RenderClear(r, g, b, a)
	render.PushRenderTarget(LK3D.CurrRenderTarget)
		render.OverrideDepthEnable(true, true)
		render.OverrideAlphaWriteEnable(true, true)
		render.Clear(r, g, b, a or 255, true, true)
		render.OverrideAlphaWriteEnable(false)
		render.OverrideDepthEnable(false)
	render.PopRenderTarget()
end

function LK3D.RenderClearDepth()
	render.PushRenderTarget(LK3D.CurrRenderTarget)
		render.OverrideDepthEnable(true, true)
		render.ClearDepth()
		render.OverrideDepthEnable(false)
	render.PopRenderTarget()
end


function LK3D.RenderQuick(call)
	local ow, oh = ScrW(), ScrH()
	render.SetViewPort(0, 0, LK3D.CurrRenderTarget:Width(), LK3D.CurrRenderTarget:Height())
	cam.Start2D()
	render.PushRenderTarget(LK3D.CurrRenderTarget)
	render.PushFilterMag(LK3D.FilterMode)
	render.PushFilterMin(LK3D.FilterMode)
		local fine, err = pcall(call)
		if not fine then
			LK3D.New_D_Print("RenderQuick fail; " .. err, LK3D_SERVERITY_ERROR, "LK3D")
		end
	render.PopFilterMag()
	render.PopFilterMin()
	render.PopRenderTarget()
	cam.End2D()
	render.SetViewPort(0, 0, ow, oh)
end

-----------------------------
-- Translation / Rotation
-----------------------------
function LK3D.SetCamPos(np)
	LK3D.CamPos = np
end

function LK3D.SetCamAng(na)
	LK3D.CamAng = na
end

function LK3D.SetCamPosAng(np, na)
	LK3D.CamPos = np or LK3D.CamPos
	LK3D.CamAng = na or LK3D.CamAng
end

LK3D.MatCache = LK3D.MatCache or {}
LK3D.MatCacheTR = LK3D.MatCacheTR or {}
LK3D.MatCacheNoZ = LK3D.MatCacheNoZ or {}

LK3D.MatCache_LM = LK3D.MatCache_LM or {}
LK3D.MatCacheTR_LM = LK3D.MatCacheTR_LM or {}
LK3D.MatCacheNoZ_LM = LK3D.MatCacheNoZ_LM or {}

function LK3D.RTToMaterial(rt, transp, ignorez)
	if not LK3D.MatCache[rt:GetName()] then
		LK3D.New_D_Print(rt:GetName() .. " isnt cached, caching!", LK3D_SEVERITY_DEBUG, "Utils")

		LK3D.MatCache[rt:GetName()] = CreateMaterial(rt:GetName() .. "_materialized_lk3d", "UnlitGeneric", {
			["$basetexture"] = rt:GetName(),
			["$nocull"] = ignorez and 1 or 0,
			["$ignorez"] = ignorez and 1 or 0,
			["$vertexcolor"] = 1,
			["$alphatest"] = transp and 1 or 0,
		})

		LK3D.MatCache_LM[rt:GetName()] = CreateMaterial("lm_" .. rt:GetName() .. "_materialized_lk3d", "LightmappedGeneric", {
			["$basetexture"] = rt:GetName(),
			["$nocull"] = ignorez and 1 or 0,
			["$ignorez"] = ignorez and 1 or 0,
			["$vertexcolor"] = 1,
			["$alphatest"] = transp and 1 or 0,
		})
	end

	return LK3D.MatCache[rt:GetName()], LK3D.MatCache_LM[rt:GetName()]
end


function LK3D.RTToMaterialEx(rt, params)
	if not LK3D.MatCache[rt:GetName()] then
		LK3D.New_D_Print(rt:GetName() .. " isnt cached, caching!", LK3D_SEVERITY_DEBUG, "Utils")

		LK3D.MatCache[rt:GetName()] = CreateMaterial(rt:GetName() .. "_materialized_lk3d", "UnlitGeneric", {
			["$basetexture"] = rt:GetName(),
			["$nocull"] = params["nocull"] and 1 or 0,
			["$ignorez"] = params["ignorez"] and 1 or 0,
			["$vertexcolor"] = params["vertexcolor"] and 1 or 0,
			["$vertexalpha"] = params["vertexalpha"] and 1 or 0,
			["$alphatest"] = params["alphatest"] and 1 or 0,
		})


		if params["lightmapped"] then
			LK3D.MatCache_LM[rt:GetName()] = CreateMaterial("lm_" .. rt:GetName() .. "_materialized_lk3d", "LightmappedGeneric", {
				["$basetexture"] = rt:GetName(),
				["$nocull"] = params["nocull"] and 1 or 0,
				["$ignorez"] = params["ignorez"] and 1 or 0,
				["$vertexcolor"] = params["vertexcolor"] and 1 or 0,
				["$vertexalpha"] = params["alphatest"] and 1 or 0,
				["$alphatest"] = params["alphatest"] and 1 or 0,
			})
		end
	end

	return LK3D.MatCache[rt:GetName()], LK3D.MatCache_LM[rt:GetName()]
end


function LK3D.RTToMaterialTL(rt)
	if not LK3D.MatCacheTR[rt:GetName()] then
		LK3D.New_D_Print(rt:GetName() .. " isnt cached, caching!", LK3D_SEVERITY_DEBUG, "Utils")

		LK3D.MatCacheTR[rt:GetName()] = CreateMaterial(rt:GetName() .. "_materialized_lk3d_transparent", "UnlitGeneric", {
			["$basetexture"] = rt:GetName(),
			--["$nocull"] = 1,
			["$vertexcolor"] = 1,
			["$vertexalpha"] = 1,
		})

		LK3D.MatCacheTR_LM[rt:GetName()] = CreateMaterial(rt:GetName() .. "_materialized_lk3d_transparent_lm", "LightmappedGeneric", {
			["$basetexture"] = rt:GetName(),
			--["$nocull"] = 1,
			["$vertexcolor"] = 1,
			["$vertexalpha"] = 1,
		})
	end

	return LK3D.MatCacheTR[rt:GetName()], LK3D.MatCacheTR_LM[rt:GetName()]
end


function LK3D.RTToMaterialNoZ(rt, transp)
	if not LK3D.MatCacheNoZ[rt:GetName()] then
		LK3D.New_D_Print(rt:GetName() .. " isnt cached, caching!", LK3D_SEVERITY_DEBUG, "Utils")

		LK3D.MatCacheNoZ[rt:GetName()] = CreateMaterial("noz_" .. rt:GetName() .. "_materialized_lk3d", "UnlitGeneric", {
			["$basetexture"] = rt:GetName(),
			["$nocull"] = 1,
			["$ignorez"] = 1,
			["$vertexcolor"] = 1,
			--["$alphatest"] = transp and 1 or 0,
		})

		LK3D.MatCacheNoZ_LM[rt:GetName()] = CreateMaterial("noz_" .. rt:GetName() .. "_materialized_lk3d_lm", "LightmappedGeneric", {
			["$basetexture"] = rt:GetName(),
			["$nocull"] = 1,
			["$ignorez"] = 1,
			["$vertexcolor"] = 1,
			--["$alphatest"] = transp and 1 or 0,
		})
	end

	return LK3D.MatCacheNoZ[rt:GetName()], LK3D.MatCacheNoZ_LM[rt:GetName()]
end

-- this uses render.Spin() to render a helpful message over how we're processing sutff
local rt_nfo = GetRenderTarget("lk3d_processing_rt", 512, 512)
function LK3D.RenderProcessingMessage(message, prog, xtrarender)
	local last_rt = nil
	if render.GetRenderTarget() ~= nil then
		last_rt = render.GetRenderTarget()
		render.PopRenderTarget()
	end


	local ow, oh = ScrW(), ScrH()
	render.SetViewPort(0, 0, 512, 512)
	cam.Start2D()
	render.PushRenderTarget(rt_nfo)
		render.SetColorMaterialIgnoreZ()
		draw.NoTexture()

		local proc_mat = LK3D.GetTextureByIndex("lk3d_processing").mat
		surface.SetDrawColor(255, 255, 255, 255)
		surface.SetMaterial(proc_mat)
		surface.DrawTexturedRect(0, 0, ScrW(), ScrH())

		if message then
			surface.SetDrawColor(64, 84, 200)

			local m_scl = Matrix()
			m_scl:SetTranslation(Vector(0, 12 * 4))
			m_scl:SetScale(Vector(2, 2))
			cam.PushModelMatrix(m_scl)
				draw.DrawText(message, "BudgetLabel", 0, 0, Color(64, 84, 200), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			cam.PopModelMatrix()
		end

		if prog then
			local m_scl = Matrix()
			m_scl:SetTranslation(Vector(0, ScrH() - 120))
			m_scl:SetScale(Vector(4, 4))
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




-- adds a model to the current universe
function LK3D.AddModelToUniverse(index, mdl, pos, ang)
	LK3D.New_D_Print("Adding \"" .. index .. "\" to universe with model \"" .. (mdl or "cube") .. "\"", LK3D_SEVERITY_DEBUG, "LK3D")
	if not LK3D.Models[mdl] then
		LK3D.New_D_Print("Model \"" .. mdl .. "\" doesnt exist!", LK3D_SERVERITY_WARN, "LK3D")
		mdl = "fail"
	end

	local tmatrix_o = Matrix()
	tmatrix_o:SetTranslation(pos or Vector(0, 0, 0))
	tmatrix_o:SetAngles(ang or Angle(0, 0, 0))
	tmatrix_o:SetScale(Vector(1, 1, 1))

	LK3D.CurrUniv["objects"][index] = {
		mdl = mdl or "cube",
		pos = pos or Vector(0, 0, 0),
		ang = ang or Angle(0, 0, 0),
		scl = Vector(1, 1, 1),
		mat = "white",
		col = Color(255, 255, 255, 255),
		name = index,
		tmatrix = tmatrix_o -- translation matrix new
	}
end

function LK3D.RemoveModelFromUniverse(index)
	LK3D.CurrUniv["objects"][index] = nil
end


function LK3D.SetModelMat(index, mat)
	if not LK3D.CurrUniv["objects"][index] then
		return
	end

	if not LK3D.Textures[mat] then
		LK3D.CurrUniv["objects"][index].mat = "fail"
		return
	end

	LK3D.CurrUniv["objects"][index].mat = mat
end

function LK3D.SetModelCol(index, col)
	if not LK3D.CurrUniv["objects"][index] then
		return
	end

	LK3D.CurrUniv["objects"][index].col = col
end

function LK3D.SetModelPos(index, pos)
	LK3D.CurrUniv["objects"][index].pos = pos
	LK3D.CurrUniv["objects"][index].tmatrix:SetTranslation(pos)
end

function LK3D.SetModelAng(index, ang)
	LK3D.CurrUniv["objects"][index].ang = ang
	LK3D.CurrUniv["objects"][index].tmatrix:SetAngles(ang)
end
function LK3D.SetModelScale(index, scale)
	LK3D.CurrUniv["objects"][index].scl = scale
	LK3D.CurrUniv["objects"][index].tmatrix:SetScale(scale)
end

function LK3D.SetModelModel(index, mdl)
	if not LK3D.Models[mdl] then
		return
	end
	if mdl == LK3D.CurrUniv["objects"][index].mdl then
		return
	end
	LK3D.CurrUniv["objects"][index].mdl = mdl

	if LK3D.CurrUniv["modelCache"] then
		LK3D.CurrUniv["modelCache"][index] = nil
	end
end

function LK3D.SetModelPosAng(index, pos, ang)
	LK3D.CurrUniv["objects"][index].pos = pos or Vector(0, 0, 0)
	LK3D.CurrUniv["objects"][index].ang = ang or Angle(0, 0, 0)
	LK3D.CurrUniv["objects"][index].tmatrix:SetAngles(ang or Angle(0, 0, 0))
	LK3D.CurrUniv["objects"][index].tmatrix:SetTranslation(pos or Vector(0, 0, 0))
end

function LK3D.SetModelFlag(index, flag, value)
	if flag == nil then
		return
	end

	LK3D.CurrUniv["objects"][index][flag] = value
end

function LK3D.SetModelHide(index, bool)
	LK3D.CurrUniv["objects"][index]["RENDER_NOGLOBAL"] = bool
end


function LK3D.DeclareModelAnim(index, an_index, frames, func)
	local object = LK3D.CurrUniv["objects"][index]

	if object.mdlCache == nil then
		object.mdlCache = {}
	end


	object.mdlCache[an_index or "UNDEFINED"] = {
		frames = frames or 6,
		func = func or function() end,
		meshes = {},
		genned = false
	}
	object.anim_delta = object.anim_delta or 0
	object.anim_rate = object.anim_rate or 1
	object.anim_state = object.anim_state or true
end
-- model funcs =
-- function(delta, vpos, vuv, vrgb, vnorm)
-- return nothing just alter


function LK3D.SetModelAnimPlayRate(index, rate)
	LK3D.CurrUniv["objects"][index].anim_rate = rate or 1
end

function LK3D.SetModelAnimPlay(index, bool)
	LK3D.CurrUniv["objects"][index].anim_state = bool or false
end

function LK3D.SetModelAnimDelta(index, delta)
	LK3D.CurrUniv["objects"][index].anim_delta = delta or 0
end

function LK3D.SetModelAnim(index, an_index)
	LK3D.CurrUniv["objects"][index].anim_index = an_index
end


include("lk3d_lkpack.lua") -- lkpack first
include("lk3d_modelutils.lua")
include("lk3d_procmodel.lua")
include("lk3d_models.lua")

LK3D.ModelInitExtra = LK3D.ModelInitExtra or {}
for k, v in pairs(LK3D.ModelInitExtra) do
	local fine, err = pcall(v) -- fix extern model init load issues
	if not fine then
		LK3D.New_D_Print("LK3D ModelInitExtra error! [" .. k .. "]; " .. err, LK3D_SEVERITY_ERROR, "LK3D")
	end
end

include("lk3d_textures.lua")


include("lk3d_particles.lua")
include("lk3d_debugutils.lua")
include("lk3d_trace.lua")
include("lk3d_bmark.lua")
include("lk3d_rt.lua")
include("lk3d_proctex.lua")
include("lk3d_physics.lua")
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

LK3D.InitProcessTexture()
LK3D.New_D_Print("LK3D fully loaded!", LK3D_SEVERITY_INFO, "LK3D")