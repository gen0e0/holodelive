# HOLOdeLIVE カードスキル

## 概要

HOLOdeLIVE には69枚のカードがあり、全てのカードがユニークなスキルを持つ。スキルの共通化はほぼ不可能であり、各カードに固有のスキルコード（`cards/NNN_name/card_skills.gd`）が存在する。

スキルは以下の3種類に大別される:

| 種類 | 発動タイミング | 件数 |
|---|---|---|
| **Play Skill** | カードをステージにプレイした時、またはオープンした時 | 57 |
| **Action Skill** | アクションフェーズに任意で発動（各スキルにつき1回/ターン） | 9 |
| **Passive Skill** | 常時効果を発揮 | 11 |

一部のカード（001, 012, 035, 041, 049）は複数のスキルを持つ。

---

## スキル種別の詳細

### Play Skill（プレイスキル）

カードがステージに配置された時、またはゲスト（楽屋の裏向きカード）がオープンされた時に自動的に発動する。ゲームの主要なインタラクションの大部分を担う。

**発動条件:**
- ステージにプレイした時
- 楽屋のゲストをオープンした時（ただし、032 ちょこの効果でオープンされた場合は発動しない）

**典型的な効果パターン:**
- カードの移動（帰宅、手札戻し、デッキ操作）
- ドロー・サーチ
- 手札からの追加プレイ
- ターンフラグの設定

### Action Skill（アクションスキル）

アクションフェーズに、プレイヤーが任意で発動できるスキル。各スキルにつき1ターンに1回まで使用可能。

**該当カード:** 016, 020, 023, 034, 035(2nd), 046, 048, 056, 065

**特徴:**
- 自身を帰宅させるコストを持つものが多い（016, 023, 046）
- RNGを伴うもの（020: ダイス勝負）
- 位置入替（035: デッキ最下部と交換、056: 相手手札と交換、065: 相手ステージへ移動）

### Passive Skill（パッシブスキル）

場に存在する限り常時効果を発揮する。ライブ準備時に Modifier として自身や隣接カードに付与される。

**パッシブの分類:**

| 分類 | カード | 効果 |
|---|---|---|
| WILD | 001, 012, 039, 049 | 好きなアイコンとして扱える |
| ランクアップ | 001(2nd) | 成立役を1つ上にする |
| 隣接バフ | 015(VOCAL), 041(ENGLISH), 055(INDONESIA) | 隣接カードにアイコン/スートを付与 |
| ショウダウン修飾 | 004(FIRST_READY), 005(DOUBLE_WIN) | ショウダウンルールを変更 |
| 耐性 | 049(2nd: MATSURI_IMMUNE) | 特定スキルの対象外 |
| 自己除去型 | 058, 059 | 場に出た時に効果を発動し、ゲームから除去される |

---

## 実装パターン分類

全69スキルは以下の5パターンに分類できる。

### パターン1: 即時効果

選択不要で即座に完了する。`phase == 0` で処理を行い `SkillResult.done()` を返す。

```gdscript
## こーせーのー: 山札の上から1枚引いて手札に加える。
func _skill_0(ctx: SkillContext) -> SkillResult:
	ZoneOps.draw_card(ctx.state, ctx.player, ctx.recorder)
	return SkillResult.done()
```

**該当カード:** 009, 017, 018, 022, 043, 050, 051, 058, 062, 069, 全Passive

### パターン2: 単一選択

ターゲットを提示 → プレイヤーが選択 → 実行。2フェーズ構成。

```gdscript
## ぎゅむっ: 相手の場のカードを1枚、山札の一番上に置く。
func _skill_0(ctx: SkillContext) -> SkillResult:
	if ctx.phase == 0:
		var targets: Array = _get_opp_field_ids(ctx)
		if targets.is_empty():
			return SkillResult.done()
		return SkillResult.waiting(Enums.ChoiceType.SELECT_CARD, targets)
	else:
		var chosen: int = ctx.choice_result
		ZoneOps.move_to_deck_top(ctx.state, chosen, ctx.recorder)
		return SkillResult.done()
```

**該当カード:** 002, 003, 006, 007, 011, 023, 029, 031, 037, 038, 040, 042, 045, 047, 053, 054, 060, 061

### パターン3: 複数段階

