# CLAUDE.md — agent context for `vcb-improvements`

Read this first. Dense on purpose, for an AI coding agent. If it conflicts with the code, the
code wins — but verify before assuming this file is stale.

---

## 0. What this repo is

- A **runtime [Godot Mod Loader](https://github.com/GodotModding/godot-mod-loader) mod** for
  **Virtual Circuit Board**: a growing bundle of **small quality-of-life improvements**. Pure
  GDScript; loads at runtime from the game's `mods/` folder and **never replaces `vcb.pck`**.
- It runs on the **original, closed-source VCB engine** (Godot 3.5.1). The native `Transistor*`
  classes are provided by the game at runtime; the "unknown class" editor warning for them is
  EXPECTED — never stub them.
- **Independent of, but compatible with**, the other VCB mods. It deliberately avoids *script
  extensions* on scripts other mods extend, so it can't clash (see §2).

## 1. The improvements

Each improvement is self-contained and listed in `README.md` (that file is the user-facing log —
**add every new improvement there**). Current:

### #1 Drag Override (`scripts/drag_override.gd`)
While simulating, a **click-drag** applies the in-sim *mouse override* to **every latch the
pointer sweeps over**, not just the first click. Toggle mode → each swept latch toggles once;
Press mode → each is forced ON while held, released on mouse-up. A checkbox under the
Toggle/Press buttons in the simulation panel turns it on.

A **"Copy first state"** sub-option (a second checkbox, shown only while Drag Override is on, and
only meaningful in **Toggle** mode) makes the drag *copy the state of the first switch you flip*
onto every latch it reaches instead of toggling each independently: the first flipped switch sets a
`_copy_target` (its resulting state), then each subsequent swept latch is flipped **only if it
differs** from the target (`TE.get_entity_state` comparison), so a whole bank ends up uniform and
already-matching switches are never flipped back. The first flip is either the clicked latch (its
target is read in `_begin_drag` as `not get_entity_state`, since the Simulator has already queued
the toggle) or, if the click landed off a switch, the first latch the sweep reaches.

How it works, and why it's built this way:
- **The engine's own override is reused.** `Simulator` (`res://src/main/simulator.gd`, node
  `Main/Systems/Simulator`) exposes `set_mouse_override(pos, state)`, `is_override_toggle_mode`,
  `is_run`, `is_engine_ready`, `TE` (the `TransistorEngine`), and `texture_die` (the entity-LUT
  image). The driver calls `set_mouse_override` exactly as the Simulator does on a plain click, so
  Toggle/Press semantics and `override_set` bookkeeping are the vanilla ones.
- **No script extension.** The driver is a plain `Node` added under `Main` that listens to the
  `E.mi_mouse_input_on_board` event via `E.follow_events`. `cursor_board.gd` emits that event on
  **mouse motion too** (deduped per board pixel: `p_is_pressed = true`, `p_is_just_pressed =
  false`), which is what makes a "sweep" observable without touching `simulator.gd`. This matters
  because the **Multiplayer mod extends `simulator.gd`** — extending it here too would couple the
  two mods; a standalone listener can't clash.
- **Handler order.** The Simulator connects to `mi_mouse_input_on_board` at game start; our driver
  connects at runtime (after `Main` is built), so our handler runs **after** the Simulator's. On
  the initial press the Simulator already toggled/pressed the clicked latch, so the driver records
  that latch as "visited" and only handles *new* latches the drag reaches.
- **Latch identity + dedup.** `_latch_key_at` reads `texture_die` at the board position (same
  math as `set_mouse_override`: `r8+g8*256`, `b8+a8*256`), skips `ffffffff` (empty) and
  non-latches (`TE.is_entity_latch`), and keys the latch by its entity coords. `_visited` ensures
  each latch is handled at most once per drag (no re-toggle while lingering).
- **Press-mode release.** Extra latches forced ON during the drag are released on mouse-up
  (`_pressed_positions`); the Simulator releases the first click's latch itself.
- **The checkbox** is the game's own `res://src/gui/flux/flux_btn_checkbox.tscn` (same widget as
  the array "Multicolored Traces" option), placed in the simulation panel's VBox right after
  `SimulatorBar2` (the Toggle/Press bar). That panel (`SimulationCard`) is `show()`/`hide()`-d by
  `circuit_editor.gd` for sim/edit, so the checkbox is **sim-only** and keeps its state across
  sim stop/restart because its node is never rebuilt. Read its state with `public_get_pressed()`.
  The **"Copy first state"** checkbox (`BtnDragOverrideCopy`) sits right beneath it; the driver
  connects the master checkbox's `toggled` signal and shows/hides the sub-option with it
  (`_refresh_copy_visibility`).

