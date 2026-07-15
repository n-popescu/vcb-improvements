extends Node

# drag_override.gd — Improvement #1 driver: "Drag Override".
#
# Listens to board mouse input during simulation and, when the checkbox is enabled, applies the
# game's OWN mouse-override (Simulator.set_mouse_override) to EVERY latch the pointer sweeps over
# while the left button is held — not just the one first clicked. In Toggle mode each swept latch
# toggles once; in Press mode each is forced ON while held and released on mouse-up. So you can
# flip a whole row of separate switches in one click-drag.
#
# It never edits simulator.gd's source (no script extension), so it coexists with mods that DO
# extend the Simulator (e.g. the Multiplayer mod). It only reads the Simulator's public members and
# calls set_mouse_override — exactly what the Simulator does itself on a plain in-sim click.
#
# The initial click is left to the Simulator's own _ev_mi_mouse_input_on_board (our handler runs
# after it, since we connect at runtime), so we only ADD the drag. Each latch is handled at most
# once per drag, so lingering on one switch never re-toggles it.
#
# MULTIPLAYER: this rides the Multiplayer mod's ENet peer (it never opens its own). The INITIAL
# click is already mirrored by the MP mod (MPDrawSync -> Simulator.apply_remote_sim_click); we only
# mirror the EXTRA latches the drag sweeps (and, in Press mode, their release), so both boards end
# up with the same override_set and the deterministic engines stay in lockstep. Each swept override
# carries the sender's interaction mode and is applied on the peer with THAT mode (adopting it
# temporarily), matching how MP applies a remote click. Both players need this mod installed for
# the drag to sync; with the MP mod absent it's simply local. Same lockstep tolerance as MP's own
# in-sim clicks (each peer free-runs its deterministic engine).

var _simulator: Node = null
var _checkbox: Node = null
var _copy_checkbox: Node = null

var _drag_active := false
var _visited := {}             # latch-key -> true : latches already handled this drag
var _pressed_positions := []   # press-mode: positions we forced ON, to release on mouse-up
var _applying_remote := false

# "Copy first state" sub-option: the resulting state of the first switch flipped this drag; every
# other swept latch is set to match it (toggle-mode only).
var _copy_target := false
var _copy_target_set := false

const _INVALID := Vector2(-1, -1)


func _ready() -> void :
	E.follow_events(self, [
		E.mi_mouse_input_on_board,
	])


func set_simulator(p_simulator: Node) -> void :
	_simulator = p_simulator


func set_checkbox(p_checkbox: Node) -> void :
	_checkbox = p_checkbox
	# Show/hide the "Copy first state" sub-option with the master Drag Override toggle.
	if _checkbox != null and _checkbox.has_signal("toggled") \
			and not _checkbox.is_connected("toggled", self, "_on_drag_override_toggled"):
		var _e = _checkbox.connect("toggled", self, "_on_drag_override_toggled")
	_refresh_copy_visibility()


func set_copy_checkbox(p_checkbox: Node) -> void :
	_copy_checkbox = p_checkbox
	_refresh_copy_visibility()


func _on_drag_override_toggled(_pressed: bool) -> void :
	_refresh_copy_visibility()


# The "Copy first state" checkbox is only meaningful while Drag Override itself is on.
func _refresh_copy_visibility() -> void :
	if _copy_checkbox != null:
		_copy_checkbox.visible = _is_enabled()


func _is_enabled() -> bool:
	if _checkbox == null:
		return false
	if _checkbox.has_method("public_get_pressed"):
		return _checkbox.public_get_pressed()
	return false


func _copy_enabled() -> bool:
	if _copy_checkbox == null:
		return false
	if _copy_checkbox.has_method("public_get_pressed"):
		return _copy_checkbox.public_get_pressed()
	return false


func _ev_mi_mouse_input_on_board(_mode: int, _args: Dictionary) -> void :
	if _applying_remote:
		return
	if not _is_enabled():
		return
	var sim = _simulator
	if sim == null:
		return
	if not (sim.is_run and sim.is_engine_ready) or sim.TE == null:
		return
	# Don't act on input the Multiplayer mod is replaying from the network (edit-mode remote draws
	# re-echo this event); the peer's sweeps arrive via _rpc_apply_drag_override instead.
	var ed := _editor()
	if ed != null and bool(ed.get("is_processing_remote_input")):
		return
	var pos: Vector2 = _args[E.mi_mouse_input_on_board.p_position]
	var is_pressed: bool = _args[E.mi_mouse_input_on_board.p_is_pressed]
	var is_just_pressed: bool = _args[E.mi_mouse_input_on_board.p_is_just_pressed]
	var is_just_released: bool = _args[E.mi_mouse_input_on_board.p_is_just_released]
	var is_left_click: bool = _args[E.mi_mouse_input_on_board.p_is_left_click]

	if is_just_released:
		_end_drag(sim)
		return
	if not is_left_click:
		return
	if is_just_pressed:
		_begin_drag(sim, pos)
		return
	if _drag_active and is_pressed:
		_sweep(sim, pos)


