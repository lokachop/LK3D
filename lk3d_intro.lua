LK3D = LK3D or {}
LK3D.IntroUniv = LK3D.NewUniverse("lk3d_uni_intro")
LK3D.IntroStart = CurTime()
local i_len = 1 -- 12
LK3D.IntroEnd = CurTime() + i_len

local rtRender_intro = GetRenderTarget("lk3d_introrender_" .. ScrW() .. "x" .. ScrH(), ScrW(), ScrH())


LK3D.PushUniverse(LK3D.IntroUniv)
    LK3D.AddModelToUniverse("plane_floor", "plane_hp")
    LK3D.SetModelPosAng("plane_floor", Vector(0, 0, 0), Angle(0, 0, 90))
    LK3D.SetModelFlag("plane_floor", "NO_SHADING", false)
    LK3D.SetModelFlag("plane_floor", "NO_LIGHTING", false)
    LK3D.SetModelFlag("plane_floor", "NO_VW_CULLING", true)
    LK3D.SetModelScale("plane_floor", Vector(6, 6, 6))
    LK3D.SetModelMat("plane_floor", "intro_plane")


    LK3D.AddModelToUniverse("cube_lightref", "cube_nuv")
    LK3D.SetModelFlag("cube_lightref", "NO_SHADING", true)
    LK3D.SetModelFlag("cube_lightref", "NO_LIGHTING", true)
    LK3D.SetModelMat("cube_lightref", "white")
    LK3D.SetModelScale("cube_lightref", Vector(.05, .05, .05))
    LK3D.SetModelCol("cube_lightref", Color(245, 240, 196))
    LK3D.SetModelFlag("cube_lightref", "CONSTANT", true)
    LK3D.SetModelPosAng("cube_lightref", Vector(0, 0, 1))

    LK3D.AddModelToUniverse("loka_test", "lokachop")
    LK3D.SetModelPosAng("loka_test", Vector(0, 0, 0), Angle(0, 90, 90))
    LK3D.SetModelFlag("loka_test", "NO_SHADING", false)
    LK3D.SetModelFlag("loka_test", "SHADING_SMOOTH", true)
    LK3D.SetModelFlag("loka_test", "SHADOW_VOLUME", true)
    --LK3D.SetModelFlag("loka_test", "SHADOW_ZPASS", true)
    LK3D.SetModelFlag("loka_test", "NO_LIGHTING", false)
    LK3D.SetModelScale("loka_test", Vector(.25, .25, .25))
    LK3D.SetModelMat("loka_test", "intro_loka1")

    LK3D.AddModelToUniverse("plane_face", "plane")
    LK3D.SetModelPosAng("plane_face", Vector(-.18, 0, .25), Angle(0, 90, 0))
    LK3D.SetModelFlag("plane_face", "NO_SHADING", true)
    LK3D.SetModelFlag("plane_face", "NO_LIGHTING", true)
    LK3D.SetModelScale("plane_face", Vector(.175, .175, .15))
    LK3D.SetModelMat("plane_face", "lokaface2")
    LK3D.SetModelHide("plane_face", true)
    LK3D.SetModelFlag("plane_face", "NO_TRACE", true)

    LK3D.AddModelToUniverse("plane_transp_paint", "plane")
    LK3D.SetModelPosAng("plane_transp_paint", Vector(-.1825, 0, .25), Angle(0, 90, 0))
    LK3D.SetModelFlag("plane_transp_paint", "NO_SHADING", true)
    LK3D.SetModelFlag("plane_transp_paint", "NO_LIGHTING", false)
    LK3D.SetModelScale("plane_transp_paint", Vector(.175, .175, .15))
    LK3D.SetModelMat("plane_transp_paint", "intro_paint_loka3")


    LK3D.AddModelToUniverse("plane_powered_by", "plane")
    LK3D.SetModelPosAng("plane_powered_by", Vector(2, -.8, .5), Angle(0, -110, 0))
    LK3D.SetModelFlag("plane_powered_by", "NO_SHADING", true)
    LK3D.SetModelFlag("plane_powered_by", "NO_LIGHTING", true)
    LK3D.SetModelFlag("plane_powered_by", "CONSTANT", true)
    LK3D.SetModelFlag("plane_powered_by", "NORM_INVERT", true)
    LK3D.SetModelScale("plane_powered_by", Vector(1, 1, 1))
    LK3D.SetModelMat("plane_powered_by", "intro_sign_powered2")

    --intro_sign_powered


    LK3D.AddModelToUniverse("cube_shadow1", "cube")
    LK3D.SetModelPosAng("cube_shadow1", Vector(-.2, .6, .15), Angle(0, -8, 90))
    LK3D.SetModelFlag("cube_shadow1", "NO_SHADING", false)
    LK3D.SetModelFlag("cube_shadow1", "SHADING_SMOOTH", true)
    LK3D.SetModelFlag("cube_shadow1", "SHADOW_VOLUME", true)
    --LK3D.SetModelFlag("cube_shadow1", "SHADOW_ZPASS", true)
    LK3D.SetModelFlag("cube_shadow1", "NO_LIGHTING", false)
    LK3D.SetModelScale("cube_shadow1", Vector(.15, .15, .15))
    LK3D.SetModelMat("cube_shadow1", "intro_box1")

    LK3D.AddLight("li_1", Vector(0, 0, 1), 1.75, Color(245, 240, 196), true)
