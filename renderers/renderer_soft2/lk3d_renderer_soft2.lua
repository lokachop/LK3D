LK3D = LK3D or {}
local Renderer = {}

Renderer.PrettyName = "Software2 (pixel)"
Renderer.DO_PERSP_CORRECT_COLOUR   = true
Renderer.DO_PERSP_CORRECT_TEXTURE  = false

Renderer.TEXINTERP_MODE = 0 -- 0 = nearest, 1 = bayer, 2 = linear
Renderer.WIREFRAME = false
Renderer.RENDER_HALF = true

include("libs/lmat.lua")
include("libs/lvec.lua")
include("libs/lang.lua")

local CamMatrix_Rot = LMAT.Matrix()
local CamMatrix_Trans = LMAT.Matrix()
local CamMatrix_Proj = LMAT.Matrix()


local CamMatrix_Rot1 = LMAT.Matrix()
local CamMatrix_Rot2 = LMAT.Matrix()
local CamMatrix_Rot3 = LMAT.Matrix()

local function buildProjectionMatrix(aspect, near, far)
	CamMatrix_Proj:Identity()

	local scale = 1 / math.tan(math.rad(LK3D.FOV * 0.5))
	CamMatrix_Proj[ 1] = scale / aspect
	CamMatrix_Proj[ 6] = scale
	CamMatrix_Proj[11] = far / (far - near)
	CamMatrix_Proj[12] = far * near / (far - near)
	CamMatrix_Proj[15] = 1
	CamMatrix_Proj[16] = 0

	hasBuiltMatrix = true
end

local function updateMatrices()
	CamMatrix_Trans:SetTranslation(LVEC.Vector(LK3D.CamPos[1], -LK3D.CamPos[2], -LK3D.CamPos[3]))
	CamMatrix_Rot:SetAngles(LANG.Angle(-LK3D.CamAng.p + 90, 0, -LK3D.CamAng.y + 90))

	--CamMatrix_Rot1:SetAngles(LANG.Angle(-LK3D.CamAng.p + 90, 0, 0))
	--CamMatrix_Rot2:SetAngles(LANG.Angle(0, -LK3D.CamAng.y + 90, 0))
	--CamMatrix_Rot3:SetAngles(LANG.Angle(0, 0, 0))

	-- BAD!
	buildProjectionMatrix(ScrW() / ScrH(), LK3D.NEAR_Z, LK3D.FAR_Z)
end




local function scaleViewport(w, h, v)
	return (v[1] * w * .5) + (w * .5), (v[2] * h * .5) + (h * .5)
end

local function lerp(t, a, b)
	return a * (1 - t) + b * t
end

local function lerpVec(t, a, b)
	return LVEC.Vector(
		a[1] * (1 - t) + b[1] * t,
		a[2] * (1 - t) + b[2] * t,
		a[3] * (1 - t) + b[3] * t,
		a[4] * (1 - t) + b[4] * t
	)
end
local function lerpUV(t, a, b)
	return {
		a[1] * (1 - t) + b[1] * t,
		a[2] * (1 - t) + b[2] * t,
	}
end

local function lerpCol(t, a, b)
	return {
		a[1] * (1 - t) + b[1] * t,
		a[2] * (1 - t) + b[2] * t,
		a[3] * (1 - t) + b[3] * t,
	}
end

