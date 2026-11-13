extends TextureButton

func _ready() -> void:
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	OS.shell_open("https://github.com/KoKaJun1or") 
