import bpy
import os

# Export the revolver_blockout collection as glTF Binary (.glb) into the Godot
# project's weapons folder. Run AFTER revolver_blockout.py.
#   blender -b --python revolver_blockout.py --python _export_glb.py

OUT = r"E:/Claude/Games/RetroFPS/godot-project/ROTGUT/weapons/revolver_viewmodel.glb"
os.makedirs(os.path.dirname(OUT), exist_ok=True)

# select ONLY the gun pieces (so the default camera/light don't get exported)
for o in bpy.data.objects:
    o.select_set(False)
col = bpy.data.collections.get("revolver_blockout")
objs = list(col.objects)
for o in objs:
    o.select_set(True)
bpy.context.view_layer.objects.active = objs[0]

bpy.ops.export_scene.gltf(
    filepath=OUT,
    export_format='GLB',     # single self-contained .glb (mesh + material baked in)
    use_selection=True,      # only the selected gun pieces
    export_yup=True,         # Blender Z-up -> Godot Y-up (our convention)
)
print("EXPORTED_GLB:", OUT, "| pieces:", len(objs))
