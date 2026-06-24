# Revolver Viewmodel — Asset Spec

> First real asset for ROTGUT. Working name: **"The Slab"** (rename freely).
> Source of truth for this model. Update as decisions change.

## Vision (from reference + interview)
A **heavy, brutal, chunky-slab revolver** that looks like it *hurts* to fire. Oversized
and stylized so it dominates the lower screen and reads instantly at high speed.
Rusted / worn-gunmetal finish, lots of small grimy surface detail.

Primary reference: **"heavy_001"** slab revolver (blocky industrial frame, fat fluted
cylinder, flip-up sight). Secondary: blued revolver with aggressive triangular cylinder
flutes + lanyard ring.

## Shape language (what we model)
Big chunky forms only — the small detail is *painted*, not modeled (see split below).
- **Frame / barrel:** long slab-sided rectangular block, beveled hard edges. The dominant mass.
- **Cylinder:** fat fluted drum, sits proud, the visual heart of the gun. Aggressive
  triangular/arrow flutes (from ref 1) — model a few, paint the rest.
- **Top:** flip-up iron sight + a hint of vented rib along the barrel top.
- **Grip:** chunky, angled, slightly shaped. Material TBD (worn wood vs rubber) — decide in texture pass.
- **Trigger + guard:** guard with the distinctive round loop detail.
- **Lanyard ring:** small ring dangling off the grip base. Cheap, characterful, on-theme.

## Action / reload
- **First pass: top-break.** Barrel+cylinder assembly hinges down/forward on a pivot ahead
  of the trigger. Model a visible hinge point so the break reads.
- **Long-term goal:** something *unique and brutal* — rage you can feel. Build topology so the
  front assembly can pivot/separate for a nastier custom reload later.

## Model vs. texture (PS1 discipline)
Textures are tiny (64–128px, nearest-filter, no mipmaps) and the engine adds the PS1
wobble/grime shader. So:
- **MODEL (geometry):** the big silhouette forms — frame, cylinder drum, grip, guard, sight, ring.
- **PAINT (texture):** bolts, rivets, panel seams, scratches, rust streaks, vent slots, fine flutes.

## Targets / conventions
- **Triangle budget:** ~800–1400 tris (viewmodel earns a higher budget — always on screen, close).
- **Scale:** 1 unit = 1 m. Barrel length ~0.30–0.40 m (oversized). Keep 1u=1m discipline even
  though a viewmodel is camera-parented.
- **Orientation:** Godot forward = -Z. Apply rotation & scale before export. glTF "+Y up".
- **Texture:** single 128×128 albedo (bump to 128×256 only if needed), power-of-two, pixel art.
- **Naming:** `revolver_viewmodel.glb`, `revolver_albedo.png`.
- **Export target:** `../godot-project/ROTGUT/weapons/`.

## Build order
1. **Blockout** — DONE. `revolver_blockout.py` builds 9 chunky masses (~132 tris) in the
   `revolver_blockout` collection: drum, barrel, underlug, frame_rear, rib, 2 sights, hammer, grip.
   Script is idempotent (wipes the collection before rebuilding) — but only re-run it BEFORE
   you start hand-editing, or it'll wipe your edits.
   > Source of truth: `assets-raw/weapons/revolver.blend` (14 pieces incl. hand-added muzzle,
   > undermuzzel, undergrip, trigger, trigger_guard). Exported untextured to
   > `../godot-project/ROTGUT/weapons/revolver.glb` (2026-06-24).
   > KNOWN ISSUE: `undergrip` mesh is CORRUPT (loop data references out-of-range verts —
   > "index 254 / size 28"; displays fine but breaks glTF export). Current `.glb` EXCLUDES it
   > (13 of 14 pieces). Must be rebuilt/cleaned in the source before it can be exported.
   > Export helper: `_export_to_godot.py` (has EXCLUDE={"undergrip"} — remove once fixed).
2. **Refine forms in edit mode** — learn the real tools here. First hand-modeling tasks:
   - **Trigger guard loop** + **trigger** (deliberately left out of the blockout — good first exercise).
   - **Cylinder flutes** — model 3-4 big triangular flutes, paint the rest.
   - **Bevel hard edges** so they catch light (Bevel modifier or Ctrl+B).
   - Shape the grip (taper, palm swell), connect the topstrap over the cylinder.
3. UV unwrap.
4. Texture (pixel-art albedo + painted grime).
5. Export `.glb`, drop into Godot, set nearest filter / no mipmaps.
6. (Later, code side) wire to weapon.gd; rig idle/fire/reload anims.

## Notes for the code session (not done here)
- Viewmodel will need anchor/orientation tuning once in-engine.
- Reload anim will eventually want the custom "brutal" break — flag topology for it.
