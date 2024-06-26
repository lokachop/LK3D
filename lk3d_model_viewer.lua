LK3D = LK3D or {}

LK3D.MV = LK3D.MV or {}

-- orbit cam
-- https://www.mbsoftworks.sk/tutorials/opengl4/026-camera-pt3-orbit-camera/
-- ☻ ☻ ☻ ☻ ☻ ☻ ☻ ☻ ☻ ☻ ☻ ☻ ☻ ☻ ☻ ☻ ☻ ☻ ☻ ☻ ☻ ☻ ☻ ☻ ☻ ☻ ☻ ☻ ☻ ☻ ☻ ☻ ☻ ☻ ☻ ☻ ☻
LK3D.MV_OCam = LK3D.MV_OCam or {}
LK3D.MV_OCam.Origin = LK3D.MV_OCam.Origin or Vector(0, 0, 0)
LK3D.MV_OCam.Azimuth = LK3D.MV_OCam.Azimuth or 0
LK3D.MV_OCam.Polar = LK3D.MV_OCam.Polar or 0
LK3D.MV_OCam.Dist = LK3D.MV_OCam.Dist or 1


LK3D.MV.Model = LK3D.MV.Model or "cube_nuv"
LK3D.MV.Texture = LK3D.MV.Texture or "checker"
LK3D.MV.BaseShader = LK3D.MV.BaseShader or "none"
LK3D.MV.Animation = LK3D.MV.Animation or "none"

LK3D.DeclareProcPlane("plane_editor", 32, 32, 16, 16)


local rt_renderCanvas = GetRenderTarget("lk3d_mv_rt2", 608, 536)
local univ_lk3dmv = LK3D.NewUniverse("lk3d_uni_mv")

local function initUniv()
	LK3D.PushUniverse(univ_lk3dmv)
		LK3D.AddObjectToUniverse("floor_plane", "plane_editor")
		local aabb_mdl = LK3D.TraceTriangleAABBs[LK3D.MV.Model]

		LK3D.SetObjectPosAng("floor_plane", Vector(0, 0, aabb_mdl[1].z), Angle(0, 0, 90))
		LK3D.SetObjectFlag("floor_plane", "NO_SHADING", false)
		LK3D.SetObjectFlag("floor_plane", "NO_LIGHTING", true)
		LK3D.SetObjectFlag("floor_plane", "CONSTANT", true)
		LK3D.SetObjectFlag("floor_plane", "SHADING_SMOOTH", false)
		LK3D.SetObjectScale("floor_plane", Vector(1, 1, 1))
		LK3D.SetObjectMat("floor_plane", "checker")


		LK3D.SetObjectFlag("floor_plane", "VERT_SH_PARAMS", {
			[1] = false, -- vpos
			[2] = true, -- vuv
			[3] = false, -- vrgb
			[4] = false, -- shader obj ref
		})
		LK3D.SetObjectFlag("floor_plane", "VERT_SHADER", function(vpos, vuv, vrgb)
			vuv[1] = vuv[1] * 16
			vuv[2] = vuv[2] * 16
		end)


		LK3D.AddLight("light1_test", Vector(0, 1.225, 0), 2.6, Color(255, 255, 255), true)

		LK3D.AddObjectToUniverse("the_model", "cube_nuv")
		LK3D.SetObjectPosAng("the_model", Vector(0, 0, 0), Angle(0, 0, 90))
		LK3D.SetObjectFlag("the_model", "NO_SHADING", true)
		LK3D.SetObjectFlag("the_model", "NO_LIGHTING", true)
		LK3D.SetObjectFlag("the_model", "CONSTANT", true)
		LK3D.SetObjectFlag("the_model", "SHADING_SMOOTH", false)
		LK3D.SetObjectScale("the_model", Vector(1, 1, 1))
		LK3D.SetObjectMat("the_model", "checker")
	LK3D.PopUniverse()
	end