3フェーズ以上の対話が必要。中間状態を `ctx.data` に保存して次フェーズに引き継ぐ。

```gdscript
## 入口の女: 山札から2枚引いて手札に加え、手札から2枚選び山札に戻す。
func _skill_0(ctx: SkillContext) -> SkillResult:
	if ctx.phase == 0:
		ZoneOps.draw_card(ctx.state, ctx.player, ctx.recorder)
		ZoneOps.draw_card(ctx.state, ctx.player, ctx.recorder)
		return SkillResult.waiting(Enums.ChoiceType.SELECT_CARD, hand.duplicate())
	elif ctx.phase == 1:
		ctx.data["first_returned"] = ctx.choice_result
		ZoneOps.move_to_deck_top(ctx.state, ctx.choice_result, ctx.recorder)
		return SkillResult.waiting(Enums.ChoiceType.SELECT_CARD, hand.duplicate())
	else:
		ZoneOps.move_to_deck_top(ctx.state, ctx.choice_result, ctx.recorder)
		return SkillResult.done()
```

**該当カード:** 016, 019, 025, 026, 028, 030, 035, 036, 046, 052, 056, 057, 068

### パターン4: RNG（ランダム/ダイス/じゃんけん）

`Enums.ChoiceType.RANDOM_RESULT` を使用し、外部から乱数結果を注入する。テスト時に決定的な結果を与えられる。

```gdscript
## 全ホロメン妹化計画: 互いにサイコロを振り、勝敗で効果が変わる。
func _skill_0(ctx: SkillContext) -> SkillResult:
	if ctx.phase == 0:
		return SkillResult.waiting(Enums.ChoiceType.RANDOM_RESULT, [1, 2, 3, 4, 5, 6])
	elif ctx.phase == 1:
		ctx.data["my_roll"] = ctx.choice_result
		return SkillResult.waiting(Enums.ChoiceType.RANDOM_RESULT, [1, 2, 3, 4, 5, 6])
	else:
		# 勝敗判定と効果適用
		...
		return SkillResult.done()
```

**該当カード:** 010, 020, 022, 036, 041(play), 056, 059

### パターン5: スキル参照

他のカードの Play Skill を動的に検索・実行する。`ctx.skill_registry` を通じてスキルを取得し、サブ `SkillContext` を生成して委譲する。

```gdscript
## それこよの！: 相手の場のカードのプレイ時能力を使用する。
func _skill_0(ctx: SkillContext) -> SkillResult:
	if ctx.phase == 0:
		return SkillResult.waiting(Enums.ChoiceType.SELECT_CARD, targets)
	elif ctx.phase == 1:
		var inst: CardInstance = ctx.state.instances[ctx.choice_result]
		var skill: BaseCardSkill = ctx.skill_registry.get_skill(inst.card_id)
		var sub_ctx := SkillContext.new(ctx.state, ctx.registry, chosen, ctx.player, 0, null, ctx.recorder, ctx.skill_registry)
		var sub_result: SkillResult = skill.execute_skill(sub_ctx, 0)
		if sub_result.status == SkillResult.Status.WAITING_FOR_CHOICE:
			ctx.data["sub_skill_card_id"] = inst.card_id
			return sub_result
		return SkillResult.done()
	else:
		# サブスキルの続行
		...
```

**該当カード:** 008, 034, 044, 066

---

## インフラストラクチャ

### SkillContext

スキル実行に必要な全情報を束ねるコンテキストオブジェクト。

| プロパティ | 型 | 説明 |
|---|---|---|
| **state** | GameState | ゲーム状態への参照 |
| **registry** | CardRegistry | カード定義レジストリ |
| **recorder** | DiffRecorder | 状態変更の記録 |
| **skill_registry** | SkillRegistry | スキルレジストリ（スキル参照パターン用） |
| **source_instance_id** | int | スキル発動元のカードインスタンスID |
| **player** | int | アクティブプレイヤー（0 or 1） |
| **phase** | int | 現在のフェーズ（0, 1, 2, ...） |
| **choice_result** | Variant | プレイヤーの選択結果 |
| **data** | Dictionary | フェーズ間データの引き継ぎ |

### SkillResult

スキル実行の戻り値。完了またはプレイヤーの選択待ちを表す。

