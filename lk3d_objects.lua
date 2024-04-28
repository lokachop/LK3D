--[[--
## Manages objects
---

Module to create / update / delete objects on the active universe   
]]
-- @module objects
LK3D = LK3D or {}

--- Adds an object to the active universe
-- @tparam string index Index tag of the object
-- @tparam string mdl LK3D model of the object
-- @tparam ?vector pos Position to set the object to
-- @tparam ?vector ang Angle to set the object to
-- @usage LK3D.AddObjectToUniverse("cube1", "cube_nuv")
function LK3D.AddObjectToUniverse(index, mdl, pos, ang)
	LK3D.New_D_Print("Adding \"" .. index .. "\" to universe with model \"" .. (mdl or "cube") .. "\"", LK3D_SEVERITY_DEBUG, "LK3D")
	if not LK3D.Models[mdl] then
		LK3D.New_D_Print("Model \"" .. mdl .. "\" doesnt exist!", LK3D_SERVERITY_WARN, "LK3D")
		mdl = "fail"
	end

	local tmatrix_o = Matrix()
	tmatrix_o:SetTranslation(pos or Vector(0, 0, 0))
	tmatrix_o:SetAngles(ang or Angle(0, 0, 0))
	tmatrix_o:SetScale(Vector(1, 1, 1))

	LK3D.CurrUniv["objects"][index] = {
		mdl = mdl or "cube",
		pos = pos or Vector(0, 0, 0),
		ang = ang or Angle(0, 0, 0),
		scl = Vector(1, 1, 1),
		mat = "white",
		col = Color(255, 255, 255, 255),
		name = index,
		tmatrix = tmatrix_o -- translation matrix new
	}
end

--- Removes an object from the active universe
-- @tparam string index Index tag of the object
-- @usage LK3D.RemoveObjectFromUniverse("cube1")
function LK3D.RemoveObjectFromUniverse(index)
	LK3D.CurrUniv["objects"][index] = nil
end

--- Sets the material of an object
-- @tparam string index Index tag of the object
-- @tparam string mat Material name
-- @usage LK3D.SetObjectMat("cube1", "checker")
function LK3D.SetObjectMat(index, mat)
	if not LK3D.CurrUniv["objects"][index] then
		return
	end

	if not LK3D.Textures[mat] then
		LK3D.CurrUniv["objects"][index].mat = "fail"
		return
	end

	LK3D.CurrUniv["objects"][index].mat = mat
end

--- Sets the colour of an object
-- @tparam string index Index tag of the object
-- @tparam color col New colour
-- @usage LK3D.SetObjectCol("cube1", Color(64, 128, 255))
function LK3D.SetObjectCol(index, col)
	if not LK3D.CurrUniv["objects"][index] then
		return
	end

	LK3D.CurrUniv["objects"][index].col = col
end

--- Sets the position of an object
-- @tparam string index Index tag of the object
-- @tparam vector pos New position
-- @usage LK3D.SetObjectPos("cube1", Vector(0, 0, 1))
function LK3D.SetObjectPos(index, pos)
	LK3D.CurrUniv["objects"][index].pos = pos
	LK3D.CurrUniv["objects"][index].tmatrix:SetTranslation(pos)
end

--- Sets the angle of an object
-- @tparam string index Index tag of the object
-- @tparam angle ang New angle
-- @usage LK3D.SetObjectAng("cube1", Angle(0, 0, 90))
function LK3D.SetObjectAng(index, ang)
	LK3D.CurrUniv["objects"][index].ang = ang
	LK3D.CurrUniv["objects"][index].tmatrix:SetAngles(ang)
end

--- Sets the position and angle of an object
-- @tparam string index Index tag of the object
-- @tparam ?vector pos New position
-- @tparam ?angle ang New angle
-- @usage LK3D.SetObjectPosAng("cube1", Vector(0, 0, 1), Angle(0, 0, 90))
function LK3D.SetObjectPosAng(index, pos, ang)
	LK3D.CurrUniv["objects"][index].pos = pos or Vector(0, 0, 0)
	LK3D.CurrUniv["objects"][index].ang = ang or Angle(0, 0, 0)
	LK3D.CurrUniv["objects"][index].tmatrix:SetAngles(ang or Angle(0, 0, 0))
	LK3D.CurrUniv["objects"][index].tmatrix:SetTranslation(pos or Vector(0, 0, 0))
end

--- Sets the scale of the object
-- @tparam string index Index tag of the object
-- @tparam vector scale New scale
-- @usage LK3D.SetObjectScale("cube1", Vector(.25, .25, 1))
function LK3D.SetObjectScale(index, scale)
	LK3D.CurrUniv["objects"][index].scl = scale
	LK3D.CurrUniv["objects"][index].tmatrix:SetScale(scale)
end

