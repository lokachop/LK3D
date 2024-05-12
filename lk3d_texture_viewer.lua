LK3D = LK3D or {}

LK3D.TexViewer = LK3D.TexViewer or {}
LK3D.TexViewer.TargetTex = LK3D.TexViewer.TargetTex or "car_hull_sheet"
LK3D.TexViewer.CamPos = Vector(0, 0, 2)

LK3D.TexViewer.BasePanel = LK3D.TexViewer.BasePanel



local univRenderTexView = nil
local function initUniverse()
	univRenderTexView = LK3D.NewUniverse("lk3d_texture_viewer")

	LK3D.PushUniverse(univRenderTexView)
		LK3D.AddObjectToUniverse("the_plane", "plane")
		LK3D.SetObjectPos("the_plane", Vector(0, 0, 0))
		LK3D.SetObjectAng("the_plane", Angle(0, 0, 90))

		LK3D.SetObjectMat("the_plane", LK3D.TexViewer.TargetTex)
		LK3D.SetObjectFlag("the_plane", "NO_SHADING", true)
		LK3D.SetObjectFlag("the_plane", "NO_LIGHTING", true)
		LK3D.SetObjectFlag("the_plane", "CONSTANT", true)
	LK3D.PopUniverse()
end
initUniverse()


local renderRT = GetRenderTarget("lk3d_texviewer_render_rt_2", 800, 800)

