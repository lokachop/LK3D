LK3D = LK3D or {}

LK3D.CurrRenderTarget = LK3D.DEF_RT
LK3D.RenderTargetStack = {}
function LK3D.PushRenderTarget(rt)
	LK3D.RenderTargetStack[#LK3D.RenderTargetStack + 1] = LK3D.CurrRenderTarget
	LK3D.CurrRenderTarget = rt
end

function LK3D.PopRenderTarget()
	LK3D.CurrRenderTarget = LK3D.RenderTargetStack[#LK3D.RenderTargetStack] or LK3D.DEF_RT
	LK3D.RenderTargetStack[#LK3D.RenderTargetStack] = nil
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
