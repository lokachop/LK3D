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
