LK3D = LK3D or {}

-- allows dumping lk3d nfo

-- returns a str with the dump
-- this contains info about the current call
function LK3D.GetDump()
    local t_concat = {}
    t_concat[#t_concat + 1] = "--==LK3D DUMP==--"
    local nice_t_str = os.date("%d/%m/%y %H:%M:%S")

    t_concat[#t_concat + 1] = "@@ " .. nice_t_str
    t_concat[#t_concat + 1] = ""
    t_concat[#t_concat + 1] = "LK3D Ver.        : " .. (LK3D.Version or "UNKNOWN??")

    local memcount = collectgarbage("count")
    t_concat[#t_concat + 1] = "Mem Usage        : " .. math.Round(memcount, 3) .. "kb (" .. math.Round(memcount / 1024, 3) .. "mb)"

    local cam_p = LK3D.CamPos
    local cam_a = LK3D.CamAng

    t_concat[#t_concat + 1] = "CamPos           : " .. "Vector(" .. cam_p.x .. ", " .. cam_p.y .. ", " .. cam_p.z .. ")"
    t_concat[#t_concat + 1] = "CamAng           : " .. "Angle(" .. cam_a.p .. ", " .. cam_a.y .. ", " .. cam_a.r .. ")"
    t_concat[#t_concat + 1] = "WireFrame        : " .. tostring(LK3D.WireFrame)
    t_concat[#t_concat + 1] = "FarZ             : " .. LK3D.FAR_Z
    t_concat[#t_concat + 1] = "NearZ            : " .. LK3D.NEAR_Z
    t_concat[#t_concat + 1] = "FOV              : " .. LK3D.FOV
    t_concat[#t_concat + 1] = "Ortho            : " .. tostring(LK3D.Ortho)
    t_concat[#t_concat + 1] = "FilterMode       : " .. tostring(LK3D.FilterMode)
    t_concat[#t_concat + 1] = "AmbientCol       : " .. tostring(LK3D.AmbientCol)
    t_concat[#t_concat + 1] = "SunDir           : " .. tostring(LK3D.SunDir)
    t_concat[#t_concat + 1] = "ShadowExtrude    : " .. tostring(LK3D.SHADOW_EXTRUDE)
    t_concat[#t_concat + 1] = "ExpensiveTrace   : " .. tostring(LK3D.DoExpensiveTrace)
    t_concat[#t_concat + 1] = "TraceRetTable    : " .. tostring(LK3D.TraceReturnTable)

    if #LK3D.UniverseStack > 0 then
        t_concat[#t_concat + 1] = "---- universe stack dump ----"
        for k, v in ipairs(LK3D.UniverseStack) do
            t_concat[#t_concat + 1] = "\t" .. tostring(k) .. ": " .. tostring(v)
        end
    end

    if #LK3D.RenderTargetStack > 0 then
        t_concat[#t_concat + 1] = "---- RT stack dump ----"
        for k, v in ipairs(LK3D.RenderTargetStack) do
            t_concat[#t_concat + 1] = "\t" .. tostring(k) .. ": " .. tostring(v)
        end
    end
    t_concat[#t_concat + 1] = "Renderer         : " .. tostring(LK3D.ActiveRenderer) .. " [" .. (LK3D.Renderers[LK3D.ActiveRenderer].PrettyName or "No fancyname") .. "]"

    t_concat[#t_concat + 1] = "---- curr univ stats ----"
    if LK3D.CurrUniv then
        t_concat[#t_concat + 1] = "Object Count     : " .. (LK3D.CurrUniv.objects and table.Count(LK3D.CurrUniv.objects) or "no objects")
        t_concat[#t_concat + 1] = "Light Count      : " .. (LK3D.CurrUniv.lightcount or "no lights")
        t_concat[#t_concat + 1] = "Light Count(func): " .. (LK3D.CurrUniv.lights and table.Count(LK3D.CurrUniv.lights) or "no lights")
        t_concat[#t_concat + 1] = "Particle emmiters: " .. (LK3D.CurrUniv.particles and table.Count(LK3D.CurrUniv.particles) or "no partemitters")
    end


    t_concat[#t_concat + 1] = "--==END LK3D DUMP==--"


    return table.concat(t_concat, "\n")
end


-- returns dump about the models
function LK3D.GetModelDump()
    local t_concat = {}

    t_concat[#t_concat + 1] = "Models           : " .. table.Count(LK3D.Models)
    t_concat[#t_concat + 1] = "---=begin modelist=---"

     for k, v in pairs(LK3D.Models) do
        t_concat[#t_concat + 1] = "" .. k
        t_concat[#t_concat + 1] = "\t" .. "verts  : " .. #v.verts
        t_concat[#t_concat + 1] = "\t" .. "uvs    : " .. #v.uvs
        t_concat[#t_concat + 1] = "\t" .. "indices: " .. #v.uvs
        t_concat[#t_concat + 1] = "\t\n"
    end
    t_concat[#t_concat + 1] = "---=end modelist=---"

    return table.concat(t_concat, "\n")
end


function LK3D.GetTexDump()
    local t_concat = {}

    t_concat[#t_concat + 1] = "Models           : " .. table.Count(LK3D.Models)
    t_concat[#t_concat + 1] = "---=begin texturelist=---"

    for k, v in pairs(LK3D.Textures) do
        t_concat[#t_concat + 1] = "" .. k .. " (" .. v.mat:Width() .. "x" .. v.mat:Height() .. ")"
    end
    t_concat[#t_concat + 1] = "---=end texturelist=---"

    return table.concat(t_concat, "\n")
end