import bpy
import math
from mathutils import Vector

# Generic clay-render of whatever MESH objects are in the opened .blend.
#   blender -b --factory-startup revolver.blend --python _render_file.py

scene = bpy.context.scene
meshes = [o for o in scene.objects if o.type == 'MESH']

mins = Vector(( 1e9,  1e9,  1e9))
maxs = Vector((-1e9, -1e9, -1e9))
for o in meshes:
    for c in o.bound_box:
        w = o.matrix_world @ Vector(c)
        mins = Vector((min(mins[i], w[i]) for i in range(3)))
        maxs = Vector((max(maxs[i], w[i]) for i in range(3)))
center = (mins + maxs) * 0.5
dims = maxs - mins
max_dim = max(dims)

# --- clay / workbench render setup ---
scene.render.engine = 'BLENDER_WORKBENCH'
sh = scene.display.shading
sh.light = 'STUDIO'
sh.color_type = 'SINGLE'
sh.single_color = (0.55, 0.55, 0.58)
sh.show_cavity = True
sh.show_shadows = True
scene.render.resolution_x = 1000
scene.render.resolution_y = 650
scene.render.film_transparent = False
scene.render.image_settings.file_format = 'PNG'
world = scene.world or bpy.data.worlds.new("w")
scene.world = world
world.use_nodes = True
bg = world.node_tree.nodes.get("Background")
if bg:
    bg.inputs[0].default_value = (0.045, 0.045, 0.05, 1.0)


def render_from(direction, name, ortho=False, ortho_margin=1.2):
    cd = bpy.data.cameras.new(name)
    cam = bpy.data.objects.new(name, cd)
    scene.collection.objects.link(cam)
    d = Vector(direction).normalized()
    cam.location = center + d * (max_dim * 2.6)
    cam.rotation_euler = (cam.location - center).to_track_quat('Z', 'Y').to_euler()
    if ortho:
        cd.type = 'ORTHO'
        cd.ortho_scale = max_dim * ortho_margin
    else:
        cd.lens = 50
    scene.camera = cam
    out = "E:/Claude/Games/RetroFPS/assets-raw/weapons/_revolver_%s.png" % name
    scene.render.filepath = out
    bpy.ops.render.render(write_still=True)
    print("RENDERED", out)


print("MESH_OBJECTS", sorted(o.name for o in meshes))
print("DIMS  x=%.3f y=%.3f z=%.3f  (meters)" % (dims.x, dims.y, dims.z))
render_from((1.0, 0.0, 0.05), "side", ortho=True, ortho_margin=1.15)
render_from((2.2, -0.9, 0.8), "threequarter", ortho=False)
