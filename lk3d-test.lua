include("lk3d.lua")
LK3D.DeclareTextureFromMatObj("grid_test", 64, 64, Material("gui/alpha_grid.png", "nocull ignorez noclamp"))
LK3D.DeclareTextureFromMatObj("rgbtest", 256, 256, Material("gui/colors_dark.png", "nocull ignorez noclamp"))
LK3D.DeclareTextureFromSourceMat("metal_sub", 128, 128, "metal/metalhull003a")
LK3D.DeclareTextureFromSourceMat("water_bad", 256, 256, "dev/dev_glassfrosted01a")
LK3D.DeclareTextureFromSourceMat("water_bad_2", 256, 256, "nature/toxicslime002a")
LK3D.DeclareTextureFromFunc("ScreenCopy", 800, 600, function() end)
LK3D.DeclareTextureFromFunc("rainbow", 128, 128, function() end)


local rtRender = GetRenderTarget("testlk3d_0", 800, 600)
local rtCamera = GetRenderTarget("lk3dtest7", 256, 256)

LK3D.AddModelToUniverse("train1", "train")
LK3D.SetModelMat("train1", "metal_sub")
LK3D.SetModelAng("train1", Angle(0, -90, 90))


LK3D.AddModelToUniverse("cube1", "cube")
LK3D.SetModelPos("cube1", Vector(4, 0, 0))
LK3D.SetModelCol("cube1", Color(255, 0, 0))
LK3D.SetModelScale("cube1", Vector(1, 1, 1))


LK3D.AddModelToUniverse("origin1", "origin")
LK3D.SetModelPos("origin1", Vector(-4, 8, 0))
LK3D.SetModelMat("origin1", "rgbtest")
LK3D.SetModelScale("origin1", Vector(1, 1, 1))
LK3D.SetModelAng("origin1", Angle(0, 0, 0))



LK3D.AddModelToUniverse("cube2", "cube")
LK3D.SetModelPos("cube2", Vector(4, 4, 0))
LK3D.SetModelMat("cube2", "rgbtest")
LK3D.SetModelScale("cube2", Vector(1, 1, 1))
LK3D.SetModelAng("cube2", Angle(45, 0, 0))

LK3D.AddModelToUniverse("plane1", "plane")
LK3D.SetModelPos("plane1", Vector(0, 0, 4))
LK3D.SetModelAng("plane1", Angle(0, -90, 0))
LK3D.SetModelScale("plane1", Vector(1, 1, 1))
LK3D.SetModelMat("plane1", "ScreenCopy")

LK3D.AddModelToUniverse("camera", "train")
LK3D.SetModelScale("camera", Vector(0.25, 0.25, 0.5))

LK3D.AddModelToUniverse("plane2", "plane")
LK3D.SetModelPos("plane2", Vector(0, 4, 0))
LK3D.SetModelAng("plane2", Angle(0, 0, 0))
LK3D.SetModelMat("plane2", "rgbtest")

LK3D.AddModelToUniverse("ocean", "plane_hp")
LK3D.SetModelPos("ocean", Vector(0, 0, -4))
LK3D.SetModelAng("ocean", Angle(0, -90, 90))
LK3D.SetModelScale("ocean", Vector(32, 32, 32))
LK3D.SetModelCol("ocean", Color(255, 0, 0))
LK3D.SetModelMat("ocean", "water_bad_2")


-- vert shader syntax
LK3D.SetModelFlag("ocean", "VERT_SHADER", function(vpos, vuv)
    --local vid = LK3D.SHADER_VERTID
    --uvs are table with no keys (ex. {1, 0} is u = 1 v = 0)
    local t_var = CurTime() * .25

    local xc = math.sin((vpos.x * 48) + t_var * 6) / 32
    local zc = math.sin((vpos.z * 64) + (t_var + 2.12) * 4) / 32

    vuv[1] = vuv[1] - (zc * .5)
    vuv[2] = vuv[2] + (xc * .5)

    vpos:Add(Vector(0, xc + zc, zc))
end)