**Multiplayer:** the sweep is mirrored to the peer so both boards stay in lockstep. The INITIAL
click is already synced by the MP mod (`MPDrawSync` → `Simulator.apply_remote_sim_click`); this mod only mirrors the EXTRA swept latches (and, in press mode, their release) via its own `remote func
_rpc_apply_drag_override` riding the MP ENet peer, applying each on the peer with the SENDER's
interaction mode (adopted temporarily, like `apply_remote_sim_click`). In **Copy first state** each
mirrored latch is sent as a **force-to-target** (`toggle_mode = false`, `state = _copy_target`) so
the peer *sets* it to the target rather than toggling — both boards land on the same state, and it's
a touch more skew-robust than a bare toggle. All broadcasts are gated on
`_live_session()` (MP autoload + `network_peer` + `is_connected` + `is_game_started`, via
`get_node_or_null`/`Object.get`), so with the MP mod absent it's simply local. Both players need
this mod. Same lockstep tolerance as MP's own in-sim clicks (a toggle depends on the current entity
state, so a large tick skew could in theory flip differently — no worse than a vanilla mirrored
click).

## 2. Coexistence + multiplayer-compatibility rule

Prefer **standalone nodes + events/queries** over `install_script_extension`. If an improvement
*must* extend a game script, first check it isn't one the Multiplayer or Board Size mods already
extend (MP extends: `editor.gd`, `history.gd`, `simulator.gd`, `simulation_controls.gd`,
`simulation_sliders.gd`, `shortcuts.gd`, `tool_selection.gd`, `tool_bucket.gd`, `camera.gd`,
`button_*` / `*_label` GUI scripts; Board Size extends: `circuit_renderer.gd`,
`tool_array_pencil_eraser.gd`, `file_system.gd`). GML *does* allow stacking multiple extensions of
one script, but avoiding overlap keeps things clash-free by construction.

**Every improvement MUST be compatible with the [VCB Multiplayer](https://github.com/n-popescu/vcb-multiplayer)
mod.** Concretely: anything that mutates **shared board or simulation state** (pixels, latches,
overrides, undo, selection…) must be **mirrored to the peer** so both boards stay in lockstep — ride
the MP mod's ENet peer with a `remote func`, guarded by a `_live_session()` check so it no-ops when
no session is live, and carry any per-player mode with the payload (apply it on the peer, don't
force the peer's own setting). Per-player *view* state (cursor, camera, a UI toggle's own value)
must NOT be broadcast. Improvement #1's `drag_override.gd` is the reference pattern
(`_broadcast_override` / `_rpc_apply_drag_override`, mirroring only the extra swept latches on top
of the click the MP mod already syncs). Never let a feature desync the two boards.

## 3. Engine / GDScript constraints

- **Godot 3.5.1**, GDScript 3.5 semantics — **not** Godot 4. No Godot-4 syntax.
- **Tabs, not spaces**, in every `.gd`. Quick check: `grep -nP '^\t* +\S' <file>` must be empty
  for lines you add.
- `C` and `E` are the game's autoload singletons and are always present — reference them directly.
  `MP` / `MPDrawSync` belong to the Multiplayer mod and may be absent; never reference them as
  globals (look them up with `get_node_or_null`).
- You **cannot run or parse-check GDScript** in CI here — review carefully and verify in-game. Mod
  Loader logs go to the game's `user://ModLoader.log`.

## 4. Layout

```
.github/workflows/build.yml   zips the package + auto-releases on version bump
build.sh                      → npopescu-VCBImprovements.zip
README.md                     user-facing log of improvements (keep updated)
mods-unpacked/npopescu-VCBImprovements/
├── manifest.json             Mod Loader manifest (id = npopescu-VCBImprovements)
├── mod_main.gd               waits for Main + the sim UI, then builds the driver node + checkbox
└── scripts/
    └── drag_override.gd      improvement #1: sweep-override driver (listens to board mouse input)
```

Versioning: bump `manifest.json` `version_number` (semver) on every functional change; a bump
landing on `main` auto-cuts a Release.

## 5. Git / PR workflow for agents

- Branch from `origin/main` (`git fetch origin main` first).
- **Branch names MUST start with `claude/` and END WITH the current session id**, or `git push`
  fails with HTTP 403. Example: `claude/<topic>-<sessionid>`.
- Commits are auto-signed (ssh). Don't disable signing/hooks.
- Open PRs against `main`; squash-merge. **One PR per change** (don't open duplicate branches).
- Changes are unverified in-engine; give a test recipe in the PR (start sim, tick **Drag
  Override** under Toggle/Press, drag across a row of switches in both modes; confirm the checkbox
  is hidden in edit mode and keeps its state across sim restart). **Multiplayer:** with the MP mod
  on Host + Join, enter simulation and drag across switches on one — the same latches must change
  on the other board (both modes), in lockstep.
```
