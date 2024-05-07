LK3D = LK3D or {}
LK3D.Radiosa = LK3D.Radiosa or {}
-- The main solver, calculates lighting with radiosity algorithm
local solver = {}

function solver.PreProcess()
end

function solver.CalculateValue(patch, pos, norm)

    return {0, 0, 0} -- unimplemented
end


return solver