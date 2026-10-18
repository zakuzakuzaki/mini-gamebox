extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var popup = root.get_node("DebugPopup")
	popup.show_error("TTS", "読み上げに失敗しました", "language-unavailable")
	assert(popup.dialog.visible)
	assert(popup.details_label.text.contains("language-unavailable"))
	popup.show_error("別のゲーム", "テストエラー")
	assert(popup.pending.size() == 1)
	popup.dialog.hide()
	popup.dialog.confirmed.emit()
	await process_frame
	assert(popup.dialog.visible)
	assert(popup.dialog.title.contains("別のゲーム"))
	assert(popup.details_label.text == "テストエラー")
	popup.dialog.hide()
	print("Debug popup checks passed")
	quit()
