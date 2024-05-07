LK3D = LK3D or {}
LK3D.Radiosa = LK3D.Radiosa or {}

--[[
    LK3D Radiosa
    (LK3D Radiosity-Based Lightmapping system)


    Coded by lokachop @@ ages ago
    Hugely based on the hugo elias radiosity, https://www.jmeiners.com/Hugo-Elias-Radiosity/
]]--
include("lk3d_radiosa_consts.lua")
include("lk3d_radiosa_utils.lua")

include("lk3d_radiosa_uv_pack.lua")
include("lk3d_radiosa_uv_unwrap.lua")
include("lk3d_radiosa_patches.lua")

-- Solver to use, only 1 at once!
LK3D.Radiosa.SOLVER = include("solvers/lk3d_radiosa_solver_radiosity.lua")
--LK3D.Radiosa.SOLVER = include("solvers/lk3d_radiosa_solver_light_at_pos.lua")

include("lk3d_radiosa_step.lua") -- This file should contain the bulk for how it operates


function LK3D.MarkForLightmapping(objectID)

end

function LK3D.CommitLightmapping()

end
