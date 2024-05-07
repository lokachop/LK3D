LK3D = LK3D or {}
LK3D.Radiosa = LK3D.Radiosa or {}

local math = math
local math_abs = math.abs
local math_floor = math.floor
local math_min = math.min



-- returns a table that merges matching verts for perf
local concat_tbl_vert = {}
concat_tbl_vert[1] = "x"
concat_tbl_vert[3] = "y"
concat_tbl_vert[5] = "z"

local concat_round = 4
local function hashVec(v)
	concat_tbl_vert[2] = math.Round(v[1], concat_round)
	concat_tbl_vert[4] = math.Round(v[2], concat_round)
	concat_tbl_vert[6] = math.Round(v[3], concat_round)

	return table.concat(concat_tbl_vert, "")
end


local concat_tbl_edge = {}
concat_tbl_edge[2] = ":EDGE:"
local function hashEdge(v1, v2)
	concat_tbl_edge[1] = hashVec(v1)
	concat_tbl_edge[3] = hashVec(v2)
	return table.concat(concat_tbl_edge, "")
end


local function getLongestEdge(tri)
	local v1 = tri[1]
	local v2 = tri[2]
	local v3 = tri[3]

	local v1p = v1.pos
	local v2p = v2.pos
	local v3p = v3.pos


	local lenE1 = v1p:Distance(v2p)
	local lenE2 = v2p:Distance(v3p)
	local lenE3 = v3p:Distance(v1p)

	-- Get its longest edge
	local longest = math.max(lenE1, lenE2, lenE3)

	local vertPair = {v1p, v2p}
	if longest == lenE2 then
		vertPair = {v2p, v3p}
	elseif longest == lenE3 then
		vertPair = {v3p, v1p}
	end


	return longest, vertPair
end

local function matchingEdgePairs(pair1, pair2)
	--local hash1 = hashEdge(pair1[1], pair1[2])
	--local hash2 = hashEdge(pair2[1], pair2[2])

	--local hash3 = hashEdge(pair1[2], pair1[1])

	--local match1 = hash1 == hash2
	--local match2 = hash3 == hash2

	local match1 = pair1[1] == pair2[1] and pair1[2] == pair2[2]
	local match2 = pair1[1] == pair2[2] and pair1[2] == pair2[1]

	return match1 or match2 --or match2
end




local function triToUVNoOffset(tri)
	local v1 = tri[1]
	local v2 = tri[2]
	local v3 = tri[3]

	local v1pos = v1.pos
	local v2pos = v2.pos
	local v3pos = v3.pos


	local norm = tri[1].norm
	norm:Normalize()


	local uv1 = {0, 0}
	local uv2 = {0, 0}
	local uv3 = {0, 0}

	-- https://web.archive.org/web/20071024115118/http://www.flipcode.org/cgi-bin/fcarticles.cgi?show=64423
	local density = LK3D.Radiosa.LIGHTMAP_TRI_SZ
	if (math_abs(norm[1]) > math_abs(norm[2])) and (math_abs(norm[1]) > math_abs(norm[3])) then
		uv1 = {v1pos[3] * density, -v1pos[2] * density}
		uv2 = {v2pos[3] * density, -v2pos[2] * density}
		uv3 = {v3pos[3] * density, -v3pos[2] * density}
	elseif (math_abs(norm[2]) > math_abs(norm[1])) and (math_abs(norm[2]) > math_abs(norm[3])) then
		uv1 = {v1pos[1] * density, -v1pos[3] * density}
		uv2 = {v2pos[1] * density, -v2pos[3] * density}
		uv3 = {v3pos[1] * density, -v3pos[3] * density}
	elseif (math_abs(norm[1]) > math_abs(norm[3])) and (math_abs(norm[2]) > math_abs(norm[3])) then -- this is BAD
		uv1 = {v1pos[2] * density, -v1pos[3] * density}
		uv2 = {v2pos[2] * density, -v2pos[3] * density}
		uv3 = {v3pos[2] * density, -v3pos[3] * density}
	else
		uv1 = {v1pos[1] * density, -v1pos[2] * density}
		uv2 = {v2pos[1] * density, -v2pos[2] * density}
		uv3 = {v3pos[1] * density, -v3pos[2] * density}
	end


	--uv1 = {v1pos[1] * density, v1pos[2] * density}
	--uv2 = {v2pos[1] * density, v2pos[2] * density}
	--uv3 = {v3pos[1] * density, v3pos[2] * density}

	return uv1, uv2, uv3
