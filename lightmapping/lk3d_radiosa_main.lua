--[[--
## Lightmapping / Radiosity
---

Module that generates calculates lightmaps on objects using radiosity  
Rewritten from scratch again, major issues solved and speed increased  
Docs for this are currently unfinished!  
This module is basically a GLua implementation of [this radiosity article](https://www.jmeiners.com/Hugo-Elias-Radiosity/)  
[Reading the manual entry on the lightmapper is recommended!](../manual/lightmapper-radiosity.md.html)
]]
-- @module lightmapping
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

include("lk3d_radiosa_ftrace.lua") -- FastTrace, fast*er* tracing library for static scenes

include("lk3d_radiosa_patches.lua")
include("lk3d_radiosa_trilut_genner.lua")

include("lk3d_radiosa_io.lua") -- Handles input / output (Loading / exporting lightmaps)

include("lk3d_radiosa_solver_handle.lua") -- This file should contain the bulk for how it operates

-- Solver to use, only 1 at once!
--LK3D.Radiosa.SOLVER = include("solvers/lk3d_radiosa_solver_radiosity.lua")
--LK3D.Radiosa.SOLVER = include("solvers/lk3d_radiosa_solver_light_at_pos.lua")
--LK3D.Radiosa.SOLVER = include("solvers/lk3d_radiosa_solver_ao.lua")
LK3D.Radiosa.SOLVER = include("solvers/lk3d_radiosa_solver_radiosity.lua")




local objectsMarkedForLightmap = {}
--- Marks an object to be lightmapped  
-- @usage LK3D.MarkForLightmapping("corn_box_a")
function LK3D.MarkForLightmapping(objectID)
    objectsMarkedForLightmap[objectID] = true
end

--- Clears the list of objects to be lightmapped  
-- @usage LK3D.Radiosa.ClearLightmapMarkedObjects()
function LK3D.Radiosa.ClearLightmapMarkedObjects()
    objectsMarkedForLightmap = {}
end

--- Returns the list of objects to be lightmapped  
-- @usage LK3D.Radiosa.GetLightmapMarkedObjects()
function LK3D.Radiosa.GetLightmapMarkedObjects()
    return objectsMarkedForLightmap
end

--- Runs the lightmapper  
-- @warning This function is horribly slow!
-- @usage -- mark a few things to lightmap
-- LK3D.MarkForLightmapping("sub_lower")
-- LK3D.MarkForLightmapping("sub_stairs")
-- LK3D.MarkForLightmapping("sub_upper")
-- LK3D.MarkForLightmapping("sub_engine")
-- 
-- -- now run the lightmapper
-- LK3D.CommitLightmapping()
function LK3D.CommitLightmapping()
    LK3D.Radiosa.BeginLightmapping()
end
