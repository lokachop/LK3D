LK3D = LK3D or {}
LK3D.ProcTex = LK3D.ProcTex or {}
LK3D.New_D_Print("Loading!", LK3D_SEVERITY_INFO, "ProcTex")

LK3D.ProcTex.Coros = {}
LK3D.ProcTex.PixelItr = 64

function LK3D.ProcTex.New(name, w, h)
	LK3D.DeclareTextureFromFunc(name, w, h, function()
	end)
end

function LK3D.ProcTex.ApplySolid(name, col_r, g, b)
	LK3D.UpdateTexture(name, function()
		if col_r["r"] then
			render.Clear(col_r.r, col_r.g, col_r.b, 255)
		else
			render.Clear(col_r, g, b, 255)
		end
	end)
end

function LK3D.ProcTex.ApplySource(name, tex)
	local f_t = LK3D.FriendlySourceTexture(tex)
	LK3D.UpdateTexture(name, function()
		surface.SetDrawColor(255, 255, 255, 255)
		surface.SetMaterial(f_t)
		surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
	end)
end



function LK3D.ProcTex.ApplySimplexBase(name, sx, sy, mul, seed)
	local rt = LK3D.Textures[name].rt

	local w, h = rt:Width(), rt:Height()
	local ow, oh = ScrW(), ScrH()
	render.SetViewPort(0, 0, w, h)
	cam.Start2D()
	render.PushRenderTarget(rt)
		render.SetColorMaterialIgnoreZ()
		for i = 0, ScrW() * ScrH() do

			local xc, yc = (i % ScrW()), math.floor(i / ScrW())
			local c_val = LK3D.Simplex2D(xc * sx, yc * sy, seed)
			--print(xc / (32 * sx), yc / (32 * sy))
			--print(c_val)
			--c_val = math.abs(c_val) < .05 and 255 or 0
			c_val = c_val * (255 * (mul or 1))
			surface.SetDrawColor(c_val, c_val, c_val, 255)
			surface.DrawRect(xc, yc, 1, 1)
		end
		render.PopRenderTarget()
	cam.End2D()
	render.SetViewPort(0, 0, ow, oh)
end

function LK3D.ProcTex.SimplexAdditive(name, sx, sy, seed)
	local rt = LK3D.Textures[name].rt

	local w, h = rt:Width(), rt:Height()
	local ow, oh = ScrW(), ScrH()
	render.SetViewPort(0, 0, w, h)
	cam.Start2D()
	render.PushRenderTarget(rt)
	render.CapturePixels()
		render.SetColorMaterialIgnoreZ()
		for i = 0, ScrW() * ScrH() do
			local xc, yc = (i % ScrW()), math.floor(i / ScrW())
			local tl_val = LK3D.Simplex2D(xc * sx, yc * sy, seed)
			tl_val = (tl_val + 1) / 2
			local pr, pg, pb = render.ReadPixel(xc, yc)
			surface.SetDrawColor(pr * tl_val, pg * tl_val, pb * tl_val, 255)
			surface.DrawRect(xc, yc, 1, 1)
		end
		render.PopRenderTarget()
	cam.End2D()
	render.SetViewPort(0, 0, ow, oh)
end


function LK3D.ProcTex.ApplyPerlinBase(name, sx, sy, mul, seed)
	local rt = LK3D.Textures[name].rt

	local w, h = rt:Width(), rt:Height()
	local ow, oh = ScrW(), ScrH()
	render.SetViewPort(0, 0, w, h)
	cam.Start2D()
	render.PushRenderTarget(rt)
		render.SetColorMaterialIgnoreZ()
		for i = 0, ScrW() * ScrH() do
			local xc, yc = (i % ScrW()), math.floor(i / ScrW())
			local c_val = LK3D.Perlin2D(xc / (32 * sx), yc / (32 * sy), seed)
			--c_val = math.abs(c_val) < .05 and 255 or 0
			c_val = c_val * (255 * (mul or 1))
			surface.SetDrawColor(c_val, c_val, c_val, 255)
			surface.DrawRect(xc, yc, 1, 1)
		end
		render.PopRenderTarget()
	cam.End2D()
	render.SetViewPort(0, 0, ow, oh)