local function openTexViewer()
	if IsValid(LK3D.TexViewer.BasePanel) then
		LK3D.TexViewer.BasePanel:Close()
	end


	LK3D.TexViewer.BasePanel = vgui.Create("DFrame")
	LK3D.TexViewer.BasePanel:SetSize(800, 600)
	LK3D.TexViewer.BasePanel:Center()

	LK3D.TexViewer.BasePanel:SetTitle("LK3D Texture Viewer")
	LK3D.TexViewer.BasePanel:SetIcon("icon16/film.png")

	LK3D.TexViewer.BasePanel:MakePopup()


	local basePanel = vgui.Create("DPanel", LK3D.TexViewer.BasePanel)
	basePanel:Dock(FILL)

	local bottomPanel = vgui.Create("DPanel", basePanel)
	bottomPanel:SetSize(800, 64)
	bottomPanel:Dock(BOTTOM)
	function bottomPanel:Paint(w, h)
		surface.SetDrawColor(255, 0, 0)
		surface.DrawRect(0, 0, w, h)
	end

	local renderPanel = vgui.Create("DPanel", basePanel)
	renderPanel:SetSize(800, 600 - 96)
	renderPanel:Dock(BOTTOM)

	function renderPanel:OnMousePressed()
		renderPanel:MouseCapture(true)
		renderPanel:SetCursor("blank")
		self.dragging = true
	end

	function renderPanel:OnMouseReleased()
		renderPanel:MouseCapture(false)
		renderPanel:SetCursor("none")
		self.dragging = false
		self.teleback = false
	end

	-- https://github.com/Facepunch/garrysmod/blob/4cccb02fe953bd9a72606aa829f61b90fb85c148/garrysmod/lua/vgui/dadjustablemodelpanel.lua
	renderPanel.l_x = 0
	renderPanel.l_y = 0
	function renderPanel:GetDelta()

		local x, y = input.GetCursorPos()

		local dx = x - self.l_x
		local dy = y - self.l_y

		local center_x, center_y = self:LocalToScreen(self:GetWide() * 0.5, self:GetTall() * 0.5)
		input.SetCursorPos(center_x, center_y)

		self.l_x = center_x
		self.l_y = center_y

		if not self.teleback then
			self.teleback = true
			return 0, 0
		end

		return dx, dy
	end

	function renderPanel:OnMouseWheeled(delta)
		if delta < 0 then
			LK3D.TexViewer.CamPos[3] = LK3D.TexViewer.CamPos[3] * 1.1
		else
			LK3D.TexViewer.CamPos[3] = LK3D.TexViewer.CamPos[3] / 1.1
		end

		LK3D.TexViewer.CamPos[3] = math.min(math.max(LK3D.TexViewer.CamPos[3], 0.01), 32)

		--LK3D.TexViewer.CamPos[3] = math.min(math.max(LK3D.TexViewer.CamPos[3] - (delta / 4), 0.1), 128)
	end


	function renderPanel:Think()
		if self.dragging then
			local dx, dy = self:GetDelta()

			local zoomMul = LK3D.TexViewer.CamPos[3]
			--oomMul = math.min(zoomMul, 1)
			local dragMul = .25

			LK3D.TexViewer.CamPos[1] = LK3D.TexViewer.CamPos[1] + (dy * FrameTime() * zoomMul * dragMul)
			LK3D.TexViewer.CamPos[2] = LK3D.TexViewer.CamPos[2] + (dx * FrameTime() * zoomMul * dragMul)

		end

	end


	function renderPanel:Paint(w, h)
		LK3D.PushRenderTarget(renderRT)
			LK3D.RenderClear(8, 96, 48)

			local prevPos = LK3D.CamPos
			local prevAng = LK3D.CamAng

			local cPos = LK3D.TexViewer.CamPos

			local siz = cPos[3]
			LK3D.SetCamOrthoParams({
				left   = -siz,
				right  =  siz,
				top    = -siz,
				bottom =  siz,
			})

			LK3D.SetCamOrtho(true)
				LK3D.SetCamPos(Vector(cPos[1], cPos[2], 2))
				LK3D.SetCamAng(Angle(90, 0, 0))

				LK3D.PushUniverse(univRenderTexView)
					LK3D.RenderActiveUniverse()
				LK3D.PopUniverse()

			LK3D.SetCamOrtho(false)
			LK3D.SetCamPos(prevPos)
			LK3D.SetCamAng(prevAng)

		LK3D.PopRenderTarget()


		render.PushFilterMag(TEXFILTER.POINT)
		render.PushFilterMin(TEXFILTER.POINT)
			surface.SetDrawColor(255, 255, 255)
			local rtMat = LK3D.RTToMaterialNoZ(renderRT)
			surface.SetMaterial(rtMat)


			local rSizeX, rSizeY = 800, 800

			local endU = w / rSizeX
			local endV = h / rSizeY

			surface.DrawTexturedRectUV(0, 0, w, h, 0, 0, endU, endV)
		render.PopFilterMin()
		render.PopFilterMag()

		-- draw the div lines
		local zoomVal = LK3D.TexViewer.CamPos[3]
		local pixelGridDist = 0.05

		local zoomIn = 0.01 / zoomVal
		local zoomAlpha = math.max(math.min(zoomIn - pixelGridDist, 1), 0)
		if zoomAlpha <= 0 then
			return
		end

		surface.SetDrawColor(32, 96, 48, zoomAlpha * 255)


		local texCurrent = LK3D.GetTextureByIndex(LK3D.TexViewer.TargetTex).rt
		local tW, tH = texCurrent:Width(), texCurrent:Height()

		-- SCRAPPED BECAUSE OF THIS SHIT
		local subXCenter = (1 / zoomVal)
		local subYCenter = (1 / zoomVal)

		local offsetX = (-LK3D.TexViewer.CamPos[2] * (400 / zoomVal)) + subXCenter
		local offsetY = (-LK3D.TexViewer.CamPos[1] * (400 / zoomVal)) + subYCenter




		local stepsSzW = 800 / (tW * zoomVal)
		local stepsSzH = 800 / (tH * zoomVal)

		local stepsW = w / stepsSzW
		for i = 0, stepsW do
			local stepVar = i * stepsSzW

			surface.DrawRect(stepVar + (-offsetX % stepsSzW), 0, 2, h)
		end

		local stepsH = h / stepsSzH
		for i = 0, stepsH do
			local stepVar = i * stepsSzH

			surface.DrawRect(0, stepVar + (-offsetY % stepsSzH), w, 2)
		end

		--surface.SetDrawColor(255, 255, 0)
		--surface.DrawRect(0, 0, w, h)
	end

end




concommand.Add("lk3d_texture_viewer", function()
	openTexViewer()

end)