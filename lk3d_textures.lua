LK3D = LK3D or {}
-----------------------------
-- Textures
-----------------------------

LK3D.Textures = LK3D.Textures or {}

function LK3D.GetTextureByIndex(index)
	if not LK3D.Textures[index] then
		return LK3D.Textures["fail"]
	end

	return LK3D.Textures[index]
end

function LK3D.FriendlySourceTextureNTNC(matsrc)
	local matc = CreateMaterial(matsrc .. "_friendly_ntnc_", "UnlitGeneric", {
		["$basetexture"] = matsrc,
		["$nodecal"] = 1,
		["$ignorez"] = 1,
		["$nocull"] = 1,
		["$vertexcolor"] = 1,
	})

	-- from adv. material stool, idk where the github is though
	if (matc.GetString(matc, "$basetexture") ~= matsrc) then
		local m = Material(matsrc)
		matc.SetTexture(matc, "$basetexture", m.GetTexture(m, "$basetexture"))
	end

	return matc
end


function LK3D.FriendlySourceTexture(matsrc)
	local matc = CreateMaterial(matsrc .. "_friendly_", "UnlitGeneric", {
		["$basetexture"] = matsrc,
		["$nodecal"] = 1,
		["$ignorez"] = 1,
		--["$nocull"] = 1,
		["$vertexcolor"] = 1,
		["$vertexalpha"] = 1
	})

	-- from adv. material stool, idk where the github is though
	if (matc.GetString(matc, "$basetexture") ~= matsrc) then
		local m = Material(matsrc)
		matc.SetTexture(matc, "$basetexture", m.GetTexture(m, "$basetexture"))
	end

	return matc
end


function LK3D.UpdateRtEz(rt, call)
	local ow, oh = ScrW(), ScrH()
	render.SetViewPort(0, 0, rt:Width(), rt:Height())
	cam.Start2D()
	render.PushRenderTarget(rt)
	render.PushFilterMag(LK3D.FilterMode)
	render.PushFilterMin(LK3D.FilterMode)
		pcall(call)
	render.PopFilterMag()
	render.PopFilterMin()
	render.PopRenderTarget()
	cam.End2D()
	render.SetViewPort(0, 0, ow, oh)
end


function LK3D.DeclareTextureFromFunc(index, w, h, func, transp, ignorez)
	LK3D.New_D_Print("Declaring texture \"" .. index .. "\" [" .. w .. "x" .. h .. "]; FUNC", 2, "Textures")
	if not LK3D.Textures[index] then
		local rtg = GetRenderTarget("lk3d_mat_" .. index .. "_rt", w, h)
		local matg, matg_lm = LK3D.Utils.RTToMaterial(rtg, transp, ignorez)

		LK3D.Textures[index] = {
			rt = rtg,
			mat = matg,
			mat_lm = matg_lm,
			name = index
		}
	end

	local ow, oh = ScrW(), ScrH()
	render.SetViewPort(0, 0, w, h)
	cam.Start2D()
	render.PushRenderTarget(LK3D.Textures[index].rt)
	render.PushFilterMag(LK3D.FilterMode)
	render.PushFilterMin(LK3D.FilterMode)
		render.Clear(0, 0, 0, 0)
		if transp then
			render.OverrideAlphaWriteEnable(true, true)
		end
		local fine, err = pcall(func)
		if not fine then
			LK3D.New_D_Print("Error while making texture \"" .. index .. "\" [" .. w .. "x" .. h .. "]; " .. err, 4, "Textures")
		end
		if transp then
			render.OverrideAlphaWriteEnable(false)
		end
	render.PopFilterMag()
	render.PopFilterMin()
	render.PopRenderTarget()
	cam.End2D()
	render.SetViewPort(0, 0, ow, oh)

	-- returning for noobs i guess
	return LK3D.Textures[index]
end

