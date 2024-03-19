--[[                                                    
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

return function(fps)
local collider={}; collider.__index=collider

-------------------------------------------------------------------------------

local vector3 = fps.vector3
local matrix4 = fps.matrix4
local raycast = fps.raycast
local gjk     = fps.gjk

-------------------------------------------------------------------------------

local math_min = math.min
local math_max = math.max

-------------------------------------------------------------------------------

function collider.new()
	return setmetatable({
		body        = nil,
		shape       = nil,
		density     = 0.5,
		friction    = 1,
		restitution = 0,
		size        = {1,1,1},
		transform   = {
			1,0,0,0,
			0,1,0,0,
			0,0,1,0,
			0,0,0,1
		},
		touching    = {}
	},collider)
end

function collider.set_shape(collider_,shape)
	collider_.shape=shape
end

function collider.set_density(collider_,density)
	collider_.density=density
	
	if collider_.body then
		collider_.body:update_mass()
	end
end

function collider.set_friction(collider_,friction)
	collider_.friction=friction
end

function collider.set_restitution(collider_,restitution)
	collider_.restitution=restitution
end

function collider.set_size(collider_,x,y,z)
	local s=collider_.size
	
	s[1],s[2],s[3]=x,y,z
	
	if collider_.body then
		collider_.body:update_mass()
		collider_.body:update_boundary()
	end
end

function collider.set_transform(
	collider_,
	a11,a12,a13,a14,
	a21,a22,a23,a24,
	a31,a32,a33,a34,
	a41,a42,a43,a44
)
	local t=collider_.transform
	
	t[1],t[2],t[3],t[4]     = a11,a12,a13,a14
	t[5],t[6],t[7],t[8]     = a21,a22,a23,a24
	t[9],t[10],t[11],t[12]  = a31,a32,a33,a34
	t[13],t[14],t[15],t[16] = a41,a42,a43,a44
	
	if collider_.body then
		collider_.body:update_mass()
		collider_.body:update_boundary()
	end
end

function collider.set_position_offset(collider_,x,y,z)
	local t=collider_.transform
	
	t[4],t[8],t[12]=x,y,z
	
	if collider_.body then
		collider_.body:update_mass()
		collider_.body:update_boundary()
	end
end

function collider.get_shape(collider_)
	return collider_.shape
end

function collider.get_density(collider_)
	return collider_.density
end

function collider.get_friction(collider_)
	return collider_.friction
end

function collider.get_restitution(collider_)
	return collider_.restitution
end

function collider.get_size(collider_)
	local s=collider_.size
	
	return s[1],s[2],s[3]
end

function collider.get_mass(collider_)
	local s=collider_.size
	local density=collider_.density
	
	return (s[1]*s[2]*s[3])*density
end

function collider.get_transform(collider_)
	local t=collider_.transform
	
	return
		t[1],t[2],t[3],t[4],
		t[5],t[6],t[7],t[8],
		t[9],t[10],t[11],t[12],
		t[13],t[14],t[15],t[16]
end

function collider.get_position_offset(collider_)
	local t=collider_.transform
	
	return t[4],t[8],t[12]
end

function collider.get_world_position(collider_)
	local
	ct11,ct12,ct13,ct14,
	ct21,ct22,ct23,ct24,
	ct31,ct32,ct33,ct34,
	ct41,ct42,ct43,ct44
	=collider_:get_transform()
	
	local
	bt11,bt12,bt13,bt14,
	bt21,bt22,bt23,bt24,
	bt31,bt32,bt33,bt34,
	bt41,bt42,bt43,bt44
	=collider_.body:get_transform()
	
	return matrix4.multiply_vector3(
		bt11,bt12,bt13,bt14,
		bt21,bt22,bt23,bt24,
		bt31,bt32,bt33,bt34,
		bt41,bt42,bt43,bt44,
		ct14,ct24,ct34
	)
end

function collider.get_world_vertex(collider_,vertex)
	local vertices=collider_.shape.vertices
	local size=collider_.size
	
	local vi=(vertex-1)*3
	
	local
	ct11,ct12,ct13,ct14,
	ct21,ct22,ct23,ct24,
	ct31,ct32,ct33,ct34,
	ct41,ct42,ct43,ct44
	=collider_:get_transform()
	
	local
	bt11,bt12,bt13,bt14,
	bt21,bt22,bt23,bt24,
	bt31,bt32,bt33,bt34,
	bt41,bt42,bt43,bt44
	=collider_.body:get_transform()
	
	return matrix4.multiply_vector3(
		bt11,bt12,bt13,bt14,
		bt21,bt22,bt23,bt24,
		bt31,bt32,bt33,bt34,
		bt41,bt42,bt43,bt44,
		matrix4.multiply_vector3(
			ct11,ct12,ct13,ct14,
			ct21,ct22,ct23,ct24,
			ct31,ct32,ct33,ct34,
			ct41,ct42,ct43,ct44,
			vertices[vi+1]*size[1],
			vertices[vi+2]*size[2],
			vertices[vi+3]*size[3]
		)
	)
end

function collider.raycast(collider_,x,y,z,dx,dy,dz)
	local t=collider_.transform
	
	local 
	i11,i12,i13,i14,
	i21,i22,i23,i24,
	i31,i32,i33,i34,
	i41,i42,i43,i44
	=matrix4.inverse(
		t[1],t[2],t[3],t[4],
		t[5],t[6],t[7],t[8],
		t[9],t[10],t[11],t[12],
		t[13],t[14],t[15],t[16]
	)
	
	--Project to collider space
	x,y,z=matrix4.multiply_vector3(
		i11,i12,i13,i14,
		i21,i22,i23,i24,
		i31,i32,i33,i34,
		i41,i42,i43,i44,
		x,y,z
	)
	dx,dy,dz=matrix4.multiply_vector3(
		i11,i12,i13,0,
		i21,i22,i23,0,
		i31,i32,i33,0,
		i41,i42,i43,i44,
		dx,dy,dz
	)
	
	local sx=collider_.size[1]
	local sy=collider_.size[2]
	local sz=collider_.size[3]
	
	local vertices=collider_.shape.vertices
	local faces=collider_.shape.faces
	
	local px,py,pz,snx,sny,snz,m
	
	for i=1,#faces,3 do
		local v1=(faces[i]-1)*3
		local v2=(faces[i+1]-1)*3
		local v3=(faces[i+2]-1)*3
		
		local cx,cy,cz,nx,ny,nz,l=raycast.triangle(
			x,y,z,
			dx,dy,dz,
			vertices[v1+1]*sx,
			vertices[v1+2]*sy,
			vertices[v1+3]*sz,
			vertices[v2+1]*sx,
			vertices[v2+2]*sy,
			vertices[v2+3]*sz,
			vertices[v3+1]*sx,
			vertices[v3+2]*sy,
			vertices[v3+3]*sz
		)
		
		if l and (not m or l<m) then
			px,py,pz=cx,cy,cz
			snx,sny,snz=nx,ny,nz
			m=l
		end
	end
	
	if m then --Project to body space
		px,py,pz=matrix4.multiply_vector3(
			t[1],t[2],t[3],t[4],
			t[5],t[6],t[7],t[8],
			t[9],t[10],t[11],t[12],
			t[13],t[14],t[15],t[16],
			px,py,pz
		)
		snx,sny,snz=matrix4.multiply_vector3(
			t[1],t[2],t[3],0,
			t[5],t[6],t[7],0,
			t[9],t[10],t[11],0,
			t[13],t[14],t[15],t[16],
			snx,sny,snz
		)
	end
	
	return px,py,pz,snx,sny,snz,m
end

-------------------------------------------------------------------------------

return collider
end