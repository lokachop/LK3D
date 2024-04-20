--[[--
]]
-- @module rendertarget
LK3D = LK3D or {}

LK3D.MatCache = LK3D.MatCache or {}
LK3D.MatCacheTR = LK3D.MatCacheTR or {}
LK3D.MatCacheNoZ = LK3D.MatCacheNoZ or {}

LK3D.MatCache_LM = LK3D.MatCache_LM or {}
LK3D.MatCacheTR_LM = LK3D.MatCacheTR_LM or {}
LK3D.MatCacheNoZ_LM = LK3D.MatCacheNoZ_LM or {}

--- Turns a rendertarget into a lua material  
-- **Not an LK3D Texture**
-- @tparam rendertarget rt Rendertarget to use
-- @tparam ?bool transp Add $alphatest shader parameter
-- @tparam ?bool ignorez Add $ignorez and $nocull shader parameter
-- @treturn material Material of the RT
-- @treturn material Lightmapped material of the RT
-- @usage local rtMat = LK3D.RTToMaterial(rt_render)
function LK3D.RTToMaterial(rt, transp, ignorez)
	if not LK3D.MatCache[rt:GetName()] then
		LK3D.New_D_Print(rt:GetName() .. " isnt cached, caching!", LK3D_SEVERITY_DEBUG, "Utils")

		LK3D.MatCache[rt:GetName()] = CreateMaterial(rt:GetName() .. "_materialized_lk3d", "UnlitGeneric", {
			["$basetexture"] = rt:GetName(),
			["$nocull"] = ignorez and 1 or 0,
			["$ignorez"] = ignorez and 1 or 0,
			["$vertexcolor"] = 1,
			["$alphatest"] = transp and 1 or 0,
		})

		LK3D.MatCache_LM[rt:GetName()] = CreateMaterial("lm_" .. rt:GetName() .. "_materialized_lk3d", "LightmappedGeneric", {
			["$basetexture"] = rt:GetName(),
			["$nocull"] = ignorez and 1 or 0,
			["$ignorez"] = ignorez and 1 or 0,
			["$vertexcolor"] = 1,
			["$alphatest"] = transp and 1 or 0,
		})
	end

	return LK3D.MatCache[rt:GetName()], LK3D.MatCache_LM[rt:GetName()]
end

--- Extended version of LK3D.RTToMaterial()  
-- **Not an LK3D Texture**
-- @tparam rendertarget rt Rendertarget to use
-- @tparam table params Parameters, refer to usage
-- @treturn material Material of the RT
-- @treturn material Lightmapped material of the RT
-- @usage local rtMat = LK3D.RTToMaterialEx(rt_render, {
--	  ["nocull"] = false,
--	  ["ignorez"] = false,
--	  ["vertexcolor"] = true,
--	  ["vertexalpha"] = true,
--	  ["alphatest"] = false,
-- })
function LK3D.RTToMaterialEx(rt, params)
	if not LK3D.MatCache[rt:GetName()] then
		LK3D.New_D_Print(rt:GetName() .. " isnt cached, caching!", LK3D_SEVERITY_DEBUG, "Utils")

		LK3D.MatCache[rt:GetName()] = CreateMaterial(rt:GetName() .. "_materialized_lk3d", "UnlitGeneric", {
			["$basetexture"] = rt:GetName(),
			["$nocull"] = params["nocull"] and 1 or 0,
			["$ignorez"] = params["ignorez"] and 1 or 0,
			["$vertexcolor"] = params["vertexcolor"] and 1 or 0,
			["$vertexalpha"] = params["vertexalpha"] and 1 or 0,
			["$alphatest"] = params["alphatest"] and 1 or 0,
		})


		if params["lightmapped"] then
			LK3D.MatCache_LM[rt:GetName()] = CreateMaterial("lm_" .. rt:GetName() .. "_materialized_lk3d", "LightmappedGeneric", {
				["$basetexture"] = rt:GetName(),
				["$nocull"] = params["nocull"] and 1 or 0,
				["$ignorez"] = params["ignorez"] and 1 or 0,
				["$vertexcolor"] = params["vertexcolor"] and 1 or 0,
				["$vertexalpha"] = params["alphatest"] and 1 or 0,
				["$alphatest"] = params["alphatest"] and 1 or 0,
			})
		end
	end

	return LK3D.MatCache[rt:GetName()], LK3D.MatCache_LM[rt:GetName()]
end


--- Translucent version of LK3D.RTToMaterial()  
-- **Not an LK3D Texture**
-- @tparam rendertarget rt Rendertarget to use
-- @treturn material Material of the RT
-- @treturn material Lightmapped material of the RT
-- @usage local rtMatTransp = LK3D.RTToMaterialTL(rt_render)
function LK3D.RTToMaterialTL(rt)
	if not LK3D.MatCacheTR[rt:GetName()] then
		LK3D.New_D_Print(rt:GetName() .. " isnt cached, caching!", LK3D_SEVERITY_DEBUG, "Utils")

		LK3D.MatCacheTR[rt:GetName()] = CreateMaterial(rt:GetName() .. "_materialized_lk3d_transparent", "UnlitGeneric", {
			["$basetexture"] = rt:GetName(),
			--["$nocull"] = 1,
			["$vertexcolor"] = 1,
			["$vertexalpha"] = 1,
		})

		LK3D.MatCacheTR_LM[rt:GetName()] = CreateMaterial(rt:GetName() .. "_materialized_lk3d_transparent_lm", "LightmappedGeneric", {
			["$basetexture"] = rt:GetName(),
			--["$nocull"] = 1,
			["$vertexcolor"] = 1,
			["$vertexalpha"] = 1,
		})
	end

	return LK3D.MatCacheTR[rt:GetName()], LK3D.MatCacheTR_LM[rt:GetName()]
end

--- No-Z version of LK3D.RTToMaterial()  
-- **Not an LK3D Texture**
-- @tparam rendertarget rt Rendertarget to use
-- @tparam bool transp **Broken**
-- @treturn material Material of the RT
-- @treturn material Lightmapped material of the RT
-- @usage local rtMatNoZ = LK3D.RTToMaterialNoZ(rt_render)
function LK3D.RTToMaterialNoZ(rt, transp)
	if not LK3D.MatCacheNoZ[rt:GetName()] then
		LK3D.New_D_Print(rt:GetName() .. " isnt cached, caching!", LK3D_SEVERITY_DEBUG, "Utils")

		LK3D.MatCacheNoZ[rt:GetName()] = CreateMaterial("noz_" .. rt:GetName() .. "_materialized_lk3d", "UnlitGeneric", {
			["$basetexture"] = rt:GetName(),
			["$nocull"] = 1,
			["$ignorez"] = 1,
			["$vertexcolor"] = 1,
			--["$alphatest"] = transp and 1 or 0,
		})

		LK3D.MatCacheNoZ_LM[rt:GetName()] = CreateMaterial("noz_" .. rt:GetName() .. "_materialized_lk3d_lm", "LightmappedGeneric", {
			["$basetexture"] = rt:GetName(),
			["$nocull"] = 1,
			["$ignorez"] = 1,
			["$vertexcolor"] = 1,
			--["$alphatest"] = transp and 1 or 0,
		})
	end

	return LK3D.MatCacheNoZ[rt:GetName()], LK3D.MatCacheNoZ_LM[rt:GetName()]
end
