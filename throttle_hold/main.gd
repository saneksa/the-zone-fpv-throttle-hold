extends Node
## throttle_hold 1.0
##
## Disarms the drone and zeroes motor RPM on start and on every respawn
## (via Player's `teleported` signal) until the physical throttle stick is
## lowered to zero.
##
## Game: The Zone - FPV Drone Simulator
##   https://store.steampowered.com/app/3491280/The_Zone__FPV_Drone_Simulator/
## Mod loader: zonemods
##   https://github.com/goodluckNito/The-Zone-FPV-mods
##
## Why the drone takes off / hops on respawn without this mod:
##   1. In player_rigid_body.gd, Player.respawn() emits `teleported`, resets
##      `transform = ZGamestate.respawn_transform`, and zeroes linear/angular
##      velocity, but it does NOT reset `current_motor_rpm` or `auto_armed`.
##   2. If the throttle stick is above zero when respawning, the drone stays
##      armed with motors spinning at flight RPM (~15,000+ RPM) and immediately
##      launches off the ground on the first physics tick.
##   3. By connecting to `Player.teleported` (emitted synchronously on the first
##      line of `Player.respawn()`) and setting `auto_armed = false` and
##      `current_motor_rpm = 0.0` immediately, `Player.is_armed()` is false on
##      the very first physics tick after respawn. In `player_rigid_body.gd`,
##      `if not is_armed(): force_in_direction = Vector3.ZERO` and rotation
##      torque returns 0.0, so the drone sits completely still on the ground
##      with "DISARMED / LOWER THROTTLE TO ARM" shown on the OSD until the
##      pilot lowers the throttle stick to `<= release_threshold`.

const VERSION := "1.0"
const LOG_MAX := 400

var _log := PackedStringArray()
var _release_throttle := 0.05
var _hold := true
var _hold_ticks := 0
var _player: Node3D = null


func zm_init(_core: Node, _dir: String) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = 100
	_say("throttle_hold %s" % VERSION)

	var cfg := ConfigFile.new()
	if cfg.load("res://throttle_hold/settings.cfg") == OK:
		var rt := float(cfg.get_value("throttle_hold", "release_threshold", 0.05))
		if rt < 0.0:
			_release_throttle = clampf((rt + 1.0) * 0.5, 0.01, 0.15)
		else:
			_release_throttle = clampf(rt, 0.01, 0.15)
	_say("release_threshold=%.3f" % _release_throttle)

	get_tree().node_added.connect(_on_node_added)
	_hold = true
	_hold_ticks = 0
	_write()


func _physics_process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		var zc = get_node_or_null("/root/ZCommands")
		var cand = zc.get("player") if zc != null else null
		if cand is Node3D:
			_bind_player(cand as Node3D)
		else:
			var found := _find_player(get_tree().root)
			if found != null:
				_bind_player(found)
		if _player == null:
			return

	if not _hold:
		return

	_hold_ticks += 1
	var ti := float(_player.get("throttle_input"))
	var inp = _player.get("_input")
	var connected := true
	if inp != null and inp.has_method("controller_connected"):
		connected = bool(inp.call("controller_connected"))

	# Wait at least 2 physics ticks after respawn so Player._physics_process
	# has updated throttle_input from the current stick position.
	if _hold_ticks >= 2 and connected and ti <= _release_throttle:
		_hold = false
		_player.set("current_motor_rpm", 0.0)
		_player.set("auto_armed", true)
		_set_osd_warning("")
		_say("released: throttle_input=%.3f" % ti)
		_write()
		return

	# Keep disarmed and motors stopped while waiting for throttle zero.
	_player.set("auto_armed", false)
	_player.set("manually_armed", false)
	_player.set("current_motor_rpm", 0.0)
	if _hold_ticks >= 2 and ti > _release_throttle:
		_set_osd_warning("LOWER THROTTLE TO ARM")


func _bind_player(p: Node3D) -> void:
	_player = p
	if _player.has_signal("teleported"):
		var cb := Callable(self, "_on_player_teleported")
		if not _player.is_connected("teleported", cb):
			_player.connect("teleported", cb)
	_engage_hold("player_bound")


func _on_player_teleported() -> void:
	_engage_hold("respawn")


func _engage_hold(reason: String) -> void:
	_hold = true
	_hold_ticks = 0
	if _player != null and is_instance_valid(_player):
		_player.set("auto_armed", false)
		_player.set("manually_armed", false)
		_player.set("current_motor_rpm", 0.0)
		if _player is RigidBody3D:
			var rb := _player as RigidBody3D
			rb.linear_velocity = Vector3.ZERO
			rb.angular_velocity = Vector3.ZERO
	_say("hold (%s)" % reason)
	_write()


func _set_osd_warning(msg: String) -> void:
	var gs = get_node_or_null("/root/ZGamestate")
	if gs == null:
		return
	var osd = gs.get("OSD_VALUES")
	if osd is Dictionary:
		osd["arm_warning"] = msg


func _on_node_added(n: Node) -> void:
	if n is Node3D and _is_player_node(n):
		_bind_player(n as Node3D)


func _is_player_node(n: Node) -> bool:
	var s = n.get_script()
	if s != null and str(s.resource_path).to_lower().contains("player_rigid_body"):
		return true
	return false


func _find_player(n: Node) -> Node3D:
	if n is Node3D and _is_player_node(n):
		return n as Node3D
	for c in n.get_children():
		var r := _find_player(c)
		if r != null:
			return r
	return null


func _say(s: String) -> void:
	_log.append(s)
	if _log.size() > LOG_MAX:
		_log = _log.slice(_log.size() - LOG_MAX)
	print("[throttle_hold] " + s)


func _write() -> void:
	var f := FileAccess.open(OS.get_executable_path().get_base_dir().path_join("throttle_hold/status.txt"), FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(_log) + "\n")
