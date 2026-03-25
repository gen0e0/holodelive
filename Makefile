.PHONY: test cache debug

GODOT_BIN ?= /usr/local/bin/godot

## Godot クラスキャッシュ再構築
cache:
	$(GODOT_BIN) --headless --editor --quit

## 全テスト実行
test:
	GODOT_BIN=$(GODOT_BIN) ./addons/gdUnit4/runtest.sh -a test/

## デバッグシーン起動
## 使い方:
##   make debug
##   make debug test=preset_id
##   make debug ARGS="p0=3,7 s1=47 auto=play:3:stage"
##   make debug test=9 cpu=both max_turns=30
##   make debug test=9 speed=3            # 3倍速
##   make debug cpu=both max_turns=30 speed=100
debug:
	-$(GODOT_BIN) res://scenes/debug/debug_scene.tscn -- $(if $(test),test=$(test)) $(if $(cpu),cpu=$(cpu)) $(if $(max_turns),max_turns=$(max_turns)) $(if $(speed),speed=$(speed)) $(ARGS)