end

function LK3D.ProcTex.PerlinAdditive(name, sx, sy, seed)
	local rt = LK3D.Textures[name].rt

	local w, h = rt:Width(), rt:Height()
	local ow, oh = ScrW(), ScrH()
	render.SetViewPort(0, 0, w, h)
	cam.Start2D()
	render.PushRenderTarget(rt)
	render.CapturePixels()
		render.SetColorMaterialIgnoreZ()
		for i = 0, ScrW() * ScrH() do
			local xc, yc = (i % ScrW()), math.floor(i / ScrW())
			local tl_val = LK3D.Perlin2D(xc / (32 * sx), yc / (32 * sy), seed)
			tl_val = (tl_val + 1) / 2
			local pr, pg, pb = render.ReadPixel(xc, yc)
			surface.SetDrawColor(pr * tl_val, pg * tl_val, pb * tl_val, 255)
			surface.DrawRect(xc, yc, 1, 1)
		end
		render.PopRenderTarget()
	cam.End2D()
	render.SetViewPort(0, 0, ow, oh)
end



function LK3D.ProcTex.ApplyWorleyBase(name, sx, sy, invert, seed)
	local rt = LK3D.Textures[name].rt

	local w, h = rt:Width(), rt:Height()
	local ow, oh = ScrW(), ScrH()
	render.SetViewPort(0, 0, w, h)
	cam.Start2D()
	render.PushRenderTarget(rt)
		render.SetColorMaterialIgnoreZ()
		for i = 0, ScrW() * ScrH() do
			local xc, yc = (i % ScrW()), math.floor(i / ScrW())
			local c_val = LK3D.Worley2D(xc / (.25 * sx), yc / (.25 * sy), seed) * .5 + .5
			--c_val = math.abs(c_val) < .05 and 255 or 0
			c_val = invert and math.abs(1 - c_val) or c_val

			c_val = c_val * 255
			surface.SetDrawColor(c_val, c_val, c_val, 255)
			surface.DrawRect(xc, yc, 1, 1)
		end
		render.PopRenderTarget()
	cam.End2D()
	render.SetViewPort(0, 0, ow, oh)
end

function LK3D.ProcTex.WorleyAdditive(name, sx, sy, sub, seed)
	local rt = LK3D.Textures[name].rt

	local w, h = rt:Width(), rt:Height()
	local ow, oh = ScrW(), ScrH()
	render.SetViewPort(0, 0, w, h)
	cam.Start2D()
	render.PushRenderTarget(rt)
	render.CapturePixels()
		render.SetColorMaterialIgnoreZ()
		for i = 0, (ScrW() * ScrH()) do
			local xc, yc = (i % ScrW()), math.floor(i / ScrW())
			local c_val = LK3D.Worley2D(xc / (.25 * sx), yc / (.25 * sy), seed) * .5 + .5
			c_val = sub and math.abs(1 - c_val) or c_val
			local pr, pg, pb = render.ReadPixel(xc, yc)
			surface.SetDrawColor(pr * c_val, pg * c_val, pb * c_val, 255)
			surface.DrawRect(xc, yc, 1, 1)
		end
		render.PopRenderTarget()
	cam.End2D()
	render.SetViewPort(0, 0, ow, oh)
end


function LK3D.ProcTex.Operator(name, call)
	local rt = LK3D.Textures[name].rt

	local w, h = rt:Width(), rt:Height()
	local ow, oh = ScrW(), ScrH()
	render.SetViewPort(0, 0, w, h)
	cam.Start2D()
	render.PushRenderTarget(rt)
		render.SetColorMaterialIgnoreZ()
		for i = 0, ScrW() * ScrH() do

			local xc, yc = (i % ScrW()), math.floor(i / ScrW())
			local c_val = call and call(xc, yc, w, h) or Color(255, 0, 0)
			surface.SetDrawColor(c_val.r, c_val.g, c_val.b, 255)
			surface.DrawRect(xc, yc, 1, 1)
		end
		render.PopRenderTarget()
	cam.End2D()
	render.SetViewPort(0, 0, ow, oh)
end

