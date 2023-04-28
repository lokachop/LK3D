LK3D = LK3D or {}
-----------------------------
-- debugutils
-----------------------------

LK3D.DebugUtils = LK3D.DebugUtils or {}
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