extends Node2D

const BUILD_ID := "VM-0.1.2"

@onready var build_label: Label = $HUD/Margin/Readout/Build

func _ready() -> void:
	build_label.text = "Build %s · Shared Movement Laboratory" % BUILD_ID
	print("Vending Machine Survival %s started." % BUILD_ID)
	print("Shared movement laboratory. No control-feel claims are supported yet.")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_viewport().set_input_as_handled()
		var reload_error := get_tree().reload_current_scene()
		if reload_error != OK:
			push_error("Could not reload the movement laboratory (error %s)." % reload_error)