local function addParam(parent, text, key)
	local frame_params = vgui.Create("DPanel", parent)
	frame_params:SetTall(16)
	frame_params:SetWide(parent:GetWide())
	frame_params:Dock(TOP)

	local label_params = vgui.Create("DLabel", frame_params)
	label_params:SetText(text)
	label_params:SizeToContents()
	label_params:SetColor(Color(0, 0, 0))
	label_params:Dock(LEFT)


	local check_params = vgui.Create("DCheckBox", frame_params)
	check_params:SetSize(16, 16)
	check_params:SetPos(parent:GetWide() - 32)


	if type(key) == "string" then
		function check_params:OnChange(val)
			LK3D.MV[key] = val
		end
	elseif type(key) == "function" then
		check_params.OnChange = key
	end
end

local function openMV()
	if IsValid(LK3D.MVFrame) then
		LK3D.MVFrame:Close()
	end
	initUniv()

	LK3D.MVFrame = vgui.Create("DFrame")
	LK3D.MVFrame:SetSize(800, 600)
	LK3D.MVFrame:SetSizable(false)
	LK3D.MVFrame:Center()
	LK3D.MVFrame:MakePopup()

	LK3D.MVFrame:SetTitle("LK3D - MdlView")
	LK3D.MVFrame:SetIcon("icon16/photo.png")


	local pnl_top_split =  vgui.Create("DPanel", LK3D.MVFrame)
	pnl_top_split:SetTall(600 - 64)
	pnl_top_split:Dock(TOP)

	-- sidebar for checkbox options
	local pnl_sidebar = vgui.Create("DPanel", pnl_top_split)
	pnl_sidebar:SetWide(128 + 64)
	pnl_sidebar:Dock(LEFT)

	addParam(pnl_sidebar, "Wireframe", "Wireframe")
	addParam(pnl_sidebar, "Draw AABB (Needs Debug)", "DrawAABB")

	addParam(pnl_sidebar, "Hide Floor", function(self, state)
		LK3D.PushUniverse(univ_lk3dmv)
			LK3D.SetObjectHide("floor_plane", state)
		LK3D.PopUniverse()
	end)

	addParam(pnl_sidebar, "Shading", function(self, state)
		LK3D.PushUniverse(univ_lk3dmv)
			LK3D.SetObjectFlag("the_model", "NO_SHADING", not state)
			LK3D.SetObjectFlag("floor_plane", "NO_SHADING", not state)

			LK3D.SetObjectFlag("floor_plane", "NEEDS_CACHE_UPDATE", true)
			LK3D.SetObjectFlag("the_model", "NEEDS_CACHE_UPDATE", true)
		LK3D.PopUniverse()
	end)

	addParam(pnl_sidebar, "Gouraud", function(self, state)
		LK3D.PushUniverse(univ_lk3dmv)
			LK3D.SetObjectFlag("the_model", "SHADING_SMOOTH", state)
			LK3D.SetObjectFlag("floor_plane", "SHADING_SMOOTH", state)

			LK3D.SetObjectFlag("floor_plane", "NEEDS_CACHE_UPDATE", true)
			LK3D.SetObjectFlag("the_model", "NEEDS_CACHE_UPDATE", true)
		LK3D.PopUniverse()
	end)

	addParam(pnl_sidebar, "Lighting", function(self, state)
		LK3D.PushUniverse(univ_lk3dmv)
			LK3D.SetObjectFlag("the_model", "NO_LIGHTING", not state)
			LK3D.SetObjectFlag("floor_plane", "NO_LIGHTING", not state)

			LK3D.SetObjectFlag("floor_plane", "NEEDS_CACHE_UPDATE", true)
			LK3D.SetObjectFlag("the_model", "NEEDS_CACHE_UPDATE", true)
		LK3D.PopUniverse()
	end)

	addParam(pnl_sidebar, "Lighting Normal Affect", function(self, state)
		LK3D.PushUniverse(univ_lk3dmv)
			LK3D.SetObjectFlag("the_model", "NORM_LIGHT_AFFECT", state)
			LK3D.SetObjectFlag("floor_plane", "NORM_LIGHT_AFFECT", state)

			LK3D.SetObjectFlag("floor_plane", "NEEDS_CACHE_UPDATE", true)
			LK3D.SetObjectFlag("the_model", "NEEDS_CACHE_UPDATE", true)
		LK3D.PopUniverse()
	end)

	addParam(pnl_sidebar, "Normal Invert", function(self, state)
		LK3D.PushUniverse(univ_lk3dmv)
			LK3D.SetObjectFlag("the_model", "NORM_INVERT", state)
			LK3D.SetObjectFlag("floor_plane", "NORM_INVERT", state)

			LK3D.SetObjectFlag("floor_plane", "NEEDS_CACHE_UPDATE", true)
			LK3D.SetObjectFlag("the_model", "NEEDS_CACHE_UPDATE", true)
		LK3D.PopUniverse()
	end)

	addParam(pnl_sidebar, "ShadowVolume", function(self, state)
		LK3D.PushUniverse(univ_lk3dmv)
			LK3D.SetObjectFlag("the_model", "SHADOW_VOLUME", state)

			LK3D.SetObjectFlag("the_model", "NEEDS_CACHE_UPDATE", true)
		LK3D.PopUniverse()
	end)

	addParam(pnl_sidebar, "Shadow ZPass", function(self, state)
		LK3D.PushUniverse(univ_lk3dmv)
			LK3D.SetObjectFlag("the_model", "SHADOW_ZPASS", state)

			LK3D.SetObjectFlag("the_model", "NEEDS_CACHE_UPDATE", true)
		LK3D.PopUniverse()
	end)

	addParam(pnl_sidebar, "Shadow Sun", function(self, state)
		LK3D.PushUniverse(univ_lk3dmv)
			LK3D.SetObjectFlag("the_model", "SHADOW_DOSUN", state)

			LK3D.SetObjectFlag("the_model", "NEEDS_CACHE_UPDATE", true)
		LK3D.PopUniverse()
	end)

	addParam(pnl_sidebar, "Shadow Constant", function(self, state)
		LK3D.PushUniverse(univ_lk3dmv)
			LK3D.SetObjectFlag("the_model", "SHADOW_VOLUME_BAKE", state)

			LK3D.SetObjectFlag("the_model", "NEEDS_CACHE_UPDATE", true)
			LK3D.SetObjectFlag("the_model", "SHADOW_VOLUME_BAKE_CLEAR", true)
		LK3D.PopUniverse()
	end)


	addParam(pnl_sidebar, "No Constant", function(self, state)
		LK3D.PushUniverse(univ_lk3dmv)
			LK3D.SetObjectFlag("the_model", "CONSTANT", not state)
			LK3D.SetObjectFlag("floor_plane", "CONSTANT", not state)

			LK3D.SetObjectFlag("floor_plane", "NEEDS_CACHE_UPDATE", true)
			LK3D.SetObjectFlag("the_model", "NEEDS_CACHE_UPDATE", true)
		LK3D.PopUniverse()
	end)

	addParam(pnl_sidebar, "Shader No SmoothNormal", function(self, state)
		LK3D.PushUniverse(univ_lk3dmv)
			LK3D.SetObjectFlag("the_model", "SHADER_NO_SMOOTHNORM", state)
			LK3D.SetObjectFlag("floor_plane", "SHADER_NO_SMOOTHNORM", state)

			LK3D.SetObjectFlag("floor_plane", "NEEDS_CACHE_UPDATE", true)
			LK3D.SetObjectFlag("the_model", "NEEDS_CACHE_UPDATE", true)
		LK3D.PopUniverse()
	end)


	local combo_animation = nil

	local combo_model = vgui.Create("DComboBox", pnl_sidebar)
	combo_model:SetTall(16)
	combo_model:SetWide(pnl_sidebar:GetWide())
	combo_model:Dock(TOP)

	for k, v in pairs(LK3D.Models) do
		combo_model:SetValue(LK3D.MV.Model)
		combo_model:AddChoice(k)
	end

	function combo_model:OnSelect(choice, val)
		LK3D.MV.Model = val


		LK3D.PushUniverse(univ_lk3dmv)
			LK3D.SetObjectAnim("the_model", "none")
			LK3D.SetObjectModel("the_model", LK3D.MV.Model)
			LK3D.SetObjectFlag("the_model", "NEEDS_CACHE_UPDATE", true)
			LK3D.SetObjectFlag("the_model", "SHADOW_VOLUME_BAKE_CLEAR", true)

			local n_aabb = LK3D.GetRecalcAABB(LK3D.CurrUniv["objects"]["the_model"])
			LK3D.SetObjectPosAng("floor_plane", Vector(0, 0, n_aabb[1].z), Angle(0, 0, 90))
		LK3D.PopUniverse()


		combo_animation:Clear()

		combo_animation:SetValue("none")
		combo_animation:AddChoice("none")

		if not LK3D.GetModelAnimated(val) then
			return
		end

		LK3D.PushUniverse(univ_lk3dmv)
			LK3D.PushObjectAnims("the_model", val)
			local animList = LK3D.GetModelAnimations(val)
			for k, v in ipairs(animList) do
				combo_animation:AddChoice(v)
			end


		LK3D.PopUniverse()
	end

	local combo_texture = vgui.Create("DComboBox", pnl_sidebar)
	combo_texture:SetTall(16)
	combo_texture:SetWide(pnl_sidebar:GetWide())
	combo_texture:Dock(TOP)

	for k, v in pairs(LK3D.Textures) do
		combo_texture:SetValue(LK3D.MV.Texture)
		combo_texture:AddChoice(k)
	end

	function combo_texture:OnSelect(choice, val)
		LK3D.MV.Texture = val


		LK3D.PushUniverse(univ_lk3dmv)
			LK3D.SetObjectMat("the_model", LK3D.MV.Texture)
			LK3D.SetObjectFlag("the_model", "NEEDS_CACHE_UPDATE", true)
			LK3D.SetObjectFlag("the_model", "SHADOW_VOLUME_BAKE_CLEAR", true)
		LK3D.PopUniverse()
	end


	local combo_baseshader = vgui.Create("DComboBox", pnl_sidebar)
	combo_baseshader:SetTall(16)
	combo_baseshader:SetWide(pnl_sidebar:GetWide())
	combo_baseshader:Dock(TOP)

	for k, v in pairs(LK3D.Shaders) do
		combo_baseshader:SetValue(LK3D.MV.BaseShader)
		combo_baseshader:AddChoice(k)
	end
	combo_baseshader:AddChoice("none")

	function combo_baseshader:OnSelect(choice, val)
		LK3D.MV.BaseShader = val


		LK3D.PushUniverse(univ_lk3dmv)
			LK3D.SetObjectPrefabShader("the_model", LK3D.MV.BaseShader)
			LK3D.SetObjectFlag("the_model", "NEEDS_CACHE_UPDATE", true)
			LK3D.SetObjectFlag("the_model", "SHADOW_VOLUME_BAKE_CLEAR", true)
		LK3D.PopUniverse()
	end


	combo_animation = vgui.Create("DComboBox", pnl_sidebar)
	combo_animation:SetTall(16)
	combo_animation:SetWide(pnl_sidebar:GetWide())
	combo_animation:Dock(TOP)

	combo_animation:SetValue("none")
	combo_animation:AddChoice("none")

	function combo_animation:OnSelect(choice, val)
		LK3D.MV.Animation = val


		LK3D.PushUniverse(univ_lk3dmv)
			--LK3D.SetObjectPrefabShader("the_model", LK3D.MV.Animation)
			LK3D.PushObjectAnims("the_model", LK3D.MV.Model)

			LK3D.SetObjectAnim("the_model", val)

			if LK3D.AnimFrameDiv then -- HACK: not everyone animates at 24fps,  this is hardcoded because of PONR!
				LK3D.SetObjectAnimRate("the_model", 24)
			else
				LK3D.SetObjectAnimRate("the_model", 1)
			end


			LK3D.SetObjectFlag("the_model", "NEEDS_CACHE_UPDATE", true)
			LK3D.SetObjectFlag("the_model", "SHADOW_VOLUME_BAKE_CLEAR", true)
		LK3D.PopUniverse()
	end


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
		LK3D.MV_OCam.Dist = math.min(math.max(LK3D.MV_OCam.Dist - (delta / 16), 1), 8)
	end

	local colOriginHighlight = Color(96, 255, 96)
	local pihalf = math.pi / 2
	function pnl_render:Paint(w, h)
		-- translate camera
		local od = LK3D.MV_OCam.Dist ^ 2
		local az = LK3D.MV_OCam.Azimuth
		local pl = LK3D.MV_OCam.Polar
		local org = LK3D.MV_OCam.Origin

		if self.dragging then
			local dx, dy = self:GetDelta()

			LK3D.MV_OCam.Azimuth = (az + (-dx / 256)) % (math.pi * 2)
			LK3D.MV_OCam.Polar = (pl + (dy / 256))

			if LK3D.MV_OCam.Polar >= pihalf then
				LK3D.MV_OCam.Polar = pihalf
			end
			if LK3D.MV_OCam.Polar <= -pihalf then
				LK3D.MV_OCam.Polar = -pihalf
			end


		end


		local c_pos = Vector(
			org.x + (od * (math.cos(pl) * math.cos(az))),
			org.y + (od * (math.cos(pl) * math.sin(az))),
			org.z + (od * math.sin(pl))
		)

		if self.dragging then
			local vMul = 0.05
			local dirVec = (org - c_pos):GetNormalized():Angle()


			local newPosAdd = Vector(0, 0, 0)



			if input.IsKeyDown(KEY_W) then
				newPosAdd = newPosAdd + dirVec:Forward()
			end

			if input.IsKeyDown(KEY_S) then
				newPosAdd = newPosAdd - dirVec:Forward()
			end

			if input.IsKeyDown(KEY_A) then
				newPosAdd = newPosAdd - dirVec:Right()
			end

			if input.IsKeyDown(KEY_D) then
				newPosAdd = newPosAdd + dirVec:Right()
			end

			if input.IsKeyDown(KEY_SPACE) then
				newPosAdd = newPosAdd + Vector(0, 0, 1)
			end

			if input.IsKeyDown(KEY_LCONTROL) then
				newPosAdd = newPosAdd - Vector(0, 0, 1)
			end

			LK3D.MV_OCam.Origin = LK3D.MV_OCam.Origin + newPosAdd:GetNormalized() * vMul

			LK3D.PushUniverse(univ_lk3dmv)
				LK3D.DebugUtils.Cross(LK3D.MV_OCam.Origin, 1, FrameTime() * 2, colOriginHighlight)
			LK3D.PopUniverse()
		end


		LK3D.MV.CamPos = c_pos

		LK3D.SetCamAng((org - c_pos):GetNormalized():Angle())
		LK3D.SetCamPos(c_pos)


		LK3D.SetRenderer(LK3D_RENDER_HARD)
		LK3D.SetCamFOV(90)
		LK3D.SetWireFrame(LK3D.MV.Wireframe or false)
		LK3D.PushRenderTarget(rt_renderCanvas)
			LK3D.PushUniverse(univ_lk3dmv)
				LK3D.UpdateLightPos("light1_test", c_pos)
				LK3D.RenderClear(32, 48, 64)

				if LK3D.MV.DrawAABB then
					local n_aabb = LK3D.GetRecalcAABB(LK3D.CurrUniv["objects"]["the_model"])

					LK3D.DebugUtils.Cross(n_aabb[1], .15, .05, Color(255, 0, 0))
					LK3D.DebugUtils.Cross(n_aabb[2], .15, .05, Color(0, 255, 0))

					LK3D.DebugUtils.Line(n_aabb[1], Vector(n_aabb[1].x, n_aabb[1].y, n_aabb[2].z), .05, Color(255, 255, 0))
					LK3D.DebugUtils.Line(n_aabb[1], Vector(n_aabb[1].x, n_aabb[2].y, n_aabb[1].z), .05, Color(255, 255, 0))
					LK3D.DebugUtils.Line(n_aabb[1], Vector(n_aabb[2].x, n_aabb[1].y, n_aabb[1].z), .05, Color(255, 255, 0))

					LK3D.DebugUtils.Line(n_aabb[2], Vector(n_aabb[2].x, n_aabb[2].y, n_aabb[1].z), .05, Color(255, 255, 0))
					LK3D.DebugUtils.Line(n_aabb[2], Vector(n_aabb[2].x, n_aabb[1].y, n_aabb[2].z), .05, Color(255, 255, 0))
					LK3D.DebugUtils.Line(n_aabb[2], Vector(n_aabb[1].x, n_aabb[2].y, n_aabb[2].z), .05, Color(255, 255, 0))

					LK3D.DebugUtils.Line(Vector(n_aabb[2].x, n_aabb[1].y, n_aabb[1].z), Vector(n_aabb[2].x, n_aabb[2].y, n_aabb[1].z), .05, Color(255, 255, 0))
					LK3D.DebugUtils.Line(Vector(n_aabb[2].x, n_aabb[1].y, n_aabb[1].z), Vector(n_aabb[2].x, n_aabb[1].y, n_aabb[2].z), .05, Color(255, 255, 0))

					LK3D.DebugUtils.Line(Vector(n_aabb[1].x, n_aabb[2].y, n_aabb[1].z), Vector(n_aabb[1].x, n_aabb[2].y, n_aabb[2].z), .05, Color(255, 255, 0))
					LK3D.DebugUtils.Line(Vector(n_aabb[1].x, n_aabb[2].y, n_aabb[1].z), Vector(n_aabb[2].x, n_aabb[2].y, n_aabb[1].z), .05, Color(255, 255, 0))

					LK3D.DebugUtils.Line(Vector(n_aabb[1].x, n_aabb[2].y, n_aabb[2].z), Vector(n_aabb[1].x, n_aabb[1].y, n_aabb[2].z), .05, Color(255, 255, 0))
					LK3D.DebugUtils.Line(Vector(n_aabb[1].x, n_aabb[1].y, n_aabb[2].z), Vector(n_aabb[2].x, n_aabb[1].y, n_aabb[2].z), .05, Color(255, 255, 0))
				end

				LK3D.RenderActiveUniverse()
			LK3D.PopUniverse()

			LK3D.RenderQuick(function()
				local mdl_tblpointer = LK3D.Models[LK3D.MV.Model]
				local vcount = #mdl_tblpointer.verts
				local uvcount = #mdl_tblpointer.uvs
				local indexcount = #mdl_tblpointer.indices
				draw.SimpleText("MdlVerts  : " .. vcount    , "BudgetLabel", ScrW() * .5, 0 , Color(255, 196, 196), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
				draw.SimpleText("MdlUvs    : " .. uvcount   , "BudgetLabel", ScrW() * .5, 12, Color(196, 255, 196), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
				draw.SimpleText("MdlIndices: " .. indexcount, "BudgetLabel", ScrW() * .5, 24, Color(196, 196, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			end)
		LK3D.PopRenderTarget()


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
	local pnl_control = vgui.Create("DPanel", LK3D.MVFrame)
	pnl_control:SetTall(64)
	pnl_control:Dock(BOTTOM)
end


concommand.Add("lk3d_model_viewer", function()
	openMV()
end)