local function clip1(tbl, tbluv, tblCol, v1, v2, v3, uv1, uv2, uv3, c1, c2, c3)
	local alphaA = (-v1[3]) / (v2[3] - v1[3])
	local alphaB = (-v1[3]) / (v3[3] - v1[3])

	local v1o = lerpVec(alphaA, v1, v2)
	local v2o = lerpVec(alphaB, v1, v3)

	local uv1o = lerpUV(alphaA, uv1, uv2)
	local uv2o = lerpUV(alphaB, uv1, uv3)

	local c1o = lerpCol(alphaA, c1, c2)
	local c2o = lerpCol(alphaB, c1, c3)

	tbl[#tbl + 1] = {v1o, v2, v3}
	tbluv[#tbluv + 1] = {uv1o, uv2, uv3}
	tblCol[#tblCol + 1] = {c1o, c2, c3}

	tbl[#tbl + 1] = {v2o, v1o, v3}
	tbluv[#tbluv + 1] = {uv2o, uv1o, uv3}
	tblCol[#tblCol + 1] = {c2o, c1o, c3}
end

local function clip2(tbl, tbluv, tblCol, v1, v2, v3, uv1, uv2, uv3, c1, c2, c3)
	local alphaA = (-v1[3]) / ((v3[3] - v1[3]) + .00001) -- no div0
	local alphaB = (-v2[3]) / ((v3[3] - v2[3]) + .00001)

	local v1o = lerpVec(alphaA, v1, v3)
	local v2o = lerpVec(alphaB, v2, v3)

	local uv1o = lerpUV(alphaA, uv1, uv3)
	local uv2o = lerpUV(alphaB, uv2, uv3)

	local c1o = lerpCol(alphaA, c1, c3)
	local c2o = lerpCol(alphaB, c2, c3)

	tbl[#tbl + 1] = {v1o, v2o, v3}
	tbluv[#tbluv + 1] = {uv1o, uv2o, uv3}
	tblCol[#tblCol + 1] = {c1o, c2o, c3}
end

-- returns tbl of verts
local function clipTri(v1, v2, v3, uv1, uv2, uv3, c1, c2, c3)

	-- cull
	-- xGreater
	if  v1[1] < v1[4] and
		v2[1] < v2[4] and
		v3[1] < v3[4] then
		return
	end

	-- xLess
	if  v1[1] > -v1[4] and
		v2[1] > -v2[4] and
		v3[1] > -v3[4] then
		return
	end

	-- yGreater
	if  v1[2] < v1[4] and
		v2[2] < v2[4] and
		v3[2] < v3[4] then
		return
	end

	-- yLess
	if  v1[2] > -v1[4] and
		v2[2] > -v2[4] and
		v3[2] > -v3[4] then
		return
	end

	local v1z = -v1[3]
	local v2z = -v2[3]
	local v3z = -v3[3]

	--if v1z < 0 and v2z < 0 and v3z < 0 then
	--	return
	--end

	local tblOut = {}
	local tblUV = {}
	local tblCol = {}
	-- near plane
	if v1z < 0 then
		if v2z < 0 then
			clip2(tblOut, tblUV, tblCol, v1, v2, v3, uv1, uv2, uv3, c1, c2, c3)
		elseif v3z < 0 then
			clip2(tblOut, tblUV, tblCol, v1, v3, v2, uv1, uv3, uv2, c1, c3, c2)
		else
			clip1(tblOut, tblUV, tblCol, v1, v2, v3, uv1, uv2, uv3, c1, c2, c3)
		end
	elseif v2z < 0 then
		if v3z < 0 then
			clip2(tblOut, tblUV, tblCol, v2, v3, v1, uv2, uv3, uv1, c2, c3, c1)
		else
			clip1(tblOut, tblUV, tblCol, v2, v1, v3, uv2, uv1, uv3, c2, c1, c3)
		end
	elseif v3z < 0 then
		clip1(tblOut, tblUV, tblCol, v3, v1, v2, uv3, uv1, uv2, c3, c1, c2)
	else
		tblOut[#tblOut + 1] = {v1, v2, v3}
		tblUV[#tblUV + 1] = {uv1, uv2, uv3}
		tblCol[#tblCol + 1] = {c1, c2, c3}
	end

	return tblOut, tblUV, tblCol
end


local function t_tri(x0, y0, u0, v0, x1, y1, u1, v1, x2, y2, u2, v2)
	if LK3D.WireFrame then
		surface.DrawLine(x0, y0, x1, y1)
		surface.DrawLine(x1, y1, x2, y2)
		surface.DrawLine(x2, y2, x0, y0)
		return
	end

	--x0 = math.Clamp(x0, 0, ScrW())
	--y0 = math.Clamp(y0, 0, ScrH())

	--x1 = math.Clamp(x1, 0, ScrW())
	--y1 = math.Clamp(y1, 0, ScrH())

	--x2 = math.Clamp(x2, 0, ScrW())
	--y2 = math.Clamp(y2, 0, ScrH())

	local tri = {
		{x = x0, y = y0, u = u0, v = v0},
		{x = x1, y = y1, u = u1, v = v1},
		{x = x2, y = y2, u = u2, v = v2},
	}

	surface.DrawPoly(tri)

	local tri2 = {
		{x = x2, y = y2, u = u2, v = v2},
		{x = x1, y = y1, u = u1, v = v1},
		{x = x0, y = y0, u = u0, v = v0},
	}
	surface.DrawPoly(tri2)
end

local _v0 = {0, 0}
local _v1 = {0, 0}
local _v2 = {0, 0}

local _d00, _d01, _d11, _d20, _d21 = 0, 0, 0, 0, 0
local function baryCentric(px, py, ax, ay, bx, by, cx, cy)
	_v0[1] = bx - ax
	_v0[2] = by - ay

	_v1[1] = cx - ax
	_v1[2] = cy - ay

	_v2[1] = px - ax
	_v2[2] = py - ay


	_d00 = _v0[1] * _v0[1] + _v0[2] * _v0[2]

	_d01 = _v0[1] * _v1[1] + _v0[2] * _v1[2]


	_d11 = _v1[1] * _v1[1] + _v1[2] * _v1[2]


	_d20 = _v2[1] * _v0[1] + _v2[2] * _v0[2]


	_d21 = _v2[1] * _v1[1] + _v2[2] * _v1[2]

	local denom = _d00 * _d11 - _d01 * _d01
	local v = (_d11 * _d20 - _d01 * _d21) / denom
	local w = (_d00 * _d21 - _d01 * _d20) / denom
	local u = 1 - v - w

	return v, w, u
end

local math = math
local math_floor = math.floor

local dBuff = {}

local _TEX_NEAREST = 1
local _TEX_BAYER = 2
local _TEX_LINEAR = 3
local texMode = _TEX_NEAREST

local _table = {255, 0, 0}
local function renderTriangleSimple(x0, y0, x1, y1, x2, y2, c0, c1, c2, v0_w, v1_w, v2_w, u0, v0, u1, v1, u2, v2, tdata)
	local rtW = ScrW()
	local rtH = ScrH()

	local minX = math.min(x0, x1, x2)
	local minY = math.min(y0, y1, y2)
	local maxX = math.max(x0, x1, x2)
	local maxY = math.max(y0, y1, y2)

	minX = math.max(minX, 0)
	minY = math.max(minY, 0)
	maxX = math.min(maxX, rtW - 1)
	maxY = math.min(maxY, rtH - 1)

	local texW, texH = 32, 32

	local ow, oh = ScrW(), ScrH()
	for y = minY, maxY do
		for x = minX, maxX do
			--x, y = math_round(x), math_round(y)
			x, y = math_floor(x + .5), math_floor(y + .5)

			--if true and ((x + y) + FrameNumber()) % 2 == 0 then
			--	continue
			--end


			local w1, w2, w0 = baryCentric(x + .5, y + .5, x0, y0, x1, y1, x2, y2)

			if w0 < 0 or w1 < 0 or w2 < 0 then
				continue
			end

			local wCalc = -((w0 * v0_w) + (w1 * v1_w) + (w2 * v2_w))
			local dCalc = (1 / wCalc)

			local prev = dBuff[x + (y * rtW)] or math.huge
			if (dCalc < prev) then
				local negW = -wCalc
				local uCalc = ((w0 * u0) + (w1 * u1) + (w2 * u2))
				local vCalc = ((w0 * v0) + (w1 * v1) + (w2 * v2))

				if perspTex then
					uCalc = uCalc / negW
					vCalc = vCalc / negW
				end

				local tCol = _table
				if texMode == _TEX_NEAREST then
					local tu = math_floor(texW * uCalc) % texW
					local tv = math_floor(texH * vCalc) % texH

					--tCol = {255, 0, 0}--tdata[tu + (tv * texW)]
					tCol = {tu * 255, tv * 255, 0}
				elseif texMode == _TEX_BAYER then
					local bayerIdx = (x % 4) + ((y % 4) * 4) + 1

					local tu = math_floor((texW * uCalc) + bayer4[bayerIdx]) % texW
					local tv = math_floor((texH * vCalc) + bayer4[bayerIdx]) % texH

					tCol = {255, 0, 0} --tdata[tu + (tv * texW)]
				elseif texMode == _TEX_LINEAR then
					local du = (texW * uCalc) % 1
					local dv = (texH * vCalc) % 1


					local tu = math_floor(texW * uCalc) % texW
					local tv = math_floor(texH * vCalc) % texH

					local tu_a = math_floor((texW * uCalc) + 1) % texW
					local tv_a = math_floor((texH * vCalc) + 1) % texH


					local sp_tl = {255, 0, 0}--tdata[tu + (tv * texW)]
					local sp_tr = {0, 255, 0}--tdata[tu_a + (tv * texW)]

					local sp_bl = {255, 0, 255}--tdata[tu + (tv_a * texW)]
					local sp_br = {0, 255, 255}--tdata[tu_a + (tv_a * texW)]


					local _lerpH_T = {lerp(du, sp_tl[1], sp_tr[1]), lerp(du, sp_tl[2], sp_tr[2]), lerp(du, sp_tl[3], sp_tr[3])}
					local _lerpH_B = {lerp(du, sp_bl[1], sp_br[1]), lerp(du, sp_bl[2], sp_br[2]), lerp(du, sp_bl[3], sp_br[3])}


					tCol = {lerp(dv, _lerpH_T[1], _lerpH_B[1]), lerp(dv, _lerpH_T[2], _lerpH_B[2]), lerp(dv, _lerpH_T[3], _lerpH_B[3])}

					--local _t_data = tdata[tu + (tv * texW)]
					--tCol = {_t_data[1] + (du * 64), _t_data[2] + (dv * 64), _t_data[3]}
				end

				local rCalc = ((w0 * c0[1]) + (w1 * c1[1]) + (w2 * c2[1]))
				local gCalc = ((w0 * c0[2]) + (w1 * c1[2]) + (w2 * c2[2]))
				local bCalc = ((w0 * c0[3]) + (w1 * c1[3]) + (w2 * c2[3]))

				if perspCol then
					rCalc = rCalc / negW
					gCalc = gCalc / negW
					bCalc = bCalc / negW
				end

				--rt[x + (y * rtW)] = {tCol[1] * rCalc, tCol[2] * gCalc, tCol[3] * bCalc}
				render.SetViewPort(math.floor(x), math.floor(y), 1, 1)
				render.Clear(tCol[1] * rCalc, tCol[2] * rCalc, tCol[3] * rCalc, 255)
				--render.Clear((x / ScrW()) * 255, (y / ScrH()) * 255, 0, 255)

				dBuff[x + (y * rtW)] = dCalc

				-- overdraw test
				--local contPrev = rt[x + (y * rtW)]
				--local _add = 16
				--rt[x + (y * rtW)] = {contPrev[1] + _add, contPrev[2] + _add, contPrev[3] + _add}

				-- zbuffer see
				-- local dCol = dCalc * 16
				-- rt[x + (y * rtW)] = {dCol, dCol, dCol}
			end
		end
	end

	render.SetViewPort(0, 0, ow, oh)
end



local function renderModel(obj)
	local w, h = ScrW(), ScrH()


	local mdlData = LK3D.Models[obj.mdl]
	local verts = mdlData.verts
	local indices = mdlData.indices
	local normals = mdlData.normals
	local s_normals = mdlData.s_normals
	local uvs = mdlData.uvs


	local col = obj.col
	local objColR = col.r
	local objColG = col.g
	local objColB = col.b

	--local textureData = LKTEX.Textures[obj.mat]


	-- transform the verts
	local transf = {}

	local realScl = Vector(obj.scl[1], obj.scl[3], obj.scl[2])
	for i = 1, #verts do
		local vert = verts[i]
		local cpy = Vector(vert) --LVEC.Vector(vert[1], vert[2], vert[3])
		--print(cpy)
		-- local
		--cpy = cpy * obj.mat_rot
		--cpy = cpy * obj.mat_transscl
		cpy:Rotate(obj.ang)
		cpy = cpy * realScl
		cpy = cpy + obj.pos
		--cpy = obj.tmatrix * cpy
		cpy = LVEC.Vector(-cpy[1], cpy[2], cpy[3])

		-- TODO: implement cam matrix
		local transRot = (CamMatrix_Rot) * CamMatrix_Trans
		cpy = cpy * transRot

		transf[#transf + 1] = cpy
	end


	local zsort = {}
	for i = 1, #indices do
		local idx = indices[i]

		local v1 = transf[idx[1][1]]
		local v2 = transf[idx[2][1]]
		local v3 = transf[idx[3][1]]

		local avgZ = (v1[3] + v2[3] + v3[3]) * .33

		zsort[#zsort + 1] = {i, -avgZ}
	end

	table.sort(zsort, function(a, b)
		return a[2] < b[2]
	end)


	for b = 1, #zsort do
		local i = zsort[b][1]
		local idx = indices[i]

		local v1 = transf[idx[1][1]]
		local v2 = transf[idx[2][1]]
		local v3 = transf[idx[3][1]]

		local puv1 = uvs[idx[1][2]]
		local puv2 = uvs[idx[2][2]]
		local puv3 = uvs[idx[3][2]]


		local v1s = v1:Copy() * CamMatrix_Proj
		local v2s = v2:Copy() * CamMatrix_Proj
		local v3s = v3:Copy() * CamMatrix_Proj


		local pcol_s1 = {objColR, objColG, objColB}
		local pcol_s2 = {objColR, objColG, objColB}
		local pcol_s3 = {objColR, objColG, objColB}

		if obj["SHADING"] and obj["SHADING_SMOOTH"] then
			local norm1 = s_normals[idx[1][1]]:Copy()
			norm1 = norm1 * obj.mat_rot

			local norm2 = s_normals[idx[2][1]]:Copy()
			norm2 = norm2 * obj.mat_rot

			local norm3 = s_normals[idx[3][1]]:Copy()
			norm3 = norm3 * obj.mat_rot

			local dot1 = norm1:Dot(LK3D.SunDir)
			local dot2 = norm2:Dot(LK3D.SunDir)
			local dot3 = norm3:Dot(LK3D.SunDir)

			dot1 = math.max((dot1 + 2) * .25, 0)
			dot2 = math.max((dot2 + 2) * .25, 0)
			dot3 = math.max((dot3 + 2) * .25, 0)

			pcol_s1[1] = pcol_s1[1] * dot1
			pcol_s1[2] = pcol_s1[2] * dot1
			pcol_s1[3] = pcol_s1[3] * dot1

			pcol_s2[1] = pcol_s2[1] * dot2
			pcol_s2[2] = pcol_s2[2] * dot2
			pcol_s2[3] = pcol_s2[3] * dot2

			pcol_s3[1] = pcol_s3[1] * dot3
			pcol_s3[2] = pcol_s3[2] * dot3
			pcol_s3[3] = pcol_s3[3] * dot3
		elseif obj["SHADING"] then
			local norm = normals[i]:Copy()
			norm = norm * obj.mat_rot

			local dot = norm:Dot(LK3D.SunDir)
			dot = math.max((dot + 2) * .25, 0)

			pcol_s1[1] = pcol_s1[1] * dot
			pcol_s1[2] = pcol_s1[2] * dot
			pcol_s1[3] = pcol_s1[3] * dot

			pcol_s2[1] = pcol_s2[1] * dot
			pcol_s2[2] = pcol_s2[2] * dot
			pcol_s2[3] = pcol_s2[3] * dot

			pcol_s3[1] = pcol_s3[1] * dot
			pcol_s3[2] = pcol_s3[2] * dot
			pcol_s3[3] = pcol_s3[3] * dot
		end



		-- lets do clipping!
		local tris, uvs, cols = clipTri(v1s, v2s, v3s, puv1, puv2, puv3, pcol_s1, pcol_s2, pcol_s3)
		if not tris then
			continue
		end

		for j = 1, #tris do
			local trisC = tris[j]
			local uvsC = uvs[j]
			local colsC = cols[j]
			--local cv1, cv2, cv3 = trisC[1], trisC[2], trisC[3]
			local cv1 = trisC[1]:Copy()
			local cv2 = trisC[2]:Copy()
			local cv3 = trisC[3]:Copy()

			cv1:Div(cv1[4]) -- div by w here
			cv2:Div(cv2[4])
			cv3:Div(cv3[4])

			local uv1 = uvsC[1]
			local uv2 = uvsC[2]
			local uv3 = uvsC[3]


			local d1s, d2s, d3s = cv1[3], cv2[3], cv3[3]
			if (d1s >= 1) or (d2s >= 1) or (d3s >= 1) then
				continue
			end

			local d1, d2, d3 = cv1[4], cv2[4], cv3[4]

			local v1_w = 1 / d1
			local v2_w = 1 / d2
			local v3_w = 1 / d3

			local px1, py1 = scaleViewport(w, h, cv1)
			local px2, py2 = scaleViewport(w, h, cv2)
			local px3, py3 = scaleViewport(w, h, cv3)

			local norm = Vector(normals[i])
			norm:Rotate(-obj.ang)
			norm = LVEC.Vector(norm[1], norm[2], norm[3])

			local normCam = norm:Copy()
			normCam = normCam * CamMatrix_Rot

			local dotCam = normCam:Dot(v1)
			if dotCam < 0 then
				continue
			end


			local tu1, tv1 = uv1[1], uv1[2]
			local tu2, tv2 = uv2[1], uv2[2]
			local tu3, tv3 = uv3[1], uv3[2]
			if perspTex then
				tu1, tv1 = tu1 / d1, tv1 / d1
				tu2, tv2 = tu2 / d2, tv2 / d2
				tu3, tv3 = tu3 / d3, tv3 / d3
			end

			local col_s1, col_s2, col_s3

			if perspCol then
				col_s1 = {colsC[1][1], colsC[1][2], colsC[1][3]}
				col_s1[1] = col_s1[1] / d1
				col_s1[2] = col_s1[2] / d1
				col_s1[3] = col_s1[3] / d1

				col_s2 = {colsC[2][1], colsC[2][2], colsC[2][3]}
				col_s2[1] = col_s2[1] / d2
				col_s2[2] = col_s2[2] / d2
				col_s2[3] = col_s2[3] / d2

				col_s3 = {colsC[3][1], colsC[3][2], colsC[3][3]}
				col_s3[1] = col_s3[1] / d3
				col_s3[2] = col_s3[2] / d3
				col_s3[3] = col_s3[3] / d3
			else
				col_s1 = colsC[1]
				col_s2 = colsC[2]
				col_s3 = colsC[3]
			end

			--FLK3D.RenderTriangleSimple(px1, py1, px2, py2, px3, py3,
			--col_s1, col_s2, col_s3,
			--v1_w, v2_w, v3_w,
			--tu1, tv1, tu2, tv2, tu3, tv3, textureData
			--)

			local textureData = {}
			renderTriangleSimple(
				px1, py1, px2, py2, px3, py3,
				col_s1, col_s2, col_s3,
				v1_w, v2_w, v3_w,
				tu1, tv1, tu2, tv2, tu3, tv3, textureData
			)

			--surface.SetDrawColor(col_s1, col_s2, col_s3)
			--surface.SetMaterial(LK3D.Textures[obj.mat].mat)

			--t_tri(
			--	px1, py1, tu1, tv1,
			--	px2, py2, tu2, tv2,
			--	px3, py3, tu3, tv3
			--)

			--t_tri(
			--	px3, py3, tu3, tv3,
			--	px2, py2, tu2, tv2,
			--	px1, py1, tu1, tv1
			--)
		end
	end

end


local ScreenSzStack = {}
local function insScreenSz()
	ScreenSzStack[#ScreenSzStack + 1] = {ScrW(), ScrH()}
end

local function popScreenSz()
	local val = table.remove(ScreenSzStack, 1)
	return val[1], val[2]
end



local function beginView()
	insScreenSz()

	local crt = LK3D.CurrRenderTarget
	local rtw, rth = crt:Width(), crt:Height()
	render.SetViewPort(0, 0, rtw, rth)
	cam.Start2D()
	render.PushRenderTarget(crt)
	render.PushFilterMag(LK3D.FilterMode)
	render.PushFilterMin(LK3D.FilterMode)
end

local function endView()
	local ow, oh = popScreenSz()
	render.PopFilterMag()
	render.PopFilterMin()
	render.PopRenderTarget()
	cam.End2D()
	render.SetViewPort(0, 0, ow, oh)
end

local function shouldRender(obj)
	if obj["RENDER_NOGLOBAL"] then
		return false
	end

	return true
end

-- this function should take the currently active universe and render all the objects in it to the active rendertarget on the camera position with the camera angles
function Renderer.Render()
	dBuff = {} -- clear depth buffer HACKY
	local currUniv = LK3D.CurrUniv
	updateMatrices()

	beginView()
		for k, v in pairs(currUniv["objects"]) do
			if not shouldRender(v) then
				continue
			end

			local fine, err = pcall(renderModel, v)
			if not fine then
				LK3D.New_D_Print("Error rendering model \"" .. k .. "\" on universe \"" .. currUniv.tag .. "\": " .. err, LK3D_SEVERITY_ERROR, "Software2")
				break
			end
		end
	endView()
end



local id = LK3D.DeclareRenderer(Renderer)
LK3D_RENDER_SOFT2 = id