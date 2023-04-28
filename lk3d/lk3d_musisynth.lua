--[[
	LK3D MusiSynth

	coded by lokachop
	procedural music via software synth & bytebeat
]]--

LK3D = LK3D or {}
LK3D.MusiSynth = LK3D.MusiSynth or {}
function LK3D.MusiSynth.NewInstrument(len, rate)
	return {
		len = len or 1,
		sprate = rate or 11025,
		elems = {
		}
	}
end
function LK3D.MusiSynth.NewWaveList()
	return {}
end

function LK3D.MusiSynth.NewWave(typ_e, props)
	return {
		type = typ_e,
		offset = props.offset or 0,
		rate = props.rate or 440,
		vol = props.vol or 1,
		lowpass = props.lowpass,
		highpass = props.highpass,
		multiplicators = {},
		mixers = {},
		adsrs = {},
	}
end
function LK3D.MusiSynth.AddADSR(to, adsr, type)
	if not to.adsrs then
		to.adsrs = {}
	end
	adsr["type"] = type or "amp"
	to.adsrs[#to.adsrs + 1] = adsr
end



function LK3D.MusiSynth.AddMultiplicator(to, mult)
	if not to.multiplicators then
		return
	end
	to.multiplicators[#to.multiplicators + 1] = mult
end

function LK3D.MusiSynth.AddMixer(to, mixer)
	if not to.mixers then
		return
	end
	to.mixers[#to.mixers + 1] = mixer
end

function LK3D.MusiSynth.AddWave(to, wave)
	if not to.elems then
		return
	end
	to.elems[#to.elems + 1] = wave
end



-- http://www.vttoth.com/CMS/index.php/technical-notes/68
-- (a + b) - a * b * sign(a + b) -- found on some random reddit post
-- assumes samples are -1 to 1
local function sample_mix(vals)
	local final = vals[1]
	for i = 2, #vals do
		local cv = vals[i]
		final = (final + cv) - final * cv * (((final + cv) >= 0) and 1 or -1) -- sign
	end
	return final
end

local function tbl_avrg(tbl)
	local sum = 0
	for i = 1, #tbl do
		sum = sum + tbl[i]
	end
	return sum / #tbl
end

local calc_rand = {}
for i = 1, 32768 do -- 32k cached random
	calc_rand[i] = math.Rand(-1, 1)
end

local t_call_tbl = {
	["sine"] = function(t, e, vol, dat, rate)
		return math.sin((((t / dat.sprate) + e.offset) * math.pi) * rate) * vol
	end,
	["square"] = function(t, e, vol, dat, rate)
		return math.sin((((t / dat.sprate) + e.offset) * math.pi) * (rate * 2)) > 0 and vol or -vol
	end,
	["triangle"] = function(t, e, vol, dat, rate)
		return math.tan(math.sin((((t / dat.sprate) + e.offset) * math.pi) * (rate * 2))) * vol
	end,
	["saw"] = function(t, e, vol, dat, rate)
		return ((((((t * rate) % dat.sprate) / (dat.sprate / 2)) + e.offset) % 2) - 1) * vol
	end,
	["noise"] = function(t, e, vol, dat, rate)
		return calc_rand[math.floor((((t / 440) * rate) % dat.sprate) % 32768) + 1] * vol
	end,
	["smoothnoise"] = function(t, e, vol, dat, rate)
		local curr = math.floor((((t / 440) * rate) % dat.sprate) % 32768) + 1
		local vals = {}
		for i = 1, 6 do
			vals[#vals + 1] = calc_rand[((curr + i) % 32768) + 1]
		end


		return tbl_avrg(vals) * vol
	end
}

function LK3D.MusiSynth.AddWaveFunc(name, call)
	t_call_tbl[name] = call
end




local function calc_adsr(t, e, adsrdat)
	local stage = 1 -- start attack
	local adsr_dat = adsrdat

	local t_ret = t

	for i = 1, #adsr_dat do
		local lencurr = adsr_dat[i].len
		if t_ret > lencurr then
			t_ret = t_ret - lencurr
			stage = stage + 1
			continue
		else
			break
		end
	end

	local prev_adsr_info = adsr_dat[stage - 1] or (adsrdat["type"] == "amp" and {["val"] = e.vol} or {["val"] = 1})
	local curr_adsr_info = adsr_dat[stage]


	local adsr_delta = (t_ret / curr_adsr_info.len)
	local target = curr_adsr_info["val"]
	local prev = prev_adsr_info["val"]


	return Lerp(adsr_delta, prev, target)
end

local function samp_full_calc(t, data, e)
	local sec = t / data.sprate

	local vc = e.vol
	local rm = 1
	if e.adsrs then
		vc = 1
		for _, v in ipairs(e.adsrs) do
			if v["type"] == "amp" then
				vc = vc * calc_adsr(sec, e, v)
			end
			if v["type"] == "rate" then
				rm = rm * calc_adsr(sec, e, v)
			end
		end
	end

	return t_call_tbl[e.type](t, e, vc, data, e.rate * rm)
end

LK3D.MusiSynth.ExistingDatas = {}
function LK3D.MusiSynth.GenerateSoundData(data, name)
	local len = data.len
	local elements = data.elems

	local vals = {}
	local t_v = math.floor(CurTime())
	local prev_samples = {}
	sound.Generate("lk3d_ms_" .. name .. t_v, data.sprate, len, function(t)
		vals = {}
		for k, v in ipairs(elements) do
			if t_call_tbl[v.type] then
				local real_calc = samp_full_calc(t, data, v)

				for _, v2 in ipairs(v.multiplicators) do
					real_calc = real_calc * samp_full_calc(t, data, v2)
				end

				local tomix = {}
				for _, v2 in ipairs(v.mixers) do
					tomix[#tomix + 1] = samp_full_calc(t, data, v2)
				end

				if #tomix ~= 0 then
					real_calc = sample_mix(tomix)
				end

				local old_real = real_calc
				if (v.lowpass ~= nil) then
					local lpv = v.lowpass
					real_calc = (lpv * real_calc) + ((prev_samples[k] or 0) * (1 - lpv))
				end

				if (v.highpass ~= nil) then
					local hpv = v.highpass
					real_calc = (hpv * real_calc) - ((prev_samples[k] or 0) * (1 - hpv))
				end

				prev_samples[k] = old_real
				vals[#vals + 1] = real_calc
			end
		end

		local sm = sample_mix(vals)
		return sm
	end)

	LK3D.MusiSynth.ExistingDatas[name] = "lk3d_ms_" .. name .. t_v
end

LK3D.MusiSynth.ExistingPitches = {}
function LK3D.MusiSynth.GenerateSoundScript(data, name, pitch)
	if not LK3D.MusiSynth.ExistingDatas[name] then
		LK3D.MusiSynth.GenerateSoundData(data, name)
	end
	pitch = math.floor(pitch * 10) / 10

	LK3D.MusiSynth.ExistingPitches[name] = LK3D.MusiSynth.ExistingPitches[name] or {}
	sound.Add({
		name = "lk3d_musisynth_" .. name .. "_p_" .. pitch,
		channel = CHAN_AUTO,
		volume = 1,
		pitch = pitch,
		sound = LK3D.MusiSynth.ExistingDatas[name],
	})

	LK3D.MusiSynth.ExistingPitches[name][pitch] = true
end


LK3D.MusiSynth.ValidInstruments = {}
-- 0-255 with 1 decimal autogen
function LK3D.MusiSynth.DeclareInstrument(data, name)
	for i = 1, 255, .1 do
		LK3D.MusiSynth.GenerateSoundScript(data, name, i)
	end

	LK3D.New_D_Print("Declared instrument \"" .. name .. "\"", 2, "MusiSynth")
	LK3D.MusiSynth.ValidInstruments[name] = true
end

function LK3D.MusiSynth.PlayInstrument(name, pitch)
	local c_pitch = math.max(math.min(math.floor(pitch * 10) / 10, 254), 1)
	local id = "lk3d_musisynth_" .. name .. "_p_" .. c_pitch
	--surface.PlaySound(id)
	LocalPlayer():EmitSound(id, 0, 100, 1, CHAN_STATIC, SND_NOFLAGS, 0)
	--sound.Play(id, Vector(0, 0, 0), 75, 100, 1)
end

local instr_digisnare = LK3D.MusiSynth.NewInstrument(.3)
local wavedsnare = LK3D.MusiSynth.NewWave("smoothnoise", {
	rate = 220,
	vol = 2,
	--lowpass = .5,
	highpass = .5
})

-- quick adsr reminder for whoever reads this
-- https://kronoslang.io/resources/code-examples/unit-generators/adsr-envelope
--
--\/attack   
--     /\ <- delay
--    /  \         \/sustain
--   /    \___________________
--  /                         \ release
-- /                           \
LK3D.MusiSynth.AddADSR(wavedsnare, {
	{len = .3, val = 0}, -- attack
	{len = 0, val = 0}, -- delay
	{len = 0, val = 0}, -- sustain
	{len = 0, val = 0}, -- release
})

LK3D.MusiSynth.AddWave(instr_digisnare, wavedsnare)



local instr_flute = LK3D.MusiSynth.NewInstrument(1.5)
local waveflute = LK3D.MusiSynth.NewWave("sine", {
	rate = 1100,
	vol = 0,
	--lowpass = .5,
	--highpass = .5
})
LK3D.MusiSynth.AddADSR(waveflute, {
	{len = .125, val = .35}, -- attack
	{len = 1.375, val = 0}, -- delay
	{len = 5.25, val = 0}, -- sustain
	{len = .5, val = 0}, -- release
})

local wave_flute_add = LK3D.MusiSynth.NewWave("sine", {
	rate = 120,
	vol = 1,
	--lowpass = .5,
	--highpass = .5
})
LK3D.MusiSynth.AddMultiplicator(waveflute, wave_flute_add)
LK3D.MusiSynth.AddWave(instr_flute, waveflute)


local instr_4 = LK3D.MusiSynth.NewInstrument(.35)
local wave4 = LK3D.MusiSynth.NewWave("smoothnoise", {
	rate = 1100,
	vol = 0,
	--lowpass = .5,
	--highpass = .5
})
LK3D.MusiSynth.AddADSR(wave4, {
	{len = .35, val = .35}, -- attack
	{len = .35, val = 0}, -- delay
	{len = .25, val = 0}, -- sustain
	{len = .5, val = 0}, -- release
})
LK3D.MusiSynth.AddADSR(wave4, {
	{len = .35, val = 1.25}, -- attack
	{len = .35, val = 1}, -- delay
	{len = .25, val = 1}, -- sustain
	{len = .5, val = 1}, -- release
}, "rate")

LK3D.MusiSynth.AddWave(instr_4, wave4)

LK3D.MusiSynth.DeclareInstrument(instr_digisnare, "digisnare")
LK3D.MusiSynth.DeclareInstrument(instr_flute, "flute")
LK3D.MusiSynth.DeclareInstrument(instr_4, "weird")



local instr_drumsnare = LK3D.MusiSynth.NewInstrument(0.5)

local wave_ns = LK3D.MusiSynth.NewWave("smoothnoise", {
	rate = 1200,
	vol = 0,
	lowpass = .5,
	--highpass = .5
})
LK3D.MusiSynth.AddADSR(wave_ns, {
	{len = .01, val = 0}, -- attack
	{len = .0, val = 1}, -- delay
	{len = .15, val = 0}, -- sustain
	{len = .5, val = 0}, -- release
})


LK3D.MusiSynth.AddWave(instr_drumsnare, wave_ns)
LK3D.MusiSynth.DeclareInstrument(instr_drumsnare, "snare")





LK3D.MusiSynth.AddWaveFunc("hihat_long", function(t, e, vol, dat, rate)
	local time = t / dat.sprate
	local curr = math.floor((((t / 440) * rate) % dat.sprate) % 32768) + 1

	local vals = {}
	for i = 1, 6 do
		vals[#vals + 1] = calc_rand[((curr + i) % 32768) + 1]
	end

	return tbl_avrg(vals) * math.pow(1 - ((time * 4) % 1), 4)
end)

local instr_hihat = LK3D.MusiSynth.NewInstrument(12.3, 44100)
local wave_hihat = LK3D.MusiSynth.NewWave("hihat_long", {
	rate = 440,
	vol = 1,
	--lowpass = .5,
	--highpass = .5
})
LK3D.MusiSynth.AddWave(instr_hihat, wave_hihat)
LK3D.MusiSynth.DeclareInstrument(instr_hihat, "hihat_long")


--timer.Simple(1, function()
--	LK3D.MusiSynth.PlayInstrument("sonar_test", 100)
--end)


-- gui section
LK3D.MusiSynth.Editor = {}
LK3D.MusiSynth.Editor.Bcol = Color(34, 38, 40)
LK3D.MusiSynth.Editor.BDcol = Color(28, 31, 32)
LK3D.MusiSynth.Editor.BDDcol = Color(21, 23, 24)
LK3D.MusiSynth.Editor.BElmcol = Color(30, 34, 36)

LK3D.MusiSynth.Editor.Wcol = Color(25, 27, 29)
LK3D.MusiSynth.Editor.BGcol = Color(65, 75, 85)
LK3D.MusiSynth.Editor.BGDarkcol = Color(38, 44, 49)
LK3D.MusiSynth.Editor.TBcol = Color(35, 34, 40)


LK3D.MusiSynth.Editor.CurrFile = "None"
LK3D.MusiSynth.Editor.ValidElements = {}
LK3D.MusiSynth.Editor.Elements = {}
LK3D.MusiSynth.Editor.RenderOffset = Vector(0, 0)

local iconMats = {}
local function buttonPaint(s, w, h)
	local ogc = s:GetTextColor()
	local col = Color(ogc.r, ogc.g, ogc.b, 255)

	if s:IsDown() then
		col.r = col.r * 1.5
		col.g = col.g * 1.5
		col.b = col.b * 1.5
	end


	surface.SetDrawColor(col)
	surface.DrawRect(0, 0, w, h)

	local icon = s:GetImage()
	if not iconMats[icon] then
		iconMats[icon] = Material(icon, "ignorez nocull")
	end
	surface.SetMaterial(iconMats[icon])
	surface.SetDrawColor(255, 255, 255)
	surface.DrawTexturedRect(0, 0, h, h)

	col.r = col.r * 2.2
	col.g = col.g * 2.2
	col.b = col.b * 2.2

	draw.SimpleText(s:GetText(), "BudgetLabel", h, h / 2, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end

local function btn_place(e)
	e:DockMargin(4, 4, 0, 4)
	e:Dock(LEFT)
	e:SetImageVisible(false)
	e.Paint = buttonPaint
end

function LK3D.MusiSynth.Editor.MakeTopbar(tb)
	function tb:Paint(w, h)
		surface.SetDrawColor(LK3D.MusiSynth.Editor.TBcol)
		surface.DrawRect(0, 0, w, h)
	end
	local btnnew = vgui.Create("DImageButton", tb)
	btnnew:SetWidth(48)
	btnnew:SetText("New")
	btnnew:SetTextColor(Color(78, 141, 69, 0))
	btnnew:SetIcon("icon16/page_add.png")
	btn_place(btnnew)

	function btnnew:DoClick()
		LK3D.MusiSynth.Editor.CurrFile = "NewFile"
		LK3D.MusiSynth.Editor.Elements = {}
		LK3D.MusiSynth.Editor.RenderOffset = Vector(0, 0)
		LK3D.MusiSynth.Editor.Selected = nil
	end


	local btnopen = vgui.Create("DImageButton", tb)
	btnopen:SetWidth(48)
	btnopen:SetText("Open")
	btnopen:SetTextColor(Color(69, 76, 141, 0))
	btnopen:SetIcon("icon16/folder_page.png")
	btn_place(btnopen)


	local btnsave = vgui.Create("DImageButton", tb)
	btnsave:SetWidth(48)
	btnsave:SetText("Save")
	btnsave:SetTextColor(Color(69, 124, 141, 0))
	btnsave:SetIcon("icon16/folder_add.png")
	btn_place(btnsave)

end


function LK3D.MusiSynth.Editor.MakeWavePrev(wprev)
	function wprev:Paint(w, h)
		surface.SetDrawColor(LK3D.MusiSynth.Editor.Wcol)
		surface.DrawRect(0, 0, w, h)

		draw.SimpleText("Waveform Preview", "BudgetLabel", 0, 0, Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end
end



local icon_genned = {}

local function iconGen(nm, func)
	local rt = GetRenderTarget("lk3dmusi_" .. nm, 512, 256)
	local ma_t = CreateMaterial("lk3dmusi_m_" .. nm, "UnlitGeneric", {
		["$basetexture"] = rt:GetName(),
		["$ignorez"] = 1,
		["$nocull"] = 1,
		["$vertexcolor"] = 1,
		["$alphatest"] = 1
	})

	local ow, oh = ScrW(), ScrH()
	render.SetViewPort(0, 0, rt:Width(), rt:Height())
	cam.Start2D()
	render.PushRenderTarget(rt)
	render.Clear(0, 0, 0, 0)
	render.OverrideAlphaWriteEnable(true, true)
		func()
	render.OverrideAlphaWriteEnable(false)
	render.PopRenderTarget(rt)
	cam.End2D()
	render.SetViewPort(0, 0, ow, oh)

	icon_genned[nm] = {
		rt = rt,
		mat = ma_t
	}
end



iconGen("squrwave", function()
	render.Clear(0, 0, 0, 0)
	surface.SetDrawColor(100, 50, 0, 255)

	local itr = ScrW() / 1

	for i = 1, itr do
		local d = i / itr

		local mv = (i * 4) % itr
		if (mv > 0) and (mv < (itr / 2)) then
			surface.DrawRect(ScrW() * d, ScrH() - 32, 16, 16)
		elseif mv <= 0 or (mv == (itr / 2)) then
			surface.DrawRect(ScrW() * d, (ScrH() / 2) - 80, 16, 192)
		else
			surface.DrawRect(ScrW() * d, 32, 16, 16)
		end
	end
end)


iconGen("sinewave", function()
	render.Clear(0, 0, 0, 0)
	surface.SetDrawColor(100, 50, 0, 255)

	local itr = ScrW() / 1

	for i = 1, itr do
		local d = i / itr

		local mv = (d * 24) + 1
		surface.DrawRect(ScrW() * d, (ScrH() / 2) + (math.sin(mv) * (ScrH() * .25)), 16, 16)
	end
end)

iconGen("triwave", function()
	render.Clear(0, 0, 0, 0)
	surface.SetDrawColor(100, 50, 0, 255)

	local itr = ScrW() / 1

	for i = 1, itr do
		local d = i / itr

		local mv = (d * 24) + 1
		surface.DrawRect(ScrW() * d, (ScrH() / 2) + (math.tan(math.sin(mv)) * (ScrH() * .15)), 16, 16)
	end
end)

iconGen("sawwave", function()
	render.Clear(0, 0, 0, 0)
	surface.SetDrawColor(100, 50, 0, 255)

	local itr = ScrW() / 1

	for i = 1, itr do
		local d = i / itr

		local mv = (d * 32) + 3
		surface.DrawRect(ScrW() * d, (ScrH() / 2) + (((mv % 8) - 4) * 16), 16, (mv % 8) == 0 and 128 or 16)
	end
end)

iconGen("noisewave", function()
	render.Clear(0, 0, 0, 0)
	surface.SetDrawColor(100, 50, 0, 255)

	local itr = ScrW() / 1

	for i = 1, itr do
		local d = i / itr
		local nsd = (i / 8) % 64

		local fnsd = math.floor(nsd)
		local fract = nsd - fnsd
		local ns_v = Lerp(fract, calc_rand[fnsd + 1], calc_rand[fnsd + 2])

		surface.DrawRect(ScrW() * d, (ScrH() / 2) + (ns_v * (ScrH() * .25)), 16, 16)
	end
end)

iconGen("smoothnoisewave", function()
	render.Clear(0, 0, 0, 0)
	surface.SetDrawColor(100, 50, 0, 255)

	local itr = ScrW() / 1

	for i = 1, itr do
		local d = i / itr
		local nsd = (i / 32) % 64

		local fnsd = math.floor(nsd)
		local fract = nsd - fnsd
		local ns_v = Lerp(fract, calc_rand[fnsd + 1], calc_rand[fnsd + 2])

		surface.DrawRect(ScrW() * d, (ScrH() / 2) + (ns_v * (ScrH() * .25)), 16, 16)
	end
end)


iconGen("mod_amplify", function()
	render.Clear(0, 0, 0, 0)
	surface.SetDrawColor(100, 50, 100, 255)

	local m = Matrix()
	m:Rotate(Angle(0, 45, 0))
	m:SetTranslation(Vector(ScrW() / 2, ScrH() / 2))

	cam.PushModelMatrix(m)
	surface.DrawRect(-16, -98, 32, 196)
	surface.DrawRect(-98, -16, 196, 32)
	cam.PopModelMatrix()
end)

iconGen("mod_adsr", function()
	render.Clear(0, 0, 0, 0)
	surface.SetDrawColor(100, 50, 100, 255)

	local adsr_icon = {
		{len = .125, val = .75},
		{len = .25, val = .35},
		{len = .5, val = .35},
		{len = .125, val = 0},
	}

	local itr = ScrW() / 1

	for i = 1, itr do
		local d = i / itr

		local dc = d
		local adsr_st = 1
		for i2 = 1, #adsr_icon do
			local cu = adsr_icon[i2]
			if dc > cu.len then
				dc = dc - cu.len
				adsr_st = adsr_st + 1
			else
				break
			end
		end
		local adsr_curr = adsr_icon[adsr_st]
		local adsr_prev = adsr_icon[math.max(adsr_st - 1, 1)]

		local delta_curr = (dc / adsr_curr.len)
		local v_curr = (Lerp(delta_curr, adsr_prev.val, adsr_curr.val) - .5)

		surface.DrawRect(ScrW() * d, (ScrH() / 2) - (v_curr * 256), 16, 16)
	end
end)

iconGen("mod_highpass", function()
	render.Clear(0, 0, 0, 0)
	surface.SetDrawColor(100, 50, 100, 255)

	local itr = ScrW() / 1

	for i = 1, itr do
		local d = i / itr
		local vc = math.log(d) * 32

		surface.DrawRect(ScrW() * d, (ScrH() / 2) - vc, 16, 16)
	end
end)

iconGen("mod_lowpass", function()
	render.Clear(0, 0, 0, 0)
	surface.SetDrawColor(100, 50, 100, 255)

	local itr = ScrW() / 1

	for i = 1, itr do
		local d = i / itr
		local vc = math.log(math.abs(1 - d)) * 32

		surface.DrawRect(ScrW() * d, (ScrH() / 2) - vc, 16, 16)
	end
end)


-- there's a 1 pixel imperfection, sorry
iconGen("output", function()
	render.Clear(0, 0, 0, 0)
	surface.SetDrawColor(0, 50, 100, 255)

	surface.DrawRect(ScrW() / 2, 48, 16, ScrH() - 86)

	local m = Matrix()
	m:SetAngles(Angle(0, 45, 0))
	m:SetTranslation(Vector((ScrW() / 2) - 48, (ScrH() / 2) + 16))

	cam.PushModelMatrix(m)
	surface.DrawRect(0, 0, 96, 16)
	cam.PopModelMatrix()

	m:SetAngles(Angle(0, -45, 0))
	m:SetTranslation(Vector((ScrW() / 2) - 62, (ScrH() / 2) - 16))
	cam.PushModelMatrix(m)
	surface.DrawRect(0, 0, 96, 16)
	cam.PopModelMatrix()

	surface.DrawRect(172, ScrH() - 110, 32, 16)
	surface.DrawRect(172, ScrH() - 150, 32, 16)
	surface.DrawRect(162, ScrH() - 150, 16, 52)

	local hc = ScrH() * .55
	surface.DrawRect((ScrW() / 2) + 32, (ScrH() / 2) - (hc / 2) + 5, 16, hc)
	hc = ScrH() * .7
	surface.DrawRect((ScrW() / 2) + 64, (ScrH() / 2) - (hc / 2) + 5, 16, hc)

	hc = ScrH() * .85
	surface.DrawRect((ScrW() / 2) + 96, (ScrH() / 2) - (hc / 2) + 5, 16, hc)
end)


iconGen("mod_modulator", function()
	render.Clear(0, 0, 0, 0)
	surface.SetDrawColor(100, 50, 100, 255)

	local itr = ScrW() / 1

	for i = 1, itr do
		local d = i / itr

		local mv = (d * 8) + 1

		local s1 = math.sin(mv)
		local s2 = math.sin(mv * 8) * s1
		surface.DrawRect(ScrW() * d, (ScrH() / 2) + (s2 * (ScrH() * .25)), 16, 16)
	end
end)


local t_sort = {
	["output"] = 1,
	["wave"] = 2,
	["mod"] = 3,
}

local typeicons = {
	output = "icon16/database_go.png",
	wave = "icon16/page_white_world.png",
	mod = "icon16/database_edit.png"
}

function LK3D.MusiSynth.Editor.DeclareElement(name, type, data)
	LK3D.MusiSynth.Editor.ValidElements[name] = data
	LK3D.MusiSynth.Editor.ValidElements[name].type = type
	LK3D.MusiSynth.Editor.ValidElements[name].renderOrd = t_sort[type]

	table.sort(LK3D.MusiSynth.Editor.ValidElements, function(a, b)
		return t_sort[a.type] > t_sort[b.type]
	end)
end

LK3D.MusiSynth.Editor.DeclareElement("output", "output", {
	fancyName = "Output",
	icon = "output",
	col = Color(0, 100, 200),
	props = {
		khz = 11025
	},
	inputs = 1,
	outputs = 0,
})

--[[
LK3D.MusiSynth.Editor.DeclareElement("amp", "mod", {
	fancyName = "Amplify",
	icon = "mod_amplify",
	col = Color(200, 100, 200),
	props = {
		rate = 440,
		amplitude = 1,
		offset = 0,
	},
	inputs = 1,
	outputs = 1,
})
]]--

LK3D.MusiSynth.Editor.DeclareElement("modulator", "mod", {
	fancyName = "Modulator",
	icon = "mod_modulator",
	props = {},
	col = Color(200, 100, 200),
	inputs = 2,
	outputs = 1,
})


LK3D.MusiSynth.Editor.DeclareElement("adsr", "mod", {
	fancyName = "ADSR",
	icon = "mod_adsr",
	props = {
		attack = {len = .125, val = .75},
		decay = {len = .25, val = .35},
		sustain = {len = .5, val = .35},
		release = {len = .125, val = 0},
	},
	col = Color(200, 100, 200),
	inputs = 1,
	outputs = 1,
})

LK3D.MusiSynth.Editor.DeclareElement("highpass", "mod", {
	fancyName = "Highpass",
	icon = "mod_highpass",
	col = Color(200, 100, 200),
	props = {
		mult = .5,
	},
	inputs = 1,
	outputs = 1,
})

LK3D.MusiSynth.Editor.DeclareElement("lowpass", "mod", {
	fancyName = "Lowpass",
	icon = "mod_lowpass",
	col = Color(200, 100, 200),
	props = {
		mult = .5
	},
	inputs = 1,
	outputs = 1,
})

LK3D.MusiSynth.Editor.DeclareElement("square", "wave", {
	fancyName = "Square Wave",
	icon = "squrwave",
	col = Color(200, 100, 0),
	props = {
		rate = 440,
		amplitude = 1,
		offset = 0,
	},
	inputs = 0,
	outputs = 1,
})

LK3D.MusiSynth.Editor.DeclareElement("sine", "wave", {
	fancyName = "Sine Wave",
	icon = "sinewave",
	col = Color(200, 100, 0),
	props = {
		rate = 440,
		amplitude = 1,
		offset = 0,
	},
	inputs = 0,
	outputs = 1,
})

LK3D.MusiSynth.Editor.DeclareElement("tri", "wave", {
	fancyName = "Triangle Wave",
	icon = "triwave",
	col = Color(200, 100, 0),
	props = {
		rate = 440,
		amplitude = 1,
		offset = 0,
	},
	inputs = 0,
	outputs = 1,
})

LK3D.MusiSynth.Editor.DeclareElement("saw", "wave", {
	fancyName = "Saw Wave",
	icon = "sawwave",
	col = Color(200, 100, 0),
	props = {
		rate = 440,
		amplitude = 1,
		offset = 0,
	},
	inputs = 0,
	outputs = 1,
})

LK3D.MusiSynth.Editor.DeclareElement("noise", "wave", {
	fancyName = "Noise",
	icon = "noisewave",
	col = Color(200, 100, 0),
	props = {
		rate = 440,
		amplitude = 1,
		offset = 0,
	},
	inputs = 0,
	outputs = 1,
})

LK3D.MusiSynth.Editor.DeclareElement("smoothnoise", "wave", {
	fancyName = "Smooth Noise",
	icon = "smoothnoisewave",
	col = Color(200, 100, 0),
	props = {
		rate = 440,
		amplitude = 1,
		offset = 0,
	},
	inputs = 0,
	outputs = 1,
})


local function r_tbl_copy(tbl)
	local ntbl = {}
	for k, v in pairs(tbl) do
		if type(v) ~= "table" then
			ntbl[k] = v
		else
			ntbl[k] = r_tbl_copy(v)
		end
	end

	return ntbl
end

local function addElementToEditPanel(data, x, y)
	LK3D.MusiSynth.Editor.Elements[#LK3D.MusiSynth.Editor.Elements + 1] = {
		pos = Vector(x, y),
		data = r_tbl_copy(data),
	}
end


local corner_mat = Material("gui/corner16", "ignorez nocull")
local function drawCircleBad(x, y, w, h)
	surface.SetMaterial(corner_mat)
	surface.DrawTexturedRectUV(x - w, y - h, w, h, 0, 0, 1, 1)
	surface.DrawTexturedRectUV(x, y - h, w, h, 1, 0, 0, 1)
	surface.DrawTexturedRectUV(x - w, y, w, h, 0, 1, 1, 0)
	surface.DrawTexturedRectUV(x, y, w, h, 1, 1, 0, 0)
end


local function drawPanelInCanvas(x, y, data)
	local w, h = 96, 64

	local col = data.col
	local col_c = Color(col.r * .75, col.g * .75, col.b * .75)
	surface.SetDrawColor(col_c)
	surface.DrawRect(x, y, w, h)

	surface.SetDrawColor(col)
	surface.DrawRect(x + 2, y + 2, w - 4, h - 4)

	draw.SimpleText(data.type, "BudgetLabel", x + 2, y + h - 14, col_c, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

	surface.SetDrawColor(255, 255, 255, 255)
	surface.SetMaterial(icon_genned[data.icon].mat)

	local sm = w < h and w or h
	local wc = sm * 1.5
	local hc = sm * .75
	surface.DrawTexturedRect(x + (w / 2) - (wc / 2), y + (h / 2) - (hc / 2), wc, hc)


	local t_icon = typeicons[data.type]
	if not iconMats[t_icon] then
		iconMats[t_icon] = Material(t_icon, "ignorez nocull")
	end

	surface.SetMaterial(iconMats[t_icon])
	surface.DrawTexturedRect(x, y, 16, 16)

	draw.SimpleText(data.fancyName, "BudgetLabel", x + w / 2, y + 0, Color(255, 255, 255), TEXT_ALIGN_CENTER)

	local inputcount = data.inputs
	local center = h / 2

	for i = 1, inputcount do
		local yc = center - (24 * (inputcount / 2)) + (24 * (i - .5))

		surface.SetDrawColor(32, 32, 32)
		drawCircleBad(x, y + yc, 6, 6)
		surface.SetDrawColor(64, 128, 255)
		drawCircleBad(x, y + yc, 4, 4)
	end

	local outputcount = data.outputs

	for i = 1, outputcount do
		local yc = center - (24 * (outputcount / 2)) + (24 * (i - .5))

		surface.SetDrawColor(32, 32, 32)
		drawCircleBad(x + w, y + yc, 6, 6)
		surface.SetDrawColor(255, 128, 64)
		drawCircleBad(x + w, y + yc, 4, 4)
	end
end


local function inrange(px, py, x, y, w, h)
	return (px >= x and px <= (x + w)) and (py >= y and py <= (y + h))
end

function LK3D.MusiSynth.Editor.MakeEditPanel(editpnl)
	editpnl:Receiver("musisynth_edit_element", function(pnl, tbl, dropped, idx, x, y)
		if dropped then
			print("pnl dropped!")
			for k, v in pairs(tbl) do
				print(v)
				print(v.ElementData)

				addElementToEditPanel(v.ElementData, x + LK3D.MusiSynth.Editor.RenderOffset.x, y + LK3D.MusiSynth.Editor.RenderOffset.y)
			end
		end
	end, {})

	editpnl:SetMouseInputEnabled(true)

	function editpnl:Think()
		if dragndrop.IsDragging() then
			return
		end

		if self:IsHovered() and input.IsMouseDown(MOUSE_LEFT) then
			local cpx, cpy = self:CursorPos()
			if self.Grabbing ~= nil then
				local obj = LK3D.MusiSynth.Editor.Elements[self.Grabbing]


				obj.pos = self.GrabStart + Vector(math.Round(cpx, -1), math.Round(cpy, -1))
				self:SetCursor("sizeall")
				return
			end


			if not self.StartDrag then
				-- check for all elements we can grab
				for k, v in pairs(LK3D.MusiSynth.Editor.Elements) do
					if inrange(
						cpx + LK3D.MusiSynth.Editor.RenderOffset.x, cpy + LK3D.MusiSynth.Editor.RenderOffset.y,
						v.pos.x - 48, v.pos.y - 32,
						96, 64
					) then
						self.GrabStart = v.pos - Vector(cpx, cpy)
						self.Grabbing = k
						LK3D.MusiSynth.Editor.Selected = k
						return
					end
				end

				self.MouseStart = LK3D.MusiSynth.Editor.RenderOffset + Vector(cpx, cpy)
				self.StartDrag = true
			end

			local d = self.MouseStart - Vector(cpx, cpy)
			LK3D.MusiSynth.Editor.RenderOffset = d
			self:SetCursor("sizeall")
		elseif self.StartDrag then
			self.StartDrag = false
			self:SetCursor("none")
		elseif self.Grabbing ~= nil then
			self.Grabbing = nil
			self:SetCursor("none")
		end

	end

	function editpnl:Paint(w, h)
		surface.SetDrawColor(LK3D.MusiSynth.Editor.Bcol)
		surface.DrawRect(0, 0, w, h)

		local ro = LK3D.MusiSynth.Editor.RenderOffset
		local rox, roy = ro.x, ro.y
		surface.SetDrawColor(LK3D.MusiSynth.Editor.BDcol)


		--	_____________
		-- |			 |
		-- |			 |
		-- |			 |
		-- |			 |
		-- |_____________|
		-- 800 x 600
		-- stepsz = 16

		local stepsz = 32
		local stw = w / stepsz
		for i = 0, stw do
			local sm = i * stepsz
			surface.DrawRect(sm + (-rox % stepsz), 0, 2, h)
		end
		local sth = h / stepsz
		for i = 0, sth do
			local sm = i * stepsz
			surface.DrawRect(0, sm + (-roy % stepsz), w, 2)
		end


		--local steps = 32
		--local ws, hs = w / steps, h / steps
		--for i = 0, steps - 1 do
		--	local hsm = i * hs
		--	local wsm = i * ws
		--	surface.DrawRect(0, (-roy + (h / 2) + hsm) % h, w, 2)
		--
		--	surface.DrawRect((-rox + (w / 2) + wsm) % w, 0, 2, h)
		--end

		surface.SetDrawColor(LK3D.MusiSynth.Editor.BDDcol)
		surface.DrawRect(0, -roy, w, 4)
		surface.DrawRect(-rox, 0, 4, h)


		--local m = Matrix()
		for k, v in pairs(LK3D.MusiSynth.Editor.Elements) do
			local vc = Vector(v.pos.x - 48, v.pos.y - 32) - LK3D.MusiSynth.Editor.RenderOffset

			-- no matrices, it doesnt renderclip if translating via matrix
			--m:SetTranslation(Vector(v.pos.x - 48, v.pos.y - 32) - LK3D.MusiSynth.Editor.RenderOffset)
			--cam.PushModelMatrix(m)
				drawPanelInCanvas(vc.x, vc.y, v.data)
			--cam.PopModelMatrix(m)
		end

		draw.SimpleText("Editor (" .. LK3D.MusiSynth.Editor.CurrFile .. "):[x" .. LK3D.MusiSynth.Editor.RenderOffset.x .. ", y" .. LK3D.MusiSynth.Editor.RenderOffset.y .. "]", "BudgetLabel", 0, 0, Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end
end



function LK3D.MusiSynth.Editor.MakeElementsPanel(elmpanel)

	function elmpanel:Paint(w, h)
		surface.SetDrawColor(LK3D.MusiSynth.Editor.BElmcol)
		surface.DrawRect(0, 0, w, h)

		draw.SimpleText("Element List", "BudgetLabel", 0, 0, Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end


	for k, v in SortedPairsByMemberValue(LK3D.MusiSynth.Editor.ValidElements, "renderOrd") do
		local felm = vgui.Create("DPanel")
		felm:DockMargin(12, 24, 12, 0)
		felm:Dock(TOP)
		felm:SetHeight(64)
		felm:Droppable("musisynth_edit_element")

		felm.ElementData = v

		local col = v.col
		local fname = v.fancyName
		local icon = v.icon
		local typ_e = v.type
		function felm:Paint(w, h)
			local col_c = Color(col.r * .75, col.g * .75, col.b * .75)
			surface.SetDrawColor(col_c)
			surface.DrawRect(0, 0, w, h)


			surface.SetDrawColor(col)
			surface.DrawRect(2, 2, w - 4, h - 4)

			draw.SimpleText(typ_e, "BudgetLabel", 2, h - 14, col_c, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

			surface.SetDrawColor(255, 255, 255, 255)
			surface.SetMaterial(icon_genned[icon].mat)

			local sm = w < h and w or h
			local wc = sm * 1.5
			local hc = sm * .75
			surface.DrawTexturedRect((w / 2) - (wc / 2), (h / 2) - (hc / 2), wc, hc)


			local t_icon = typeicons[typ_e]
			if not iconMats[t_icon] then
				iconMats[t_icon] = Material(t_icon, "ignorez nocull")
			end

			surface.SetMaterial(iconMats[t_icon])
			surface.DrawTexturedRect(0, 0, 16, 16)

			draw.SimpleText(fname, "BudgetLabel", w / 2, 0, Color(255, 255, 255), TEXT_ALIGN_CENTER)
		end

		elmpanel:AddItem(felm)
	end
end


local panel_conf_type_calls = {
	["number"] = function(p, tbl, k, v)
		local pn_new = vgui.Create("DPanel", p)

		function pn_new:Paint(w, h)
			surface.SetDrawColor(LK3D.MusiSynth.Editor.Bcol)
			surface.DrawRect(0, 0, w, h)

			draw.SimpleText(k, "Trebuchet24", 0, h / 2, Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end

		local n_input = vgui.Create("DNumberWang", pn_new)
		n_input:SetMin(-(64 ^ 8))
		n_input:SetMax(64 ^ 8)
		n_input:SetValue(v)
		n_input:Dock(RIGHT)

		function n_input:OnValueChanged(nv)
			tbl[k] = nv
		end


		return pn_new
	end
}


function LK3D.MusiSynth.Editor.MakeConfigPanel(cfgpanel)
	cfgpanel.LastConfig = nil
	cfgpanel:DockPadding(0, 24, 0, 0)


	function cfgpanel:Think()
		if LK3D.MusiSynth.Editor.Selected ~= self.LastConfig then
			self.LastConfig = LK3D.MusiSynth.Editor.Selected
			for k, v in pairs(cfgpanel:GetChildren()) do
				v:Remove()
			end

			if not LK3D.MusiSynth.Editor.Selected then
				return
			end


			local pn_delete = vgui.Create("DPanel", self)
			pn_delete:Dock(TOP)

			function pn_delete:Paint(w, h)
				surface.SetDrawColor(100, 64, 64)
				surface.DrawRect(0, 0, w, h)

				draw.SimpleText("Delete", "Trebuchet24", 0, h / 2, Color(255, 64, 64), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			end

			local curr_sel_data = LK3D.MusiSynth.Editor.Elements[LK3D.MusiSynth.Editor.Selected].data

			for k, v in pairs(curr_sel_data.props) do
				if panel_conf_type_calls[type(v)] then
					local _, pn_dock = pcall(panel_conf_type_calls[type(v)], self, curr_sel_data.props, k, v)
					pn_dock:DockMargin(0, 0, 0, 0)
					pn_dock:Dock(TOP)
					pn_dock:SetTall(24)
				end
			end
		end
	end


	function cfgpanel:Paint(w, h)
		surface.SetDrawColor(LK3D.MusiSynth.Editor.BElmcol)
		surface.DrawRect(0, 0, w, h)

		local nm = (LK3D.MusiSynth.Editor.Selected ~= nil) and LK3D.MusiSynth.Editor.Elements[LK3D.MusiSynth.Editor.Selected].data.fancyName or "None"

		draw.SimpleText("Config [#" .. (LK3D.MusiSynth.Editor.Selected or 0) .. "]: " .. nm, "BudgetLabel", 0, 0, Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end
end


function LK3D.MusiSynth.Editor.OpenEditor()
	if IsValid(LK3D.MusiSynth.Editor.MainFrame) then
		return
	end
	LK3D.MusiSynth.Editor.MainFrame = vgui.Create("DFrame")
	local mf = LK3D.MusiSynth.Editor.MainFrame

	mf:SetMinWidth(800)
	mf:SetMinHeight(600)

	mf:SetSize(ScrW() * .75, ScrH() * .75)
	mf:Center()
	mf:MakePopup()
	mf:SetTitle("MusiSynth Editor")
	mf:SetIcon("icon16/music.png")
	mf:SetSizable(true)
	mf:DockPadding(8, 24, 8, 8)


	function mf:Paint(w, h)
		surface.SetDrawColor(LK3D.MusiSynth.Editor.BGcol)
		surface.DrawRect(0, 0, w, h)

		surface.SetDrawColor(LK3D.MusiSynth.Editor.BGDarkcol)
		surface.DrawRect(0, 0, w, 24)
	end


	local tb = vgui.Create("DPanel", mf)
	tb:SetTall(24)
	tb:SetWidth(mf:GetWide())
	tb:DockMargin(0, 0, 0, 4)
	tb:Dock(TOP)
	LK3D.MusiSynth.Editor.MakeTopbar(tb)


	local bdiv = vgui.Create("DVerticalDivider", mf)
	bdiv:Dock(BOTTOM)
	bdiv:Dock(FILL)
	bdiv:SetBottomMin(96)
	bdiv:SetTopMin(128)
	bdiv:SetDividerHeight(6)
	bdiv:SetTopHeight(704)


	local editwdiv = vgui.Create("DHorizontalDivider")
	editwdiv:SetLeftMin(128)
	editwdiv:SetRightMin(256)
	editwdiv:SetDividerWidth(4)
	editwdiv:SetLeftWidth(128)


	local editpnl = vgui.Create("DPanel")
	LK3D.MusiSynth.Editor.MakeEditPanel(editpnl)

	local editorwdiv = vgui.Create("DHorizontalDivider")
	editorwdiv:SetLeftMin(400)
	editorwdiv:SetRightMin(256)
	editorwdiv:SetDividerWidth(4)
	editorwdiv:SetLeftWidth(800)


	local elmpanel = vgui.Create("DScrollPanel")
	LK3D.MusiSynth.Editor.MakeElementsPanel(elmpanel)

	local cfgpanel = vgui.Create("DPanel")
	LK3D.MusiSynth.Editor.MakeConfigPanel(cfgpanel)

	editorwdiv:SetLeft(editpnl)
	editorwdiv:SetRight(cfgpanel)

	editwdiv:SetRight(editorwdiv)
	editwdiv:SetLeft(elmpanel)




	local wprev = vgui.Create("DPanel")
	LK3D.MusiSynth.Editor.MakeWavePrev(wprev)
	bdiv:SetTop(editwdiv)
	bdiv:SetBottom(wprev)
end

concommand.Add("lk3d_musisynth_openeditor",	function()
	LK3D.MusiSynth.Editor.OpenEditor()
end)