function LK3D.ProcTex.ApplyValueBase(name, sx, sy, seed)
	local rt = LK3D.Textures[name].rt

	local w, h = rt:Width(), rt:Height()
	local ow, oh = ScrW(), ScrH()
	render.SetViewPort(0, 0, w, h)
	cam.Start2D()
	render.PushRenderTarget(rt)
		render.SetColorMaterialIgnoreZ()
		for i = 0, ScrW() * ScrH() do
			local xc, yc = (i % ScrW()), math.floor(i / ScrW())
			local c_val = LK3D.ValueNoise2D(xc / (.25 * sx), yc / (.25 * sy), seed) * .5 + .5
			c_val = c_val * 255
			surface.SetDrawColor(c_val, c_val, c_val, 255)
			surface.DrawRect(xc, yc, 1, 1)
		end
		render.PopRenderTarget()
	cam.End2D()
	render.SetViewPort(0, 0, ow, oh)
end


function LK3D.ProcTex.ValueAdditive(name, sx, sy, sub, seed)
	LK3D.UpdateTexture(name, function()
		render.CapturePixels()
		for i = 0, ScrW() * ScrH() do
			local xc, yc = (i % ScrW()), math.floor(i / ScrW())

			local c_val = LK3D.ValueNoise2D(xc / (.25 * sx), yc / (.25 * sy), seed) * .5 + .5
			c_val = sub and math.abs(1 - c_val) or c_val

			local pr, pg, pb = render.ReadPixel(xc, yc)
			surface.SetDrawColor(pr * c_val, pg * c_val, pb * c_val, 255)
			surface.DrawRect(xc, yc, 1, 1)
		end
	end)
end



local function blendif(from, to, sx, sy, tresh, seed, call)
	local frt = LK3D.GetTextureByIndex(from).rt
	local fw, fh = frt:Width(), frt:Height()

	cam.Start2D()
	render.PushRenderTarget(frt)
	local ow, oh = ScrW(), ScrH()
	render.SetViewPort(0, 0, fw, fh)
		render.CapturePixels()
	render.PopRenderTarget()
	render.SetViewPort(0, 0, ow, oh)
	cam.End2D()


	LK3D.UpdateTexture(to, function()
		local wm = fw / (ScrW())
		local hm = fh / (ScrH())

		for i = 0, (ScrW() * ScrH()) do
			local xc, yc = (i % ScrW()), math.floor(i / ScrW())

			local c_val = call(xc / sx, yc / sy, seed)

			if c_val > tresh then
				local diff = ((c_val - tresh) / math.abs(1 - tresh)) * 2

				local r_xc = math.floor(xc * wm)
				local r_yc = math.floor(yc * hm)
				local rr, rg, rb = render.ReadPixel(r_xc, r_yc)
				render.SetColorMaterialIgnoreZ()
				surface.SetDrawColor(rr, rg, rb, 255 * diff)
				surface.DrawRect(xc, yc, 1, 1)
			end
		end
	end)
end

function LK3D.ProcTex.PerlinMask(from, to, sx, sy, treshold, seed)
	blendif(from, to, 32 * sx, 32 * sy, treshold, seed, LK3D.Perlin2D)
end

function LK3D.ProcTex.WorleyMask(from, to, sx, sy, treshold, seed)
	blendif(from, to, .25 * sx, .25 * sy, treshold, seed, LK3D.ProcTex.Worley.worley)
end

function LK3D.ProcTex.SimplexMask(from, to, sx, sy, treshold, seed)
	blendif(from, to, .25 * sx, .25 * sy, treshold, seed, LK3D.Simplex2D)
end


