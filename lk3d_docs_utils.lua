LK3D = LK3D or {}
file.CreateDir("lk3d/png_captures")
-- used to generate stuff for the docs manual
local rtSz = 256
local rtRender = GetRenderTarget("LK3DWikiRT_" .. rtSz, rtSz, rtSz)
local rtRenderSmooth = GetRenderTarget("LK3DWikiRTSmooth_" .. rtSz, rtSz, rtSz)
local rtRenderStitch = GetRenderTarget("LK3DWikiRTStitch_" .. rtSz, rtSz * 2, rtSz)

local univWiki = LK3D.NewUniverse("lk3d_wiki_univ")

local function rtToPNG(rt, name)
	local rw, rh = rt:Width(), rt:Height()

	local ow, oh = ScrW(), ScrH()
	render.SetViewPort(0, 0, rw, rh)
	render.PushRenderTarget(rt)
		local pngData = render.Capture({
			format = "png",
			alpha = true,
			x = 0,
			y = 0,
			w = rw,
			h = rh,
		})
	render.PopRenderTarget()
	render.SetViewPort(0, 0, ow, oh)

	if pngData == nil then
		print("Dont have mainmenu open!")
		return
	end

	print("Capture successful!")
	file.Write("lk3d/png_captures/" .. name .. ".png", pngData)
end


LK3D.PushUniverse(univWiki)
	LK3D.AddObjectToUniverse("object", "cube_nuv")
	LK3D.SetObjectPosAng("object", Vector(0, 0, 0), Angle(0, 0, 90))
	LK3D.SetObjectScale("object", Vector(1, 1, 1))
	LK3D.SetObjectMat("object", "white")
	LK3D.SetObjectFlag("object", "NO_LIGHTING", true)
	LK3D.SetObjectFlag("object", "NO_SHADING", true)
	LK3D.SetObjectFlag("object", "SHADING_SMOOTH", false)
	LK3D.SetObjectFlag("object", "CONSTANT", true)

	LK3D.AddLight("light", Vector(0, 0, 0), 4, Color(255, 196, 128), true)
LK3D.PopUniverse()




local cWhite = Color(255, 255, 255)
local function renderShaderPreview(mdl, mat, smoothshade, shader, rt)
	LK3D.PushUniverse(univWiki)
		LK3D.SetObjectModel("object", mdl)
		LK3D.SetObjectMat("object", mat)
		LK3D.SetObjectFlag("object", "SHADING_SMOOTH", smoothshade)
		LK3D.SetObjectPrefabShader("object", shader)
		LK3D.SetObjectFlag("object", "NEEDS_CACHE_UPDATE", true)
		LK3D.SetObjectFlag("object", "SHADOW_VOLUME_BAKE_CLEAR", true)
		LK3D.SetObjectFlag("object", "SHADER_NO_SMOOTHNORM", not smoothshade)

		local aabbData = LK3D.GetRecalcAABB(LK3D.CurrUniv["objects"]["object"])
		local mins = aabbData[1]
		local maxs = aabbData[2]


		local cPos = Vector(mins[1] * 2.5, maxs[2] * 3.25, maxs[3] * 1.5)
		local cAng = (Vector(0, 0, 0) - cPos):Angle()
		cAng[1] = cAng[1]
		cAng[2] = cAng[2]

		LK3D.UpdateLightPos("light", cPos)

		local prevPos = LK3D.CamPos
		local prevAng = LK3D.CamAng
		local prevFOV = LK3D.FOV
		local prevDebug = LK3D.Debug

		LK3D.Debug = false
		LK3D.SetCamPos(cPos)
		LK3D.SetCamAng(cAng)
		LK3D.SetCamFOV(55)
		LK3D.PushRenderTarget(rt)
			LK3D.RenderClear(8, 16, 24)
			LK3D.RenderActiveUniverse()

			LK3D.RenderQuick(function()
				print("render")
				local nameString = mdl .. " [" .. shader .. "]"
				PONR.DrawRetroText(nil, nameString, ScrW() * .5, ScrH() * .85, cWhite, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1)
				if smoothshade then
					PONR.DrawRetroText(nil, "(smooth)", ScrW() * .5, ScrH() * .85 + 16, cWhite, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1)
				end
			end)
		LK3D.PopRenderTarget()
		LK3D.SetCamPos(prevPos)
		LK3D.SetCamAng(prevAng)
		LK3D.SetCamFOV(prevFOV)
		LK3D.Debug = prevDebug
	LK3D.PopUniverse()

	file.CreateDir("lk3d/png_captures/" .. shader)
end

local shader_materials = {
	["reflective"] = "spheremap_hq",
	["reflective_simple"] = "spheremap_hq",
	["reflective_screen_rot"] = "spheremap_hq",

	["norm_screenspace"] = "white",
	["norm_screenspace_rot"] = "white",
	["norm_vis"] = "white",
	["norm_vis_rot"] = "white",

	["world_pos"] = "white",
	["world_pos_local"] = "white",

	["vert_col"] = "white",
	["depth"] = "white",
}

local models_render = {
	"cube_nuv",
	"sphere_t1",
	"barrel",
	"suzanne",
}

local function getMaterialForShader(shader)
	if shader_materials[shader] then
		return shader_materials[shader]
	end

	return "checker_big"
end


-- ???

local function doShaderPreviewStitched(mdl, mat, shader)
	renderShaderPreview(mdl, mat, false, shader, rtRender)
	renderShaderPreview(mdl, mat, true, shader, rtRenderSmooth)

	local matRT1 = LK3D.RTToMaterial(rtRender, false, true)
	local matRT2 = LK3D.RTToMaterial(rtRenderSmooth, false, true)

	LK3D.PushRenderTarget(rtRenderStitch)
		LK3D.RenderQuick(function()
			render.Clear(0, 0, 0, 255)

			surface.SetDrawColor(255, 255, 255)
			surface.SetMaterial(matRT1)
			surface.DrawTexturedRect(0, 0, rtSz, rtSz)

			surface.SetMaterial(matRT2)
			surface.DrawTexturedRect(rtSz, 0, rtSz, rtSz)
		end)
	LK3D.PopRenderTarget()


	rtToPNG(rtRenderStitch, shader .. "/" .. mdl)
end






concommand.Add("lk3d_render_wiki_images", function()
	print("Go!, Close EscapeMenu!")
	timer.Simple(1, function()
		print("Executing!")

		for k, v in pairs(LK3D.Shaders) do
			local shaderName = k
			for i = 1, #models_render do
				local mdl = models_render[i]
				local mat = getMaterialForShader(shaderName)

				doShaderPreviewStitched(mdl, mat, shaderName)
			end
		end
	end)
end)