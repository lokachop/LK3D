LK3D = LK3D or {}

-- helper lk3d module for "skeletal" models
-- these are really a bunch of different models being translated cleverly
-- horribly optimized TODO: optimize!

LK3D.SkeletalOriginLUT = {}

function LK3D.DeclareSkeletalOriginPos(mdlname, pos)
    LK3D.SkeletalOriginLUT[mdlname] = pos
end




local function make_bone_obj(data)
    return {
        idx = data.idx,
        parent = data.parent,
        pos = data.pos * 1,
        end_pos = data.end_pos * 1,
        ang = Angle(data.ang),
        children = {}
    }
end

local function recursive_bone_insert(data, bone, transform_pointers)
    for k, v in ipairs(data) do
        if v.idx == bone.parent then
            local bone_object = make_bone_obj(bone)
            v.children[#v.children + 1] = bone_object
            transform_pointers[bone.idx] = bone_object
            return true
        else
            local ret = recursive_bone_insert(v.children, bone, transform_pointers)
            if ret then
                return true
            end
        end
    end
end

-- creates a skeletal model
function LK3D.DeclareSkeleton(object, data)
    local obj_ptr = LK3D.CurrUniv["objects"][object]
    if not obj_ptr then
        return
    end

    -- build the tree
    local tree_gen = {}
    local transform_pointers = {}
    for k, v in ipairs(data) do
        if v.parent == -1 then
            local bone_object = make_bone_obj(v)
            tree_gen[#tree_gen + 1] = bone_object
            transform_pointers[v.idx] = bone_object
        else
            -- search the tree and insert it in
            recursive_bone_insert(tree_gen, make_bone_obj(v), transform_pointers)
        end
    end

    obj_ptr.skeleton = tree_gen
    obj_ptr.skeleton_transforms = transform_pointers
    obj_ptr.parented_obj_ids = {}
    obj_ptr.calc_bones = {}

    obj_ptr.skeleton_anim_rate = 1
    obj_ptr.skeleton_anim_interval = 0.0
    obj_ptr.skeleton_anims = {}

    return transform_pointers
end


function LK3D.AddSkeletonParentedObject(object, otherobj, boneparent)

    if not boneparent then
        return
    end

    local obj_ptr = LK3D.CurrUniv["objects"][object]
    if not obj_ptr then
        return
    end

    if not obj_ptr.skeleton then
        return
    end

    local other_obj_ptr = LK3D.CurrUniv["objects"][otherobj]
    if not other_obj_ptr then
        return
    end

    if not obj_ptr.parented_obj_ids then
        obj_ptr.parented_obj_ids = {}
    end

    local parented_ids = obj_ptr.parented_obj_ids


    if not parented_ids[boneparent] then
        parented_ids[boneparent] = {}
    end

    local parented_bp = parented_ids[boneparent]

    parented_bp[#parented_bp + 1] = otherobj
end

-- removes a whole skeleton (base object + parented objects)
function LK3D.RemoveSkeletonObject(object)
    if not object then
        return
    end

    local obj_ptr = LK3D.CurrUniv["objects"][object]
    if not obj_ptr then
        return
    end

    if not obj_ptr.parented_obj_ids then
        return
    end

    for k, v in pairs(obj_ptr.parented_obj_ids) do
        if LK3D.CurrUniv["objects"][v] then
            LK3D.RemoveObjectFromUniverse(v)
        end
    end

    LK3D.RemoveObjectFromUniverse(object)
end

function LK3D.DeclareSkeletonAnim(object, anim, func)
    if not func then
        return
    end

    local obj_ptr = LK3D.CurrUniv["objects"][object]
    if not obj_ptr then
        return
    end

    obj_ptr.skeleton_anims[anim] = func
end

function LK3D.SetSkeletonAnim(object, targetanim)
    if not targetanim then
        return
    end

    local obj_ptr = LK3D.CurrUniv["objects"][object]
    if not obj_ptr then
        return
    end

    obj_ptr.skeleton_curr_anim = targetanim
end


function LK3D.SetSkeletonAnimPlayRate(object, rate)
    if not rate then
        return
    end

    local obj_ptr = LK3D.CurrUniv["objects"][object]
    if not obj_ptr then
        return
    end

    obj_ptr.skeleton_anim_rate = rate
end

-- because recalculating matrices is slow
function LK3D.SetSkeletonUpdateInterval(object, interval)
    if not interval then
        return
    end

    local obj_ptr = LK3D.CurrUniv["objects"][object]
    if not obj_ptr then
        return
    end



    obj_ptr.skeleton_anim_interval = interval
end


local function recursive_recalculate_bones(bones, object, l_matrix)
    for k, v in ipairs(bones) do
        local l_mtrx_cpy = Matrix(l_matrix)

        local real_matrix = Matrix(l_matrix)
        real_matrix:Translate(v.pos)

        object.calc_bones[v.idx] = real_matrix

        if #v.children ~= 0 then
            l_mtrx_cpy:Translate(v.pos)
            l_mtrx_cpy:Translate(v.end_pos)
            l_mtrx_cpy:Rotate(v.ang)
            recursive_recalculate_bones(v.children, object, l_mtrx_cpy)
        end
    end
end


local function object_update_bone_objects(object)
    if CurTime() < (object.next_calculate or 0) then
        return
    end
    object.next_calculate = CurTime() + object.skeleton_anim_interval

    if (not object["NO_VW_CULLING"]) and ((object.pos - LK3D.CamPos):Dot(LK3D.CamAng:Forward()) > 0) then
        recursive_recalculate_bones(object.skeleton, object, Matrix())
    end


    if not object.parented_obj_ids then
        return
    end

    local matrix_obj = Matrix()
    matrix_obj:SetTranslation(object.pos)
    matrix_obj:SetAngles(object.ang)


    for k, v in pairs(object.parented_obj_ids) do
        local count = #v
        if count == 0 then
            continue
        end

        for i = 1, count do
            local obj_idex = v[i]
            local obj_ptr = LK3D.CurrUniv["objects"][obj_idex]


            local b_calc_idx = (Matrix(object.calc_bones[k]) or Matrix()) -- matrix
            b_calc_idx:Rotate(obj_ptr.bone_ang) -- war crime war crime
            b_calc_idx = matrix_obj * b_calc_idx


            --local world_p, world_a = LocalToWorld(b_calc_pos, b_calc_ang, object.pos, object.ang)


            LK3D.SetObjectPosAng(obj_idex, b_calc_idx:GetTranslation(), b_calc_idx:GetAngles())
        end
    end
end


function LK3D.UpdateSkeletons()
    for k, v in pairs(LK3D.CurrUniv["objects"]) do
        if v.skeleton then
            object_update_bone_objects(v)
        end
    end
end


-- debug
local lif = .01
local function recursive_render_children(bones, l_matrix)
    for k, v in ipairs(bones) do
        local l_mtrx_cpy = Matrix(l_matrix)

        -- translate with MATRIX
        local of_pos = l_mtrx_cpy * (v.pos * 1)
        local of_pos_end = l_mtrx_cpy * (v.pos + v.end_pos * 1)

        local real_angle = Matrix(l_mtrx_cpy)
        real_angle:Rotate(v.ang)
        real_angle = real_angle:GetAngles()

        LK3D.DebugUtils.Box(of_pos_end, Vector(.005, .005, .005), real_angle, lif, Color(0, 255, 0))

        --LK3D.DebugUtils.Cross(of_pos_end, .025, lif, Color(0, 0, 255))

        LK3D.DebugUtils.Line(of_pos, of_pos_end, lif, Color(255, 0, 0))

        if #v.children ~= 0 then
            l_mtrx_cpy:Translate(v.pos)
            l_mtrx_cpy:Translate(v.end_pos)
            l_mtrx_cpy:Rotate(v.ang)
            recursive_render_children(v.children, l_mtrx_cpy)
        end
    end
end


function LK3D.RenderSkeleton(object)
    if not LK3D.Debug then
        return
    end

    local obj_ptr = LK3D.CurrUniv["objects"][object]
    if not obj_ptr then
        return
    end

    if not obj_ptr.skeleton then
        return
    end

    local tree = obj_ptr.skeleton
    local mat_mv = Matrix()
    mat_mv:SetTranslation(obj_ptr.pos)
    mat_mv:SetAngles(obj_ptr.ang)

    recursive_render_children(tree, mat_mv)
end