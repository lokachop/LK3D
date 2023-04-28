LK3D = LK3D or {}
--[[
    LK3D File parser

    Coded by Lokachop

    loads luafiles with custom macros for easier optimized coding

    scrapped LOL
]]--


local macroList = {
    ["declareExchangeFunc"] = function()

    end,
    ["exchangeFunc"] = function()

    end
}



local exchange_genned_funcs = {}

-- loads a file with macros
function LK3D.LoadMacroFile(path_w_lua)
    local path_targ = "deepdive/gamemode/" .. path_w_lua
    print("LOAD PATH; " .. path_w_lua)

    if not file.Exists(path_targ, "LUA") then
        print("Doesnt exist!")
        return
    end

    local f_read = file.Read(path_targ, "LUA")
    if not f_read then
        print("Doesnt read!")
        return
    end

    -- parse all the macros....
    -- macros are stored in comments so lets parse first the multilines which are usually function declarations
    for content in string.gmatch(f_read, "-+%[+([%c%s%w%p]+)]+-+") do
        print(content)
    end
end