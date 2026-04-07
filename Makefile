.PHONY: help test cache debug host join create-sprites create-card-images export-win
.DEFAULT_GOAL := help

GODOT_BIN ?= /usr/local/bin/godot
ASEPRITE_BIN ?= /Applications/Aseprite.app/Contents/MacOS/aseprite

help: ## ヘルプ表示
	@grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | \
		sed 's/:.*## /\t/' | \
		while IFS=$$'\t' read -r target desc; do \
			printf "  \033[36m%-24s\033[0m %s\n" "$$target" "$$desc"; \
		done

cache: ## Godot クラスキャッシュ再構築
	$(GODOT_BIN) --headless --editor --quit

test: ## 全テスト実行
	GODOT_BIN=$(GODOT_BIN) ./addons/gdUnit4/runtest.sh -a test/

debug: ## デバッグシーン起動 (test=ID cpu=both max_turns=N speed=N)
	-$(GODOT_BIN) res://scenes/debug/debug_scene.tscn -- $(if $(test),test=$(test)) $(if $(cpu),cpu=$(cpu)) $(if $(max_turns),max_turns=$(max_turns)) $(if $(speed),speed=$(speed)) $(ARGS)

host: ## マルチプレイ ホスト起動
	$(GODOT_BIN) -- --host

join: ## マルチプレイ クライアント接続 (ip=ADDR)
	$(GODOT_BIN) -- --join=$(if $(ip),$(ip),127.0.0.1)

create-sprites: ## Aseprite → SpriteSheet 変換
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

CARD_WIDTH ?= 610
create-card-images: ## カード画像圧縮 (CARD_WIDTH=610)
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

export-win: ## Windows exe エクスポート (OUT=path)
	@mkdir -p builds
	$(GODOT_BIN) --headless --export-release "Windows Desktop" $(if $(OUT),$(OUT),builds/holodelive.exe)
