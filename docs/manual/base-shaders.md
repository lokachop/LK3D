# Base Shaders
This is a list of all of the built-in LK3D base shaders, with screenshots.  
Most of these only work when the models are non-cached, as they need to be updated constantly.  

---

<font size="6"> `reflective`</font>  

Spheremap shader, maps a 2D sphere map onto a 3D model, used to make shiny *metallic* objects  
**This shader is really expensive! Its advised to use** `reflective_screen_rot` **if your model has smooth normals!**

![image](../images/shader_captures/reflective/cube_nuv.png)
![image](../images/shader_captures/reflective/barrel.png)
![image](../images/shader_captures/reflective/suzanne.png)

---

<font size="6"> `reflective_simple`</font>  

Faster, lazier and horribly broken version of `reflective`  
This shader is mostly phased out by `reflective_screen_rot`  
**Breaks with non-smooth normals**  
![image](../images/shader_captures/reflective_simple/cube_nuv.png)
![image](../images/shader_captures/reflective_simple/barrel.png)
![image](../images/shader_captures/reflective_simple/suzanne.png)

---

<font size="6"> `reflective_screen_rot`</font>  

Maps a spheremap to a model using the screenspace instead  
**Breaks with non-smooth normals**  
![image](../images/shader_captures/reflective_screen_rot/cube_nuv.png)
![image](../images/shader_captures/reflective_screen_rot/barrel.png)
![image](../images/shader_captures/reflective_screen_rot/suzanne.png)

---

<font size="6"> `specular`</font>  

Hacky specular shader, looks horrible and runs horrible too!  
![image](../images/shader_captures/specular/cube_nuv.png)
![image](../images/shader_captures/specular/barrel.png)
![image](../images/shader_captures/specular/suzanne.png)

---

<font size="6"> `norm_vis`</font>  

Shows the **rotated** normals as the vertex colours  
![image](../images/shader_captures/norm_vis/cube_nuv.png)
![image](../images/shader_captures/norm_vis/barrel.png)
![image](../images/shader_captures/norm_vis/suzanne.png)

---

<font size="6"> `norm_vis_rot`</font>  

Unlike what it name implies, shows the **non-rotated** normals as the vertex colours  
![image](../images/shader_captures/norm_vis_rot/cube_nuv.png)
![image](../images/shader_captures/norm_vis_rot/barrel.png)
![image](../images/shader_captures/norm_vis_rot/suzanne.png)

---

<font size="6"> `norm_screenspace`</font>  

Deprecated  

![image](../images/shader_captures/norm_screenspace/cube_nuv.png)
![image](../images/shader_captures/norm_screenspace/barrel.png)
![image](../images/shader_captures/norm_screenspace/suzanne.png)

---

<font size="6"> `norm_screenspace_rot`</font>  

Shows **screen-space** normals as the vertex colours  

![image](../images/shader_captures/norm_screenspace_rot/cube_nuv.png)
![image](../images/shader_captures/norm_screenspace_rot/barrel.png)
![image](../images/shader_captures/norm_screenspace_rot/suzanne.png)

---

<font size="6"> `world_pos`</font>  

Shows the world position of each vertex as the vertex colours  
**Only works in positions between Vector(-8, -8, -8) & Vector(8, 8, 8)**  

![image](../images/shader_captures/world_pos/cube_nuv.png)
![image](../images/shader_captures/world_pos/barrel.png)
![image](../images/shader_captures/world_pos/suzanne.png)


---

<font size="6"> `world_pos_local`</font>  

Shows the position local to the camera of each vertex as the vertex colours  

![image](../images/shader_captures/world_pos_local/cube_nuv.png)
![image](../images/shader_captures/world_pos_local/barrel.png)
![image](../images/shader_captures/world_pos_local/suzanne.png)

---

<font size="6"> `vert_col`</font>  

Sets the vertex colour of each vertex to the hue of their index  

![image](../images/shader_captures/vert_col/cube_nuv.png)
![image](../images/shader_captures/vert_col/barrel.png)
![image](../images/shader_captures/vert_col/suzanne.png)

---

<font size="6"> `ps1`</font>  

PS1-Like vertex wobble shader, effectively floors vertex positions  

![image](../images/shader_captures/ps1/cube_nuv.png)
![image](../images/shader_captures/ps1/barrel.png)
![image](../images/shader_captures/ps1/suzanne.png)