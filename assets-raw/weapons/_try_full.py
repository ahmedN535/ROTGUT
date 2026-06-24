import bpy

# TEST: strip UVs the clean way (uv_layers API only, no raw attribute surgery),
# validate, and try exporting ALL meshes incl. undergrip to a throwaway file.
OUT = r"E:/Claude/Games/RetroFPS/assets-raw/weapons/_test_full.glb"

meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
for o in meshes:
    me = o.data
    while me.uv_layers:
        me.uv_layers.remove(me.uv_layers[0])
    res = me.validate(verbose=False)
    me.update()
    if res:
        print("VALIDATE_FIXED:", o.name)

for x in bpy.data.objects:
    x.select_set(False)
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]

bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB',
                          use_selection=True, export_yup=True)
print("FULL_EXPORT_OK meshes:", len(meshes))