| メソッド | 説明 |
|---|---|
| `SkillResult.done()` | スキル完了 |
| `SkillResult.waiting(choice_type, valid_targets)` | 選択待ち |

**ChoiceType:**
- `SELECT_CARD` — カードを1枚選択
- `SELECT_ZONE` — ゾーン（"stage" / "backstage"）を選択
- `RANDOM_RESULT` — ランダム結果の注入（ダイス、じゃんけん等）

### PendingChoice

スキル解決中のプレイヤー入力待ち状態を表す。GameController がスキルスタックを解決する過程で生成され、プレイヤーの応答後にスキルの次フェーズが再開される。

### ZoneOps

カードのゾーン間移動を行うユーティリティクラス。全ての移動を DiffRecorder に記録する。

| メソッド | 説明 |
|---|---|
| `draw_card` | デッキ先頭 → 手札 |
| `move_to_home` | 任意ゾーン → 自宅 |
| `move_to_deck_top` | 任意ゾーン → デッキ先頭 |
| `move_to_deck_bottom` | 任意ゾーン → デッキ末尾 |
| `play_to_stage_from_zone` | 任意ゾーン → ステージ |
| `play_to_backstage` | 任意ゾーン → 楽屋 |

### SkillRegistry

`card_id` → `BaseCardSkill` のマッピング。GameSetup 時に全カードのスキルスクリプトを登録する。

---

## 全カードスキル一覧

