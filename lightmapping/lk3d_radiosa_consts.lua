LK3D = LK3D or {}
LK3D.Radiosa = LK3D.Radiosa or {}
LK3D.Radiosa.LIGHTMAP_RES = 2048
LK3D.Radiosa.LIGHTMAP_TRI_SZ = 80
LK3D.Radiosa.LIGHTMAP_TRI_PAD = 32
LK3D.Radiosa.LIGHTMAP_AUTO_EXPORT = true -- export when done




LK3D.Radiosa.USE_RAYTRACE = false -- raytrace the lighting instead of radiosity, faster but unimplemented!
LK3D.Radiosa.STEPS = 1 -- number of times to run the radiosity algorithm, higher == slower but better GI (1 = no GI)
LK3D.Radiosa.BUFFER_SZ = 96 -- internal buffer size of the radiosity render, higher == better quality but exponentially slower
LK3D.Radiosa.FOV = 90 -- render FOV, if unsure, leave at 90
LK3D.Radiosa.LIGHTSCL_DIV = 12 -- how much to divide the intensity of the lights when spawning their reference model
LK3D.Radiosa.REFLECTANCE = .9 -- reflectance of all of the materials in the scene


LK3D.Radiosa.MUL_EMMISIVE_START = .75 -- internal, controls how bright emmisive surfaces are by default
LK3D.Radiosa.MUL_RENDER = 96 -- internal, controls brightness




-- for legacy, remove soon
LK3D.LIGHTMAP_RES = (256 + 64 + 16) * 1.75 --2.5 -- .75
LK3D.LIGHTMAP_TRISZ = 10 * 1.75 --1.75 -- .5
LK3D.LIGHTMAP_TRIPAD = 5
LK3D.LIGHTMAP_AUTO_EXPORT = true -- auto export when done

LK3D.RADIOSITY_DO_RT = false
LK3D.RADIOSITY_STEPS = 1
LK3D.RADIOSITY_BUFFER_SZ = 96
LK3D.RADIOSITY_FOV = 90
LK3D.RADIOSITY_LIGHTSCL_DIV = 12
LK3D.RADIOSITY_REFLECTANCE = .9
LK3D.RADIOSITY_MUL_EMMISIVE_START = .75
LK3D.RADIOSITY_MUL_RENDER = 96