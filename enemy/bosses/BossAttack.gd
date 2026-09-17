extends Resource
class_name BossAttack

## A single named attack a boss can perform. Bosses hold an array of these
## and pick one when it's time to attack, rather than hardcoding attack
## logic per boss — keeps each boss file small even with several attacks.
##
## The actual attack *behavior* still lives in code (Boss.gd calls a method
## named by `attack_id`), but tunables (timing, damage, telegraph length)
## live here so you can balance without touching code — handy when you're
## iterating fast in the last two days before the deadline.

@export var attack_id: String = ""       # matched against a match/when in Boss.gd
@export var telegraph_duration: float = 0.5
@export var cooldown: float = 2.0
@export var damage: int = 1
@export var min_phase: int = 1            # only usable from this phase onward
@export var weight: float = 1.0           # relative chance when multiple attacks are eligible
