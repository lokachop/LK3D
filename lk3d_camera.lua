LK3D = LK3D or {}

function LK3D.SetCamPos(pos)
	LK3D.CamPos = pos
end

function LK3D.SetCamAng(ang)
	LK3D.CamAng = ang
end

function LK3D.SetCamPosAng(pos, ang)
	LK3D.CamPos = pos or LK3D.CamPos
	LK3D.CamAng = ang or LK3D.CamAng
end
