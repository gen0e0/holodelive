extends Node

## ゲーム全体の設定を管理するグローバルシングルトン。
## オートロードとして登録し、どこからでも GameConfig.xxx でアクセスする。

const SETTINGS_PATH: String = "user://settings.cfg"

## アニメーション速度倍率。1.0=通常、2.0=2倍速、50.0=統合テスト用高速。
## StagingDirector やバナー演出など、時間に関わる全コンポーネントがこの値を参照する。
var animation_speed: float = 1.0

## オーディオ設定 (0.0–1.0)
var master_volume: float = 1.0:
	set(v):
		master_volume = clampf(v, 0.0, 1.0)
		_apply_bus_volume("Master", master_volume)

var bgm_volume: float = 1.0:
	set(v):
		bgm_volume = clampf(v, 0.0, 1.0)
		_apply_bus_volume("BGM", bgm_volume)

var sfx_volume: float = 1.0:
	set(v):
		sfx_volume = clampf(v, 0.0, 1.0)
		_apply_bus_volume("SFX", sfx_volume)

var _settings_popup: PopupPanel = null


func _ready() -> void:
	_ensure_audio_buses()
	load_settings()


# =============================================================================
# オーディオバス
# =============================================================================

func _ensure_audio_buses() -> void:
	var master_idx: int = AudioServer.get_bus_index("Master")
	if AudioServer.get_bus_index("BGM") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "BGM")
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "SFX")
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")


func _apply_bus_volume(bus_name: String, linear: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	if linear <= 0.0:
		AudioServer.set_bus_mute(idx, true)
	else:
		AudioServer.set_bus_mute(idx, false)
		AudioServer.set_bus_volume_db(idx, linear_to_db(linear))


# =============================================================================
# 永続化
# =============================================================================

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		_apply_all_volumes()
		return
	master_volume = cfg.get_value("audio", "master_volume", 1.0)
	bgm_volume = cfg.get_value("audio", "bgm_volume", 1.0)
	sfx_volume = cfg.get_value("audio", "sfx_volume", 1.0)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("audio", "bgm_volume", bgm_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.save(SETTINGS_PATH)


func _apply_all_volumes() -> void:
	_apply_bus_volume("Master", master_volume)
	_apply_bus_volume("BGM", bgm_volume)
	_apply_bus_volume("SFX", sfx_volume)


# =============================================================================
# 設定ポップアップ
# =============================================================================

func open_settings() -> void:
	if _settings_popup != null and is_instance_valid(_settings_popup):
		_settings_popup.popup_centered()
		return
	var scene: PackedScene = preload("res://scenes/settings/settings_popup.tscn")
	_settings_popup = scene.instantiate() as PopupPanel
	get_tree().root.add_child(_settings_popup)
	_settings_popup.popup_centered()
