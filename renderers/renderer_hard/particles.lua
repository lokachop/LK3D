LK3D = LK3D or {}
local render = render
local render_SetMaterial = render.SetMaterial
local render_OverrideBlend = render.OverrideBlend




local mesh = mesh
local mesh_Color = mesh.Color
local mesh_Position = mesh.Position
local mesh_TexCoord = mesh.TexCoord
local mesh_AdvanceVertex = mesh.AdvanceVertex
local mesh_End = mesh.End
local mesh_Begin = mesh.Begin


local tbl_white = {255, 255, 255}
local light_mult_at_pos = include("lightmult.lua")
local function renderParticleEmitter(data)
	local typeData = LK3D.Particles[data.type]
	if not typeData then
		return
	end

	local prop = data.prop
	local lifeExpected = typeData.life

	local particles = data.activeParticles
	local totalParts = #particles

	local pos = (prop.pos or Vector(0, 0, 0))
	local lit = prop.lit or false
	local sz = (prop.part_sz or .25)
	local esz = prop.end_sz

	local dolerp = prop.end_sz ~= nil and true or false


	local startCol = prop.start_col or tbl_white
	local endCol = prop.end_col or tbl_white

	local doCLerp = (startCol[1] ~= endCol[1]) or (startCol[2] ~= endCol[2]) or (startCol[3] ~= endCol[3])
	local doActCol = (not doCLerp and startCol)
	local pr, pg, pb = 255, 255, 255
	if doActCol then
		pr, pg, pb = startCol[1], startCol[2], startCol[2]
	end

	local gr = prop.grav
	local const = prop.grav_constant and true or false

	render_SetMaterial(LK3D.WireFrame and wfMat or LK3D.Textures[typeData.mat].mat)


	local param_blend = prop.blend_params
	if param_blend then
		render_OverrideBlend(true, param_blend.srcBlend, param_blend.destBlend, param_blend.blendFunc, param_blend.srcBlendAlpha, param_blend.destBlendAlpha, param_blend.blendFuncAlpha)
	end
	mesh_Begin(MATERIAL_QUADS, totalParts)
		for i = 1, totalParts do
			local part = particles[i]
			local delta = (CurTime() - part.start) / lifeExpected
			--local invdelta = math_abs(1 - delta)
			local gmul = (const and 1 or (delta * delta))
			local vcalc = part.vel_start + Vector(0, 0, -gr * gmul)
			vcalc:Mul(delta)
			local pcalc = part.pos_start + vcalc
			pcalc:Add(part.orig_pos)
			if ((pcalc - LK3D.CamPos):Dot(LK3D.CamAng:Forward()) < 0) then
				continue
			end

			local dir_calc = (pcalc - LK3D.CamPos):GetNormalized()



			local rc, gc, bc = pr, pg, pb
			if doCLerp then
				rc = startCol[1] + (endCol[1] - startCol[1]) * delta
				gc = startCol[2] + (endCol[2] - startCol[2]) * delta
				bc = startCol[3] + (endCol[3] - startCol[3]) * delta
			end

			if lit then
				local r, g, b = light_mult_at_pos(pcalc)
				rc, gc, bc = rc * r, gc * g, bc * b
			end

			local rot_var = part.rot_mult * delta
			local dcalcA = dir_calc:Angle() + Angle(0, 0, rot_var * 360)
			local lc = dcalcA:Right() * (dolerp and (sz + (esz - sz) * delta) or sz)
			local uc = dcalcA:Up() * (dolerp and (sz + (esz - sz) * delta) or sz)


			-- why not do
			-- mesh.QuadEasy(pcalc, dir_calc, prop.part_sz or .25, prop.part_sz or .25)
			-- instead?

			-- a useful func is in the air?
			-- WRONG, no colours, no rotation


			-- do everything manually

			--  #---#
			--  | =(|
			--  O---#
			mesh_Color(rc, gc, bc, 255)
			mesh_Position(pcalc - lc + uc)
			mesh_TexCoord(0, 0, 1)
			mesh_AdvanceVertex()


			--  #---#
			--  | =(|
			--  #---O
			mesh_Color(rc, gc, bc, 255)
			mesh_Position(pcalc + lc + uc)
			mesh_TexCoord(0, 1, 1)
			mesh_AdvanceVertex()

			--  #---O
			--  | =(|
			--  #---#
			mesh_Color(rc, gc, bc, 255)
			mesh_Position(pcalc + lc - uc)
			mesh_TexCoord(0, 1, 0)
			mesh_AdvanceVertex()

			--  O---#
			--  | =(|
			--  #---#
			mesh_Color(rc, gc, bc, 255)
			mesh_Position(pcalc - lc - uc)
			mesh_TexCoord(0, 0, 0)
			mesh_AdvanceVertex()
		end
	mesh_End()
	if param_blend then
		render_OverrideBlend(false)
	end
end


return renderParticleEmitter