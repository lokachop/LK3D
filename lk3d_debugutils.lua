--[[--
## Helpful debug render functions
---

You can think of this as LK3D's version of debugoverlay  
**These only work with LK3D.Debug set to true**!  
]]
-- @module debugutils
LK3D = LK3D or {}
LK3D.DebugUtils = LK3D.DebugUtils or {}


--- Draws a debug line
-- @tparam vector start Start position of the line
-- @tparam vector endpos End position of the line
-- @tparam number life How long should the line be rendered for (in seconds)
-- @tparam color col Colour of the line
-- @usage -- draws a red vertical line that persists for 16s
-- LK3D.DebugUtils.Line(Vector(0, 0, 0), Vector(0, 0, 1), 16, Color(255, 0, 0))
function LK3D.DebugUtils.Line(start, endpos, life, col)
	if not LK3D.Debug then
		return
	end

	local t = LK3D.CurrUniv["debug_obj"]
	if not t then
		LK3D.CurrUniv["debug_obj"] = {}
		t = LK3D.CurrUniv["debug_obj"]
	end
	if not t["line"] then
		t["line"] = {}
	end
	local tl = t["line"]

	tl[#tl + 1] = {
		type = "line",
		col = col or Color(255, 255, 255, 255),
		s_pos = start or Vector(0, 0, 0),
		e_pos = endpos or Vector(0, 0, 1),
		life = CurTime() + life or CurTime() + .25,
	}
end

--- Draws a debug cross
-- @tparam vector pos Center of the cross
-- @tparam number size Size of the cross
-- @tparam number life How long should the cross be rendered for (in seconds)
-- @tparam color col Colour of the cross
-- @usage -- draws a red cross at the center of the universe that persists for 16s
-- LK3D.DebugUtils.Cross(Vector(0, 0, 0), 1, 16, Color(255, 0, 0))
function LK3D.DebugUtils.Cross(pos, size, life, col)
	if not LK3D.Debug then
		return
	end

	local t = LK3D.CurrUniv["debug_obj"]
	if not t then
		LK3D.CurrUniv["debug_obj"] = {}
		t = LK3D.CurrUniv["debug_obj"]
	end
	if not t["line"] then
		t["line"] = {}
	end
	local tl = t["line"]

	tl[#tl + 1] = {
		type = "line",
		col = col or Color(255, 255, 255, 255),
		s_pos = (pos or Vector(0, 0, 0)) + Vector(-size, 0, 0),
		e_pos = (pos or Vector(0, 0, 0)) + Vector(size, 0, 0),
		life = CurTime() + life or CurTime() + .25,
	}

	tl[#tl + 1] = {
		type = "line",
		col = col or Color(255, 255, 255, 255),
		s_pos = (pos or Vector(0, 0, 0)) + Vector(0, -size, 0),
		e_pos = (pos or Vector(0, 0, 0)) + Vector(0, size, 0),
		life = CurTime() + life or CurTime() + .25,
	}

	tl[#tl + 1] = {
		type = "line",
		col = col or Color(255, 255, 255, 255),
		s_pos = (pos or Vector(0, 0, 0)) + Vector(0, 0, -size),
		e_pos = (pos or Vector(0, 0, 0)) + Vector(0, 0, size),
		life = CurTime() + life or CurTime() + .25,
	}
end


--- Draws a debug box
-- @tparam vector pos Center of the box
-- @tparam vector size Scale of the box
-- @tparam angle ang Angle of the box
-- @tparam number life How long should the box be rendered for (in seconds)
-- @tparam color col Colour of the box
-- @usage -- draws a red box at the center of the universe, rotated 45 degrees that persists for 16s
-- LK3D.DebugUtils.Box(Vector(0, 0, 0), Vector(1, 1, 1), Angle(45, 0, 0), 16, Color(255, 0, 0))
function LK3D.DebugUtils.Box(pos, size, ang, life, col)
	if not LK3D.Debug then
		return
	end

	local t = LK3D.CurrUniv["debug_obj"]
	if not t then
		LK3D.CurrUniv["debug_obj"] = {}
		t = LK3D.CurrUniv["debug_obj"]
	end
	if not t["box"] then
		t["box"] = {}
	end
	local tl = t["box"]

	tl[#tl + 1] = {
		type = "box",
		col = col or Color(255, 255, 255, 255),
		pos = pos or Vector(0, 0, 0),
		size = size or Vector(1, 1, 1),
		ang = ang or Angle(0, 0, 0),
		life = CurTime() + life or CurTime() + .25,
	}
end