end


local function triToUV(tri)
	local uv1, uv2, uv3 = triToUVNoOffset(tri)

	local min_u = math_min(uv1[1], uv2[1], uv3[1])
	local min_v = math_min(uv1[2], uv2[2], uv3[2])


	uv1 = {uv1[1] - min_u, uv1[2] - min_v}
	uv2 = {uv2[1] - min_u, uv2[2] - min_v}
	uv3 = {uv3[1] - min_u, uv3[2] - min_v}

	return uv1, uv2, uv3
end

local function quadToUV(quad)
	local tri1 = quad[1]
	local tri2 = quad[2]
	--print("-------------1-----------------")
	--print(tri1[1].hash_pos, tri1[2].hash_pos, tri1[3].hash_pos)
	--print("-------------2-----------------")
	--print(tri2[1].hash_pos, tri2[2].hash_pos, tri2[3].hash_pos)

	--print(tri1 == tri2)

	local tri1_uv1, tri1_uv2, tri1_uv3 = triToUVNoOffset(tri1)
	local tri2_uv1, tri2_uv2, tri2_uv3 = triToUVNoOffset(tri2)

	local min_u = math_min(tri1_uv1[1], tri1_uv2[1], tri1_uv3[1],   tri2_uv1[1], tri2_uv2[1], tri2_uv3[1])
	local min_v = math_min(tri1_uv1[2], tri1_uv2[2], tri1_uv3[2],   tri2_uv1[2], tri2_uv2[2], tri2_uv3[2])

	tri1_uv1 = {tri1_uv1[1] - min_u, tri1_uv1[2] - min_v}
	tri1_uv2 = {tri1_uv2[1] - min_u, tri1_uv2[2] - min_v}
	tri1_uv3 = {tri1_uv3[1] - min_u, tri1_uv3[2] - min_v}


	tri2_uv1 = {tri2_uv1[1] - min_u, tri2_uv1[2] - min_v}
	tri2_uv2 = {tri2_uv2[1] - min_u, tri2_uv2[2] - min_v}
	tri2_uv3 = {tri2_uv3[1] - min_u, tri2_uv3[2] - min_v}

	return tri1_uv1, tri1_uv2, tri1_uv3, tri2_uv1, tri2_uv2, tri2_uv3
end

local EPSILON_VERT = 0.0001
local function matching_vertices(v1, v2)
	return v1:DistToSqr(v2) < EPSILON_VERT
end



local function getMatchingVertexCount(tri1, tri2)
	local tri1_v1 = tri1[1].pos
	local tri1_v2 = tri1[2].pos
	local tri1_v3 = tri1[3].pos

	local tri2_v1 = tri2[1].pos
	local tri2_v2 = tri2[2].pos
	local tri2_v3 = tri2[3].pos


	local to_check = {
		tri1_v1,
		tri1_v2,
		tri1_v3
	}

	local counter = 0
	for i = 1, #to_check do
		local vert = to_check[i]

		if matching_vertices(vert, tri2_v1) then
			counter = counter + 1
		end

		if matching_vertices(vert, tri2_v2) then
			counter = counter + 1
		end

		if matching_vertices(vert, tri2_v3) then
			counter = counter + 1
		end
	end


	return counter
end





