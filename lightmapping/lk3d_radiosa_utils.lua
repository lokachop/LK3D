LK3D = LK3D or {}
LK3D.Radiosa = LK3D.Radiosa or {}

local math = math
local math_Round = math.Round


local function copyUV(uv)
	return {uv[1], uv[2]}
end

local function copyTable(tblpointer)
	local new = {}
	for k, v in pairs(tblpointer) do
		if type(v) == "table" then
			new[k] = copyTable(v)
		elseif type(v) == "Vector" then
			new[k] = Vector(v)
		elseif type(v) == "Angle" then
			new[k] = Angle(v)
		else
			new[k] = v
		end
	end
	return new
end

-- returns a hash from a vector (string)
local concat_tbl_vert = {}
local concat_round = 4
local function hashVec(v)
	concat_tbl_vert[1] = "x"
	concat_tbl_vert[2] = math_Round(v[1], concat_round)
	concat_tbl_vert[3] = "y"
	concat_tbl_vert[4] = math_Round(v[2], concat_round)
	concat_tbl_vert[5] = "z"
	concat_tbl_vert[6] = math_Round(v[3], concat_round)

	return table.concat(concat_tbl_vert, "")
end


-- gets the tris of a mesh as a non tblptr table
-- (verts n uvs are copied)
function LK3D.Radiosa.GetTriTable(obj)
	if not obj then
		return
	end

	if not LK3D.CurrUniv["objects"][obj] then
		return
	end

	local obj_ptr = LK3D.CurrUniv["objects"][obj]
	local mdl = obj_ptr.mdl

	if not LK3D.Models[mdl] then
		return
	end


	local mdlpointer = LK3D.Models[mdl]
	local verts = mdlpointer.verts
	local uvs = mdlpointer.uvs
	local uvs_lm = obj_ptr.lightmap_uvs
	local dolm = (uvs_lm ~= nil)

	local indices = mdlpointer.indices

	local tri_list_genned = {}
	for i = 1, #indices do
		local ind = indices[i]
		local v1 = Vector(verts[ind[1][1]]) -- lets copy aswell to be safe, even if slow
		local v2 = Vector(verts[ind[2][1]])
		local v3 = Vector(verts[ind[3][1]])

		local uv1 = copyUV(uvs[ind[1][2]]) -- same here
		local uv2 = copyUV(uvs[ind[2][2]])
		local uv3 = copyUV(uvs[ind[3][2]])

		local lm_uv1 = {0, 0}
		local lm_uv2 = {0, 0}
		local lm_uv3 = {0, 0}
		if dolm then
			lm_uv1 = copyUV(uvs_lm[ind[1][3]])
			lm_uv2 = copyUV(uvs_lm[ind[2][3]])
			lm_uv3 = copyUV(uvs_lm[ind[3][3]])
		end



		local norm = (v2 - v1):Cross(v3 - v1)
		norm:Normalize()

		tri_list_genned[#tri_list_genned + 1] = {
			{
				pos = v1,
				uv = uv1,
				ind_pos = ind[1][1],
				ind_uv = ind[1][2],
				ind_uv_lm = ind[1][3],
				norm = norm,
				hash_pos = hashVec(v1),
				lm_uv = lm_uv1,
			},
			{
				pos = v2,
				uv = uv2,
				ind_pos = ind[2][1],
				ind_uv = ind[2][2],
				ind_uv_lm = ind[2][3],
				norm = norm,
				hash_pos = hashVec(v2),
				lm_uv = lm_uv2,
			},
			{
				pos = v3,
				uv = uv3,
				ind_pos = ind[3][1],
				ind_uv = ind[3][2],
				ind_uv_lm = ind[3][3],
				norm = norm,
				hash_pos = hashVec(v3),
				lm_uv = lm_uv3,
			}
		}
	end

	return tri_list_genned
end


function LK3D.Radiosa.GetSolver()
	return LK3D.Radiosa.SOLVER
end



