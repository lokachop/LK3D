LK3D = LK3D or {}
LK3D.Radiosa = LK3D.Radiosa or {}

-- Handles patches in Radiosa

-- Creates a new patch struct
function LK3D.Radiosa.NewPatch()
    local patch = {
        pos =  Vector(0, 0, 0),
        norm = Vector(0, 1, 0),
        reflectivity = {1, 1, 1},
        emmision = {0, 0, 0},
    }

    return patch
end

function LK3D.Radiosa.SetPatchPosition(patch, pos)
    patch.pos = pos or patch.pos
end

function LK3D.Radiosa.SetPatchNormal(patch, norm)
    patch.norm = norm or patch.norm
end

function LK3D.Radiosa.SetPatchReflectivity(patch, reflectivity)
    patch.reflectivity = reflectivity or patch.reflectivity
end

function LK3D.Radiosa.SetPatchEmmision(patch, emission)
    patch.emission = emission or patch.emission
end

function LK3D.Radiosa.GetPatchPos(patch)
    return patch.pos
end

function LK3D.Radiosa.GetPatchNormal(patch)
    return patch.norm
end

function LK3D.Radiosa.GetPatchPosNormal(patch)
    return patch.pos, patch.norm
end

function LK3D.Radiosa.GetPatchReflectivity(patch)
    return patch.reflectivity
end

function LK3D.Radiosa.GetPatchEmmision(patch)
    return patch.emmision
end