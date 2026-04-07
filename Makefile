.PHONY: test cache debug host join create-sprites create-card-images export-win

GODOT_BIN ?= /usr/local/bin/godot
ASEPRITE_BIN ?= /Applications/Aseprite.app/Contents/MacOS/aseprite

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
##   make debug cpu=none test=9          # ローカル2人対戦
debug:
	-$(GODOT_BIN) res://scenes/debug/debug_scene.tscn -- $(if $(test),test=$(test)) $(if $(cpu),cpu=$(cpu)) $(if $(max_turns),max_turns=$(max_turns)) $(if $(speed),speed=$(speed)) $(ARGS)

## ネットワーク対戦テスト
## Terminal 1: make host
## Terminal 2: make join
host:
	$(GODOT_BIN) -- --host

join:
	$(GODOT_BIN) -- --join=$(if $(ip),$(ip),127.0.0.1)

## Aseprite → SpriteSheet 変換
## artwork/sd/*.aseprite → cards/NNN_***/sd.json + sd.png
## 使い方:
##   make create-sprites              # 全ファイル変換
create-sprites:
	@for f in artwork/sd/*.aseprite; do \
		id=$$(basename "$$f" .aseprite | grep -oE '^[0-9]+'); \
		dir=$$(ls -d --color=never cards/$${id}_* 2>/dev/null | head -1); \
		if [ -z "$$dir" ]; then \
			echo "WARN: No card dir for ID $$id, skipping $$f"; \
			continue; \
		fi; \
		echo "Export: $$f -> $$dir/sd.*"; \
		$(ASEPRITE_BIN) -b \
			--all-layers \
			--split-layers \
			"$$f" \
			--sheet "$$dir/sd.png" \
			--data "$$dir/sd.json" \
			--format json-hash \
			--filename-format "{title} ({group}/{layer})"; \
	done
	@echo "Rebuilding Godot cache..."
	@$(GODOT_BIN) --headless --editor --quit

## カード画像圧縮
## artwork/cards/NNN_YYYY.png → cards/NNN_YYYY/img_card.png (リサイズ+圧縮)
## 使い方:
##   make create-card-images
##   make create-card-images CARD_WIDTH=610   # 幅を指定（高さは比率維持）
CARD_WIDTH ?= 610
create-card-images:
	@for f in artwork/cards/*.png; do \
		id=$$(basename "$$f" .png | grep -oE '^[0-9]+'); \
		dir=$$(ls -d --color=never cards/$${id}_* 2>/dev/null | head -1); \
		if [ -z "$$dir" ]; then \
			echo "WARN: No card dir for ID $$id, skipping $$f"; \
			continue; \
		fi; \
		echo "Convert: $$f -> $$dir/img_card.png (width=$(CARD_WIDTH))"; \
		magick "$$f" -resize $(CARD_WIDTH)x -strip -quality 95 "$$dir/img_card.png"; \
	done
	@echo "Done. Card images resized to width=$(CARD_WIDTH)."

## Windows exe エクスポート
## 使い方:
##   make export-win
##   make export-win OUT=builds/custom_name.exe
export-win:
	@mkdir -p builds
	$(GODOT_BIN) --headless --export-release "Windows Desktop" $(if $(OUT),$(OUT),builds/holodelive.exe)
