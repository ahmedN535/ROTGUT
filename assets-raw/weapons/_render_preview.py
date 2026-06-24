import bpy
import math
from mathutils import Vector

# Render a quick clay preview of the revolver_blockout collection.
# Run AFTER revolver_blockout.py (blender -b ... --python blockout --python this).

scene = bpy.context.scene
col = bpy.data.collections.get("revolver_blockout")
objs = list(col.objects)

# --- combined world-space bounding box ---
mins = Vector(( 1e9,  1e9,  1e9))
maxs = Vector((-1e9, -1e9, -1e9))
for o in objs:
    for corner in o.bound_box:
        w = o.matrix_world @ Vector(corner)
        mins = Vector((min(mins[i], w[i]) for i in range(3)))
        maxs = Vector((max(maxs[i], w[i]) for i in range(3)))
center = (mins + maxs) * 0.5
max_dim = max(maxs[i] - mins[i] for i in range(3))

# --- camera at a 3/4 side view ---
cam_data = bpy.data.cameras.new("preview_cam")
cam_data.lens = 50
cam = bpy.data.objects.new("preview_cam", cam_data)
scene.collection.objects.link(cam)
direction = Vector((2.2, -0.5, 0.6)).normalized()
cam.location = center + direction * (max_dim * 2.6)
cam.rotation_euler = (cam.location - center).to_track_quat('Z', 'Y').to_euler()
scene.camera = cam

# --- world background (mid-dark grey) ---
world = scene.world or bpy.data.worlds.new("preview_world")
scene.world = world
world.use_nodes = True
bg = world.node_tree.nodes.get("Background")
if bg:
    bg.inputs[0].default_value = (0.045, 0.045, 0.05, 1.0)

# --- Workbench clay render: fast, great for judging silhouette ---
scene.render.engine = 'BLENDER_WORKBENCH'
shading = scene.display.shading
shading.light = 'STUDIO'
shading.color_type = 'SINGLE'
shading.single_color = (0.55, 0.55, 0.58)
shading.show_cavity = True
shading.show_shadows = True

scene.render.resolution_x = 1000
scene.render.resolution_y = 650
scene.render.film_transparent = False
scene.render.image_settings.file_format = 'PNG'
scene.render.filepath = bpy.path.abspath(
    "//_blockout_preview.png") if bpy.data.filepath else \
    "E:/Claude/Games/RetroFPS/assets-raw/weapons/_blockout_preview.png"

bpy.ops.render.render(write_still=True)
print("PREVIEW_RENDERED:", scene.render.filepath)