--[[
LK3D.AddModelToUniverse("plane_vsh", "plane_hp")
LK3D.SetModelPos("plane_vsh", Vector(0, 0, 12))
LK3D.SetModelAng("plane_vsh", Angle(0, -90, 90))
LK3D.SetModelScale("plane_vsh", Vector(1, 1, 1))
LK3D.SetModelCol("plane_vsh", Color(255, 255, 255))
LK3D.SetModelMat("plane_vsh", "rainbow")

LK3D.SetModelFlag("plane_vsh", "VERT_SHADER", function(vpos, vuv)
    local zpos = math.sin(vpos.z + CurTime() * 2)


    vpos:Rotate(Angle(zpos * 25, zpos * 45, zpos * 12))
end)
]]--


local function updateLK3DRenders()
    -- render to main RT
    LK3D.RenderClear(100, 25, 25)
    LK3D.SetWireFrame(false)

    LK3D.SetCamPos(LocalPlayer():EyePos() / 120)
    LK3D.SetCamAng(LocalPlayer():EyeAngles())

    LK3D.SetModelAng("cube1", Angle(CurTime() * 90, CurTime() * 45, 0))
    LK3D.SetModelAng("cube2", Angle(math.sin(CurTime() * 2) * 45, 0, 0))


    local vm = CurTime() * 64
    local pc = Vector(math.sin(math.rad(vm)) * 4, math.cos(math.rad(vm)) * 4, 3)
    local ac = Angle(0, -vm - 90, 0)
    LK3D.SetModelPos("camera", pc)
    LK3D.SetModelAng("camera", ac + Angle(0, -90, 90))


    LK3D.RenderActiveUniverse()

    LK3D.SetRenderer(LK3D_RENDER_HARD)
    LK3D.PushRenderTarget(rtCamera)
        LK3D.RenderClear(25, 25, 100)

        LK3D.SetModelHide("camera", true)
        LK3D.SetCamPos(pc)
        LK3D.SetCamAng(ac)

        LK3D.RenderActiveUniverse()
    LK3D.PopRenderTarget()

    LK3D.SetModelHide("camera", false)

    -- render to a diff RT
    LK3D.PushRenderTarget(rtRender)

    -- move shit to a diff universe so we dont have objects from default universe

    -- hardware renderer
    LK3D.SetRenderer(LK3D_RENDER_HARD)

    --LK3D.PushUniverse(universe)
    LK3D.RenderClear(25, 100, 25)

    LK3D.SetCamPos(LocalPlayer():EyePos() / 120)
    LK3D.SetCamAng(LocalPlayer():EyeAngles())

    LK3D.RenderActiveUniverse()

    --LK3D.PopUniverse()
    LK3D.PopRenderTarget()

    -- back to software
    LK3D.SetRenderer(LK3D_RENDER_SOFT)

    LK3D.UpdateTexture("ScreenCopy", function()
        local rtmat = LK3D.RTToMaterial(rtCamera)
        render.PushFilterMag(LK3D.FilterMode)
        render.PushFilterMin(LK3D.FilterMode)
            render.DrawTextureToScreen(rtmat:GetTexture("$basetexture"))
        render.PopFilterMag()
        render.PopFilterMin()
    end)


    LK3D.UpdateTexture("rainbow", function()
        local div = 2

        for i = 0, ScrW() / div do
            surface.SetDrawColor(HSVToColor((i / (ScrW() / div)) * 360 + (CurTime() * 256), 1, 1))
            surface.DrawRect(i * div, 0, div, ScrW())
        end
    end)
end


LK3D.SetFOV(90)
local nextFrame = CurTime()
hook.Add("HUDPaint", "lk3d_test", function()
    if CurTime() > nextFrame then
        updateLK3DRenders()
        --nextFrame = CurTime() + LK3D.ScreenWait
    end

    -- lets now draw the canvases
    surface.SetDrawColor(255, 255, 255, 255) -- reset the colour
    render.PushFilterMag(LK3D.FilterMode)
    render.PushFilterMin(LK3D.FilterMode)


    -- this is cached so its fast
    local mat1 = LK3D.RTToMaterial(LK3D.Const.DEF_RT) -- default RT constant
    surface.SetMaterial(mat1)

    surface.DrawTexturedRect(0, 0, 800, 600) -- default RT is 800 x 600


    local mat2 = LK3D.RTToMaterial(rtRender) -- our own RT
    surface.SetMaterial(mat2)
    --                        10px margin
    surface.DrawTexturedRect(810, 0, 800, 600) -- we know our RT is 800 x 600 cuz we made it
    render.PopFilterMag()
    render.PopFilterMin()

    LK3D.SetWireFrame(false)
end)