function LK3D.ProcTex.TextureGenThink()
	LK3D.ProcTex.PixelItr = (196 / #LK3D.ProcTex.Coros)

	local toRem = {}
	for k, v in ipairs(LK3D.ProcTex.Coros) do
		local fine, ret = coroutine.resume(v)
		if not fine then
			toRem[#toRem + 1] = k
			LK3D.New_D_Print("ERROR: " .. ret, LK3D_SEVERITY_ERROR, "ProcTex")
		end

		if ret == 2 then
			print("rem; " .. k)
			toRem[#toRem + 1] = k
		end
	end

	for k, v in ipairs(toRem) do
		LK3D.ProcTex.Coros[v] = nil
	end
end


-- TODO: Value noise (https://en.wikipedia.org/wiki/Value_noise)
-- TODO: Simplex noise (https://en.wikipedia.org/wiki/Simplex_noise)
-- TODO: Distortions (rotate, scale, persp, fractal distort)
-- TODO: Localized copying
-- TODO: algorithms for regular textures (bricks, tiles, sewers, etc)
-- TODO: edge det. algorithm (https://en.wikipedia.org/wiki/Edge_detection)



-- LK3D.ProcTex.Perlin uses: https://redirect.cs.umbc.edu/~olano/s2002c36/ch02.pdf


LK3D.ProcTex.New("TerrainTest2", 64, 64)
LK3D.ProcTex.ApplySolid("TerrainTest2", Color(255, 255, 255))
--LK3D.ProcTex.ApplySimplexBase("Perlintest", 0.05, 0.025, 2, math.random(0, 1243))
--LK3D.ProcTex.SimplexAdditive("Perlintest", 0.025, 0.055)
--LK3D.ProcTex.SimplexAdditive("Perlintest", 0.125, 0.125)

--[[
local c_lb = Color(64, 64, 255)
local c_tb = Color(255, 255, 128)
local c_mid = Color(64, 255, 32)
local c_top = Color(32, 196, 16)
local c_topper = Color(255, 255, 255)
local function lerpColor(t, a, b)
	return Color(
		Lerp(t, a.r, b.r),
		Lerp(t, a.g, b.g),
		Lerp(t, a.b, b.b)
	)
end

local function getTerrCol(v)
	if v <= .25 then
		return lerpColor(v * 4, c_lb, c_tb)
	end
	v = v - .25
	if v <= .25 then
		return lerpColor(v * 4, c_tb, c_mid)
	end
	v = v - .25
	if v <= .25 then
		return lerpColor(v * 4, c_mid, c_top)
	end
	v = v - .25
	return lerpColor(v * 4, c_top, c_topper)

end

LK3D.ProcTex.Operator("TerrainTest2", function(xc, yc, w, h)
	local px = xc / w
	local py = yc / h


	local perlin_val0 = LK3D.Simplex2D(px * 2.12244, py * 2.2244, 413253) * 4
	local perlin_val1 = LK3D.Simplex2D((px + 41634) * 6.231, (py + 34634) * 6.236, 413253) * 1
	local perlin_val2 = LK3D.Simplex2D(px * 12.9782244, py * 12.786244, 413253) * 0.55

	local p_f = (perlin_val0 + perlin_val1 + perlin_val2) / 3
	p_f = (p_f + 1) / 2
	return getTerrCol(p_f) --Color(p_f, p_f, p_f)

	--local spx = LK3D.Simplex2D(xc / w, yc / h)
	--spx = (spx + 1) / 2
	--return Color(255, 255, spx * 255)
end)
]]--

LK3D.ProcTex.New("worleytest", 64, 64)
--LK3D.ProcTex.ApplyWorleyBase("worleytest", 1, 1, 1, math.random(0, 1243))



LK3D.ProcTex.New("submarine_rust", 256, 256)
LK3D.ProcTex.ApplySource("submarine_rust", "metal/metalfloor005a")

LK3D.ProcTex.New("submarine_rusted", 256, 256)
LK3D.ProcTex.ApplySource("submarine_rusted", "metal/metalpipe010a")
--LK3D.ProcTex.LK3D.ProcTex.PerlinMask("submarine_rust", "submarine_rusted", 1, 1, .3, math.random(0, 1243))



LK3D.ProcTex.New("blend_orange", 256, 256)
LK3D.ProcTex.ApplySource("blend_orange", "dev/dev_measuregeneric01")

LK3D.ProcTex.New("blend_show", 256, 256)
LK3D.ProcTex.ApplySource("blend_show", "dev/dev_measuregeneric01b")
--LK3D.ProcTex.LK3D.ProcTex.PerlinMask("blend_orange", "blend_show", 2, 2, .45, math.random(0, 1243))

