# VCB Improvements

A runtime [Godot Mod Loader](https://github.com/GodotModding/godot-mod-loader) mod for
[Virtual Circuit Board](https://store.steampowered.com/app/1885690/Virtual_Circuit_Board/) that
bundles **small quality-of-life improvements** to the game. It's a growing collection — each
improvement is self-contained, and this README tracks them.

Like the other VCB mods it's **pure GDScript**, loads at runtime, **never replaces `vcb.pck`**,
and coexists with other Mod Loader mods (including
[VCB Multiplayer](https://github.com/n-popescu/vcb-multiplayer) and the
[Board Size Modifier](https://github.com/n-popescu/vcb-board-size-modifier)).

## Improvements

### 1. Drag Override — sweep latches while simulating

While **simulating**, clicking a latch is a *mouse override* (it toggles or presses the latch in
the live circuit, depending on the **Mouse Interaction Mode** — *Toggle* vs *Press*). Vanilla only
affects the single latch you click.

With **Drag Override** enabled, a **click-drag** applies that same override to **every separate
latch the pointer sweeps over**:

- **Toggle mode** — each latch the drag crosses is toggled once (flip a whole row of switches in
  one stroke).
- **Press mode** — each latch the drag crosses is forced **ON** while held, and released when you
  let go.

Each latch is handled at most once per drag, so lingering on one switch never re-toggles it. It
works with any latch layout — the switches don't need to be connected.

**Copy first state** (a sub-option that appears under *Drag Override* when it's on, Toggle mode):
instead of toggling each switch independently, it **copies the state of the first switch you flip**
onto every latch the drag reaches. Drag from an empty spot onto an **OFF** switch and the whole
sweep turns **ON**; start on an **ON** switch and the sweep turns everything **OFF**. Switches that
already match are left alone (never flipped back). Handy for setting a whole bank of switches to one
value regardless of where each started.

**How to use:** start the simulation. In the right-hand simulation panel, under the
**Toggle / Press** buttons ("Mouse Interaction Mode"), tick **Drag Override** (and optionally
**Copy first state** just beneath it). Then click and drag across your switches. The checkboxes are
**only available while simulating**, and they **keep their state** when you stop and restart the
simulation.

> **Multiplayer:** this is fully synced. In a [VCB Multiplayer](https://github.com/n-popescu/vcb-multiplayer)
> session the swept overrides are mirrored to the other player (carrying your interaction mode; in
> *Copy first state* each swept latch is mirrored as a force-to-target so both boards land on the
> same state), so both boards stay in lockstep — just like a normal in-sim click. Both players need
> this mod installed; with the multiplayer mod absent it simply works locally.

## Compatibility with the Multiplayer mod

Every improvement in this mod is built to be **compatible with the
[VCB Multiplayer](https://github.com/n-popescu/vcb-multiplayer) mod**. Anything that changes shared
board or simulation state must be **mirrored to the other player** (riding the multiplayer mod's
ENet peer, guarded so it no-ops when no session is live), so the two boards never drift. When
adding a new improvement, sync its board/sim effects the same way (see `scripts/drag_override.gd`
for the pattern) or make sure it only affects local, per-player view state.

## Install & run

1. In the [vcb-launcher](https://github.com/n-popescu/vcb-launcher), open **Runtime modding** and
   click **Enable modding** (patches `vcb.pck` once with the Mod Loader).
2. Grab `npopescu-VCBImprovements.zip` from the
   [latest release](https://github.com/n-popescu/vcb-improvements/releases/latest), or build it
   yourself: `./build.sh`.
3. Drop that zip into the game's `mods/` folder (**📁 Mods folder** in the launcher).
4. Press **▶ Launch game**.

## Build

```bash
./build.sh   # → npopescu-VCBImprovements.zip
```

It just zips `mods-unpacked/`. CI does the same on every commit and cuts a GitHub Release
automatically when `version_number` in `manifest.json` is bumped on `main`.

## License

MIT — see [LICENSE](LICENSE).