--- Sets the model of the object
-- @tparam string index Index tag of the object
-- @tparam string mdl New model, sets to "fail" if not found
-- @usage LK3D.SetObjectModel("cube1", "cube_hd")
function LK3D.SetObjectModel(index, mdl)
	if not LK3D.Models[mdl] then
		mdl = "fail"
	end

	if mdl == LK3D.CurrUniv["objects"][index].mdl then
		return
	end

	LK3D.CurrUniv["objects"][index].mdl = mdl

	if LK3D.CurrUniv["modelCache"] then
		LK3D.CurrUniv["modelCache"][index] = nil
	end
end

--- Sets a flag on the object, refer to the Object Flags manual
-- @tparam string index Index tag of the object
-- @tparam string flag Flag index
-- @param value Value to set the flag to
-- @usage LK3D.SetObjectFlag("cube1", "NO_SHADING", true)
function LK3D.SetObjectFlag(index, flag, value)
	LK3D.CurrUniv["objects"][index][flag] = value
end

--- Hides the object from rendering, can still render individually
-- @tparam string index Index tag of the object
-- @tparam bool bool Should hide
-- @usage LK3D.SetObjectHide("cube1", true)
function LK3D.SetObjectHide(index, bool)
	LK3D.CurrUniv["objects"][index]["RENDER_NOGLOBAL"] = bool
end

--- Declares an object animation from a function
-- @tparam string index Index tag of the object
-- @tparam string an_index New animation index
-- @tparam number frames Frame count of the new animation
-- @tparam function func Animation function
-- @usage -- This animation will do nothing  
-- -- Refer to a TBD manual for more reference on this, or ask Lokachop
-- LK3D.DeclareObjectAnim("cube1", "test_hello", 32, function() end)
function LK3D.DeclareObjectAnim(index, an_index, frames, func)
	local object = LK3D.CurrUniv["objects"][index]

	if object.mdlCache == nil then
		object.mdlCache = {}
	end


	object.mdlCache[an_index or "UNDEFINED"] = {
		frames = frames or 6,
		func = func or function() end,
		meshes = {},
		genned = false
	}
	object.anim_delta = object.anim_delta or 0
	object.anim_rate = object.anim_rate or 1
	object.anim_state = object.anim_state or true
end

--- Sets the animation of an object with an animated model
-- @tparam string index Index tag of the object
-- @tparam string an_index Index of the animation
-- @usage LK3D.SetObjectAnim("human_ponr", "walkin")
function LK3D.SetObjectAnim(index, an_index)
	if an_index == "none" then
		an_index = nil
		LK3D.CurrUniv["objects"][index].mdlCache = {}
	end

	LK3D.CurrUniv["objects"][index].anim_index = an_index
end

--- Sets the speed of an animation on an object
-- @tparam string index Index tag of the object
-- @tparam number rate Rate (speed) of the animation
-- @usage LK3D.SetObjectAnimRate("human_ponr", 24) -- Please refer to LK3D.AnimFrameDiv
function LK3D.SetObjectAnimRate(index, rate)
	LK3D.CurrUniv["objects"][index].anim_rate = rate or 1
end
LK3D.SetObjectAnimPlayRate = LK3D.SetObjectAnimRate

--- Sets whether the animation of an object should play or not
-- @tparam string index Index tag of the object
-- @tparam bool bool Should play?
-- @usage LK3D.SetObjectAnimPlay("human_ponr", true)
function LK3D.SetObjectAnimPlay(index, bool)
	LK3D.CurrUniv["objects"][index].anim_state = ((bool ~= nil) and bool) or false
end

--- Sets the current delta (time) of the object's animation
-- @tparam string index Index tag of the object
-- @tparam number delta Delta to set, between 0 and 1
-- @usage LK3D.SetObjectAnimDelta("human_ponr", 0.25)
function LK3D.SetObjectAnimDelta(index, delta)
	LK3D.CurrUniv["objects"][index].anim_delta = math.min(math.max(delta, 0), 1) or 0
end

--- Gets the current delta (time) of an object's animation
-- @tparam string index Index tag of the object
-- @treturn number Delta of the animation, between 0 and 1
-- @usage local delta = LK3D.GetObjectAnimDelta("human_ponr")
function LK3D.GetObjectAnimDelta(index)
	return LK3D.CurrUniv["objects"][index].anim_delta
end







-- OLD RETROCOMPAT
function LK3D.AddModelToUniverse(index, mdl, pos, ang)
	LK3D.New_D_Print("Using deprecated function LK3D.AddModelToUniverse(), use LK3D.AddObjectToUniverse()", LK3D_SEVERITY_WARN, "LK3D")
	LK3D.AddObjectToUniverse(index, mdl, pos, ang)
end

function LK3D.RemoveModelFromUniverse(index)
	LK3D.New_D_Print("Using deprecated function LK3D.RemoveModelFromUniverse(), use LK3D.RemoveObjectFromUniverse()", LK3D_SEVERITY_WARN, "LK3D")
	LK3D.RemoveObjectFromUniverse(index)
end

function LK3D.SetModelMat(index, mat)
	LK3D.New_D_Print("Using deprecated function LK3D.SetModelMat(), use LK3D.SetObjectMat()", LK3D_SEVERITY_WARN, "LK3D")
	LK3D.SetObjectMat(index, mat)
