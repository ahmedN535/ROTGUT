import bpy
import bmesh
import math
from mathutils import Matrix, Vector

# ---------------------------------------------------------------------------
# ROTGUT - Revolver viewmodel BLOCKOUT  ("The Slab")
#
# HOW TO USE:
#   1. Open Blender. Switch to the "Scripting" workspace (top tab bar).
#   2. New text -> paste this whole file -> press "Run Script" (the play arrow).
#   3. Hover the 3D viewport, press numpad-period (.) to frame the gun.
#
# This builds the CHUNKY PROPORTIONS only. The small detail (bolts, vents,
# rust, fine flutes) gets PAINTED into the texture later - we don't model it.
#
# Orientation (matches our Godot export convention):
#   -Y = forward / muzzle      +Z = up      +X = right
#   (glTF "+Y up" export turns Blender's -Y-forward into Godot's -Z-forward)
# Scale: 1 unit = 1 meter. Oversized, stylized proportions.
# ---------------------------------------------------------------------------

COLLECTION_NAME = "revolver_blockout"


def get_collection(name):
    col = bpy.data.collections.get(name)
    if col is None:
        col = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(col)
    return col


def clear_collection_objects(name):
    """Delete everything inside the blockout collection so re-running is safe.
    WARNING: this wipes the blockout - run it before you start hand-editing,
    not after (or you'll lose your edits)."""
    col = bpy.data.collections.get(name)
    if not col:
        return
    for obj in list(col.objects):
        me = obj.data
        bpy.data.objects.remove(obj, do_unlink=True)
        if isinstance(me, bpy.types.Mesh) and me.users == 0:
            bpy.data.meshes.remove(me)


def new_mesh_object(name, bm, collection):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)  # face the normals outward
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    collection.objects.link(obj)
    return obj


def add_box(name, size, location, rotation_deg=(0, 0, 0), collection=None):
    """size = (x, y, z) FULL dimensions in meters. Scale & rotation are BAKED
    into the mesh so the object keeps a clean 1,1,1 scale (good export habit)."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)            # unit cube, edge length 1 m
    for v in bm.verts:                             # scale verts to full size
        v.co.x *= size[0]
        v.co.y *= size[1]
        v.co.z *= size[2]
    rx, ry, rz = (math.radians(a) for a in rotation_deg)
    rot = (Matrix.Rotation(rx, 4, 'X')
           @ Matrix.Rotation(ry, 4, 'Y')
           @ Matrix.Rotation(rz, 4, 'Z'))
    bmesh.ops.transform(bm, matrix=rot, verts=bm.verts)
    bmesh.ops.translate(bm, vec=Vector(location), verts=bm.verts)
    return new_mesh_object(name, bm, collection)


def add_cylinder(name, radius, depth, segments, location, axis='Y', collection=None):
    """Capped N-gon cylinder built by hand (version-proof). axis = long axis."""
    bm = bmesh.new()
    half = depth * 0.5
    top_verts, bot_verts = [], []
    for i in range(segments):
        a = (i / segments) * math.tau
        c, s = math.cos(a) * radius, math.sin(a) * radius
        if axis == 'Y':
            top_verts.append(bm.verts.new((c,  half, s)))
            bot_verts.append(bm.verts.new((c, -half, s)))
        elif axis == 'X':
            top_verts.append(bm.verts.new(( half, c, s)))
            bot_verts.append(bm.verts.new((-half, c, s)))
        else:  # 'Z'
            top_verts.append(bm.verts.new((c, s,  half)))
            bot_verts.append(bm.verts.new((c, s, -half)))
    for i in range(segments):                      # side quads
        j = (i + 1) % segments
        bm.faces.new((top_verts[i], top_verts[j], bot_verts[j], bot_verts[i]))
    bm.faces.new(top_verts)                         # caps (n-gons; fine for blockout)
    bm.faces.new(list(reversed(bot_verts)))
    bmesh.ops.translate(bm, vec=Vector(location), verts=bm.verts)
    return new_mesh_object(name, bm, collection)


# --- build -----------------------------------------------------------------
# Layout along -Y (forward).  front: barrel slab | middle: fat drum | rear: frame+grip
clear_collection_objects(COLLECTION_NAME)   # wipe any previous run (idempotent)
col = get_collection(COLLECTION_NAME)
parts = []

# Cylinder drum - the visual heart. Big & exposed so it crowns above & below
# the barrel slab. Chunky 10-sided.
parts.append(add_cylinder("drum", radius=0.060, depth=0.082, segments=10,
                          location=(0.0, 0.0, 0.0), axis='Y', collection=col))

# Barrel slab (forward, upper) - the long readable mass.
parts.append(add_box("barrel", size=(0.038, 0.235, 0.060),
                     location=(0.0, -0.160, 0.012), collection=col))

# Underlug (forward, lower) - heavy slab beneath the barrel (heavy_001 vibe).
parts.append(add_box("underlug", size=(0.038, 0.205, 0.035),
                     location=(0.0, -0.145, -0.030), collection=col))

# Rear frame - behind the drum, carries the hammer and joins the grip.
parts.append(add_box("frame_rear", size=(0.044, 0.085, 0.090),
                     location=(0.0, 0.066, 0.012), collection=col))

# Barrel rib - thin raised strip along the top of the barrel.
parts.append(add_box("rib", size=(0.020, 0.200, 0.013),
                     location=(0.0, -0.160, 0.050), collection=col))

# Front + rear sight blades (silhouette read).
parts.append(add_box("sight_front", size=(0.006, 0.010, 0.018),
                     location=(0.0, -0.255, 0.062), collection=col))
parts.append(add_box("sight_rear", size=(0.006, 0.012, 0.026),
                     location=(0.0, 0.090, 0.068), collection=col))

# Hammer nub at the very rear.
parts.append(add_box("hammer", size=(0.020, 0.030, 0.032),
                     location=(0.0, 0.110, 0.052), rotation_deg=(22, 0, 0),
                     collection=col))

# Grip - chunky, angled down-and-back from under the rear frame.
parts.append(add_box("grip", size=(0.042, 0.075, 0.165),
                     location=(0.0, 0.085, -0.085), rotation_deg=(-15, 0, 0),
                     collection=col))

# --- placeholder material (dark gunmetal, so it's not flat grey) -----------
mat = bpy.data.materials.get("revolver_blockout_mat")
if mat is None:
    mat = bpy.data.materials.new("revolver_blockout_mat")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (0.10, 0.10, 0.11, 1.0)
        if "Roughness" in bsdf.inputs:
            bsdf.inputs["Roughness"].default_value = 0.7
for obj in parts:
    if obj.data.materials:
        obj.data.materials[0] = mat
    else:
        obj.data.materials.append(mat)

# Remove Blender's default startup cube if it's still around (keeps it tidy).
default_cube = bpy.data.objects.get("Cube")
if default_cube and default_cube.name not in [p.name for p in parts]:
    bpy.data.objects.remove(default_cube, do_unlink=True)


# --- report ----------------------------------------------------------------
def tri_count(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)

total = sum(tri_count(o) for o in parts)
print("=" * 48)
print("ROTGUT revolver blockout built.")
for o in parts:
    print(f"  {o.name:<8} {tri_count(o):>4} tris")
print(f"  {'TOTAL':<8} {total:>4} tris   (final budget ~800-1400)")
print("=" * 48)
