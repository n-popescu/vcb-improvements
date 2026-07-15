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

**How to use:** start the simulation. In the right-hand simulation panel, under the
**Toggle / Press** buttons ("Mouse Interaction Mode"), tick **Drag Override**. Then click and drag
across your switches. The checkbox is **only available while simulating**, and it **keeps its
state** when you stop and restart the simulation.

> **Multiplayer note:** the drag is applied **locally**. In a multiplayer session the peer only
> receives the first click (the MP mod mirrors press/release, not pointer motion), so a swept row
> can differ between the two boards until a re-sync. Intended for single-player use.

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
