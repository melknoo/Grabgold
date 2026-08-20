class_name State
extends Node
## Basisklasse. StateMachine injiziert `actor` und `state_machine` vor dem ersten enter().

var actor: Node
var state_machine: StateMachine

func enter(_msg: Dictionary = {}) -> void: pass
func exit() -> void: pass
func update(_delta: float) -> void: pass
func physics_update(_delta: float) -> void: pass
