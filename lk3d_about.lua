LK3D = LK3D or {}


local Bcol = Color(34, 38, 40)
local BDcol = Color(28, 31, 32)
local BDDcol = Color(21, 23, 24)
local BElmcol = Color(30, 34, 36)

local Wcol = Color(25, 27, 29)
local BGcol = Color(65, 75, 85)
local BGDarkcol = Color(38, 44, 49)
local TBcol = Color(35, 34, 40)


local lk3d_logo = LK3D.Textures["lk3d_logo"].mat

local function buttonPaint(self, w, h)
	local col = Color(44, 58, 70, 128)


	if self:IsHovered() then
		col.r = col.r * 1.3
		col.g = col.g * 1.3
		col.b = col.b * 1.3
	end

	if self:IsDown() then
		col.r = col.r * 1.5
		col.g = col.g * 1.5
		col.b = col.b * 1.5
	end


	surface.SetDrawColor(col)
	surface.DrawRect(0, 0, w, h)

	col.r = col.r * 2.2
	col.g = col.g * 2.2
	col.b = col.b * 2.2

	draw.SimpleText(self.FancyText or "None?", "DermaDefaultBold", w * .5, h / 2, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

local function makeLink(parent, fancyName, address)
	local buttonLink = vgui.Create("DButton", parent)
	buttonLink:Dock(TOP)
	buttonLink:SetTall(32)
	buttonLink:SetText("")

	function buttonLink:DoClick()
		gui.OpenURL(address)
	end
	buttonLink.FancyText = fancyName or "No FancyName?"
	buttonLink.Paint = buttonPaint
end

local function makeSeparator(parent)
	local panelSep = vgui.Create("DPanel", parent)
	panelSep:Dock(TOP)
	panelSep:SetTall(6)
	function panelSep:Paint(w, h)
		surface.SetDrawColor(BElmcol)
		surface.DrawRect(0, 0, w, h)
	end
end

local function framePaint(self, w, h)
	surface.SetDrawColor(BGcol)
	surface.DrawRect(0, 0, w, h)

	surface.SetDrawColor(BGDarkcol)
	surface.DrawRect(0, 0, w, 24)
end

concommand.Add("lk3d_about", function()
	if IsValid(LK3D.FrameAbout) then
		LK3D.FrameAbout:Close()
	end


	LK3D.FrameAbout = vgui.Create("DFrame")
	LK3D.FrameAbout:SetSize(500, 500)
	LK3D.FrameAbout:SetSizable(false)
	LK3D.FrameAbout:Center()
	LK3D.FrameAbout:MakePopup()

	LK3D.FrameAbout:SetTitle("LK3D - About")
	LK3D.FrameAbout:SetIcon("icon16/information.png")
	LK3D.FrameAbout.Paint = framePaint

	local panelFill = vgui.Create("DPanel", LK3D.FrameAbout)
	panelFill:Dock(FILL)

	function panelFill:Paint(w, h)
		surface.SetDrawColor(Bcol)
		surface.DrawRect(0, 0, w, h)
	end


	local panelHead = vgui.Create("DPanel", panelFill)
	panelHead:Dock(TOP)
	panelHead:SetTall(128 + 36)


	local pw, ph = LK3D.FrameAbout:GetSize()
	local wc = 24 * 12
	local hc = 8 * 12

	local xc = (pw * .5) - (wc * .5)
	local yc = 0
	local polyQuad = {
		{x = xc + wc, y = yc + hc	, u = 1, v = 1},
		{x = xc		, y = yc + hc	, u = 0, v = 1},
		{x = xc		, y = yc		, u = 0, v = 0},
		{x = xc + wc, y = yc		, u = 1, v = 0},
	}

	function panelHead:Paint(w, h)
		surface.SetDrawColor(BElmcol)
		surface.DrawRect(0, 0, w, h)


		render.PushFilterMin(TEXFILTER.POINT)
		render.PushFilterMag(TEXFILTER.POINT)
			surface.SetDrawColor(255, 255, 255, 255) -- all this weirdness for no weird errors
			surface.SetMaterial(lk3d_logo)
			surface.DrawPoly(polyQuad)

			draw.SimpleText(LK3D.Version, "DermaLarge", w * .5, hc, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			draw.SimpleText("A rendering library by Lokachop", "DermaLarge", w * .5, hc + 36, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		render.PopFilterMag()
		render.PopFilterMin()
	end

	local panelSepHead = vgui.Create("DPanel", panelFill)
	panelSepHead:Dock(TOP)
	panelSepHead:SetTall(8)
	function panelSepHead:Paint(w, h)
		surface.SetDrawColor(BDcol)
		surface.DrawRect(0, 0, w, h)
	end

	local panelStatsHead = vgui.Create("DPanel", panelFill)
	panelStatsHead:Dock(TOP)
	panelStatsHead:SetTall(36)
	function panelStatsHead:Paint(w, h)
		draw.SimpleText("Stats", "DermaLarge", w * .5, 0, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
	end
	makeSeparator(panelFill)

	local sepTall = 32
	local modelCount = table.Count(LK3D.Models)
	local texCount = table.Count(LK3D.Textures)
	local instrCount = table.Count(LK3D.MusiSynth.ValidInstruments)
	local partCount = table.Count(LK3D.Particles)

	local panelStats = vgui.Create("DPanel", panelFill)
	panelStats:Dock(TOP)
	panelStats:SetTall(sepTall * 4)
	function panelStats:Paint(w, h)
		draw.SimpleText(texCount .. " textures"	 , "DermaLarge", w * .5, 0     	  	, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		draw.SimpleText(modelCount .. " models"	 , "DermaLarge", w * .5, sepTall	, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		draw.SimpleText(instrCount .. " sounds"	 , "DermaLarge", w * .5, sepTall * 2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		draw.SimpleText(partCount .. " particles", "DermaLarge", w * .5, sepTall * 3, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
	end

	makeSeparator(panelFill)

	local panelLinksHead = vgui.Create("DPanel", panelFill)
	panelLinksHead:Dock(TOP)
	panelLinksHead:SetTall(36)
	function panelLinksHead:Paint(w, h)
		draw.SimpleText("Links", "DermaLarge", w * .5, 0, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
	end

	makeSeparator(panelFill)

	makeLink(panelFill, "GitHub", "https://github.com/lokachop/LK3D")

end)