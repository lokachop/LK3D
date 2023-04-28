LK3D = LK3D or {}
LK3D.ProcTex = LK3D.ProcTex or {}
LK3D.New_D_Print("Loading!", 2, "ProcTex")

-- https:--github.com/WardBenjamin/SimplexNoise/blob/master/SimplexNoise/Noise.cs
LK3D.ProcTex.Simplex = LK3D.ProcTex.Simplex or {}

local spx_permutations = {
	151, 160, 137, 91, 90, 15, 131, 13, 201, 95, 96, 53, 194, 233, 7, 225, 140, 36,
	103, 30, 69, 142, 8, 99, 37, 240, 21, 10, 23, 190, 6, 148, 247, 120, 234, 75, 0,
	26, 197, 62, 94, 252, 219, 203, 117, 35, 11, 32, 57, 177, 33, 88, 237, 149, 56,
	87, 174, 20, 125, 136, 171, 168, 68, 175, 74, 165, 71, 134, 139, 48, 27, 166,
	77, 146, 158, 231, 83, 111, 229, 122, 60, 211, 133, 230, 220, 105, 92, 41, 55,
	46, 245, 40, 244, 102, 143, 54, 65, 25, 63, 161, 1, 216, 80, 73, 209, 76, 132,
	187, 208, 89, 18, 169, 200, 196, 135, 130, 116, 188, 159, 86, 164, 100, 109,
	198, 173, 186, 3, 64, 52, 217, 226, 250, 124, 123, 5, 202, 38, 147, 118, 126,
	255, 82, 85, 212, 207, 206, 59, 227, 47, 16, 58, 17, 182, 189, 28, 42, 223, 183,
	170, 213, 119, 248, 152, 2, 44, 154, 163, 70, 221, 153, 101, 155, 167, 43,
	172, 9, 129, 22, 39, 253, 19, 98, 108, 110, 79, 113, 224, 232, 178, 185, 112,
	104, 218, 246, 97, 228, 251, 34, 242, 193, 238, 210, 144, 12, 191, 179, 162,
	241, 81, 51, 145, 235, 249, 14, 239, 107, 49, 192, 214, 31, 181, 199, 106,
	157, 184, 84, 204, 176, 115, 121, 50, 45, 127, 4, 150, 254, 138, 236, 205,
	93, 222, 114, 67, 29, 24, 72, 243, 141, 128, 195, 78, 66, 215, 61, 156, 180,

	151, 160, 137, 91, 90, 15, 131, 13, 201, 95, 96, 53, 194, 233, 7, 225, 140, 36,
	103, 30, 69, 142, 8, 99, 37, 240, 21, 10, 23, 190, 6, 148, 247, 120, 234, 75, 0,
	26, 197, 62, 94, 252, 219, 203, 117, 35, 11, 32, 57, 177, 33, 88, 237, 149, 56,
	87, 174, 20, 125, 136, 171, 168, 68, 175, 74, 165, 71, 134, 139, 48, 27, 166,
	77, 146, 158, 231, 83, 111, 229, 122, 60, 211, 133, 230, 220, 105, 92, 41, 55,
	46, 245, 40, 244, 102, 143, 54, 65, 25, 63, 161, 1, 216, 80, 73, 209, 76, 132,
	187, 208, 89, 18, 169, 200, 196, 135, 130, 116, 188, 159, 86, 164, 100, 109,
	198, 173, 186, 3, 64, 52, 217, 226, 250, 124, 123, 5, 202, 38, 147, 118, 126,
	255, 82, 85, 212, 207, 206, 59, 227, 47, 16, 58, 17, 182, 189, 28, 42, 223, 183,
	170, 213, 119, 248, 152, 2, 44, 154, 163, 70, 221, 153, 101, 155, 167, 43,
	172, 9, 129, 22, 39, 253, 19, 98, 108, 110, 79, 113, 224, 232, 178, 185, 112,
	104, 218, 246, 97, 228, 251, 34, 242, 193, 238, 210, 144, 12, 191, 179, 162,
	241, 81, 51, 145, 235, 249, 14, 239, 107, 49, 192, 214, 31, 181, 199, 106,
	157, 184, 84, 204, 176, 115, 121, 50, 45, 127, 4, 150, 254, 138, 236, 205,
	93, 222, 114, 67, 29, 24, 72, 243, 141, 128, 195, 78, 66, 215, 61, 156, 180
}

local spx_f2 = .5 * (math.sqrt(3) - 1)
local spx_g2 = (3 - math.sqrt(3)) / 6