| ID | キャラクター名 | アイコン | スート | スキル種別 | スキル名 | 効果概要 | パターン |
|---|---|---|---|---|---|---|---|
| 001 | ときのそら | SEISO | LOVELY | Passive×2 | ぬんぬん / 始祖 | WILD付与 / ランクアップ | 即時 |
| 002 | 湊あくあ | CHARISMA, OTAKU | LOVELY | Play | あてぃしのこと好きすぎぃ！ | 自宅JP→ステージ | 単一選択 |
| 003 | 白上フブキ | OTAKU, CHARISMA | LOVELY | Play | フブキングダム | 手札JP♥/◆→プレイ | 単一選択 |
| 004 | 百鬼あやめ | VOCAL, DUELIST | LOVELY | Passive | なんも聞いとらんかった | FIRST_READY付与 | 即時 |
| 005 | さくらみこ | ENJOY | LOVELY | Passive | サクラカゼ | DOUBLE_WIN付与 | 即時 |
| 006 | 天音かなた | REACTION | LOVELY | Play | ぎゅむっ | 相手場→デッキ先頭 | 単一選択 |
| 007 | 風真いろは | DUELIST, KUSOGAKI | LOVELY | Play | うーばーござる | 自宅JP→手札 | 単一選択 |
| 008 | 博衣こより | INTEL | LOVELY | Play | それこよの！ | 相手場カードのPlay Skill使用 | スキル参照 |
| 009 | ロボ子さん | SEXY | LOVELY | Play | こーせーのー | 1ドロー | 即時 |
| 010 | 姫森ルーナ | ALCOHOL, SEISO | LOVELY | Play | くせえのら | 相手手札ランダム1枚帰宅 | RNG |
| 011 | 桃鈴ねね | KUSOGAKI, TRICKSTER | LOVELY | Play | 見て見て！ギラファ！ | 自場→手札（自身除外） | 単一選択 |
| 012 | AZKi | SEISO | COOL | Passive+Play | Diva / Guess! | WILD付与 / 手札SEISO→プレイ | 即時+単一選択 |
| 013 | 常闇トワ | CHARISMA | COOL | Play | ドーム炊くよ！ | protection フラグ設定 | 即時 |
| 014 | ラプラス・ダークネス | OTAKU, KUSOGAKI | COOL | Play | かつもーく | デッキからholoXサーチ→プレイ | 即時 |
| 015 | 星街すいせい | VOCAL, TRICKSTER | COOL | Passive | Hoshimatic Project | 隣接にVOCAL付与 | 即時 |
| 016 | 獅白ぼたん | ENJOY, OTAKU | COOL | Action | なんとかしてくれる | 自宅2枚→手札、自身帰宅 | 複数段階 |
| 017 | 大神ミオ | REACTION, INTEL | COOL | Play | Big God Mio-n | 相手手札全帰宅→2ドロー | 即時 |
| 018 | 沙花叉クロヱ | DUELIST, SEXY | COOL | Play | 人生リセットボタンぽちー | 自手札全帰宅→3ドロー | 即時 |
| 019 | 不知火フレア | INTEL | COOL | Play | 俺のイナ！ | 自宅→自分手札＋相手手札 | 複数段階 |
| 020 | 猫又おかゆ | SEXY, VOCAL | COOL | Action | 全ホロメン妹化計画 | ダイス勝負→奪取or帰宅 | RNG |
| 021 | 雪花ラミィ | ALCOHOL, REACTION | COOL | Play | やめなー | skip_action フラグ設定 | 即時 |
| 022 | 紫咲シオン | KUSOGAKI | COOL | Play | 無軌道雑談 | 手札シャッフル配り直し | RNG |
| 023 | 黒上フブキ | TRICKSTER | COOL | Action | もう帰ろうぜ | 自身帰宅→相手場1枚帰宅 | 単一選択 |
| 024 | 夏色まつり | SEISO | HOT | Play | まつりライン | SEISO全帰宅→WILD付与 | 即時 |
| 025 | 兎田ぺこら | CHARISMA, REACTION | HOT | Play | 豪運うさぎってわーけ！ | 手札⇔デッキ上→プレイ | 複数段階 |
| 026 | 宝鐘マリン | OTAKU, SEXY | HOT | Play | マリ箱 | 相手場→手札、自手札→楽屋 | 複数段階 |
| 027 | 角巻わため | VOCAL | HOT | Play | わるくないよねぇ | no_stage_play フラグ設定 | 即時 |
| 028 | 戌神ころね | ENJOY | HOT | Play | おらよ | 相手場2枚→手札 | 複数段階 |
| 029 | 大空スバル | REACTION | HOT | Play | 大空警察 | 相手場SEXY/KUSOGAKI/TRICKSTER→帰宅 | 単一選択 |
| 030 | 白銀ノエル | DUELIST, SEXY | HOT | Play | 入口の女 | 2ドロー→2枚デッキ上へ | 複数段階 |
| 031 | 鷹嶺ルイ | INTEL, SEXY, ALCOHOL | HOT | Play | 有能女幹部 | 自宅EN/ID→手札 | 単一選択 |
| 032 | 癒月ちょこ | SEXY, ALCOHOL | HOT | Play | 身体測定 | 相手楽屋オープン | 即時 |
| 033 | アキ・ローゼンタール | ALCOHOL, DUELIST | HOT | Play | あらあらぁ | 自分楽屋オープン | 即時 |
| 034 | 赤井はあと | KUSOGAKI, ENJOY, INTEL | HOT | Action | はあちゃまっちゃま～ | 自宅カードと入替→Play Skill発動 | スキル参照 |
| 035 | 尾丸ポルカ | TRICKSTER | HOT | Play+Action | ポルカおるか？/おらんか？ | 1ドロー→デッキ上 / デッキ下と交換 | 複数段階 |
| 036 | YAGOO | ― | ENGLISH | Play | お茶会 | 相手手札ランダム2枚奪取 | RNG |
| 037 | えーちゃん | ― | ENGLISH | Play | 休むのも仕事です！ | 相手場→帰宅 | 単一選択 |
| 038 | 春先のどか | ― | ENGLISH | Play | 大丈夫ですか？？ | 自宅→ステージ | 単一選択 |
| 039 | IRyS | SEISO | ENGLISH | Passive | ネフィリム | WILD付与 | 即時 |
| 040 | がうる・ぐら | CHARISMA, VOCAL, KUSOGAKI | ENGLISH | Play | a | 手札EN→ステージ | 単一選択 |
| 041 | 一伊那尓栖 | OTAKU | ENGLISH | Passive+Play | ネクロノミコン | 隣接にEN付与 / ダイス効果分岐 | 即時+RNG |
| 042 | 森カリオペ | VOCAL, DUELIST, ALCOHOL | ENGLISH | Play | メメント・モリ | 相手場→デッキ最下部 | 単一選択 |
| 043 | ワトソン・アメリア | ENJOY, TRICKSTER | ENGLISH | Play | グレムリンノイズ | 手札交換 | 即時 |
| 044 | 小鳥遊キアラ | REACTION | ENGLISH | Play | HOLOTALK | 自宅カードのPlay Skill使用 | スキル参照 |
| 045 | セレス・ファウナ | INTEL, SEISO | ENGLISH | Play | 癒しの極地 | 相手場KUSOGAKI→自ステージ | 単一選択 |
| 046 | オーロ・クロニー | ALCOHOL, SEXY | INDONESIA | Action | タイムリープ | 自身帰宅→相手場2枚→手札 | 複数段階 |
| 047 | ハコス・ベールズ | KUSOGAKI | INDONESIA | Play | カオスそのもの | 相手場カードと位置入替 | 単一選択 |
| 048 | 七詩ムメイ | TRICKSTER, ALCOHOL, VOCAL | INDONESIA | Action | Mumei Berries | 手札→デッキ下、1ドロー | 単一選択 |
| 049 | アイラニ・イオフィフティーン | SEISO | INDONESIA | Passive×2 | Iofi / Erofi | WILD付与 / まつり耐性 | 即時 |
| 050 | クレイジー・オリー | OTAKU, INTEL | INDONESIA | Play | ゾンビパーティ | デッキ最下部→手札 | 即時 |
| 051 | ムーナ・ホシノヴァ | VOCAL | INDONESIA | Play | 何見てンだヨ、ぺったんこ | 特定12キャラ帰宅 | 即時 |
| 052 | アユンダ・リス | ENJOY | INDONESIA | Play | ALiCE&u | デッキ上2枚→1枚自分、1枚相手 | 複数段階 |
| 053 | アーニャ・メルフィッサ | DUELIST, REACTION | INDONESIA | Play | スーパー通訳 | 手札JP☀/ID☽→プレイ | 単一選択 |
| 054 | カエラ・コヴァルスキア | INTEL | INDONESIA | Play | メンテナンス | 相手場DUELIST→帰宅 | 単一選択 |
| 055 | パヴォリア・レイネ | SEXY | STAFF | Passive | レイネの教室 | 隣接にINDONESIA付与 | 即時 |
| 056 | ベスティア・ゼータ | TRICKSTER, ENJOY | STAFF | Action | 潜入捜査 | 自身→相手手札、相手手札ランダム→自場 | RNG |
| 057 | こぼ・かなえる | KUSOGAKI, CHARISMA | STAFF | Play | クソガキング | KUSOGAKI数分、相手場→手札 | 複数段階 |
| 058 | 桐生ココ | ― | ― | Passive | 伝説のドラゴン | 全帰宅→自身除去 | 即時 |
| 059 | ぺこらマミー | ― | ― | Passive | ごはんよー | じゃんけん3回→帰宅→自身除去 | RNG |
| 060 | シオリ・ノヴェラ | INTEL | ENGLISH | Play | 知識の収集家 | 場/自宅のINTEL→手札 | 単一選択 |
| 061 | ネリッサ・レイヴンクロフト | VOCAL, SEXY | ENGLISH | Play | BAN PANTSU | 相手場SEXY→帰宅 | 単一選択 |
| 062 | 古石ビジュー | KUSOGAKI, TRICKSTER | ENGLISH | Play | 産んじゃう…！ | 対面1st→こちらステージ | 即時 |
| 063 | フワワ・アビスガード | ENJOY, KUSOGAKI | ENGLISH | Play | 番犬 | モココ(64)をサーチ→ステージ | 即時 |
| 064 | モココ・アビスガード | REACTION, DUELIST | ENGLISH | Play | 忠犬 | フワワ(63)をサーチ→ステージ | 即時 |
| 065 | 火威青 | SEXY | COOL | Action | じゃじゃーん！ | 自身→相手ステージ、1ドロー | 即時 |
| 066 | 音乃瀬奏 | KUSOGAKI | LOVELY | Play | 尻を揉むために生まれてきた女 | 前のカードのPlay Skill使用 | スキル参照 |
| 067 | 一条莉々華 | TRICKSTER, ALCOHOL | HOT | Play | 酒持ってこーい | デッキ上4枚→ALCOHOL→プレイ | 複数段階 |
| 068 | 儒烏風亭らでん | OTAKU, ALCOHOL, INTEL | COOL | Play | おあとがよろしいようで | デッキ上3枚並べ替え | 複数段階 |
| 069 | 轟はじめ | DUELIST | LOVELY | Play | タイマンだじぇ | 両1st→帰宅 | 即時 |