-- Returns a table of tris to be fed into the UV Packer algorithm
-- triList: the returned value of LK3D.Radiosa.GetTriTable()
local EPSILON = 0.00001
function LK3D.Radiosa.GetUVUnwrappedTris(object)
	local triList = LK3D.Radiosa.GetTriTable(object)

	local obj_ptr = LK3D.CurrUniv["objects"][object]
	if not obj_ptr then
		return
	end
	local mdl = obj_ptr.mdl

	local mdlpointer = LK3D.Models[mdl]
	local indices = mdlpointer.indices


	if not triList then
		return
	end
	-- as we all don't know, quads are just 2 tris with them sharing normal and their longest edge, so let's go get those quads!

	local quads = {}
	local tris = {}

	local alreadyQuaddedTris = {}
	-- very bad naive algorithm, O(n^2)
	-- still lightspeed fast with the low-poly LK3D models
	local triCount = #triList
	for i = 1, triCount do
		if alreadyQuaddedTris[i] == true then
			continue
		end

		local tri1 = triList[i]

		-- Get its longest edge
		local longest1, vertPair1 = getLongestEdge(tri1)
		local norm1 = tri1[1].norm



		local haveFound = false
		local foundPairIndices = {i}
		for j = 1, triCount do
			if j == i then -- lets NOT connect to ourselves
				continue
			end

			if alreadyQuaddedTris[j] == true then
				continue
			end

			local tri2 = triList[j]
			local norm2 = tri2[1].norm

			if (norm1:Dot(norm2) - 1) > EPSILON then
				continue -- non matching normals
			end

			local matchCount = getMatchingVertexCount(tri1, tri2)

			--print("Match Count; ", matchCount)
			--if matchCount ~= 2 then
			--	continue
			--end
			--print("Match Count; ", matchCount)
			--print("PASS")



			local longest2, vertPair2 = getLongestEdge(tri2)

			local matchLength = math.abs(longest1 - longest2) < EPSILON
			local matchPairs = matchingEdgePairs(vertPair1, vertPair2)

			local matched = matchLength and matchPairs
			if not matched then
				continue
			end

			--print("--===FOUND===--")
			--print("::MatchedLength -> " .. tostring(matchLength))
			--print("::MatchedPairs  -> " .. tostring(matchPairs))

			--print("::vertPair1     -> " .. tostring(vertPair1[1]) .. ", " .. tostring(vertPair1[2]))
			--print("::vertPair2     -> " .. tostring(vertPair2[1]) .. ", " .. tostring(vertPair2[2]))


			haveFound = true
			foundPairIndices[2] = j

			break
		end


		if not haveFound then
			continue
		end

		local ind1 = foundPairIndices[1]
		local ind2 = foundPairIndices[2]

		alreadyQuaddedTris[ind1] = true
		alreadyQuaddedTris[ind2] = true

		local q_tri1 = triList[ind1]
		local q_tri2 = triList[ind2]
		q_tri1._lm_index = ind1
		q_tri2._lm_index = ind2

		quads[#quads + 1] = {q_tri1, q_tri2}
	end

	-- now lets get the tris we have left
	for i = 1, triCount do
		if alreadyQuaddedTris[i] then
			continue
		end

		tris[#tris + 1] = triList[i]
		tris[#tris]._lm_index = i
	end

	-- add all of them to the list of to-pack tris
	local toPackTris = {}

	-- quads first, quads are just 2 tris
	for i = 1, #quads do
		local quad = quads[i]
		local triListComposed = {}

		local t1_uv1, t1_uv2, t1_uv3, t2_uv1, t2_uv2, t2_uv3 = quadToUV(quad)

		-- Tri 1
		local indexTri1 = quad[1]._lm_index
		--t1_uv1[3] = indices[indexTri1][1]
		--t1_uv2[3] = indices[indexTri1][2]
		--t1_uv3[3] = indices[indexTri1][3]
		triListComposed[#triListComposed + 1] = {t1_uv1, t1_uv2, t1_uv3, indexTri1}


		-- Tri 2
		local indexTri2 = quad[2]._lm_index
		--t2_uv1[3] = indices[indexTri2][1]
		--t2_uv2[3] = indices[indexTri2][2]
		--t2_uv3[3] = indices[indexTri2][3]
		triListComposed[#triListComposed + 1] = {t2_uv1, t2_uv2, t2_uv3, indexTri2}

		toPackTris[#toPackTris + 1] = triListComposed
	end

	-- and the standalone tris we have
	for i = 1, #tris do
		local tri = tris[i]


		local triListComposed = {}
		local uv1, uv2, uv3 = triToUV(tri)

		local indexTri = tri._lm_index
		--uv1[3] = indices[indexTri][1]
		--uv2[3] = indices[indexTri][2]
		--uv3[3] = indices[indexTri][3]

		triListComposed[#triListComposed + 1] = {
			uv1,
			uv2,
			uv3,
			indexTri
		}

		toPackTris[#toPackTris + 1] = triListComposed
	end

	--print("----- LK3D.Radiosa.GetUVUnwrappedTris Info -----")
	--print("Quads   ; " .. tostring(#quads))
	--print("Tris    ; " .. tostring(#tris))
	--print("To Pack ; " .. tostring(#toPackTris))

	-- we're done!
	return toPackTris
end