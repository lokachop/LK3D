LK3D = LK3D or {}
LK3D.Radiosa = LK3D.Radiosa or {}
-- Calculates lighting via the LK3D.GetLightIntensity()
local solver = {}

function solver.PreProcess()
end

function solver.CalculateValue(patch, pos, norm) -- return table colour {1, 1, 1}
    local intR, intG, intB = LK3D.GetLightIntensity(pos, norm)

    return {intR, intG, intB}
end


return solver