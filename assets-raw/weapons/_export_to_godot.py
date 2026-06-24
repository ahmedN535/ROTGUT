import bpy
import os

# Export every MESH object to the Godot project as revolver.glb.
# Pre-clean: strip premature/partial UV maps (we haven't done the real unwrap yet;
# an empty UVMap on 'undergrip' breaks the glTF exporter) and validate meshes.
# This only touches the in-memory copy - the source .blend is NOT modified.
#   blender -b --factory-startup revolver.blend --python _export_to_godot.py

OUT = r"E:/Claude/Games/RetroFPS/godot-project/ROTGUT/weapons/revolver.glb"
os.makedirs(os.path.dirname(OUT), exist_ok=True)

EXCLUDE = {"undergrip"}   # corrupt mesh (stale vertex refs) - skip until rebuilt
meshes = [o for o in bpy.context.scene.objects
          if o.type == 'MESH' and o.name not in EXCLUDE]
print("INCLUDED:", sorted(o.name for o in meshes))
print("EXCLUDED:", sorted(EXCLUDE))

for o in meshes:
    me = o.data
    # remove all UV layers (proper API)
    while me.uv_layers:
        me.uv_layers.remove(me.uv_layers[0])
    # nuke any leftover UV-related / partial-normals attributes
    for a in list(me.attributes):
        if a.name.startswith('.pn.') or a.name.startswith('.uv_select') or a.name == 'UVMap':
            try:
                me.attributes.remove(a)
            except Exception as e:
                print("  could not remove %s on %s: %r" % (a.name, o.name, e))
    me.validate(verbose=False)   # fix any remaining custom-data mismatches
    me.update()

for x in bpy.data.objects:
    x.select_set(False)
for o in meshes:
    o.select_set(True)
if meshes:
    bpy.context.view_layer.objects.active = meshes[0]

bpy.ops.export_scene.gltf(
    filepath=OUT,
    export_format='GLB',
    use_selection=True,
    export_yup=True,
)
print("EXPORTED_GLB:", OUT, "| meshes:", len(meshes))
