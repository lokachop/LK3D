LK3D = LK3D or {}

LK3D.UE = LK3D.UE or {}
LK3D.UE.CamAng = Angle(0, 0, 0)
LK3D.UE.CamPos = Vector(0, 0, 0)
LK3D.UE.FlSpdMul = 1
LK3D.UE.ZFar = LK3D.FAR_Z
LK3D.UE.ZNear = LK3D.NEAR_Z


local concat_friendly = {}
local head_str = "v("
local comma_str = ", "
local end_str = ")"
local patt_form = "%4.2f"
local function friendly_vstr(vec)
	concat_friendly[1] = head_str
	concat_friendly[2] = string.format(patt_form, vec[1])
	concat_friendly[3] = comma_str
	concat_friendly[4] = string.format(patt_form, vec[2])
	concat_friendly[5] = comma_str
	concat_friendly[6] = string.format(patt_form, vec[3])
	concat_friendly[7] = end_str

	return table.concat(concat_friendly, "")
end
local head_str_a = "a("
local patt_form_a = "%4.1f"
local function friendly_astr(ang)
	concat_friendly[1] = head_str_a
	concat_friendly[2] = string.format(patt_form_a, ang[1])
	concat_friendly[3] = comma_str
	concat_friendly[4] = string.format(patt_form_a, ang[2])
	concat_friendly[5] = comma_str
	concat_friendly[6] = string.format(patt_form_a, ang[3])
	concat_friendly[7] = end_str

	return table.concat(concat_friendly, "")
end

local function friendly_num(num)
	return string.format("%4.3f", num)
end


local function addParams(parent, text, key, default)
	local frame_params = vgui.Create("DPanel", parent)
	frame_params:SetTall(16)
	frame_params:SetWide(parent:GetWide())
	frame_params:Dock(TOP)

	local label_params = vgui.Create("DLabel", frame_params)
	label_params:SetText(text)
	label_params:SizeToContents()
	label_params:SetColor(Color(0, 0, 0))
	label_params:Dock(LEFT)


	local check_params = vgui.Create("DNumberWang", frame_params)
	check_params:SetSize(96, 16)
	check_params:SetPos(parent:GetWide() - 96 - 16)
	check_params:SetMin(-math.huge)
	check_params:SetMax(math.huge)
	check_params:SetValue(default or 0)

	function check_params:OnValueChanged(val)
		LK3D.UE[key] = val
	end
end



