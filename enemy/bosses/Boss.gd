extends Enemy
class_name Boss

## Base for every boss. Extends Enemy so it gets health/hurt/knockback/death
## for free, and adds two things every boss needs on top of a regular enemy:
##   1. Phases — triggered by health % thresholds, not by a timer, so
##      players who deal more damage get less time in early phases.
##   2. A small attack-pool system driven by BossAttack resources, so each
##      boss is mostly *data* (which attacks it has, and from which phase)
##      rather than a giant hand-written script.
##
## Concrete bosses extend this and override `_execute_attack(attack)` with
## a match statement on `attack.attack_id` to perform the actual behavior.

signal phase_changed(new_phase: int)
signal boss_defeated

@export var phase_health_thresholds: Array[float] = [0.66, 0.33]
## e.g. [0.66, 0.33] means: phase 1 above 66% hp, phase 2 between 66-33%,
## phase 3 below 33%. Add more entries for more phases.

@export var attacks: Array[BossAttack] = []
@export var attack_cooldown_variance: float = 0.3  # +/- random seconds, avoids robotic timing
@export var phase_transition_invuln_time: float = 0.8

var phase: int = 1
var _global_cooldown: float = 0.0
var _in_phase_transition: bool = false
var _invuln: bool = false


func _ready() -> void:
	super._ready()
	_global_cooldown = 1.0  # small grace period before the boss's first attack


func take_damage(amount: int, source_position: Vector2 = global_position) -> void:
	if _invuln:
		return
	super.take_damage(amount, source_position)
	_check_phase_transition()


func _check_phase_transition() -> void:
	if health <= 0:
		return
	var hp_pct := float(health) / float(max_health)
	var target_phase := phase_health_thresholds.size() + 1
	for i in phase_health_thresholds.size():
		if hp_pct > phase_health_thresholds[i]:
			target_phase = i + 1
			break
	if target_phase != phase:
		_enter_phase(target_phase)


func _enter_phase(new_phase: int) -> void:
	phase = new_phase
	phase_changed.emit(phase)
	_in_phase_transition = true
	_invuln = true
	_on_phase_transition_start(phase)

	var t := get_tree().create_timer(phase_transition_invuln_time)
	t.timeout.connect(func():
		_invuln = false
		_in_phase_transition = false
		_on_phase_transition_end(phase)
	)


## Override for a phase-transition animation/VFX (e.g. boss roars, arena shifts).
func _on_phase_transition_start(_new_phase: int) -> void:
	if sprite:
		sprite.modulate = Color(1, 1, 0.6)


func _on_phase_transition_end(_new_phase: int) -> void:
	if sprite:
		sprite.modulate = Color.WHITE


func _die() -> void:
	boss_defeated.emit()
	super._die()


# ---------- Attack selection (overrides Enemy's simpler _should_attack flow) ----------

func _on_patrol(delta: float) -> void:
	if _in_phase_transition:
		return
	if _global_cooldown > 0.0:
		_global_cooldown -= delta
		return
	_pick_and_start_attack()


func _pick_and_start_attack() -> void:
	var eligible: Array[BossAttack] = []
	for a in attacks:
		if phase >= a.min_phase:
			eligible.append(a)
	if eligible.is_empty():
		return

	var chosen := _weighted_pick(eligible)
	_current_attack = chosen
	state = State.TELEGRAPH
	_telegraph_timer = chosen.telegraph_duration
	_on_telegraph_start()


func _weighted_pick(pool: Array[BossAttack]) -> BossAttack:
	var total := 0.0
	for a in pool:
		total += a.weight
	var roll := randf() * total
	for a in pool:
		roll -= a.weight
		if roll <= 0.0:
			return a
	return pool[pool.size() - 1]


var _current_attack: BossAttack = null

func _do_attack() -> void:
	if _current_attack == null:
		return
	_execute_attack(_current_attack)
	_global_cooldown = _current_attack.cooldown + randf_range(-attack_cooldown_variance, attack_cooldown_variance)


## Override in each concrete boss: match attack.attack_id and perform the
## actual behavior (spawn projectiles, lunge, slam, summon adds, etc).
func _execute_attack(_attack: BossAttack) -> void:
	pass
