@tool
extends EditorPlugin

var _bridge
var _copied_on_success := false

func _enter_tree() -> void:
	_bridge = GMNNativeBridge.new()
	add_child(_bridge)
	add_tool_menu_item("GMN · Copiar reporte para ChatGPT", _copy_report)
	add_tool_menu_item("GMN · Copiar diagnóstico para ChatGPT", _copy_diagnostic)
	set_process(true)
	print("GMN-NATIVE-001 | plugin loaded; waiting for native bridge READY")

func _exit_tree() -> void:
	remove_tool_menu_item("GMN · Copiar reporte para ChatGPT")
	remove_tool_menu_item("GMN · Copiar diagnóstico para ChatGPT")
	if is_instance_valid(_bridge):
		_bridge.queue_free()

func _process(_delta: float) -> void:
	if not is_instance_valid(_bridge):
		return
	if _bridge.is_ready() and not _bridge.is_complete():
		# Native bridge owns telemetry; keep wrapper passive until checkpoint.
		return
	if _bridge.is_complete() and not _copied_on_success:
		_copied_on_success = true
		DisplayServer.clipboard_set(_bridge.get_report())
		print("GMN-NATIVE-001 | LISTO / EVIDENCIA SUFICIENTE | reporte copiado al portapapeles")

func _copy_report() -> void:
	if is_instance_valid(_bridge):
		DisplayServer.clipboard_set(_bridge.get_report())
		print("GMN-NATIVE-001 | reporte copiado")

func _copy_diagnostic() -> void:
	if is_instance_valid(_bridge):
		DisplayServer.clipboard_set(_bridge.get_diagnostic())
		print("GMN-NATIVE-001 | diagnóstico copiado")
