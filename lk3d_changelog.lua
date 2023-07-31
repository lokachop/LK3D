LK3D = LK3D or {}
LK3D.ChangeLogs = LK3D.ChangeLogs or {}
local cLogOrders = {}
local lastCLog = 0

function LK3D.NewChangeLogVersion(name, desc)
	lastCLog = lastCLog + 1
	LK3D.ChangeLogs[name] = {
		description = desc or "No description :(",
		added = {},
		changed = {},
		removed = {},
	}
	cLogOrders[lastCLog] = name
end

LK3D_CHANGELOG_ADDED = 1
LK3D_CHANGELOG_CHANGED = 2
LK3D_CHANGELOG_REMOVED = 3

local enumLUT = {
	[LK3D_CHANGELOG_ADDED] = "added",
	[LK3D_CHANGELOG_CHANGED] = "changed",
	[LK3D_CHANGELOG_REMOVED] = "removed"
}

local enumTexLUT = {
	[LK3D_CHANGELOG_ADDED] = "change_add",
	[LK3D_CHANGELOG_CHANGED] = "change_keep",
	[LK3D_CHANGELOG_REMOVED] = "change_remove"
}

function LK3D.AddToChangeLog(ver, ctype, title, desc)
	if not LK3D.ChangeLogs[ver] then
		return
	end

	if not ctype then
		return
	end

	local enumCont = enumLUT[ctype]
	if not enumCont then
		return
	end

	local tblptr = LK3D.ChangeLogs[ver][enumCont]
	tblptr[#tblptr + 1] = {title = title, desc = desc}
end


LK3D.NewChangeLogVersion("1.3 'Green Square'", "A major overhaul of the radiosity system")

LK3D.AddToChangeLog("1.3 'Green Square'", LK3D_CHANGELOG_ADDED, "LK3D_SEVERITY Enums", "Added a bunch of enums for LK3D.New_D_Print()")
LK3D.AddToChangeLog("1.3 'Green Square'", LK3D_CHANGELOG_ADDED, "Hardware renderer \"UV_USE_LIGHTMAP\" tag", "Makes the model use its lightmap UVs for normal rendering")
LK3D.AddToChangeLog("1.3 'Green Square'", LK3D_CHANGELOG_ADDED, "lk3d_exportlightmaps concommand", "Allows exporting lightmaps")
LK3D.AddToChangeLog("1.3 'Green Square'", LK3D_CHANGELOG_ADDED, "lk3d_about concommand", "Returns information about LK3D")
LK3D.AddToChangeLog("1.3 'Green Square'", LK3D_CHANGELOG_ADDED, "lk3d_changelog concommand", "Shows the LK3D changelog (this!)")

LK3D.AddToChangeLog("1.3 'Green Square'", LK3D_CHANGELOG_CHANGED, "Recoded Radiosity", "More accurate to real-life and ~33x times slower!")
LK3D.AddToChangeLog("1.3 'Green Square'", LK3D_CHANGELOG_CHANGED, "Fast lightmap loading", "LK3D.LoadLightmapFromFile now internally loads from PNG at instant speeds")

LK3D.AddToChangeLog("1.3 'Green Square'", LK3D_CHANGELOG_REMOVED, "LK3D.Utils Deleted", "All LK3D.Utils functions address to LK3D now")




-- concommand derma stuff below

surface.CreateFont("LK3DChangeLogSmall", {
	font = "Arial",
	size = 14,
	weight = 500,
})


surface.CreateFont("LK3DChangeLogMedium", {
	font = "Arial",
	size = 16,
	weight = 500,
})

surface.CreateFont("LK3DChangeLogLarge", {
	font = "Arial",
	size = 24,
	weight = 500,
})

local LLBcol = Color(80, 88, 92)
local LBcol = Color(44, 49, 51)
local Bcol = Color(34, 38, 40)
local BDcol = Color(28, 31, 32)
local BDDcol = Color(21, 23, 24)
local BElmcol = Color(30, 34, 36)

local Wcol = Color(25, 27, 29)
local BGcol = Color(65, 75, 85)
local BGDarkcol = Color(38, 44, 49)
local TBcol = Color(35, 34, 40)

local lk3d_logo = LK3D.Textures["lk3d_logo"].mat

local function framePaint(self, w, h)
	surface.SetDrawColor(BGcol)
	surface.DrawRect(0, 0, w, h)

	surface.SetDrawColor(BGDarkcol)
	surface.DrawRect(0, 0, w, 24)
end

local function makeSeparator(parent, sz)
	local panelSep = vgui.Create("DPanel", parent)
	panelSep:Dock(TOP)
	panelSep:SetTall(sz or 8)
	function panelSep:Paint(w, h)
		surface.SetDrawColor(BDcol)
		surface.DrawRect(0, 0, w, h)
	end
end

local function makeVersionHeading(parent, ver)
	makeSeparator(parent)
		local panelVersionName = vgui.Create("DPanel", parent)
		panelVersionName:Dock(TOP)
		panelVersionName:SetTall(32)
		function panelVersionName:Paint(w, h)
			draw.SimpleText(ver, "DermaLarge", w * .5, 0, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		end
	--makeSeparator(parent)
end

local function makeHeadingDescription(parent, text)
	local panelDescription = vgui.Create("DPanel", parent)
	panelDescription:Dock(TOP)
	panelDescription:SetTall(32)
	function panelDescription:Paint(w, h)
		--surface.SetDrawColor(BGDarkcol)
		--surface.DrawRect(0, 0, w, h)

		draw.SimpleText(text, "LK3DChangeLogLarge", w * .5, 0, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
	end
end

local function makeChangeDescription(text)
	local panelDescription = vgui.Create("DPanel")
	panelDescription:Dock(TOP)
	panelDescription:SetTall(32)
	function panelDescription:Paint(w, h)
		surface.SetDrawColor(BDDcol)
		surface.DrawRect(0, 0, w, h)

		draw.SimpleText(text, "LK3DChangeLogMedium", 4, 0, Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end

	return panelDescription
end

local function makeChange(parent, change, ctype)
	local catOpen = vgui.Create("DCollapsibleCategory", parent)
	catOpen:SetLabel("")
	catOpen:Dock(TOP)
	catOpen:SetTall(16 + 24)
	catOpen:SetExpanded(false)
	catOpen.labelContents = change.title


	local xc, yc = 0, 0
	local wc, hc = 20, 20
	local polyQuad = {
		{x = xc + wc, y = yc + hc	, u = 1, v = 1},
		{x = xc		, y = yc + hc	, u = 0, v = 1},
		{x = xc		, y = yc		, u = 0, v = 0},
		{x = xc + wc, y = yc		, u = 1, v = 0},
	}

	function catOpen:Paint(w, h)
		surface.SetDrawColor(BElmcol)
		surface.DrawRect(0, 0, w, h)

		local targetIcon = enumTexLUT[ctype]
		local iconMat = LK3D.Textures[targetIcon]
		if not iconMat then
			return
		end
		surface.SetDrawColor(255, 255, 255, 255) -- all this weirdness for no weird errors
		surface.SetMaterial(iconMat.mat)
		surface.DrawPoly(polyQuad)


		draw.SimpleText(self.labelContents, "LK3DChangeLogSmall", 24, 10, Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	local desc = makeChangeDescription(change.desc)
	catOpen:SetContents(desc)
end



local function makeVersionLog(parent, ver)
	local data = LK3D.ChangeLogs[ver]
	if not data then
		return
	end


	makeVersionHeading(parent, ver)
	makeHeadingDescription(parent, data.description)

	local added = data.added
	local changed = data.changed
	local removed = data.removed

	for k, v in ipairs(added) do
		makeChange(parent, v, LK3D_CHANGELOG_ADDED)
	end

	for k, v in ipairs(changed) do
		makeChange(parent, v, LK3D_CHANGELOG_CHANGED)
	end

	for k, v in ipairs(removed) do
		makeChange(parent, v, LK3D_CHANGELOG_REMOVED)
	end
end


concommand.Add("lk3d_changelog", function()
	if IsValid(LK3D.FrameChangelog) then
		LK3D.FrameChangelog:Close()
	end

	LK3D.FrameChangelog = vgui.Create("DFrame")
	LK3D.FrameChangelog:SetSize(500, 500)
	LK3D.FrameChangelog:SetSizable(false)
	LK3D.FrameChangelog:Center()
	LK3D.FrameChangelog:MakePopup()

	LK3D.FrameChangelog:SetTitle("LK3D - Changelog")
	LK3D.FrameChangelog:SetIcon("icon16/page_white_text.png")
	LK3D.FrameChangelog.Paint = framePaint

	local panelFill = vgui.Create("DScrollPanel", LK3D.FrameChangelog)
	panelFill:Dock(FILL)

	function panelFill:Paint(w, h)
		surface.SetDrawColor(Bcol)
		surface.DrawRect(0, 0, w, h)
	end

	local scrollBar = panelFill:GetVBar()
	scrollBar:SetHideButtons(true)
	function scrollBar:Paint(w, h)
		surface.SetDrawColor(LBcol)
		surface.DrawRect(0, 0, w, h)
	end

	local scrollGrip = scrollBar.btnGrip
	function scrollGrip:Paint(w, h)
		local wmul = 8
		local hmul = 8
		surface.SetDrawColor(LLBcol)
		surface.DrawRect(wmul * .5, hmul * .5, w - wmul, h - hmul)
	end


	local panelHead = vgui.Create("DPanel", panelFill)
	panelHead:Dock(TOP)
	panelHead:SetTall(128)


	local pw, ph = LK3D.FrameChangelog:GetSize()
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

			draw.SimpleText("Changelog", "DermaLarge", w * .5, hc, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		render.PopFilterMag()
		render.PopFilterMin()
	end


	for k, v in ipairs(cLogOrders) do
		makeVersionLog(panelFill, v)
	end
end)