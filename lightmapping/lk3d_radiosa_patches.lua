LK3D = LK3D or {}
LK3D.Radiosa = LK3D.Radiosa or {}
-- Handles patches in Radiosa

local patchRegistry = {}
local lastID = 0
function LK3D.Radiosa.AddPatchToRegistry(patch)
    lastID = lastID + 1
    patchRegistry[lastID] = patch
    return lastID
end

function LK3D.Radiosa.GetPatchFromRegistry(index)
    return patchRegistry[index]
end

function LK3D.Radiosa.ClearPatchRegistry()
    patchRegistry = {}
    lastID = 0
end


-- Creates a new patch struct
function LK3D.Radiosa.NewPatch()
    local patch = {
        pos =  Vector(0, 0, 0),
        norm = Vector(0, 1, 0),
        reflectivity = {1, 1, 1},
        emission = {0, 0, 0},
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

function LK3D.Radiosa.SetPatchEmission(patch, emission)
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

function LK3D.Radiosa.GetPatchEmission(patch)
    return patch.emission
end