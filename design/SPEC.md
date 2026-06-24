# ROTGUT — Game Spec
> Fast, grimy PS1-era FPS roguelite. Skill expression through movement. Speed is power.

---

## Objective

Build a movement-heavy first-person shooter roguelite where **mastery of movement directly translates to mechanical power**. The player runs through a series of pre-designed levels per run. Death resets the run but meta-progression carries over (unlocks, permanent upgrades).

The game is about one feeling: **flowing through a level at high speed, chaining movement techs, and watching your combo escalate into a visual frenzy**.

**Target player:** Someone who loves high-skill-ceiling movement games (CSGO bhop, Titanfall 2, ULTRAKILL) and wants the satisfaction of "getting good" at movement, not just aiming.

**Success looks like:** A player spends 30 minutes in the game trying to bhop better, not because there's a reward — but because the movement itself is fun and the feedback feels amazing.

---

## Core Design Pillars

### Pillar 1 — Movement Mastery
Movement is the hardest and most rewarding skill in the game. It has a high skill floor and no ceiling.

| Tech | Description |
|---|---|
| **Bunny hop** | CSGO-style: jump at the right moment while strafing (A/D) to maintain and build speed. Requires timing and air control — NOT easy to master. |
| **Air strafing** | Mouse + A/D mid-air to redirect and gain momentum. Feels wrong at first, right once learned. |
| **Double jump** | Second jump in mid-air — can be used to extend bhop chains or recover. |
| **Dash** | A directional burst with weight and impact. NOT a teleport. Adds to existing momentum — dash while fast and you get faster. |
| **Slide** | Hold crouch while moving fast to slide: low friction, locked direction, small entry boost. Decays into a normal crouch when it runs out of speed. Chains into ramps and bhops. |
| **Crouch** | Hold crouch while slow/still. Reduced speed, lowered camera. Capped below slide-entry speed so it can't self-trigger a slide. |
| **Wall ride** | Run along vertical surfaces to carry speed and reach new geometry. Wall jump launches away + up and refreshes air jumps. |
| **Swing hook** | A grappling hook that **swings**, not reels. Fire at an anchor point; while attached the player becomes a pendulum — radial velocity converts to tangential, so a well-timed release slings you out fast. Complements bhop/air-strafe; rewards reading geometry. Needs anchor points in level design to shine (see note below). |
| **Jump boost** | Boost pad / geometry interaction that launches the player upward with speed carry. |
| **Rocket jump** | Fire a rocket at your feet and ride the explosion blast. Requires health cost or risk. |

Movement should feel **wrong when you're bad** and **euphoric when you're good**. Bhop in particular should have a detectable learning curve (like CSGO) not just feel good from frame one.

