--[[--
## Rendertarget Module
---

This module handles Rendertargets in LK3D, Rendertargets are where LK3D renders to  
It also allows you to perform simple operations like clearing them and rendering stuff to them  
]]
-- @module rendertarget
LK3D = LK3D or {}

LK3D.CurrRenderTarget = LK3D.DEF_RT
LK3D.RenderTargetStack = {}


--- Pushes a new active rendertarget to the stack
-- @tparam rendertarget rt Rendertarget to push
-- @usage LK3D.PushRenderTarget(rt_render)
function LK3D.PushRenderTarget(rt)
	LK3D.RenderTargetStack[#LK3D.RenderTargetStack + 1] = LK3D.CurrRenderTarget
	LK3D.CurrRenderTarget = rt
end

--- Restores the last active rendertarget from the stack  
-- @usage LK3D.PopRenderTarget()
function LK3D.PopRenderTarget()
	LK3D.CurrRenderTarget = LK3D.RenderTargetStack[#LK3D.RenderTargetStack] or LK3D.DEF_RT
	LK3D.RenderTargetStack[#LK3D.RenderTargetStack] = nil
end

--- Clears the active rendertarget with a colour  
-- This also clears the depth and stencil buffer
-- @tparam number r Red value
-- @tparam number g Green value
-- @tparam number b Blue value
-- @tparam ?number a Alpha value
-- @usage LK3D.RenderClear(32, 64, 96)
function LK3D.RenderClear(r, g, b, a)
	render.PushRenderTarget(LK3D.CurrRenderTarget)
		render.OverrideDepthEnable(true, true)
		render.OverrideAlphaWriteEnable(true, true)
		render.Clear(r, g, b, a or 255, true, true)
		render.OverrideAlphaWriteEnable(false)
		render.OverrideDepthEnable(false)
	render.PopRenderTarget()
end

--- Clears the active rendertarget's depth buffer
-- @usage LK3D.RenderClearDepth()
function LK3D.RenderClearDepth()
	render.PushRenderTarget(LK3D.CurrRenderTarget)
		render.OverrideDepthEnable(true, true)
		render.ClearDepth()
		render.OverrideDepthEnable(false)
	render.PopRenderTarget()
end

--- Calls a function to be drawn on the active rendertarget
-- @tparam function call Function to render stuff
-- @usage LK3D.RenderQuick(function()
--   surface.SetDrawColor(255, 0, 0)
--   
--   -- ScrW() and ScrH() are the RT size
--   surface.DrawRect(0, 0, ScrW() * .5, ScrH() * .5)
-- end)
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



LK3D.MatCache = LK3D.MatCache or {}
LK3D.MatCacheTR = LK3D.MatCacheTR or {}
LK3D.MatCacheNoZ = LK3D.MatCacheNoZ or {}

LK3D.MatCache_LM = LK3D.MatCache_LM or {}
LK3D.MatCacheTR_LM = LK3D.MatCacheTR_LM or {}
LK3D.MatCacheNoZ_LM = LK3D.MatCacheNoZ_LM or {}

--- Turns a rendertarget into a lua material  
-- **Not an LK3D Texture**
-- @tparam rendertarget rt Rendertarget to use
-- @tparam ?bool transp Add $alphatest shader parameter
-- @tparam ?bool ignorez Add $ignorez and $nocull shader parameter
-- @treturn material Material of the RT
-- @treturn material Lightmapped material of the RT
-- @usage local rtMat = LK3D.RTToMaterial(rt_render)
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

--- Extended version of LK3D.RTToMaterial()  
-- **Not an LK3D Texture**
-- @tparam rendertarget rt Rendertarget to use
-- @tparam table params Parameters, refer to usage
-- @treturn material Material of the RT
-- @treturn material Lightmapped material of the RT
-- @usage local rtMat = LK3D.RTToMaterialEx(rt_render, {
--	  ["nocull"] = false,
--	  ["ignorez"] = false,
--	  ["vertexcolor"] = true,
--	  ["vertexalpha"] = true,
--	  ["alphatest"] = false,
-- })
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


--- Translucent version of LK3D.RTToMaterial()  
-- **Not an LK3D Texture**
-- @tparam rendertarget rt Rendertarget to use
-- @treturn material Material of the RT
-- @treturn material Lightmapped material of the RT
-- @usage local rtMatTransp = LK3D.RTToMaterialTL(rt_render)
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

--- No-Z version of LK3D.RTToMaterial()  
-- **Not an LK3D Texture**
-- @tparam rendertarget rt Rendertarget to use
-- @tparam bool transp **Broken**
-- @treturn material Material of the RT
-- @treturn material Lightmapped material of the RT
-- @usage local rtMatNoZ = LK3D.RTToMaterialNoZ(rt_render)
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
