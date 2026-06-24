import bpy
import os

meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
print("== DIAG ==", len(meshes), "meshes")
for o in meshes:
    me = o.data
    attrs = [(a.name, a.domain, a.data_type, len(a.data)) for a in me.attributes]
    print("ATTR [%s] v=%d e=%d p=%d loops=%d :: %s" % (
        o.name, len(me.vertices), len(me.edges), len(me.polygons), len(me.loops), attrs))

print("== PER-OBJECT EXPORT TEST ==")
for o in meshes:
    for x in bpy.data.objects:
        x.select_set(False)
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    tmp = "E:/Claude/Games/RetroFPS/assets-raw/weapons/_tmp_%s.glb" % o.name.replace(".", "_")
    try:
        bpy.ops.export_scene.gltf(filepath=tmp, export_format='GLB',
                                  use_selection=True, export_yup=True)
        print("OK   %s" % o.name)
        if os.path.exists(tmp):
            os.remove(tmp)
    except Exception as e:
        print("FAIL %s -> %r" % (o.name, e))
        if os.path.exists(tmp):
            os.remove(tmp)