> **Controls:** WASD move, Space jump (double-jump in air), Shift dash, Ctrl crouch/slide, left-click fire. Sprint was cut — a single base speed plus the movement techs replaces it (momentum games don't need a sprint).

> **Swing hook — sequencing note.** The hook is a core identity mechanic (movement is Pillar 1, and the player wanted it from the start). But a pendulum swing is only fun with **high anchor points to swing from** — it's dead weight in a flat arena. Plan: prototype the *feel* soon by adding a few tall anchor pylons/overhangs to the test arena, then refine once real levels are designed with swing lines in mind. Implementation is physics-heavier than the other techs (a rope-length constraint converting radial→tangential velocity each frame), so it gets its own focused milestone rather than being bolted onto an existing step.

### Pillar 2 — Speed Scales Power
Movement speed directly affects combat effectiveness. A player who is flowing does more damage.

- **Speed → Damage multiplier.** The faster you're moving when you fire, the more damage your shot deals. A standing shot is weak. A bhop shot is lethal.
- This means camping and standing still are mechanically punished. Aggression is optimal.
- The exact formula is TBD (will tune in playtesting) but the *feeling* is: "I need to keep moving or I'm useless."

> **Refinement (planned).** The prototype ships a wide speed→damage spread (x1.0–x4.0). Once the combo meter (Pillar 3) exists, **tone the speed multiplier down** (likely cap ~x2) so it's a *modest mechanical edge*, not the whole reward. The big dopamine and visual escalation should come from the combo system, which tracks more than just speed. Two separate systems: speed→damage (mechanical) and combo (dopamine/visual/score). They overlap but aren't the same meter.

### Pillar 3 — Combo Escalation (The Dopamine Loop)
Kills, movement speed, and style chain into a **combo multiplier** that escalates visual feedback.

- Combo grows when: you kill enemies, maintain high speed, chain techs without stopping.
- Combo decays when: you stop moving, take damage, miss shots (TBD — tune in playtesting).
- **Visual escalation tied to combo level:**

| Combo Level | Visual Effect |
|---|---|
| 0 (cold) | Normal weapon look, no effects |
| Low | Subtle glow on weapon/hands |
| Mid | Weapon model shifts (color, trails, particles) |
| High | Effects appear around the player (aura, screen edge glow, particle burst on kills) |
| MAX | Full visual frenzy — weapon looks completely transformed, every kill is an explosion of effects |

The goal: the player *sees* how well they're doing at all times, not just reads a number. Numbers can exist (score, multiplier) but the **visual language is the primary feedback**.

#### Refinement — the "dopamine sliders" multi-meter (planned)
Instead of one combo number, track several **independent meters that each fill from a different good behavior**, then feed them into one overall **style rank** (think ULTRAKILL's D→SSS or DMC ranks) that drives the visual frenzy. Candidate sliders:

| Slider | Fills when | Drains/resets when |
|---|---|---|
| **Speed** | Maintaining high velocity | Slowing down / stopping |
| **Accuracy** | Landing hits | Missing a shot |
| **Untouched** | Not taking damage | Getting hit (big drain or reset) |
| **Variety / style** | Using *different* techs + weapons | Spamming one thing (anti-monotony, ULTRAKILL-style) |
| **Kill chain** | Kills in quick succession | Time passing without a kill |

- The combined rank is what escalates the on-screen visuals (the table above) and likely feeds run score / meta-currency.
- Why multiple sliders: a single meter is easy to game by doing one thing. Several sliders that each reward a different axis push the player to do *everything well at once* — fast, accurate, untouched, varied. That's the "getting good" fantasy.
- Open: exact slider set, weighting, decay rates, and whether style grants a tangible reward (heal-on-style like ULTRAKILL? bonus currency?). Tune once enemies exist so there's something to be stylish against. Ties into the meta-progression open question.

> **v1 status.** Combo v1 is built with visual escalation (kills → rank → HUD bar + screen-edge glow + rank-up punch). **Kills are the driver**; moving fast only *sustains* the meter (halts decay), it no longer builds it — so you can't max rank by falling off the map or bhopping in circles. Kill values (`KILL_POINTS`/`TIER_BONUS` in combo_system.gd) still open to tuning. Remaining sliders (accuracy, untouched-streak, variety) are still TODO.

---

## Game Structure (Roguelite)

- **Run:** A sequence of pre-designed levels. Player goes level → level → (boss?) → death or completion.
- **Death:** Resets current run. No checkpoint within a run (or limited — TBD).
- **Between runs:** Some form of meta-progression carries over — exact model TBD.

### Inspirations for Progression Feel
- **Cruelty Squad** — chaotic, experimental, deeply unique. A reminder that we don't need to copy an existing model. The right progression system for ROTGUT may not exist yet.
- **Hades** — permanent currency, spend between runs.
- **Risk of Rain 2** — mid-run item stacking, death resets all.

### Meta-Progression: Intentionally Open
The progression model is **deliberately unspecified** until the core movement loop is playable. Once bhop, dash, and the combo system exist and feel right, the right progression structure will become obvious from playing it. Don't design it blind — let the movement suggest it.

> **Revisit this once Step 4 (full movement suite) is complete.**

---

## Weapons

Inspired by ULTRAKILL: distinct weapons that feel completely different from each other, each with unique movement synergy.

- **Weight and impact above all.** Every shot should feel like it matters. Redliner-style exaggeration: big muzzle flash, big hit reaction, screenshake, satisfying audio.
- Rocket launcher is required (enables rocket jumping — mechanical not just combat).
- Exact weapon roster TBD during weapon phase of development.
- Weapons likely found/switched during runs (not a loadout you bring in).

### Combat economy — candidate direction (DEFERRED, not scheduled)

A strong way to deliver "weight and impact": make **ammo scarce and melee the engine**.

- **Melee is primary.** You're mostly punching/swinging in close, which keeps you moving and aggressive (reinforces Pillars 1–3 instead of competing with them).
- **Kills grant ammo/charges.** Killing (via melee) earns a bullet or a "charge" for the gun.
- **The gun is a scarce finisher.** A charged shot is devastating (one-shots, or does something unique) — but you only get shots by earning them.
- **Missing is punishing** (Quake / Redliner feel). A wasted charge hurts, so the gun rewards the *aiming* skill ceiling the way movement rewards the *movement* ceiling. An earned one-shot lands harder psychologically than spammable fire.
- Camping dies: you must close in and stay mobile to feed the economy.

**What it introduces / open interactions (resolve when building):**
- A **melee mechanic** — doesn't exist yet; this is the main new chunk of work.
- **Speed → damage** overlap: does speed boost melee? Affect ammo gained per kill? (Don't let two systems do the same job — see the speed→damage refinement note in Pillar 2.)
- **Combo**: melee kills feed style; ammo could itself be a resource/slider.
- Inspirations to study: ULTRAKILL (melee + coin + blood-on-melee health economy), Redliner (ammo-from-kills, punishing misses).

> Decision pending. This may become a core combat pillar or stay a single-weapon gimmick. Revisit after the basic weapon + enemy + combo loop is proven (we're roughly there now).

---

## Aesthetic

- **PS1-era retro** — low-poly geometry, pixelated/limited textures, simple lighting.
- This is a *vibe* target, not a technical emulation. No actual polygon limit.
- Gore and grime. The name is ROTGUT.
- Fast and readable over pretty. If it slows the game down, cut it.

---

## Tech Stack

| Component | Choice |
|---|---|
| Engine | Godot 4 (latest stable) |
| Language | GDScript (static typing enforced) |
| Renderer | Compatibility (lightweight, fast, web-export ready) |
| Level Design | Pre-designed in Godot (GridMap or CSG for now; Blender import later) |
| Version Control | Git (already initialized) |
| Platform | Windows primary; web (HTML5) as stretch goal |

---

## Project Structure

Feature-based (not type-based):

```
godot-project/
├── project.godot
├── entities/
│   ├── player/          # Player scene, controller, camera
│   ├── enemy/           # Enemy types (later)
│   └── projectiles/     # Bullet, rocket, etc.
├── weapons/             # Weapon scenes and logic
├── levels/              # Pre-designed level scenes
├── ui/                  # HUD, menus, combo display
├── common/              # Shared resources, autoloads, utilities
└── addons/              # Third-party plugins (if any)

design/                  # This spec and design notes (outside Godot project)
assets-raw/              # Raw .blend, .psd files (with .gdignore)
```

---

## Team & Collaboration

Two people now: **Ahmed** (lead — core systems & gameplay) and **Tom** (joined 2026-06-24 — levels/maps). Repo: private GitHub at github.com/ahmedN535/ROTGUT.

### Split by folder, not by feature
The #1 collaboration hazard in Godot is two people editing the **same scene file** — `.tscn` files merge badly. So we divide by **ownership of folders**, so we rarely touch the same files:

| Area | Owner | Paths |
|---|---|---|
| Levels / maps / environment | **Tom** | `levels/`, level geometry, per-level lighting & layout |
| Player, enemies, weapons, combat, combo, FX | **Ahmed** | `entities/`, `weapons/`, `common/` |
| The spec | Ahmed (Tom proposes) | `design/SPEC.md` |
| Inputs & autoloads | **Coordinate first** | `project.godot` |
| Art sources / exports | Ahmed (art session) | `assets-raw/`, exported `.glb` |

Cross-domain help is fine as a one-off (e.g. Tom reworked the dash), but **changes to someone's owned area should be flagged first** so they don't collide with in-flight work.

### The level interface (set this up so Tom isn't blocked)
Right now gameplay objects (enemies, jump pads, targets) are spawned by **code** in `test_arena.gd` — Tom can't place them in a hand-built map. **Near-term enabling task:** package player / enemy / jump_pad / target as instanceable **scenes** (`.tscn`) and define a simple **Level** convention (a player spawn point + drag-in enemy/pad/target/grapple nodes). Then Tom authors maps in the editor against a stable "place these nodes" contract, without touching core scripts.

### Git workflow
- **`git pull` before starting** each session; **push small, focused commits often** so the other sees changes fast.
- Never edit the same scene at the same time — give a heads-up on what you're touching.
- Use a short-lived **branch** for anything big/experimental; commit small stuff straight to `master`.
- `.godot/` cache is git-ignored — never commit it. The repo root is the project folder (not `E:\`).

---

## Code Style (GDScript)

Static typing enforced throughout:

```gdscript
class_name PlayerController extends CharacterBody3D

signal speed_changed(new_speed: float)

@export var max_speed: float = 30.0
@onready var _camera: Camera3D = %PlayerCamera

func _physics_process(delta: float) -> void:
    _handle_movement(delta)

func _handle_movement(delta: float) -> void:
    # movement logic
    pass
```

Rules:
- Always declare types (`var x: int`, `func foo() -> void`)
- `%UniqueNames` for node references, never hardcoded `get_node()` paths
- Signals go **up** (child → parent), calls go **down** (parent → child)
- Private members prefixed with `_`
- Signals in past tense (`speed_changed`, `player_died`)

---

## Build Order (MVP First)

Build in this order. Do not start the next step until the current one is playable.

1. **Project setup + folder structure** ← we are here
2. **FPS character controller** — walk, sprint, jump, air control, gravity
3. **Bunny hop + air strafing** — the hardest and most important step
4. **Full movement suite** — dash, double jump, wall ride, rocket jump
5. **Speed → damage system** — wire movement speed to a damage multiplier
6. **Camera feel** — mouse look, weapon bob, speed FOV scaling, screen effects
7. **First weapon** — hitscan or projectile, big impact, correct feel
8. **Combo system** — speed/kill tracking → multiplier → visual escalation
9. **Test arena** — a level designed to test and show off movement
10. **First enemy type** — dumb AI, just something to shoot at
11. **Roguelite run structure** — level sequencing, death, meta-progression
12. **More weapons + enemies** — build out the content
13. **Audio/juice pass** — sounds, music, polish
14. **Export** — playable build

---

## Boundaries

**Always:**
- Get movement feeling right before touching enemies or UI
- Keep the combo/speed loop tightly linked — test them together
- Update this spec when scope or decisions change

**Ask first:**
- Adding any new system not on the build order
- Changing the roguelite progression model once decided
- Adding multiplayer (not in scope)
- Importing Blender levels (later — not until test arena phase)

**Never:**
- Build enemies before movement is satisfying
- Add UI clutter that obscures the visual combo system
- Use ForwardPlus renderer features (stay on Compatibility)
- Add cutscenes, story, or dialogue (out of scope)

---

## Open Questions

1. **Meta-progression model** — intentionally deferred. Revisit after movement suite is playable.
2. **Combo decay conditions** — does combo drop on taking damage? On missing shots? On slowing below a speed threshold?
3. **Rocket jump health cost** — does it cost HP? Drain? Or free if you're skilled enough?
4. **Level count per run** — how many levels before a "win" or boss?
5. **Blender workflow** — when do we want to bring in Blender for level design vs. building in Godot?

---

## Enemies — design direction

First enemy (**melee rusher**) uses *direct steering* (walk straight at the player), no pathfinding — fine for the open test arena.

**Deferred to the real-level phase:**
- **Pathfinding** — upgrade grounded enemies to `NavigationAgent3D` + a baked navmesh once levels have walls/obstacles to route around. Localized change thanks to the `Enemy` base class.
- **Verticality** — do NOT make rushers jump. The player is highly mobile (bhop, grapple, jump pads), so cover the air with **enemy variety** instead: grounded rushers hold the floor, flying enemies threaten air space, ranged enemies punish camping anywhere. Mobility should be rewarded but never a free win.

---

*Last updated: 2026-06-24 | Status: APPROVED — building combat*