local function spx_grad2D(seed, x, y)
	local h = bit.band(seed, 7)      -- Convert low 3 bits of hash code
	local u = h < 4 and x or y  -- into 8 simple gradient directions,
	local v = h < 4 and y or x  -- and compute the dot product with (x,y).
	return (bit.band(h, 1) ~= 0 and -u or u) + (bit.band(h, 2) ~= 0 and -2.0 * v or 2.0 * v)
end

local function spx_mod(x, m)
	local a = x % m;
	return a < 0 and a + m or a;
end
function LK3D.ProcTex.Simplex.simplex2D(x, y, seed)
	local n0, n1, n2 = 0, 0, 0

	local s = (x + y) * spx_f2
	local xs = x + s
	local ys = y + s

	local i = math.floor(xs)
	local j = math.floor(ys)


	local t = (i + j) * spx_g2

	local X0 = i - t -- Unskew the cell origin back to (x,y) space
	local Y0 = j - t

	local x0 = x - X0 -- The x,y distances from the cell origin
	local y0 = y - Y0

	-- For the 2D case, the simplex shape is an equilateral triangle.
	-- Determine which simplex we are in.
	local i1, j1 -- Offsets for second (middle) corner of simplex in (i,j) coords
	if x0 > y0 then -- lower triangle, XY order: (0,0)->(1,0)->(1,1)
		i1 = 1
		j1 = 0
	else -- upper triangle, YX order: (0,0)->(0,1)->(1,1)
		i1 = 0
		j1 = 1
	end

	-- A step of (1,0) in (i,j) means a step of (1-c,-c) in (x,y), and
	-- a step of (0,1) in (i,j) means a step of (-c,1-c) in (x,y), where
	-- c = (3-sqrt(3))/6

	local x1 = x0 - i1 + spx_g2 -- Offsets for middle corner in (x,y) unskewed coords
	local y1 = y0 - j1 + spx_g2
	local x2 = x0 - 1.0 + 2.0 * spx_g2 -- Offsets for last corner in (x,y) unskewed coords
	local y2 = y0 - 1.0 + 2.0 * spx_g2

	-- Wrap the integer indices at 256, to avoid indexing perm[] out of bounds
	local ii = spx_mod(i, 255) + 1
	local jj = spx_mod(j, 255) + 1

	-- Calculate the contribution from the three corners
	local t0 = 0.5 - x0 * x0 - y0 * y0
	if t0 < 0 then
		n0 = 0
	else
		t0 = t0 * t0
		n0 = t0 * t0 * spx_grad2D(spx_permutations[ii + spx_permutations[jj]], x0, y0)
	end

	local t1 = 0.5 - x1 * x1 - y1 * y1
	if t1 < 0 then
		n1 = 0
	else
		t1 = t1 * t1
		n1 = t1 * t1 * spx_grad2D(spx_permutations[ii + i1 + spx_permutations[jj + j1]], x1, y1)
	end

	local t2 = 0.5 - x2 * x2 - y2 * y2
	if t2 < 0 then
		n2 = 0
	else
		t2 = t2 * t2
		n2 = t2 * t2 * spx_grad2D(spx_permutations[ii + 1 + spx_permutations[jj + 1]], x2, y2)
	end

	-- Add contributions from each corner to get the final noise value.
	-- The result is scaled to return values in the interval [-1,1].
	return 40 * (n0 + n1 + n2) -- TODO: The scale factor is preliminary!
end
LK3D.New_D_Print("Loaded Simplex (can cause crashes!)!", 2, "ProcTex")

