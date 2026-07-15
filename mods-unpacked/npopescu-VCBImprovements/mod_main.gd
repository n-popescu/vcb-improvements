extends Node

# mod_main.gd — Mod Loader entry point for VCB Improvements.
#
# A collection of small quality-of-life fixes for Virtual Circuit Board. Pure GDScript; loads at
# runtime and never replaces vcb.pck. Each improvement is self-contained so they can be added or
# removed independently. See README.md for the running list of improvements.
#
# Improvement #1 — "Drag Override": while simulating, a click-drag across separate latches applies
# the mouse override (toggle, or press-and-hold, per the current Mouse Interaction Mode) to EACH
# latch the pointer sweeps over — so a whole row of switches flips in one drag. It's off by default;
# a checkbox placed under the Toggle/Press buttons in the simulation panel turns it on. A second
# checkbox (shown only while Drag Override is on) adds a "Copy first state" sub-option: instead of
# toggling each swept latch, it copies the state of the first switch you flip onto every latch the
# drag reaches. That panel is sim-only, so the checkboxes can only be changed while simulating and
# keep their state when you stop and restart the sim (their nodes aren't rebuilt). See
# scripts/drag_override.gd.

const MOD_DIR := "npopescu-VCBImprovements"
const MOD_ROOT := "res://mods-unpacked/npopescu-VCBImprovements"
const SCRIPTS := MOD_ROOT + "/scripts"
# The game's own checkbox widget (same one the "Multicolored Traces" array option uses).
const CHECKBOX_SCENE := "res://src/gui/flux/flux_btn_checkbox.tscn"

var _built := false


func _init() -> void :
	ModLoaderLog.info("Installing VCB Improvements…", MOD_DIR)


func _ready() -> void :
	# Poll for the Main scene + its simulation UI, then build once (after the game's own _ready).
	set_process(true)


func _process(_delta: float) -> void :
	if _built:
		set_process(false)
		return
	var root := get_tree().root
	var main := root.get_node_or_null("Main")
	if main == null:
		return
	var simulator := main.get_node_or_null("Systems/Simulator")
	if simulator == null:
		simulator = main.find_node("Simulator", true, false)
	# The Mouse Interaction Mode bar (Toggle / Press) only exists once the circuit editor UI built.
	var sim_bar := main.find_node("SimulatorBar2", true, false)
	if simulator == null or sim_bar == null:
		return
	_built = true
	set_process(false)
	_build(main, simulator, sim_bar)


func _build(main: Node, simulator: Node, sim_bar: Node) -> void :
	# The drag-override driver node: listens to board mouse input and applies the extra overrides.
	# Kept under Main so it lives and dies with the game scene alongside the Simulator it references.
	var driver: Node = main.get_node_or_null("VCBImprovementsDragOverride")
	if driver == null:
		driver = _new_script(SCRIPTS + "/drag_override.gd")
		if driver == null:
			return
		driver.name = "VCBImprovementsDragOverride"
		main.add_child(driver)

	# The enable checkbox, placed right under the Toggle/Press buttons in the simulation panel
	# (same widget + look as the array "Multicolored Traces" checkbox). The whole panel is hidden
	# outside simulation, so it's sim-only and keeps its state across sim stop/restart.
	var sim_vbox := sim_bar.get_parent()
	if sim_vbox != null and sim_vbox.get_node_or_null("BtnDragOverride") == null:
		if ResourceLoader.exists(CHECKBOX_SCENE):
			var scn = load(CHECKBOX_SCENE)
			if scn != null:
				var cb = scn.instance()
				cb.name = "BtnDragOverride"
				cb.title = "Drag Override"
				if cb.has_node("Label"):
					cb.get_node("Label").text = "Drag Override"
					# The checkbox widget's Label defaults to EXPAND_FILL, which stretches
					# it across the row and shoves the check box to the far right. Drop
					# EXPAND so the box sits right next to the label text instead.
					cb.get_node("Label").size_flags_horizontal = Control.SIZE_FILL
				cb.hint_tooltip = "While simulating, click-drag across separate latches\nto toggle or press-and-hold each one the pointer\nsweeps over (per the mode above).\nFlip a whole row of switches in one drag."
				sim_vbox.add_child(cb)
				sim_vbox.move_child(cb, sim_bar.get_index() + 1)
				if driver != null and driver.has_method("set_checkbox"):
					driver.set_checkbox(cb)

				# Sub-option, shown only while Drag Override is on (the driver toggles its
				# visibility): instead of toggling each swept latch, copy the state of the FIRST
				# switch you flip onto every latch the drag reaches (already-matching latches are
				# left alone). Placed just beneath the Drag Override checkbox.
				var cb2 = scn.instance()
				cb2.name = "BtnDragOverrideCopy"
				cb2.title = "Copy first state"
				if cb2.has_node("Label"):
					cb2.get_node("Label").text = "Copy first state"
					cb2.get_node("Label").size_flags_horizontal = Control.SIZE_FILL
				cb2.hint_tooltip = "With Drag Override on (Toggle mode): copy the state\nof the first switch you flip onto every switch you\ndrag across — drag from empty onto an OFF switch to\nturn it (and the rest) ON, or onto an ON switch to\nturn them all OFF. Switches already in that state\nare left alone."
				cb2.visible = false
				sim_vbox.add_child(cb2)
				sim_vbox.move_child(cb2, cb.get_index() + 1)
				if driver != null and driver.has_method("set_copy_checkbox"):
					driver.set_copy_checkbox(cb2)


	if driver != null and driver.has_method("set_simulator"):
		driver.set_simulator(simulator)


# Instance a mod script, or null (logged) if it can't be loaded — never dereference a null.
func _new_script(path: String) -> Node:
	if not ResourceLoader.exists(path):
		push_warning("[VCB-Improvements] missing script, skipping: " + path)
		return null
	var scr = load(path)
	if scr == null:
		push_warning("[VCB-Improvements] failed to load script: " + path)
		return null
	var inst = scr.new()
	if inst == null:
		push_warning("[VCB-Improvements] failed to instance script: " + path)
		return null
	return inst