function LK3D.DeclareTextureFromSourceMat(index, w, h, mat, transp)
	LK3D.New_D_Print("Declaring texture \"" .. index .. "\" [" .. w .. "x" .. h .. "]; SMAT", 2, "Textures")
	if not LK3D.Textures[index] then
		local rtg = GetRenderTarget("lk3d_mat_" .. index .. "_rt", w, h)
		local matg, matg_lm = LK3D.Utils.RTToMaterial(rtg, transp)

		LK3D.Textures[index] = {
			rt = rtg,
			mat = matg,
			mat_lm = matg_lm,
			name = index
		}
	end

	local matGetWhite = LK3D.FriendlySourceTexture(mat)

	local ow, oh = ScrW(), ScrH()
	cam.Start2D()
	render.PushRenderTarget(LK3D.Textures[index].rt)
	render.SetViewPort(0, 0, w, h)
		if transp then
			render.OverrideAlphaWriteEnable(true, true)
		end
		render.Clear(0, 0, 0, 0)
		render.SetMaterial(matGetWhite)
		render.DrawScreenQuad()
		if transp then
			render.OverrideAlphaWriteEnable(false)
		end
	render.SetViewPort(0, 0, ow, oh)
	render.PopRenderTarget()
	cam.End2D()
end

function LK3D.DeclareTextureFromMatObj(index, w, h, matobj, transp)
	LK3D.New_D_Print("Declaring texture \"" .. index .. "\" [" .. w .. "x" .. h .. "]; MATOBJ", 2, "Textures")
	if not LK3D.Textures[index] then
		local rtg = GetRenderTarget("lk3d_mat_" .. index .. "_rt", w, h)
		local matg, matg_lm = LK3D.Utils.RTToMaterial(rtg, transp)

		LK3D.Textures[index] = {
			rt = rtg,
			mat = matg,
			mat_lm = matg_lm,
			name = index
		}
	end

	local ow, oh = ScrW(), ScrH()


	render.SetViewPort(0, 0, w, h)
	cam.Start2D()
	render.PushRenderTarget(LK3D.Textures[index].rt)
		if transp then
			render.OverrideAlphaWriteEnable(true, true)
		end
		render.Clear(0, 0, 0, 0)
		surface.SetDrawColor(255, 255, 255)
		surface.SetMaterial(matobj)
		surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
		if transp then
			render.OverrideAlphaWriteEnable(false)
		end
	render.PopRenderTarget()
	cam.End2D()
	render.SetViewPort(0, 0, ow, oh)
end

function LK3D.CopyTextureRT(name, to)
	local ow, oh = ScrW(), ScrH()
	local trrt = LK3D.GetTextureByIndex(name).rt
	render.SetViewPort(0, 0, trrt:Width(), trrt:Height())
	cam.Start2D()
	render.PushRenderTarget(LK3D.GetTextureByIndex(name).rt)
		render.CopyRenderTargetToTexture(to)
	render.PopRenderTarget()
	cam.End2D()
	render.SetViewPort(0, 0, ow, oh)
end

function LK3D.CopyTexture(from, to)
	local ow, oh = ScrW(), ScrH()
	local t_mat = LK3D.GetTextureByIndex(from).rt
	render.SetViewPort(0, 0, t_mat:Width(), t_mat:Height())
	cam.Start2D()
	render.PushRenderTarget(LK3D.GetTextureByIndex(to).rt)
		render.Clear(128, 128, 255, 255, true, true)
		render.DrawTextureToScreen(t_mat)
	render.PopRenderTarget()
	cam.End2D()
	render.SetViewPort(0, 0, ow, oh)
end


local mat_noz = CreateMaterial("mat_noz_lk3d", "UnlitGeneric", {
	["$basetexture"] = "color/white",
	["$nocull"] = 1,
	["$ignorez"] = 1,
	["$vertexcolor"] = 1,
	["$vertexalpha"] = 1
})

function LK3D.UpdateTexture(index, func)
	if not LK3D.Textures[index] then
		return
	end

	--if (LK3D.Textures[index].nextUpdate or 0) > CurTime() then
	--	return
	--end

	--LK3D.Textures[index].nextUpdate = CurTime() + LK3D.ScreenWait


	local rt = LK3D.Textures[index].rt

	local w, h = rt:Width(), rt:Height()

	local ow, oh = ScrW(), ScrH()
	render.SetViewPort(0, 0, w, h)
	cam.Start2D()
	render.PushRenderTarget(rt)
		render.SetColorMaterialIgnoreZ()
		draw.NoTexture()
		local fine, err = pcall(func)
		if not fine then
			LK3D.New_D_Print("Error while updating texture \"" .. index .. "\" [" .. w .. "x" .. h .. "]; " .. err, 4, "Textures")
		end
	render.PopRenderTarget()
	cam.End2D()
	render.SetViewPort(0, 0, ow, oh)