-- https:--en.wikipedia.org/wiki/LK3D.ProcTex.Perlin_noise
LK3D.ProcTex.Perlin = LK3D.ProcTex.Perlin or {}
LK3D.ProcTex.Perlin.permutations = {
	151, 160, 137, 91, 90, 15, 131, 13, 201, 95, 96, 53, 194, 233, 7, 225, 140, 36,
	103, 30, 69, 142, 8, 99, 37, 240, 21, 10, 23, 190, 6, 148, 247, 120, 234, 75, 0,
	26, 197, 62, 94, 252, 219, 203, 117, 35, 11, 32, 57, 177, 33, 88, 237, 149, 56,
	87, 174, 20, 125, 136, 171, 168, 68, 175, 74, 165, 71, 134, 139, 48, 27, 166,
	77, 146, 158, 231, 83, 111, 229, 122, 60, 211, 133, 230, 220, 105, 92, 41, 55,
	46, 245, 40, 244, 102, 143, 54, 65, 25, 63, 161, 1, 216, 80, 73, 209, 76, 132,
	187, 208, 89, 18, 169, 200, 196, 135, 130, 116, 188, 159, 86, 164, 100, 109,
	198, 173, 186, 3, 64, 52, 217, 226, 250, 124, 123, 5, 202, 38, 147, 118, 126,
	255, 82, 85, 212, 207, 206, 59, 227, 47, 16, 58, 17, 182, 189, 28, 42, 223, 183,
	170, 213, 119, 248, 152, 2, 44, 154, 163, 70, 221, 153, 101, 155, 167, 43,
	172, 9, 129, 22, 39, 253, 19, 98, 108, 110, 79, 113, 224, 232, 178, 185, 112,
	104, 218, 246, 97, 228, 251, 34, 242, 193, 238, 210, 144, 12, 191, 179, 162,
	241, 81, 51, 145, 235, 249, 14, 239, 107, 49, 192, 214, 31, 181, 199, 106,
	157, 184, 84, 204, 176, 115, 121, 50, 45, 127, 4, 150, 254, 138, 236, 205,
	93, 222, 114, 67, 29, 24, 72, 243, 141, 128, 195, 78, 66, 215, 61, 156, 180
}

function LK3D.ProcTex.Perlin.randomGradient(x, y, seed)
	local rnd = LK3D.ProcTex.Perlin.permutations[(((x * 5453764) + (y * 56263) + (seed or 0)) % 256) + 1] % 256
	rnd = rnd / 256
	return Vector(math.sin(rnd), math.cos(rnd))
end
function LK3D.ProcTex.Perlin.dotGridGradient(ix, iy, x, y, seed)
	local grad = LK3D.ProcTex.Perlin.randomGradient(ix, iy, seed)
	return ((x - ix) * grad[1]) + ((y - iy) * grad[2])
end

-- googled smoothstep lua
local function smoothstep(t, a, b)
	return a + (b - a) * (t * t * t * (t * (t * 6 - 15) + 10))
end


function LK3D.ProcTex.Perlin.perlin(x, y, seed)
	local x0, y0 = math.floor(x), math.floor(y)
	local x1, y1 = x0 + 1, y0 + 1

	local sx, sy = x - x0, y - y0


	local n0 = LK3D.ProcTex.Perlin.dotGridGradient(x0, y0, x, y, seed)
	local n1 = LK3D.ProcTex.Perlin.dotGridGradient(x1, y0, x, y, seed)
	local ix0 = Lerp(sx, n0, n1)

	n0 = LK3D.ProcTex.Perlin.dotGridGradient(x0, y1, x, y, seed)
	n1 = LK3D.ProcTex.Perlin.dotGridGradient(x1, y1, x, y, seed)
	local ix1 = Lerp(sx, n0, n1)

	return Lerp(sy, ix0, ix1)
end
LK3D.New_D_Print("Loaded perlin!", 2, "ProcTex")


-- https:--en.wikipedia.org/wiki/Worley_noise
-- https:--thebookofshaders.com/12/
LK3D.ProcTex.Worley = LK3D.ProcTex.Worley or {}
local function v_f2(v)
	return Vector(math.floor(v[1]), math.floor(v[2]))
end
local function v_fract2(v)
	return Vector(v[1] - math.floor(v[1]), v[2] - math.floor(v[2]))
end

local function v_s2(v)
	return Vector(math.sin(v[1]), math.sin(v[2]))
end

function LK3D.ProcTex.Worley.random2(p)
	return v_fract2(v_s2(Vector(p:Dot(Vector(127.1,311.7)), p:Dot(Vector(269.5, 183.3)))) * 43758.5453)
end

function LK3D.ProcTex.Worley.worley(x, y, seed)
	local m_dist = 1
	local st = Vector(x + ((seed or 0) * ScrW()), y + ((seed or 0) * ScrH()))
	st:Div(ScrW(), ScrH())

	local i_st = v_f2(st)
	local f_st = v_fract2(st)
	local ttl = (3 * 3) - 1
	for i = 0, ttl do
		local xc = (i % 3) - 1
		local yc = math.floor(i / 3) - 1
		if not xc or not yc then
			return 100
		end

		local neighbor = Vector(xc, yc)

		local point = LK3D.ProcTex.Worley.random2(i_st + neighbor)

		local diff = neighbor + point - f_st

		m_dist = math.min(m_dist, diff:Length())
	end
	return m_dist