end

function LK3D.SetModelCol(index, col)
	LK3D.New_D_Print("Using deprecated function LK3D.SetModelCol(), use LK3D.SetObjectCol()", LK3D_SEVERITY_WARN, "LK3D")
	LK3D.SetObjectCol(index, col)
end

-- dont warn on these, we use often
local lowWarnTime = 6
local nextWarnPos = CurTime()
function LK3D.SetModelPos(index, pos)
	if CurTime() > nextWarnPos then
		nextWarnPos = nextWarnPos + lowWarnTime
		LK3D.New_D_Print("Using deprecated function LK3D.SetModelPos(), use LK3D.SetObjectPos()", LK3D_SEVERITY_WARN, "LK3D")
	end

	LK3D.SetObjectPos(index, pos)
end

local nextWarnAng = CurTime()
function LK3D.SetModelAng(index, ang)
	if CurTime() > nextWarnAng then
		nextWarnAng = nextWarnAng + lowWarnTime
		LK3D.New_D_Print("Using deprecated function LK3D.SetModelAng(), use LK3D.SetObjectAng()", LK3D_SEVERITY_WARN, "LK3D")
	end

	LK3D.SetObjectAng(index, ang)
end

local nextWarnPosAng = CurTime()
function LK3D.SetModelPosAng(index, pos, ang)
	if CurTime() > nextWarnPosAng then
		nextWarnPosAng = nextWarnPosAng + lowWarnTime
		LK3D.New_D_Print("Using deprecated function LK3D.SetModelPosAng(), use LK3D.SetObjectPosAng()", LK3D_SEVERITY_WARN, "LK3D")
	end

	LK3D.SetObjectPosAng(index, pos, ang)
end

local nextWarnScl = CurTime()
function LK3D.SetModelScale(index, scale)
	if CurTime() > nextWarnScl then
		nextWarnScl = nextWarnScl + lowWarnTime
		LK3D.New_D_Print("Using deprecated function LK3D.SetModelScale(), use LK3D.SetObjectScale()", LK3D_SEVERITY_WARN, "LK3D")
	end

	LK3D.SetObjectScale(index, scale)
end




function LK3D.SetModelModel(index, mdl)
	LK3D.New_D_Print("Using deprecated function LK3D.SetModelModel(), use LK3D.SetObjectModel()", LK3D_SEVERITY_WARN, "LK3D")
	LK3D.SetObjectModel(index, mdl)
end

function LK3D.SetModelFlag(index, flag, value)
	LK3D.New_D_Print("Using deprecated function LK3D.SetModelFlag(), use LK3D.SetObjectFlag()", LK3D_SEVERITY_WARN, "LK3D")
	LK3D.SetObjectFlag(index, flag, value)
end

function LK3D.SetModelHide(index, bool)
	LK3D.New_D_Print("Using deprecated function LK3D.SetModelHide(), use LK3D.SetObjectHide()", LK3D_SEVERITY_WARN, "LK3D")
	LK3D.SetObjectHide(index, bool)
end


-- anims
function LK3D.DeclareModelAnim(index, an_index, frames, func)
	LK3D.New_D_Print("Using deprecated function LK3D.DeclareModelAnim(), use LK3D.DeclareObjectAnim()", LK3D_SEVERITY_WARN, "LK3D")
	LK3D.DeclareObjectAnim(index, an_index, frames, func)
end

function LK3D.SetModelAnim(index, an_index)
	LK3D.New_D_Print("Using deprecated function LK3D.SetModelAnim(), use LK3D.SetObjectAnim()", LK3D_SEVERITY_WARN, "LK3D")
	LK3D.SetObjectAnim(index, an_index)
end

function LK3D.SetModelAnimPlayRate(index, rate)
	LK3D.New_D_Print("Using deprecated function LK3D.SetModelAnimPlayRate(), use LK3D.SetObjectAnimRate()", LK3D_SEVERITY_WARN, "LK3D")
	LK3D.SetObjectAnimRate(index, rate)
end

function LK3D.SetModelAnimPlay(index, bool)
	LK3D.New_D_Print("Using deprecated function LK3D.SetModelAnimPlay(), use LK3D.SetObjectAnimPlay()", LK3D_SEVERITY_WARN, "LK3D")
	LK3D.SetObjectAnimPlay(index, bool)
end

function LK3D.SetModelAnimDelta(index, delta)
	LK3D.New_D_Print("Using deprecated function LK3D.SetModelAnimDelta(), use LK3D.SetObjectAnimDelta()", LK3D_SEVERITY_WARN, "LK3D")
	LK3D.SetObjectAnimDelta(index, delta)
end

function LK3D.GetModelAnimDelta(index)
	LK3D.New_D_Print("Using deprecated function LK3D.GetModelAnimDelta(), use LK3D.GetObjectAnimDelta()", LK3D_SEVERITY_WARN, "LK3D")
	LK3D.GetObjectAnimDelta(index)
end
