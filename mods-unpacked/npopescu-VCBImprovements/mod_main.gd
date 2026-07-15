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
# a checkbox placed under the Toggle/Press buttons in the simulation panel turns it on. That panel
# is sim-only, so the checkbox can only be changed while simulating and keeps its state when you
# stop and restart the sim (its node isn't rebuilt). See scripts/drag_override.gd.

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
				cb.hint_tooltip = "While simulating, click-drag across separate latches to toggle or press-and-hold each one the pointer sweeps over (per the mode above). Flip a whole row of switches in one drag."
				sim_vbox.add_child(cb)
				sim_vbox.move_child(cb, sim_bar.get_index() + 1)
				if driver != null and driver.has_method("set_checkbox"):
					driver.set_checkbox(cb)

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