func _begin_drag(sim, pos: Vector2) -> void :
	_drag_active = true
	_visited.clear()
	_pressed_positions.clear()
	_copy_target = false
	_copy_target_set = false
	# The Simulator already applied the override for this first click (and the MP mod already
	# mirrored it); remember its latch so the sweep doesn't handle it again.
	var e: = _latch_entity_at(sim, pos)
	if e != _INVALID:
		_visited[_entity_key(e)] = true
		# In "Copy first state" (toggle mode), clicking directly on a switch IS the first flip:
		# adopt its resulting state as the target. The Simulator just queued the toggle, so the
		# entity flips to `not current` on the next solve — that's the target.
		if _copy_enabled() and bool(sim.is_override_toggle_mode):
			_copy_target = not bool(sim.TE.get_entity_state(int(e.x), int(e.y)))
			_copy_target_set = true


func _sweep(sim, pos: Vector2) -> void :
	var e: = _latch_entity_at(sim, pos)
	if e == _INVALID:
		return
	var key: = _entity_key(e)
	if _visited.has(key):
		return
	_visited[key] = true
	var toggle_mode: bool = bool(sim.is_override_toggle_mode)
	# "Copy first state" only reshapes Toggle mode (Press already forces a single ON state).
	if _copy_enabled() and toggle_mode:
		_sweep_copy(sim, pos, e)
		return
	# Default: toggle the latch (or, in Press mode, force it ON — the state arg matters only there).
	sim.set_mouse_override(pos, true)
	if not toggle_mode:
		_pressed_positions.append(pos)
	# Mirror this extra swept latch to the multiplayer peer (no-op when no live session).
	_broadcast_override(pos, true, toggle_mode)


# "Copy first state": the first switch flipped this drag sets the target state; every other swept
# latch is made to match it (only flipped when it differs). Mirrored to the peer as a force-to-
# target (Press-style) override so both boards land on the target even under a small tick skew.
func _sweep_copy(sim, pos: Vector2, e: Vector2) -> void :
	var cur: bool = bool(sim.TE.get_entity_state(int(e.x), int(e.y)))
	if not _copy_target_set:
		# First flipped switch (the click landed off a switch): toggle it, adopt its new state.
		sim.set_mouse_override(pos, true)
		_copy_target = not cur
		_copy_target_set = true
		_broadcast_override(pos, _copy_target, false)
	elif cur != _copy_target:
		# Differs from the target → toggle it so it matches (toggle mode flips to `not cur`).
		sim.set_mouse_override(pos, true)
		_broadcast_override(pos, _copy_target, false)
	# else: already at the target state → leave it untouched (nothing to mirror).


func _end_drag(sim) -> void :
	if not _drag_active:
		return
	_drag_active = false
	# Press mode: release every EXTRA latch we forced on (the Simulator releases the first click's
	# latch itself, and the MP mod mirrors that release). Toggle mode needs no release.
	if not bool(sim.is_override_toggle_mode):
		for p in _pressed_positions:
			sim.set_mouse_override(p, false)
			_broadcast_override(p, false, false)
	_visited.clear()
	_pressed_positions.clear()


# The entity coords (x,y in the sim entity list) of the latch under a board position, or _INVALID
# if the position is off-board, empty, or not a latch. Mirrors Simulator.set_mouse_override's lookup.
func _latch_entity_at(sim, pos: Vector2) -> Vector2:
	if not C.CIRCUIT.RECT.has_point(pos):
		return _INVALID
	var die: Image = sim.texture_die
	if die == null:
		return _INVALID
	die.lock()
	var px: Color = die.get_pixelv(pos)
	die.unlock()
	if px.to_html() == "ffffffff":
		return _INVALID
	var x: int = px.r8 + (px.g8 * 256)
	var y: int = px.b8 + (px.a8 * 256)
	if not sim.TE.is_entity_latch(x, y):
		return _INVALID
	return Vector2(x, y)


func _entity_key(e: Vector2) -> String:
	return str(int(e.x)) + "," + str(int(e.y))


# --- multiplayer ------------------------------------------------------------------------------
func _editor() -> Node:
	var main := get_tree().root.get_node_or_null("Main")
	if main == null:
		return null
	var ed := main.get_node_or_null("Systems/Editor")
	if ed == null:
		ed = main.find_node("Editor", true, false)
	return ed


# True when a live multiplayer session exists (MP mod loaded, connected and in-game). Queried via
# get_node_or_null / Object.get so this mod also works with the MP mod absent.
func _live_session() -> bool:
	var mp := get_tree().root.get_node_or_null("MP")
	if mp == null:
		return false
	if get_tree().network_peer == null:
		return false
	return bool(mp.get("is_connected")) and bool(mp.get("is_game_started"))


# Mirror one swept override to the peer(s), carrying our interaction mode so they apply it the same
# way (see _rpc_apply_drag_override). No-op when there's no live session.
func _broadcast_override(pos: Vector2, state: bool, toggle_mode: bool) -> void :
	if not _live_session():
		return
	rpc("_rpc_apply_drag_override", int(pos.x), int(pos.y), state, toggle_mode)


remote func _rpc_apply_drag_override(px: int, py: int, state: bool, toggle_mode: bool) -> void :
	var sim = _simulator
	if sim == null:
		return
	if not (sim.is_run and sim.is_engine_ready) or sim.TE == null:
		return
	var pos: = Vector2(px, py)
	if not C.CIRCUIT.RECT.has_point(pos):
		return
	# Apply with the SENDER's interaction mode (adopt it temporarily), like MP's remote sim click.
	_applying_remote = true
	var saved: bool = bool(sim.is_override_toggle_mode)
	sim.is_override_toggle_mode = toggle_mode
	sim.set_mouse_override(pos, state)
	sim.is_override_toggle_mode = saved
	_applying_remote = false