end
LK3D.New_D_Print("Loaded Worley!", 2, "ProcTex")


local valuens = {}
function valuens.random2(p)
	return v_fract2(v_s2(Vector(p:Dot(Vector(127.1,311.7)), p:Dot(Vector(269.5, 183.3)))) * 43758.5453)
end

function valuens.noise(x, y, seed)
	local fx = math.floor(x)
	local fy = math.floor(y)

	local ux = math.ceil(x)
	local uy = math.ceil(y)

	local decx = (x - fx)
	local decy = (y - fy)

	local valDL = valuens.random2(Vector(fx, fy))
	local valDR = valuens.random2(Vector(ux, fy))

	local valUL = valuens.random2(Vector(fx, uy))
	local valUR = valuens.random2(Vector(ux, uy))


	local rxu = Lerp(decx, valDL.x, valDR.x)
	local rxd = Lerp(decx, valUL.x, valUR.x)


	local final = Lerp(decy, rxu, rxd)

	return final

end
LK3D.New_D_Print("Loaded valueNoise!", 2, "ProcTex")

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
			local c_val = LK3D.ProcTex.Simplex.simplex2D(xc * sx, yc * sy, seed)
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
			local tl_val = LK3D.ProcTex.Simplex.simplex2D(xc * sx, yc * sy, seed)
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
			local c_val = LK3D.ProcTex.Perlin.perlin(xc / (32 * sx), yc / (32 * sy), seed)
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
			local tl_val = LK3D.ProcTex.Perlin.perlin(xc / (32 * sx), yc / (32 * sy), seed)
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
			local c_val = LK3D.ProcTex.Worley.worley(xc / (.25 * sx), yc / (.25 * sy), seed) * .5 + .5
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
			local c_val = LK3D.ProcTex.Worley.worley(xc / (.25 * sx), yc / (.25 * sy), seed) * .5 + .5
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
			local c_val = valuens.noise(xc / (.25 * sx), yc / (.25 * sy), seed) * .5 + .5
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

			local c_val = valuens.noise(xc / (.25 * sx), yc / (.25 * sy), seed) * .5 + .5
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
	blendif(from, to, 32 * sx, 32 * sy, treshold, seed, LK3D.ProcTex.Perlin.perlin)
end

function LK3D.ProcTex.WorleyMask(from, to, sx, sy, treshold, seed)
	blendif(from, to, .25 * sx, .25 * sy, treshold, seed, LK3D.ProcTex.Worley.worley)
end

function LK3D.ProcTex.SimplexMask(from, to, sx, sy, treshold, seed)
	blendif(from, to, .25 * sx, .25 * sy, treshold, seed, LK3D.ProcTex.Simplex.simplex2D)
end


function LK3D.ProcTex.TextureGenThink()
	LK3D.ProcTex.PixelItr = (196 / #LK3D.ProcTex.Coros)

	local toRem = {}
	for k, v in ipairs(LK3D.ProcTex.Coros) do
		local fine, ret = coroutine.resume(v)
		if not fine then
			toRem[#toRem + 1] = k
			LK3D.New_D_Print("ERROR: " .. ret, 4, "ProcTex")
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


-- TODO: Value noise (https:--en.wikipedia.org/wiki/Value_noise)
-- TODO: Simplex noise (https:--en.wikipedia.org/wiki/Simplex_noise)
-- TODO: Distortions (rotate, scale, persp, fractal distort)
-- TODO: Localized copying
-- TODO: algorithms for regular textures (bricks, tiles, sewers, etc)
-- TODO: edge det. algorithm (https:--en.wikipedia.org/wiki/Edge_detection)



-- LK3D.ProcTex.Perlin uses: https:--redirect.cs.umbc.edu/~olano/s2002c36/ch02.pdf


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


	local perlin_val0 = LK3D.ProcTex.Simplex.simplex2D(px * 2.12244, py * 2.2244, 413253) * 4
	local perlin_val1 = LK3D.ProcTex.Simplex.simplex2D((px + 41634) * 6.231, (py + 34634) * 6.236, 413253) * 1
	local perlin_val2 = LK3D.ProcTex.Simplex.simplex2D(px * 12.9782244, py * 12.786244, 413253) * 0.55

	local p_f = (perlin_val0 + perlin_val1 + perlin_val2) / 3
	p_f = (p_f + 1) / 2
	return getTerrCol(p_f) --Color(p_f, p_f, p_f)

	--local spx = LK3D.ProcTex.Simplex.simplex2D(xc / w, yc / h)
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

