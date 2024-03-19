--[[                                                    
Fast Physics Solver

MIT License

Copyright (c) 2024 Dice

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]

local fps={
	version="0.0.7"
}

-------------------------------------------------------------------------------

fps.vector3  = include("modules/vector3.lua")(fps)
fps.matrix3  = include("modules/matrix3.lua")(fps)
fps.matrix4  = include("modules/matrix4.lua")(fps)
fps.raycast  = include("modules/raycast.lua")(fps)
fps.ngc      = include("modules/ngc.lua")(fps)
fps.shape    = include("modules/shape.lua")(fps)
fps.collider = include("modules/collider.lua")(fps)
fps.body     = include("modules/body.lua")(fps)
fps.world    = include("modules/world.lua")(fps)

fps.solvers={
	rigid = include("solvers/rigid.lua")(fps)
}

-------------------------------------------------------------------------------

return fps