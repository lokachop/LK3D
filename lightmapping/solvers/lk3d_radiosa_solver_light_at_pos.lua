LK3D = LK3D or {}
LK3D.Radiosa = LK3D.Radiosa or {}
-- Calculates lighting via the LK3D.GetLightIntensity()
local solver = {}

-- This gets called constantly, return true when done preprocessing!
function solver.PreProcess()
    return true
end

-- Return RGB struct, 0-255
function solver.CalculateValue(patch, pos, norm) -- return table colour {1, 1, 1}
    local intR, intG, intB = LK3D.GetLightIntensity(pos, norm)

    return {intR * 255, intG * 255, intB * 255}
end


return solver