LK3D.PopUniverse()



function LK3D.ResetIntroTimer()
    LK3D.IntroStart = CurTime()
    LK3D.IntroEnd = CurTime() + i_len
end



local sprtick = 0
local light_endpos = Vector(-1.2, .7, 1.2)

local function spray(pos, dir, col)
    LK3D.SetExpensiveTrace(true)
    LK3D.SetTraceReturnTable(true)

    local tdat = LK3D.TraceRayScene(pos, dir)
    if tdat.obj then
        local matnfo = LK3D.CurrUniv["objects"][tdat.obj].mat
        local uv = tdat.uv
        LK3D.UpdateTexture(matnfo, function()
            surface.SetDrawColor(col)
            local roff = 1
            for i = 1, 8 do
                local randx, randy = math.Rand(-roff, roff), math.Rand(-roff, roff)
                surface.DrawRect(uv[1] * ScrW() + (randx * 2), uv[2] * ScrH() + (randy * 2), 2, 2)
                sprtick = sprtick + 1
            end
        end)
    end
    LK3D.SetExpensiveTrace(false)
    LK3D.SetTraceReturnTable(false)
end


local function lerp_noclamp(t, from, to)
    return from * (1 - t) + to * t
end

local function lerpvector_noclamp(t, from, to)
    return Vector(
        lerp_noclamp(t, from[1], to[1]),
        lerp_noclamp(t, from[2], to[2]),
        lerp_noclamp(t, from[3], to[3])
    )
end


local cam_endPos = Vector(-1.6, 0.7, 0.95)
local cam_endAng = Angle(26.4, -25.6, 0)
function LK3D.RenderIntro()
    if CurTime() > LK3D.IntroEnd then
        return
    end

    local i_delta = 1 + ((CurTime() - LK3D.IntroEnd) / i_len)


    local prev_renderer = LK3D.ActiveRenderer
    LK3D.SetCamPos(cam_endPos)
    LK3D.SetCamAng(cam_endAng)

    LK3D.SetCamPos(LocalPlayer():EyePos() / 100)
    LK3D.SetCamAng(LocalPlayer():EyeAngles())

    LK3D.SetRenderer(LK3D.Const.RENDER_HARD)
    LK3D.PushRenderTarget(rtRender_intro)
    LK3D.PushUniverse(LK3D.IntroUniv)
        LK3D.RenderClear(12, 12, 16)
        --LK3D.RenderClear(0, 0, 0)


        if input.IsMouseDown(MOUSE_LEFT) then
            local c_c = HSVToColor(sprtick / 16, 1, 1)
            c_c.a = 96
            spray(LocalPlayer():EyePos() / 100, LocalPlayer():EyeAngles():Forward(), c_c)
        end


        local frac_start = .3
        local li_delta = math.min(math.max(i_delta - frac_start, 0) * (1 / frac_start), 1)

        local lip = Vector(math.sin(i_delta * math.pi * 4), math.cos(i_delta * math.pi * 6), 1 + (math.sin(i_delta * math.pi * 14) * .25))
        lip = LerpVector(math.ease.InOutCubic(li_delta), lip, light_endpos)


        LK3D.UpdateLightPos("li_1", lip)
        LK3D.SetModelPos("cube_lightref", lip)
        LK3D.UpdateLightIntensity("li_1", Lerp(li_delta, 1.75, 2.2))


        local sip = lerpvector_noclamp(math.ease.OutBounce(li_delta), Vector(2, -.8, 3), Vector(2, -.8, .5))
        LK3D.SetModelPos("plane_powered_by", sip)


        LK3D.RenderActiveUniverse()
        LK3D.RenderObject("plane_face") -- avoid shadow
    LK3D.PopUniverse()
    LK3D.PopRenderTarget()
    LK3D.SetRenderer(prev_renderer)

    cam.Start2D()
    render.DrawTextureToScreen(rtRender_intro)
    cam.End2D()
end