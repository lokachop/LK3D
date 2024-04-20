--[[--
## Camera control functions
---

These functions handle moving / rotating the camera
]]
-- @module camera
LK3D = LK3D or {}
LK3D.CamPos = LK3D.CamPos or Vector(0, 0, 0)
LK3D.CamAng = LK3D.CamAng or Angle(0, 0, 0)
LK3D.FOV = LK3D.FOV or 90
LK3D.FAR_Z = LK3D.FAR_Z or 200
LK3D.NEAR_Z = LK3D.NEAR_Z or .05
LK3D.OrthoParams = {
	left = 1,
	right = -1,
	top = 1,
	bottom = -1
}

--- Sets the position of the camera
-- @tparam vector pos The new position we want to set the camera to
-- @usage LK3D.SetCamPos(Vector(0, 0, 0))
function LK3D.SetCamPos(pos)
	LK3D.CamPos = pos
end

--- Sets the angle of the camera
-- @tparam angle ang The new angle we want to set the camera to
-- @usage LK3D.SetCamAng(Angle(90, 0, 0))
function LK3D.SetCamAng(ang)
	LK3D.CamAng = ang
end

--- Sets the position and the angle of the camera
-- @tparam vector pos The new position we want to set the camera to
-- @tparam angle ang The new angle we want to set the camera to
-- @usage LK3D.SetCamPosAng(Vector(0, 0, 0), Angle(90, 0, 0))
function LK3D.SetCamPosAng(pos, ang)
	LK3D.CamPos = pos or LK3D.CamPos
	LK3D.CamAng = ang or LK3D.CamAng
end

--- Sets the FOV of the camera
-- @tparam number fov The new FOV we want to set
-- @usage LK3D.SetCamFOV(65) -- cinematic :)
function LK3D.SetCamFOV(fov)
	LK3D.FOV = fov
end

--- Sets the far z distance of the camera
-- @tparam number farZ The new far z we want to set
-- @usage LK3D.SetCamFarZ(800)
function LK3D.SetCamFarZ(farZ)
	LK3D.FAR_Z = farZ
end

--- Sets the near z distance of the camera
-- @tparam number nearZ The new near z we want to set
-- @usage LK3D.SetCamNearZ(.1)
function LK3D.SetCamNearZ(nearZ)
	LK3D.NEAR_Z = nearZ
end

--- Sets the far z and near z distance of the camera
-- @tparam ?number nearZ The new near z we want to set
-- @tparam ?number farZ The new far z we want to set
-- @usage LK3D.SetCamZDistances(.1, 800)
function LK3D.SetCamZDistances(nearZ, farZ)
	LK3D.NEAR_Z = nearZ or LK3D.NEAR_Z
	LK3D.FAR_Z = farZ or LK3D.FAR_Z
end

--- Enables / disables [Orthographic Projection](https://en.wikipedia.org/wiki/Orthographic_projection)
-- @tparam bool ortho Enable / disable orthographic projection
-- @usage LK3D.SetCamOrtho(true)
function LK3D.SetCamOrtho(ortho)
	LK3D.Ortho = ortho
end

--- Sets the ortho parameters of the render
-- @tparam table params Ortho parameters, refer to [GLua RenderCamData](https://wiki.facepunch.com/gmod/Structures/RenderCamData#ortho)
-- @usage LK3D.SetCamOrthoParams({
--	 left   = -.5,
--	 right  =  .5,
--	 top    = -.5,
--	 bottom =  .5,
-- })
function LK3D.SetCamOrthoParams(params)
	LK3D.OrthoParams = params
end




-- old deprecated
function LK3D.SetFOV(fov)
	LK3D.New_D_Print("Using deprecated function LK3D.SetFOV(), use LK3D.SetCamFOV()", LK3D_SEVERITY_WARN, "LK3D")
	LK3D.SetCamFOV(fov)
end

function LK3D.SetOrtho(flag)
	LK3D.New_D_Print("Using deprecated function LK3D.SetOrtho(), use LK3D.SetCamOrtho()", LK3D_SEVERITY_WARN, "LK3D")
	LK3D.SetCamOrtho(flag)
end

function LK3D.SetOrthoParameters(tbl)
	LK3D.New_D_Print("Using deprecated function LK3D.SetOrthoParameters(), use LK3D.SetCamOrthoParams()", LK3D_SEVERITY_WARN, "LK3D")
	LK3D.SetCamOrthoParams(tbl)
end