end

function LK3D.GetTextureSize(index)
	if not LK3D.Textures[index] then
		LK3D.D_Print("no texture \"" .. index .. "\"!", 4, "Textures")
		return
	end

	local imgdat = LK3D.Textures[index]
	return imgdat.rt:Width(), imgdat.rt:Height()
end


function LK3D.GetTexturePixelArray(index, inline)
	if not LK3D.Textures[index] then
		LK3D.D_Print("no texture \"" .. index .. "\"!", 4, "Textures")
		return
	end

	-- loop through every pixel :/
	local imgdat = LK3D.Textures[index]
	local iw, ih = imgdat.rt:Width(), imgdat.rt:Height()


	local img_arr = {}


	local ow, oh = ScrW(), ScrH()
	render.SetViewPort(0, 0, iw, ih)
	cam.Start2D()
	render.PushRenderTarget(imgdat.rt)
		render.SetColorMaterialIgnoreZ()
		draw.NoTexture()


		-- build the image array so we can sample pixels
		render.CapturePixels()
		for i = 0, (iw * ih) - 1 do
			local xc = i % iw
			local yc = math.floor(i / iw)
			if (not inline) and (not img_arr[xc]) then
				img_arr[xc] = {}
			end

			local rr, rg, rb, ra = render.ReadPixel(xc, yc)
			if not inline then
				img_arr[xc][yc] = {rr, rg, rb, ra}
			else
				img_arr[i + 1] = {rr, rg, rb, ra}
			end
		end
	render.PopRenderTarget()
	cam.End2D()
	render.SetViewPort(0, 0, ow, oh)


	return img_arr
end


function LK3D.ApplyShaderEffect(index, func)
	if not func then
		return
	end


	if not LK3D.Textures[index] then
		LK3D.D_Print("no texture \"" .. index .. "\"!", 4, "Textures")
		return
	end


	-- loop through every pixel :/
	local imgdat = LK3D.Textures[index]
	local iw, ih = imgdat.rt:Width(), imgdat.rt:Height()


	local img_arr = {}


	local ow, oh = ScrW(), ScrH()
	render.SetViewPort(0, 0, iw, ih)
	cam.Start2D()
	render.PushRenderTarget(imgdat.rt)
		render.SetColorMaterialIgnoreZ()
		draw.NoTexture()


		-- build the image array so we can sample pixels
		render.CapturePixels()
		for i = 0, (iw * ih) - 1 do
			local xc = i % iw
			local yc = math.floor(i / iw)
			if not img_arr[xc] then
				img_arr[xc] = {}
			end

			local rr, rg, rb, ra = render.ReadPixel(xc, yc)
			img_arr[xc][yc] = {rr, rg, rb, ra}
		end


		for i = 0, (iw * ih) - 1 do
			local xc = i % iw
			local yc = math.floor(i / iw)

			local fine, err = pcall(func, xc, yc, img_arr)
			if not fine then
				LK3D.New_D_Print("ShaderTexture error! \"" .. err .. "\"", 4, "Textures")
				break
			end
		end
	render.PopRenderTarget()
	cam.End2D()
	render.SetViewPort(0, 0, ow, oh)
end