local rt_renderCanvas = GetRenderTarget("lk3d_ue_2", 608, 536)
local function openUE()
	if IsValid(LK3D.UEFrame) then
		LK3D.UEFrame:Close()
	end

	LK3D.UEFrame = vgui.Create("DFrame")
	LK3D.UEFrame:SetSize(800, 600)
	LK3D.UEFrame:SetSizable(false)
	LK3D.UEFrame:Center()
	LK3D.UEFrame:MakePopup()

	LK3D.UEFrame:SetTitle("LK3D - UniverseExplorer")
	LK3D.UEFrame:SetIcon("icon16/application_xp_terminal.png")


	local pnl_top_split =  vgui.Create("DPanel", LK3D.UEFrame)
	pnl_top_split:SetTall(600 - 64)
	pnl_top_split:Dock(TOP)

	local pnl_sidebar = vgui.Create("DPanel", pnl_top_split)
	pnl_sidebar:SetWide(128 + 64)
	pnl_sidebar:Dock(LEFT)


	local combo_universe = vgui.Create("DComboBox", pnl_sidebar)
	combo_universe:SetTall(16)
	combo_universe:SetWide(pnl_sidebar:GetWide())
	combo_universe:Dock(TOP)

	for k, v in pairs(LK3D.UniverseRegistry) do
		combo_universe:AddChoice(k)
	end
	combo_universe:AddChoice("none")
	combo_universe:SetValue("none")

	function combo_universe:OnSelect(choice, val)
		LK3D.UE.Univ = val
	end


	addParams(pnl_sidebar, "ZFar", "ZFar", LK3D.FAR_Z)
	addParams(pnl_sidebar, "ZNear", "ZNear", LK3D.NEAR_Z)
	addParams(pnl_sidebar, "CamSpeed", "FlSpdMul", LK3D.UE.FlSpdMul)


	-- actual render panel
	local pnl_render = vgui.Create("DPanel", pnl_top_split)
	pnl_render:Dock(RIGHT)
	pnl_render:SetWide(800 - (128 + 64))
	pnl_render:SetMouseInputEnabled(true)

	function pnl_render:OnMousePressed()
		pnl_render:MouseCapture(true)
		pnl_render:SetCursor("blank")
		self.dragging = true
	end

	function pnl_render:OnMouseReleased()
		pnl_render:MouseCapture(false)
		pnl_render:SetCursor("none")
		self.dragging = false
		self.teleback = false
	end

	-- https://github.com/Facepunch/garrysmod/blob/4cccb02fe953bd9a72606aa829f61b90fb85c148/garrysmod/lua/vgui/dadjustablemodelpanel.lua
	pnl_render.l_x = 0
	pnl_render.l_y = 0
	function pnl_render:GetDelta()
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

	function pnl_render:OnMouseWheeled(delta)
		LK3D.UE.FlSpdMul  = math.max(LK3D.UE.FlSpdMul + (delta / 2), .1)
	end

	function pnl_render:Paint(w, h)
		if self.dragging then
			local dx, dy = self:GetDelta()
			LK3D.UE.CamAng.p = (LK3D.UE.CamAng.p + (dy / 4)) % 360
			LK3D.UE.CamAng.y = (LK3D.UE.CamAng.y - (dx / 4)) % 360

			local dir = LK3D.UE.CamAng:Forward()
			local dir_r = LK3D.UE.CamAng:Right()
			if input.IsButtonDown(KEY_W) then
				LK3D.UE.CamPos = LK3D.UE.CamPos + (dir * (FrameTime() * LK3D.UE.FlSpdMul))
			end
			if input.IsButtonDown(KEY_S) then
				LK3D.UE.CamPos = LK3D.UE.CamPos - (dir * (FrameTime() * LK3D.UE.FlSpdMul))
			end
			if input.IsButtonDown(KEY_D) then
				LK3D.UE.CamPos = LK3D.UE.CamPos + (dir_r * (FrameTime() * LK3D.UE.FlSpdMul))
			end
			if input.IsButtonDown(KEY_A) then
				LK3D.UE.CamPos = LK3D.UE.CamPos - (dir_r * (FrameTime() * LK3D.UE.FlSpdMul))
			end
		end

		LK3D.SetCamPos(LK3D.UE.CamPos)
		LK3D.SetCamAng(LK3D.UE.CamAng)

		if (not LK3D.UE.Univ) or (LK3D.UE.Univ == "none") then
			surface.SetDrawColor(64, 16, 16)
			surface.DrawRect(0, 0, w, h)
			return
		end


		local o_fz, o_nz = LK3D.FAR_Z, LK3D.NEAR_Z
		LK3D.FAR_Z = LK3D.UE.ZFar
		LK3D.NEAR_Z = LK3D.UE.ZNear

		LK3D.SetRenderer(LK3D_RENDER_HARD)
		LK3D.SetFOV(90)
		LK3D.PushRenderTarget(rt_renderCanvas)
			LK3D.PushUniverse(LK3D.UniverseRegistry[LK3D.UE.Univ])
				LK3D.RenderClear(32, 48, 64)

				LK3D.RenderActiveUniverse()

				--for k, v in pairs(LK3D.CurrUniv["objects"]) do
				--	if (v["RENDER_NOGLOBAL"] == true) then
				--		LK3D.RenderObject(k)
				--	end
				--end
				LK3D.UpdateParticles()
			LK3D.PopUniverse()

			LK3D.RenderQuick(function()
				draw.SimpleText("CamPos    : " .. friendly_vstr(LK3D.UE.CamPos) , "BudgetLabel", ScrW() * .5, 0 , Color(255, 196, 196), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
				draw.SimpleText("CamAng    : " .. friendly_astr(LK3D.UE.CamAng) , "BudgetLabel", ScrW() * .5, 12, Color(196, 255, 196), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
				draw.SimpleText("FlSpeedMul: " .. friendly_num(LK3D.UE.FlSpdMul), "BudgetLabel", ScrW() * .5, 24, Color(196, 196, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			end)
		LK3D.PopRenderTarget()


		LK3D.FAR_Z = o_fz
		LK3D.NEAR_Z = o_nz

		--surface.SetDrawColor(64, 48, 32)
		--surface.DrawRect(0, 0, w, h)


		render.PushFilterMag(TEXFILTER.POINT)
		render.PushFilterMin(TEXFILTER.POINT)
			surface.SetDrawColor(255, 255, 255)
			local rt_mat = LK3D.RTToMaterialNoZ(rt_renderCanvas)
			surface.SetMaterial(rt_mat)
			surface.DrawTexturedRect(0, 0, w, h)
		render.PopFilterMin()
		render.PopFilterMag()
	end

	-- selector panel
	local pnl_control = vgui.Create("DPanel", LK3D.UEFrame)
	pnl_control:SetTall(64)
	pnl_control:Dock(BOTTOM)
end


concommand.Add("lk3d_openuniverseexplorer", function()
	openUE()
end)