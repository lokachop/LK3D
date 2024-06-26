--[[--
## Noise Module
---

Module that provides a bunch of noise functions  
For use with procedural generation / texturing  
]]
-- @module noise
LK3D = LK3D or {}
LK3D.New_D_Print("Loading!", LK3D_SEVERITY_INFO, "Noise")


-- https://github.com/WardBenjamin/SimplexNoise/blob/master/SimplexNoise/Noise.cs
local simplex_permutations = {
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

local simplex_f2 = .5 * (math.sqrt(3) - 1)
local simplex_g2 = (3 - math.sqrt(3)) / 6
local function simplex_grad2D(seed, x, y)
	local h = bit.band(seed, 7)      -- Convert low 3 bits of hash code
	local u = h < 4 and x or y  -- into 8 simple gradient directions,
	local v = h < 4 and y or x  -- and compute the dot product with (x,y).
	return (bit.band(h, 1) ~= 0 and -u or u) + (bit.band(h, 2) ~= 0 and -2.0 * v or 2.0 * v)
end
local function simplex_mod(x, m)
	local a = x % m;
	return a < 0 and a + m or a;
end

--- Calculates 2D [Simplex noise](https://en.wikipedia.org/wiki/Simplex_noise)
-- @tparam number x X Position
-- @tparam number y Y Position
-- @tparam number seed Seed (to randomize)
-- @treturn number Noise value (-1 to 1)
-- @usage LK3D.Simplex2D(32, 64, 52623)
function LK3D.Simplex2D(x, y, seed)
	local n0, n1, n2 = 0, 0, 0

	local s = (x + y) * simplex_f2
	local xs = x + s
	local ys = y + s

	local i = math.floor(xs)
	local j = math.floor(ys)


	local t = (i + j) * simplex_g2

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

	local x1 = x0 - i1 + simplex_g2 -- Offsets for middle corner in (x,y) unskewed coords
	local y1 = y0 - j1 + simplex_g2
	local x2 = x0 - 1.0 + 2.0 * simplex_g2 -- Offsets for last corner in (x,y) unskewed coords
	local y2 = y0 - 1.0 + 2.0 * simplex_g2

	-- Wrap the integer indices at 256, to avoid indexing perm[] out of bounds
	local ii = simplex_mod(i, 255) + 1
	local jj = simplex_mod(j, 255) + 1

	-- Calculate the contribution from the three corners
	local t0 = 0.5 - x0 * x0 - y0 * y0
	if t0 < 0 then
		n0 = 0
	else
		t0 = t0 * t0
		n0 = t0 * t0 * simplex_grad2D(simplex_permutations[ii + simplex_permutations[jj]], x0, y0)
	end

	local t1 = 0.5 - x1 * x1 - y1 * y1
	if t1 < 0 then
		n1 = 0
	else
		t1 = t1 * t1
		n1 = t1 * t1 * simplex_grad2D(simplex_permutations[ii + i1 + simplex_permutations[jj + j1]], x1, y1)
	end

	local t2 = 0.5 - x2 * x2 - y2 * y2
	if t2 < 0 then
		n2 = 0
	else
		t2 = t2 * t2
		n2 = t2 * t2 * simplex_grad2D(simplex_permutations[ii + 1 + simplex_permutations[jj + 1]], x2, y2)
	end

	-- Add contributions from each corner to get the final noise value.
	-- The result is scaled to return values in the interval [-1,1].
	return 40 * (n0 + n1 + n2) -- TODO: The scale factor is preliminary!
end
LK3D.New_D_Print("Loaded Simplex (can cause crashes!)!", LK3D_SEVERITY_INFO, "Noise")



local perlin_permutations = {
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

local function perlin_randomGradient(x, y, seed)
	local rnd = perlin_permutations[(((x * 5453764) + (y * 56263) + (seed or 0)) % 256) + 1] % 256
	rnd = rnd / 256
	return Vector(math.sin(rnd), math.cos(rnd))
end

local function perlin_dotGridGradient(ix, iy, x, y, seed)
	local grad = perlin_randomGradient(ix, iy, seed)
	return ((x - ix) * grad[1]) + ((y - iy) * grad[2])
end

--- Calculates 2D [Perlin noise](https://en.wikipedia.org/wiki/Perlin_noise)
-- @tparam number x X Position
-- @tparam number y Y Position
-- @tparam number seed Seed (to randomize)
-- @treturn number Noise value (-1 to 1)
-- @usage LK3D.Perlin2D(32, 64, 52623)
function LK3D.Perlin2D(x, y, seed)
	local x0, y0 = math.floor(x), math.floor(y)
	local x1, y1 = x0 + 1, y0 + 1

	local sx, sy = x - x0, y - y0


	local n0 = perlin_dotGridGradient(x0, y0, x, y, seed)
	local n1 = perlin_dotGridGradient(x1, y0, x, y, seed)
	local ix0 = Lerp(sx, n0, n1)

	n0 = perlin_dotGridGradient(x0, y1, x, y, seed)
	n1 = perlin_dotGridGradient(x1, y1, x, y, seed)
	local ix1 = Lerp(sx, n0, n1)

	return Lerp(sy, ix0, ix1)
end
LK3D.New_D_Print("Loaded perlin!", LK3D_SEVERITY_INFO, "Noise")



-- https://thebookofshaders.com/12/
local function worley_v_f2(v)
	return Vector(math.floor(v[1]), math.floor(v[2]))
end
local function worley_v_fract2(v)
	return Vector(v[1] - math.floor(v[1]), v[2] - math.floor(v[2]))
end

local function worley_v_s2(v)
	return Vector(math.sin(v[1]), math.sin(v[2]))
end

local function worley_random2(p)
	return worley_v_fract2(worley_v_s2(Vector(p:Dot(Vector(127.1,311.7)), p:Dot(Vector(269.5, 183.3)))) * 43758.5453)
end

--- Calculates 2D [Worley noise](https://en.wikipedia.org/wiki/Worley_noise)
-- @tparam number x X Position
-- @tparam number y Y Position
-- @tparam number seed Seed (to randomize)
-- @treturn number Noise value (0 to 1)
-- @usage LK3D.Worley2D(32, 64, 52623)
function LK3D.Worley2D(x, y, seed)
	local m_dist = 1
	local st = Vector(x + ((seed or 0) * ScrW()), y + ((seed or 0) * ScrH()))
	st:Div(ScrW(), ScrH())

	local i_st = worley_v_f2(st)
	local f_st = worley_v_fract2(st)
	local ttl = (3 * 3) - 1
	for i = 0, ttl do
		local xc = (i % 3) - 1
		local yc = math.floor(i / 3) - 1
		if not xc or not yc then
			return 100
		end

		local neighbor = Vector(xc, yc)

		local point = worley_random2(i_st + neighbor)

		local diff = neighbor + point - f_st

		m_dist = math.min(m_dist, diff:Length())
	end
	return m_dist
end
LK3D.New_D_Print("Loaded Worley!", LK3D_SEVERITY_INFO, "Noise")




local function value_random2(p)
	return worley_v_fract2(worley_v_s2(Vector(p:Dot(Vector(127.1,311.7)), p:Dot(Vector(269.5, 183.3)))) * 43758.5453)
end

--- Calculates 2D [Value noise](https://en.wikipedia.org/wiki/Value_noise)
-- @tparam number x X Position
-- @tparam number y Y Position
-- @tparam number seed Seed (to randomize)
-- @treturn number Noise value (-1 to 1)
-- @usage LK3D.ValueNoise2D(32, 64, 52623)
function LK3D.ValueNoise2D(x, y, seed)
	local fx = math.floor(x)
	local fy = math.floor(y)

	local ux = math.ceil(x)
	local uy = math.ceil(y)

	local decx = (x - fx)
	local decy = (y - fy)

	local valDL = value_random2(Vector(fx, fy))
	local valDR = value_random2(Vector(ux, fy))

	local valUL = value_random2(Vector(fx, uy))
	local valUR = value_random2(Vector(ux, uy))


	local rxu = Lerp(decx, valDL.x, valDR.x)
	local rxd = Lerp(decx, valUL.x, valUR.x)


	local final = Lerp(decy, rxu, rxd)

	return final
end
LK3D.New_D_Print("Loaded valueNoise!", LK3D_SEVERITY_INFO, "Noise")