function LK3D.InitProcessTexture()
	if not LK3D.AddModelToUniverse then
		return
	end

	if not LK3D.NewUniverse then
		return
	end

	local univ_process = LK3D.NewUniverse("lk3d_uni_procscr")
	LK3D.PushUniverse(univ_process)
		LK3D.AddLight("li_1", Vector(-.8, .4, .7), 1.75, Color(245, 240, 196), true)


		LK3D.AddModelToUniverse("loka_test", "lokachop")
		LK3D.SetModelPosAng("loka_test", Vector(0, 0, 0), Angle(0, 90, 90))
		LK3D.SetModelFlag("loka_test", "NO_SHADING", true)
		LK3D.SetModelFlag("loka_test", "SHADING_SMOOTH", false)
		LK3D.SetModelFlag("loka_test", "NO_LIGHTING", false)
		LK3D.SetModelFlag("loka_test", "NORM_LIGHT_AFFECT", false)
		LK3D.SetModelFlag("loka_test", "SHADOW_VOLUME", true)
		LK3D.SetModelFlag("loka_test", "SHADOW_ZPASS", false)
		LK3D.SetModelScale("loka_test", Vector(.25, .25, .25))
		LK3D.SetModelMat("loka_test", "process_loka1")


		LK3D.AddModelToUniverse("plane_face", "plane")
		LK3D.SetModelPosAng("plane_face", Vector(-.18, 0, .25), Angle(0, 90, 0))
		LK3D.SetModelFlag("plane_face", "NO_SHADING", true)
		LK3D.SetModelFlag("plane_face", "NO_LIGHTING", true)
		LK3D.SetModelScale("plane_face", Vector(.175, .175, .15))
		LK3D.SetModelMat("plane_face", "lokaface4_slash")
		LK3D.SetModelHide("plane_face", true)
	LK3D.PopUniverse()


	LK3D.DeclareTextureFromFunc("lk3d_processing", 512, 512, function()
		render.Clear(32, 128, 48, 255, true, true)
		LK3D.PushRenderTarget(render.GetRenderTarget())
		LK3D.PushUniverse(univ_process)
			LK3D.SetCamPos(Vector(-1, .35, .45))
			LK3D.SetCamAng(Angle(14, -20, 0))
			LK3D.SetOrtho(true)

			local orths = 0.30
			LK3D.SetOrthoParameters({
				left = -orths,
				right = orths,
				top = -orths,
				bottom = orths,
			})

			LK3D.RenderClear(0, 0, 0)
			LK3D.RenderActiveUniverse()
			LK3D.RenderObject("plane_face") -- avoid shadow
			LK3D.SetOrtho(false)
		LK3D.PopUniverse()
		LK3D.PopRenderTarget()


		render.BlurRenderTarget(render.GetRenderTarget(), 4, 4, 6)
		surface.SetDrawColor(96, 74, 65, 96)
		surface.DrawRect(0, 0, ScrW(), ScrH())


		local m_scl = Matrix()
		m_scl:SetTranslation(Vector(ScrW() * .5, 0))
		m_scl:SetScale(Vector(4, 4))
		cam.PushModelMatrix(m_scl)
			draw.SimpleText("LK3D Processing...", "BudgetLabel", 0, 0, Color(255, 160, 76), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		cam.PopModelMatrix()

		m_scl = Matrix()
		m_scl:SetTranslation(Vector(0, ScrH()))
		m_scl:SetScale(Vector(4, 4))
		cam.PushModelMatrix(m_scl)
			draw.SimpleText("Please wait...", "BudgetLabel", 0, 0, Color(255, 160, 76), TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
		cam.PopModelMatrix()
	end, false, true)
end

function LK3D.SetupBaseMaterials()
	-- make default mats
	LK3D.DeclareTextureFromFunc("fail", 16, 16, function()
		render.Clear(0, 0, 0, 255)
		surface.SetDrawColor(255, 0, 255)
		surface.DrawRect(0, 0, 8, 8)
		surface.DrawRect(8, 8, 8, 8)
	end)

	LK3D.DeclareTextureFromFunc("checker", 16, 16, function()
		render.Clear(64, 64, 64, 255)
		surface.SetDrawColor(96, 96, 96)
		surface.DrawRect(0, 0, 8, 8)
		surface.DrawRect(8, 8, 8, 8)
	end)


	LK3D.DeclareTextureFromFunc("intro_plane", 1024, 1024, function()
		render.Clear(64, 64, 64, 255)
		surface.SetDrawColor(96, 96, 96)
		surface.DrawRect(0, 0, 512, 512)
		surface.DrawRect(512, 512, 512, 512)
	end)

	LK3D.DeclareTextureFromFunc("intro_box1", 128, 128, function()
		render.Clear(255, 255, 255, 255)
	end)

	LK3D.DeclareTextureFromFunc("intro_loka1", 196, 196, function()
		render.Clear(250, 240, 174, 255)
	end)

	LK3D.DeclareTextureFromFunc("intro_paint_loka3", 64, 64, function()
		render.Clear(38, 65, 38, 0)
	end, true)

	LK3D.DeclareTextureFromFunc("intro_sign_powered2", 96, 96, function()
		render.Clear(255, 255, 255, 0)

		draw.SimpleText("Powered by", "BudgetLabel", ScrW() / 2, ScrH() / 2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end, true)


	LK3D.DeclareTextureFromFunc("white", 16, 16, function()
		render.Clear(255, 255, 255, 255)
	end)

	LK3D.DeclareTextureFromFunc("lightmap_neutral2", 16, 16, function()
		render.Clear(128, 128, 128, 255)
	end, false, true)

	LK3D.DeclareTextureFromFunc("wireframe_fake", 16, 16, function()
		render.Clear(255, 255, 255, 0)

		render.DrawLine(Vector(1, 1), Vector(16, 1), Color(255, 255, 255, 255))
		render.DrawLine(Vector(16, 1), Vector(16, 16), Color(255, 255, 255, 255))
		render.DrawLine(Vector(16, 16), Vector(1, 16), Color(255, 255, 255, 255))
		render.DrawLine(Vector(1, 16), Vector(1, 1), Color(255, 255, 255, 255))

		render.DrawLine(Vector(0, 0), Vector(16, 16), Color(255, 255, 255, 255))

	end, true)


	LK3D.DeclareTextureFromFunc("dither_white", 2, 2, function()
		render.Clear(255, 255, 255, 0)

		surface.SetDrawColor(255, 255, 255)
		surface.DrawRect(0, 0, 1, 1)
		surface.DrawRect(1, 1, 1, 1)
	end, true)



	local function reScale(p1, p2, p3, p4)
		local c1 = ((p1 / 256) * ScrW())
		local c2 = ((p2 / 256) * ScrW())
		local c3 = ((p3 / 256) * ScrW())
		local c4 = ((p4 / 256) * ScrW())

		return c1, c2, c3, c4
	end

	--local mat_lokaface = Material("lk3d/loka_face_blur_square.png", "nocull ignorez smooth")
	local mat_spheremap = Material("lk3d/spheremap_bar.png", "nocull ignorez smooth")

	LK3D.DeclareTextureFromFunc("spheremap", 256, 256, function()
		surface.SetDrawColor(255, 255, 255)
		surface.SetMaterial(mat_spheremap)
		surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
	end)



	LK3D.DeclareTextureFromFunc("lokaface2_blur4", 1024, 1024, function()
		surface.SetDrawColor(38, 65, 38)
		surface.DrawRect(0, 0, ScrW(), ScrH())

		surface.SetDrawColor(39, 255, 39)
		surface.DrawRect(reScale(72, 40, 25, 118))

		surface.DrawRect(reScale(158, 40, 25, 118))
		surface.DrawRect(reScale(77, 194, 101, 8))

		render.BlurRenderTarget(render.GetRenderTarget(), 6, 3, 3)
	end, false, true)

	LK3D.DeclareTextureFromFunc("lokaface4_slash_blur", 1024, 1024, function()
		surface.SetDrawColor(38, 65, 38)
		surface.DrawRect(0, 0, ScrW(), ScrH())

		surface.SetDrawColor(39, 255, 39)
		surface.DrawRect(reScale(72, 40, 25, 118))
		surface.DrawRect(reScale(158, 40, 25, 118))


		surface.DrawRect(reScale(72, 185, 18, 10))
		surface.DrawRect(reScale(90, 190, 19, 9))
		surface.DrawRect(reScale(109, 194, 18, 9))
		surface.DrawRect(reScale(127, 199, 19, 9))

		surface.DrawRect(reScale(146, 204, 18, 9))
		surface.DrawRect(reScale(164, 208, 18, 9))


		render.BlurRenderTarget(render.GetRenderTarget(), 6, 3, 3)
	end, false, true)



	LK3D.DeclareTextureFromFunc("lokaface3_sad_blur", 1024, 1024, function()
		surface.SetDrawColor(38, 65, 38)
		surface.DrawRect(0, 0, ScrW(), ScrH())

		surface.SetDrawColor(39, 255, 39)
		surface.DrawRect(reScale(72, 40, 25, 118))

		surface.DrawRect(reScale(158, 40, 25, 118))
		surface.DrawRect(reScale(77, 194, 101, 8))


		surface.DrawRect(reScale(72, 199, 8, 8))
		surface.DrawRect(reScale(68, 203, 8, 8))

		surface.DrawRect(reScale(174, 199, 8, 8))
		surface.DrawRect(reScale(178, 203, 8, 8))


		render.BlurRenderTarget(render.GetRenderTarget(), 6, 3, 3)
	end, false, true)


	LK3D.DeclareTextureFromFunc("lokaface2", 512, 512, function()
		surface.SetDrawColor(38, 65, 38)
		surface.DrawRect(0, 0, ScrW(), ScrH())

		local bl_mat = LK3D.GetTextureByIndex("lokaface2_blur4").mat
		surface.SetDrawColor(255, 255, 255)
		surface.SetMaterial(bl_mat)
		surface.DrawTexturedRect(0, 0, ScrW(), ScrH())


		surface.SetDrawColor(39, 255, 39)
		surface.DrawRect(reScale(72, 40, 25, 118))
		surface.DrawRect(reScale(158, 40, 25, 118))
		surface.DrawRect(reScale(77, 194, 101, 8))

	end)

	LK3D.DeclareTextureFromFunc("lokaface3_sad", 512, 512, function()
		surface.SetDrawColor(38, 65, 38)
		surface.DrawRect(0, 0, ScrW(), ScrH())

		local bl_mat = LK3D.GetTextureByIndex("lokaface3_sad_blur").mat
		surface.SetDrawColor(255, 255, 255)
		surface.SetMaterial(bl_mat)
		surface.DrawTexturedRect(0, 0, ScrW(), ScrH())

		surface.SetDrawColor(39, 255, 39)
		surface.DrawRect(reScale(72, 40, 25, 118))
		surface.DrawRect(reScale(158, 40, 25, 118))
		surface.DrawRect(reScale(77, 194, 101, 8))

		surface.DrawRect(reScale(72, 199, 8, 8))
		surface.DrawRect(reScale(68, 203, 8, 8))

		surface.DrawRect(reScale(174, 199, 8, 8))
		surface.DrawRect(reScale(178, 203, 8, 8))
	end)


	LK3D.DeclareTextureFromFunc("lokaface3_sad_noz", 512, 512, function()
		surface.SetDrawColor(38, 65, 38)
		surface.DrawRect(0, 0, ScrW(), ScrH())

		local bl_mat = LK3D.GetTextureByIndex("lokaface3_sad_blur").mat
		surface.SetDrawColor(255, 255, 255)
		surface.SetMaterial(bl_mat)
		surface.DrawTexturedRect(0, 0, ScrW(), ScrH())

		surface.SetDrawColor(39, 255, 39)
		surface.DrawRect(reScale(72, 40, 25, 118))
		surface.DrawRect(reScale(158, 40, 25, 118))
		surface.DrawRect(reScale(77, 194, 101, 8))

		surface.DrawRect(reScale(72, 199, 8, 8))
		surface.DrawRect(reScale(68, 203, 8, 8))

		surface.DrawRect(reScale(174, 199, 8, 8))
		surface.DrawRect(reScale(178, 203, 8, 8))
	end, false, true)


	LK3D.DeclareTextureFromFunc("lokaface4_slash", 512, 512, function()
		surface.SetDrawColor(38, 65, 38)
		surface.DrawRect(0, 0, ScrW(), ScrH())

		local bl_mat = LK3D.GetTextureByIndex("lokaface4_slash_blur").mat
		surface.SetDrawColor(255, 255, 255)
		surface.SetMaterial(bl_mat)
		surface.DrawTexturedRect(0, 0, ScrW(), ScrH())


		surface.SetDrawColor(39, 255, 39)
		surface.DrawRect(reScale(72, 40, 25, 118))
		surface.DrawRect(reScale(158, 40, 25, 118))


		surface.DrawRect(reScale(72, 185, 18, 10))
		surface.DrawRect(reScale(90, 190, 19, 9))
		surface.DrawRect(reScale(109, 194, 18, 9))
		surface.DrawRect(reScale(127, 199, 19, 9))

		surface.DrawRect(reScale(146, 204, 18, 9))
		surface.DrawRect(reScale(164, 208, 18, 9))
	end)





	LK3D.DeclareTextureFromFunc("process_loka1", 196, 196, function()
		render.Clear(250 * .5, 240 * .5, 174 * .5, 255)
	end)

	--[[
	LK3D.ApplyShaderEffect("lokaface2", function(xc, yc, img_arr)
		local dx = xc / ScrW()
		local dy = yc / ScrH()

		local rdx = (dx - .5) * 2
		local rdy = (dy - .5) * 2

		local dist_from_center = math.Distance(rdx, rdy, 0, 0) + .01 -- avoid div by 0
		if dist_from_center > 1 then -- we dont care dont do the fancy math
			surface.SetDrawColor(0, 0, 0)
			surface.DrawRect(xc, yc, 1, 1)
			return
		end

		local dmd_dx = rdx * math.pow(dist_from_center, 2)
		local dmd_dy = rdy * math.pow(dist_from_center, 2)

		-- convert back to 0-scrw
		dmd_dx = math.floor((dmd_dx + 1) * (ScrW() * .5))
		dmd_dy = math.floor((dmd_dy + 1) * (ScrH() * .5))

		local pixel_contents = img_arr[dmd_dx][dmd_dy]

		surface.SetDrawColor(pixel_contents[1], pixel_contents[2], pixel_contents[3])
		surface.DrawRect(xc, yc, 1, 1)
	end)
	]]--

	LK3D.InitProcessTexture()
end
LK3D.SetupBaseMaterials()







local function lktcomp_d_print(...)
	if not LK3D.Debug then
		return
	end

	MsgC(Color(255, 180, 100), "[LKTCOMP]: ", Color(255, 220, 200), ..., "\n")
end


local LKTCOMP_VER = 1
local LKTCOMP_ENCODERS = {
	[1] = function(name, f_pointer, fname, actual_fname) -- rev1
		f_pointer:Seek(0)

		-- marker
		f_pointer:WriteByte(string.byte("L")) -- L
		f_pointer:WriteByte(string.byte("K")) -- K
		f_pointer:WriteByte(string.byte("T")) -- T
		f_pointer:WriteByte(string.byte("C")) -- C

		f_pointer:WriteByte(1) -- rev1


		local tex_rt = LK3D.Textures[name].rt
		local tw, th = tex_rt:Width(), tex_rt:Height()
		local px_count = tw * th
		f_pointer:WriteUShort(tw)
		f_pointer:WriteUShort(th)


		file.Write("lk3d/lktcomp_aux.txt", "")
		local aux_file = file.Open("lk3d/lktcomp_aux.txt", "wb", "DATA")

		render.PushRenderTarget(tex_rt)
			render.CapturePixels()
			for i = 0, px_count - 1 do
				local xc = i % tw
				local yc = math.floor(i / tw)
				local r, g, b, a = render.ReadPixel(xc, yc)
				aux_file:WriteULong(r + bit.lshift(g, 8) + bit.lshift(b, 16) + bit.lshift(a, 24))

			end
		render.PopRenderTarget()
		aux_file:Close()


		-- do run length encoding
		aux_file = file.Open("lk3d/lktcomp_aux.txt", "rb", "DATA")
		aux_file:Seek(0)
		LK3D.New_D_Print("ByteSize: " .. aux_file:Size(), 1, "LKTComp")
		LK3D.New_D_Print("PxSize: " .. px_count * 4, 1, "LKTComp")

		local con_bytes = 0
		for i = 0, px_count - 1 do
			aux_file:Seek(i * 4)
			local ulong_curr = aux_file:ReadULong()
			local ulong_next = aux_file:ReadULong()
			if ulong_curr ~= ulong_next or (con_bytes >= 255) then
				f_pointer:WriteByte(con_bytes)
				f_pointer:WriteULong(ulong_curr)
				con_bytes = 0
			else
				con_bytes = con_bytes + 1
			end
		end

		-- mark end
		f_pointer:WriteByte(string.byte("E")) -- E
		f_pointer:WriteByte(string.byte("N"))
		f_pointer:WriteByte(string.byte("D"))
		f_pointer:WriteByte(string.byte("E"))
		f_pointer:Close()

		-- do lzma
		if actual_fname then
			file.Write(actual_fname .. ".txt", util.Compress(file.Read(act_name, "DATA"))) -- this is dumb why are you like this loka
		else
			local act_name = fname .. ".txt"
			file.Write(act_name, util.Base64Encode(util.Compress(file.Read(act_name, "DATA")), true))
			file.Write(fname .. "_nob64" .. ".txt", util.Compress(file.Read(act_name, "DATA")))
		end
	end
}


-- compresses texture into base64 string which can be later loaded in
function LK3D.CompressTexture(name, path, actual_fname)
	LK3D.D_Print("Compressing texture \"" .. name .. "\" with LKTCOMP revision " .. LKTCOMP_VER .. "....")
	if not LK3D.Textures[name] then
		LK3D.D_Print("Texture \"" .. name .. "\" doesnt exist!")
		return
	end

	file.CreateDir("lk3d/lktcomp_textures")

	local fnm = "lk3d/lktcomp_textures/" .. name
	if path then
		fnm = path .. name
	end
	file.Write(fnm, "")

	local f_pointer = file.Open(fnm .. ".txt", "wb", "DATA")
	if LKTCOMP_ENCODERS[LKTCOMP_VER] then
		local fine, err = pcall(LKTCOMP_ENCODERS[LKTCOMP_VER], name, f_pointer, fnm, actual_fname)
		if not fine then
			LK3D.D_Print("Error compressing texture \"" .. name .. "\" with LKTCOMP revision " .. LKTCOMP_VER .. ": \"" .. err .. "\"")
		end
	end
end


local LKTCOMP_DECODERS = {
	[1] = function(name, f_pointer, trasp, ignorez)
		local tw, th = f_pointer:ReadUShort(), f_pointer:ReadUShort()
		LK3D.New_D_Print(name .. " is " .. tw .. "x" .. th .. "...", 1, "LKTComp")


		LK3D.DeclareTextureFromFunc(name, tw, th, function()
			render.Clear(255, 0, 255, 255, true, true)
		end, trasp, ignorez)


		local rt = LK3D.Textures[name].rt

		local ow, oh = ScrW(), ScrH()
		render.SetViewPort(0, 0, tw, th)
		cam.Start2D()
		render.PushRenderTarget(rt)
			render.SetColorMaterialIgnoreZ()
			draw.NoTexture()
			local px_count = tw * th
			local read_pixels = 0
			for _ = 0, px_count do
				if read_pixels >= px_count then
					break
				end

				local r_continuity_rle = f_pointer:ReadByte()
				local r_rgba = f_pointer:ReadULong()

				local r_a = math.floor(bit.rshift(r_rgba, 24) % 256)
				local r_b = math.floor(bit.rshift(r_rgba, 16) % 256)
				local r_g = math.floor(bit.rshift(r_rgba, 8) % 256)
				local r_r = math.floor(r_rgba % 256)
				for j = 0, r_continuity_rle do
					local currx = (read_pixels + j) % tw
					local curry = math.floor((read_pixels + j) / tw)

					render.SetViewPort(currx, curry, 1, 1)
					render.Clear(r_r, r_g, r_b, r_a)
					render.SetViewPort(0, 0, tw, th)
				end

				read_pixels = read_pixels + (1 + r_continuity_rle)
			end
		render.PopRenderTarget()
		cam.End2D()
		render.SetViewPort(0, 0, ow, oh)

		if f_pointer:ReadULong() == 1162104389 then
			LK3D.New_D_Print("Decompressed successfully!", 1, "LKTComp")
		end
	end
}


function LK3D.DecompressTexture(name, trasp, ignorez, data)
	LK3D.New_D_Print("Decompressing LKTCOMP \"" .. name .. "\"...", 2, "LKTComp")
	if not data then
		return
	end

	local data_nocomp = util.Decompress(util.Base64Decode(data) or "")

	if not data_nocomp then
		return
	end

	file.Write("lk3d/lkt_decomp_temp.txt", data_nocomp)
	local f_pointer = file.Open("lk3d/lkt_decomp_temp.txt", "rb", "DATA")


	-- read header
	local head = f_pointer:ReadULong()
	if head ~= 1129597772 then
		LK3D.New_D_Print("Header LKTC no match!", 1, "LKTComp")
		LK3D.New_D_Print(": " .. head, 1, "LKTComp")
		f_pointer:Close()
		return
	end

	local rev = f_pointer:ReadByte()
	LK3D.New_D_Print(name .. " is rev" .. rev .. "...", 1, "LKTComp")



	if LKTCOMP_DECODERS[rev] then
		local fine, err = pcall(LKTCOMP_DECODERS[rev], name, f_pointer, trasp, ignorez)
		if not fine then
			LK3D.New_D_Print("Error decompressing \"" .. name .. "\" with LKTC revision " .. rev .. ": \"" .. err .. "\"", 5, "LKTComp")
		end
	else
		LK3D.New_D_Print("No decoder for rev " .. rev .. ", try updating LK3D otherwise texture might be corrupted!", 5, "LKTComp")
	end

	f_pointer:Close()
end
LK3D.New_D_Print("LK3D textures fully loaded!", 2, "Base")