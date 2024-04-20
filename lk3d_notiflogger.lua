--[[--
## NotifLogger
---

Module that handles logging / console prints  
]]
-- @module notiflogger
LK3D = LK3D or {}

--- Flag for enabling / disabling logging
LK3D.DoLogging = LK3D.DoLogging or true -- write logs to lk3d/logs, WARNING SLOW, keep off when shipping

if LK3D.DoLogging then
	file.CreateDir("lk3d/logs")

	local t_str = os.date("%d_%m_%y__%H_%M")
	local full_path = "lk3d/logs/lk3dlog_" .. t_str .. ".txt"

	LK3D.D_Print("Writing to logfile; " .. full_path)
	LK3D.LogFP = file.Open(full_path, "w", "DATA") -- log file pointer

	LK3D.LogFP:Write("----====LK3D LOGFILE INIT====----\n")

	local nice_str = os.date("%d/%m/%y %H:%M:%S")
	LK3D.LogFP:Write("Initialized @" .. nice_str .. "\n")
	LK3D.LogFP:Write("--- stats ---\n")
	LK3D.LogFP:Write("LK3D Ver.        : " .. (LK3D.Version or "UNKNOWN??") .. "\n")

	LK3D.LogFP:Write("\n--- client stats --- (enable via making a file called \"do_client_stats.txt\" on data/lk3d/logs/)\n")

	local do_client_stats = file.Exists("lk3d/logs/do_client_stats.txt", "DATA") -- make sure the user actually agrees to having a fingerprint in their data folder basically (what if they use alts?)
	if do_client_stats then
		LK3D.LogFP:Write("Client Name      : " .. (LocalPlayer():IsValid() and LocalPlayer():Name() or "not init yet") .. "\n")
		LK3D.LogFP:Write("Client SteamID   : " .. (LocalPlayer():IsValid() and LocalPlayer():SteamID() or "not init yet") .. "\n")
		LK3D.LogFP:Write("Gamemode Name    : " .. engine.ActiveGamemode() .. "\n")

		local addons = engine.GetAddons()
		local mounted_addons = 0
		for k, v in ipairs(addons) do
			if v.mounted then
				mounted_addons = mounted_addons + 1
			end
		end
		LK3D.LogFP:Write("Addon Count      : " .. #addons .. " (" .. mounted_addons .. " mounted addons)" .. "\n")
	end

	LK3D.LogFP:Write("\n--- hardware stats --- (enable via making a file called \"do_hard_stats.txt\" on data/lk3d/logs/)\n")
	local do_hard_stats = file.Exists("lk3d/logs/do_hard_stats.txt", "DATA")
	if do_hard_stats then

		local memcount = collectgarbage("count")
		LK3D.LogFP:Write("Mem Usage        : " .. math.Round(memcount, 3) .. "kb (" .. math.Round(memcount / 1024, 3) .. "mb)" .. "\n")
		LK3D.LogFP:Write("Architecture     : " .. jit.arch .. "\n")
		LK3D.LogFP:Write("OS               : " .. jit.os .. "\n")
		LK3D.LogFP:Write("Jit ver.         : " .. jit.version .. "\n")

		local jit_on, jit_nfo = jit.status()

		LK3D.LogFP:Write("Jit on           : " .. tostring(jit_on) .. " (should be true!)\n")
		LK3D.LogFP:Write("Jit info         : " .. jit_nfo .. "\n")
	end

	LK3D.LogFP:Write("\n\n\n")

	local firstinit = (LK3D.WireFrame == nil)
	LK3D.LogFP:Write("Firstinit?       : " .. tostring(firstinit) .. "\n")

	local recite_textures = file.Exists("lk3d/logs/enum_textures.txt", "DATA")
	local recite_models = file.Exists("lk3d/logs/enum_models.txt", "DATA")
	if not firstinit then
		LK3D.LogFP:Write("--- non firstinit stats ---\n")
		LK3D.LogFP:Write("Textures         : " .. table.Count(LK3D.Textures) .. "\n")
		if recite_textures then
			LK3D.LogFP:Write("\t---=begin texturelist=---\n")
			LK3D.LogFP:Write("\tHINT: turn this off via removing \"enum_textures.txt\" on data/lk3d/logs/\n\n")

			for k, v in pairs(LK3D.Textures) do
				LK3D.LogFP:Write("\t" .. k .. " (" .. v.mat:Width() .. "x" .. v.mat:Height() .. ")\n")
			end

			LK3D.LogFP:Write("\n\tHINT: turn this off via removing \"enum_textures.txt\" on data/lk3d/logs/\n")
			LK3D.LogFP:Write("\t---=end texturelist=---\n")
		else
			LK3D.LogFP:Write("\tHINT: show all textures via making a file called \"enum_textures.txt\" on data/lk3d/logs/\n\n")
		end

		LK3D.LogFP:Write("Models           : " .. table.Count(LK3D.Models) .. "\n")
		if recite_models then
			LK3D.LogFP:Write("\t---=begin modelist=---\n")
			LK3D.LogFP:Write("\tHINT: turn this off via removing \"enum_models.txt\" on data/lk3d/logs/\n\n")

			for k, v in pairs(LK3D.Models) do
				LK3D.LogFP:Write("\t" .. k .. "\n")
				LK3D.LogFP:Write("\t\t" .. "verts  : " .. #v.verts .. "\n")
				LK3D.LogFP:Write("\t\t" .. "uvs    : " .. #v.uvs .. "\n")
				LK3D.LogFP:Write("\t\t" .. "indices: " .. #v.uvs .. "\n")
				LK3D.LogFP:Write("\t\t\n")
			end

			LK3D.LogFP:Write("\n\tHINT: turn this off via removing \"enum_models.txt\" on data/lk3d/logs/\n")
			LK3D.LogFP:Write("\t---=end modelist=---\n")
		else
			LK3D.LogFP:Write("\tHINT: show all models via making a file called \"enum_models.txt\" on data/lk3d/logs/\n\n")
		end

		LK3D.LogFP:Write("Last FarZ        : " .. LK3D.FAR_Z .. "\n")
		LK3D.LogFP:Write("Last NearZ       : " .. LK3D.NEAR_Z .. "\n")
		LK3D.LogFP:Write("Last FOV         : " .. LK3D.FOV .. "\n")
		LK3D.LogFP:Write("Last Ortho       : " .. tostring(LK3D.Ortho) .. "\n")
		LK3D.LogFP:Write("Last FilterMode  : " .. tostring(LK3D.FilterMode) .. "\n")
		LK3D.LogFP:Write("Last AmbientCol  : " .. tostring(LK3D.AmbientCol) .. "\n")
		LK3D.LogFP:Write("Last Renderer    : " .. tostring(LK3D.ActiveRenderer) .. " [" .. (LK3D.Renderers[LK3D.ActiveRenderer].PrettyName or "No fancyname") .. "]\n")
		LK3D.LogFP:Write("Renderer Count   : " .. table.Count(LK3D.Renderers) .. "\n")

		LK3D.LogFP:Write("---- renderer list ----" .. "\n")
		for k, v in pairs(LK3D.Renderers) do
			LK3D.LogFP:Write("\t" .. tostring(k) .. ": " .. (v.PrettyName or "No fancyname") .. "\n")
		end
	end

	LK3D.LogFP:Write("----====BEGIN LK3D LOG====----\n")
end


--- Writes a message to the logs
-- @tparam string text String to log
-- @usage LK3D.LogMessage("Hi From LK3DWiki!")
function LK3D.LogMessage(text)
	local nice_str = os.date("[%H:%M:%S] ")
	LK3D.LogFP:Write(nice_str .. text .. "\n")
end


--- Handles the automatic flushing of the log
-- @usage LK3D.AutoLogFlush()
local next_flush = CurTime() + 1
function LK3D.AutoLogFlush()
	if not LK3D.DoLogging then
		return
	end

	if CurTime() < next_flush then
		return
	end

	LK3D.LogFP:Flush()
	next_flush = CurTime() + 1
end

--- Constants
-- @section constants

-- Debug severity type
LK3D_SEVERITY_DEBUG = 1
--- Info severity type
LK3D_SEVERITY_INFO  = 2
--- Warn severity type
LK3D_SEVERITY_WARN  = 3
--- Error severity type
LK3D_SEVERITY_ERROR = 4
--- Fatal severity type
LK3D_SEVERITY_FATAL = 5

--- End
-- @section end

local fancy_severities = {
	[1] = "Debug",
	[2] = " Info",
	[3] = " Warn",
	[4] = "Error",
	[5] = "Fatal"
}

local severity_colours = {
	[1] = Color(32, 32, 32),
	[2] = Color(96, 96, 220),
	[3] = Color(220, 128, 96),
	[4] = Color(220, 96, 96),
	[5] = Color(255, 32, 32),
}

local c_gray = Color(100, 100, 100)
local c_darkgray = Color(32, 32, 32)

LK3D.ModuleColours = {}
--- Declares the colour for a log module
-- @tparam string lk_module Module name
-- @tparam color col Module colour
-- @usage LK3D.DeclareModuleColour("Custom", Color(255, 0, 0))
function LK3D.DeclareModuleColour(lk_module, col)
	LK3D.ModuleColours[lk_module] = col
end
LK3D.DeclareModuleColour("Base", Color(100, 100, 100))
LK3D.DeclareModuleColour("ProcTex", Color(100, 100, 255))
LK3D.DeclareModuleColour("ProcModel", Color(255, 100, 100))
LK3D.DeclareModuleColour("MusiSynth", Color(128, 196, 255))
LK3D.DeclareModuleColour("ModelUtils", Color(255, 100, 255))
LK3D.DeclareModuleColour("LKComp", Color(255, 255, 100))
LK3D.DeclareModuleColour("LKComp_Legacy", Color(255, 128, 32))
LK3D.DeclareModuleColour("LKTComp", Color(255, 255, 100))
LK3D.DeclareModuleColour("Particles", Color(128, 196, 255))
LK3D.DeclareModuleColour("Textures", Color(128, 64, 255))
LK3D.DeclareModuleColour("TraceSystem", Color(128, 255, 64))
LK3D.DeclareModuleColour("Utils", Color(64, 128, 196))
LK3D.DeclareModuleColour("Physics", Color(64, 196, 128))
LK3D.DeclareModuleColour("Radiosity", Color(196, 64, 128))
LK3D.DeclareModuleColour("LKPack", Color(64, 196, 64))
LK3D.DeclareModuleColour("DPRINT", Color(16, 128, 96))
LK3D.DeclareModuleColour("Hardware2", Color(16, 68, 128))
LK3D.DeclareModuleColour("Software2", Color(128, 68, 128))
LK3D.DeclareModuleColour("Noise", Color(50, 197, 116))

--- Value that marks which severity to start logging from (inclusive)
LK3D.LogSeverity = LK3D.LogSeverity or LK3D_SEVERITY_DEBUG
--- Value that marks which severity to start printing with LK3D.Debug **disabled**
LK3D.DebugOnlySev = LK3D.DebugOnlySev or LK3D_SEVERITY_INFO
--- Value that marks which severity to start printing with LK3D.Debug **enabled**
LK3D.DebugSev = LK3D.DebugSev or LK3D_SEVERITY_INFO

--- Prints a message to the console and logs it
-- @tparam string text Text to print
-- @tparam number severity Severity type constant
-- @tparam string lk_module Module to log as
-- @usage LK3D.New_D_Print("Help!" LK3D_SEVERITY_WARN, "Hardware2")
function LK3D.New_D_Print(text, severity, lk_module)
	severity = severity or 1
	lk_module = lk_module or "Base"
	if not fancy_severities[severity] then
		severity = 2
	end


	local fancy_sev_str = fancy_severities[severity]
	if LK3D.DoLogging and (severity >= LK3D.LogSeverity) then
		LK3D.LogMessage("[" .. fancy_sev_str .. "]" .. " [" .. lk_module .. "]: " .. text)
	end

	if not LK3D.Debug and (severity < LK3D.DebugOnlySev) then
		return
	end

	if LK3D.Debug and (severity < LK3D.DebugSev) then
		return
	end

	local m_col = LK3D.ModuleColours[lk_module] or c_gray
	local m_col_brighter = Color(m_col.r + 100, m_col.g + 100, m_col.b + 100)

	local sev_col = severity_colours[severity] or c_darkgray

	local nice_str_t = os.date("[%H:%M:%S] ")
	MsgC(Color(64, 196, 64), nice_str_t, sev_col, "[" .. fancy_sev_str .. "]", Color(100, 255, 100), " [LK3D] ", m_col, "[" .. lk_module .. "]", m_col_brighter, ": ", text, "\n")

	-- error cuz nice if fatal
	if severity == 5 then
		ErrorNoHaltWithStack("[LK3D FATAL]: " .. text)
	end
end





LK3D.New_D_Print("LogNotif system fully loaded!", LK3D_SEVERITY_INFO, "Base")