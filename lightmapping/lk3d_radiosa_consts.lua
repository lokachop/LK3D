LK3D = LK3D or {}
LK3D.Radiosa = LK3D.Radiosa or {}
LK3D.Radiosa.LIGHTMAP_RES = LK3D.Radiosa.LIGHTMAP_RES or 512
LK3D.Radiosa.LIGHTMAP_TRI_SZ = LK3D.Radiosa.LIGHTMAP_TRI_SZ or 10
LK3D.Radiosa.LIGHTMAP_TRI_PAD = LK3D.Radiosa.LIGHTMAP_TRI_PAD or 32
LK3D.Radiosa.LIGHTMAP_AUTO_EXPORT = LK3D.Radiosa.LIGHTMAP_AUTO_EXPORT or true -- export when done

LK3D.Radiosa.PATCH_EMISSIVE_MUL = LK3D.Radiosa.PATCH_EMISSIVE_MUL or 1 -- Multiplier to ALL emmisive patches, per-object multipliers can be achieved with object colour or the "RADIOSITY_BRIGHT_MUL" flag
LK3D.Radiosa.PATCH_REFLECTANCE = LK3D.Radiosa.PATCH_REFLECTANCE or .97 -- Reflectance multiplier of all of the materials in the scene

LK3D.Radiosa.BRIGHTNESS_MUL = LK3D.Radiosa.BRIGHTNESS_MUL or 256 * 2
LK3D.Radiosa.BRIGHTNESS_INTENSITY = LK3D.Radiosa.BRIGHTNESS_INTENSITY or 24

LK3D.Radiosa.RADIOSITY_STEPS = LK3D.Radiosa.RADIOSITY_STEPS or 3 -- number of times to run the radiosity algorithm, higher == slower but better GI (1 = no GI)
LK3D.Radiosa.RADIOSITY_BUFFER_SZ = LK3D.Radiosa.RADIOSITY_BUFFER_SZ or 64 -- internal buffer size of the radiosity render, higher == better quality but exponentially slower O(n^2)
LK3D.Radiosa.RADIOSITY_SPACING = LK3D.Radiosa.RADIOSITY_SPACING or 4 -- spacing for fastCalc -> Lower == Slower, 4 is good 8 is doable aswell
LK3D.Radiosa.RADIOSITY_QUALITY = LK3D.Radiosa.RADIOSITY_QUALITY or 0.5  -- do 0.5, higher = more detailed but wayy slower (behind scenes calculates more pixels)
LK3D.Radiosa.RADIOSITY_FOV = 90 -- hemicube render FOV, leave at 90
