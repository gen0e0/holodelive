.PHONY: test cache

GODOT_BIN ?= /usr/local/bin/godot

## Godot クラスキャッシュ再構築
cache:
	$(GODOT_BIN) --headless --editor --quit

## 全テスト実行
test:
	GODOT_BIN=$(GODOT_BIN) ./addons/gdUnit4/runtest.sh -a test/
