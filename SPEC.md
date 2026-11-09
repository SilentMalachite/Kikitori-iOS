# Kikitori iOS 仕様書

最終更新日 2026年11月9日。最低対応はユーザー指定の **iOS 18.0** とする。Phase 2では、日本語の指示をチェックリストに変換し、編集して端末に保存できる。

## 1. 利用者が自分のペースで作業できるようにする

口頭の作業指示を日本語テキストに変換し、編集できるチェックリストとして表示するiPhone向け支援アプリ。聴覚障がい、発達障がい、作業記憶の負担などにより、複数の口頭指示を理解・保持しにくい人を支える。

技術が利用者の能力や特性に適応する設計とする。自動化の範囲を広げることより、指示の意味を保持し、本人が確認・修正できることを優先する。

Windows版・macOS版とは独立したGitリポジトリで開発する。Swiftで実装し、C++共通コアや既存版の実装を共有しない。データ互換性も要求しない。

## 2. Phase 1で日本語の入力と原文確認を実装した

Phase 1の実装範囲は以下のとおり。

- iPhone用Xcodeプロジェクトと共有Scheme、Swift 6言語モード。
- 日本語テキストの入力・編集と、原文を加工せず表示する確認画面。
- 空白だけの入力では確認に進めない。判定のために原文を削ったり書き換えたりしない。
- 文章の消去前に確認する。消去直後は復元できるが、新しい入力を始めたら古い文章を復元しない。
- 入力内容は画面のメモリ内に保持する。終了後の復元は保証せず、未保存であることを画面に表示する。
- Dynamic Type、標準の配色、文字付き操作、VoiceOver用ラベルと消去・復元結果の通知。
- 入力状態の単体テストと、入力・確認・編集・消去・復元のUIテスト。

Phase 2で文章解析、チェックリスト編集、履歴、SwiftData保存を追加した。録音と権限要求はPhase 3で追加する。マイクと音声認識の用途説明はInfo.plistに用意している。

完了条件は、生成済みプロジェクトをXcodeで開けること、シミュレーター用ビルドが成功すること、上記の自動テストが成功すること。実機でしか確認できない項目は未検証として記録する。

## 3. 開発環境と最低対応OS

2026年11月8日のローカル環境をコマンドで確認した。

| 項目 | 確認結果 |
| --- | --- |
| Xcode | 27.2（27B52） |
| Swiftコンパイラー | 6.4.2、プロジェクトはSwift 6言語モード |
| iPhone / Simulator SDK | iOS 27.2 |
| その他の導入済みSDK | macOS / tvOS / watchOS / visionOS / DriverKit 27.2 |
| シミュレーター | iOS 27.2のiPhoneが利用可能。iOS 18ランタイムは未導入 |
| プロジェクト生成 | 導入済みXcodeGen 2.46.0。MITライセンス。アプリに組み込む依存は追加しない |
| 接続された実機 | `devicectl list devices` では検出なし |
| 最低対応 | iOS 18.0（ユーザー指定） |

SwiftUIとSwiftData保存はiOS 18で構成する。音声入力は従来APIの端末内処理を第一候補とする。iOS 18実機の動作は実機テストで確認する。

実機の機種名・OS・日本語音声モデルの準備状況は未確認。署名用のDevelopment Teamと正式なBundle IDも未設定で、現状は `com.example.kikitori.ios` を使用する。実機実行の前に設定する。App Store公開用のアイコンも後続で用意する。

## 4. 責務ごとに小さく分け、必要な段階で追加する

SwiftUIを画面の所有者とし、現在の入力は `@State` に保持する。入力の可否判定と消去・復元は値型の `InstructionDraft` が担当する。画面専用のViewModelや汎用プロトコルは現段階では導入しない。

```text
Kikitori.xcodeproj/                  Xcodeで開くプロジェクト・共有Scheme
project.yml                         XcodeGen設定（編集元）
Kikitori/
  App/KikitoriApp.swift              アプリの入口
  Features/Instructions/
    InstructionDraft.swift          原文と消去・復元の状態
    InstructionInputView.swift      入力画面と原文確認シート
    InstructionParser.swift         分割ルールと確認理由
  Features/Checklists/
    ChecklistDraft.swift            編集中の項目、原文、完了状態
    ChecklistEditorView.swift       チェックリストと項目の編集
    ChecklistHistoryView.swift      保存済みリストの履歴
    ChecklistRepository.swift       SwiftDataへの保存・読込・削除
  Info.plist                        アプリ設定・用途説明（生成物）
KikitoriTests/                       Swift Testingによる単体テスト
KikitoriUITests/                     XCTestによる操作テスト
```

段階ごとの責務分担は以下のとおり。

| 要素 | 担当 | 追加段階 |
| --- | --- | --- |
| InstructionParser | 原文から作業候補を抽出し、条件と不確かさを返す。UI・保存から独立した純粋処理 | Phase 2 |
| ChecklistDraft | 項目追加・更新・削除・順序・完了・リセットのための編集状態 | Phase 2 |
| ChecklistRepository | SwiftDataによる端末内の保存・読込・削除。保存失敗を呼び出し元へ返す | Phase 2 |
| SpeechRecognitionService | マイク、端末内認識、途中結果、状態遷移、エラー・中断処理 | Phase 3 |
| SwiftUI Views | 表示、操作、確認、アクセシビリティ。音声や保存の内部処理は持たない | 各段階 |

非同期処理にはSwift Concurrencyを使い、UI更新はMainActor上で行う。音声コールバックから画面へ渡す境界を明確にする。テスト上の必要性が生じた箇所に限って依存の差し替え口を設ける。

## 5. 音声認識はSFSpeechRecognizerの端末内処理を推奨する

以下はApple公式資料と導入済みSDKの宣言を調査した結果。APIの利用条件と、対象iPhoneで実際に動くことは区別する。

| 比較項目 | SpeechAnalyzer / SpeechTranscriber | SFSpeechRecognizer |
| --- | --- | --- |
| OS | iOS 26以降 | iOS 10以降。端末内対応判定・限定設定はiOS 13以降 |
| デバイス | `SpeechTranscriber.isAvailable` で判定。OS対応だけでは利用可能と断定しない | 日本語の認識器に対する `supportsOnDeviceRecognition` と利用状態を確認 |
| 日本語 | `supportedLocale(equivalentTo:)` で `ja-JP` 相当の対応を照会 | `supportedLocales()`、初期化後の `locale`、端末内対応を照会 |
| オフライン | モデル取得後の認識処理は端末内 | 対応端末で `requiresOnDeviceRecognition = true` を指定 |
| リアルタイム | 非同期の結果列と暫定結果に対応 | バッファ入力と `shouldReportPartialResults` に対応 |
| 精度 | Appleは会話・長時間・離れたマイクでの改善を説明。日本語の作業指示では未計測 | 短い入力を中心に検証する。Appleは端末内処理の精度がサーバー処理より低い場合を説明。今回はサーバー処理を使わない |
| 実装の複雑さ | 音声形式、AsyncSequence、モデル取得、暫定／確定結果の管理が必要 | コールバック、認識タスク、中断処理が必要。iOS 18向けの単一経路として採用しやすい |
| 言語モデル | `AssetInventory.assetInstallationRequest(supporting:)` と `downloadAndInstall()` で準備 | 一般モデルを明示取得する同等のAPIはない。OSの準備状況に依存 |

Appleの音声入力対応表には日本語があるが、全機種・両API・全OSで日本語の端末内認識が使える証拠にはしない。機種ごとの固定リストをアプリに埋め込まず、実行時判定と実機テストを行う。認識精度の優劣は本プロジェクトではまだ結論づけない。

Phase 3はSFSpeechRecognizerのみで始める。SpeechAnalyzerはiOS 26以降で精度や長時間処理を比較する後続候補とし、最初から二系統を維持しない。

公式資料：

- [SpeechAnalyzerの紹介・WWDC25](https://developer.apple.com/videos/play/wwdc2025/277/)
- [SpeechTranscriber](https://developer.apple.com/documentation/speech/speechtranscriber) / [AssetInventory](https://developer.apple.com/documentation/speech/assetinventory)
- [SFSpeechRecognizer](https://developer.apple.com/documentation/speech/sfspeechrecognizer) / [locale指定時の仕様](https://developer.apple.com/documentation/speech/sfspeechrecognizer/init(locale:))
- [supportsOnDeviceRecognition](https://developer.apple.com/documentation/speech/sfspeechrecognizer/supportsondevicerecognition) / [requiresOnDeviceRecognition](https://developer.apple.com/documentation/speech/sfspeechrecognitionrequest/requiresondevicerecognition)
- [Appleの言語対応表](https://www.apple.com/ios/feature-availability/#dictation)

### 音声を外部へ送らず、利用できない理由を表示する

録音開始操作の後に権限・日本語対応・端末内認識可否を確認し、条件が揃った場合だけマイクを開始する。初期化成功だけでは日本語対応と判断しない。非対応ロケールの初期化では別の音声入力言語へ切り替わる可能性があるため、生成した認識器の言語も確認する。

- `NSMicrophoneUsageDescription` と `AVAudioApplication.requestRecordPermission()` でマイク利用を説明・要求する。
- SFSpeechRecognizerでは `NSSpeechRecognitionUsageDescription` と `requestAuthorization` も必要。
- `supportsOnDeviceRecognition == true` を前提に、すべてのリクエストで `requiresOnDeviceRecognition = true` を設定する。
- オフライン非対応、言語モデル未準備、拒否・制限、無音、認識不能、中断を分けて表示する。ネットワーク認識への自動切替や外部AIによる補完は禁止する。
- バックグラウンドへ移ったら録音・認識を停止し、入力済みの文章を残す。自動再開しない。音声ファイルは初期版では保存しない。
- 将来のSpeechAnalyzer導入ではモデル取得の通信と音声送信を区別する。モデル未取得のオフライン状態では利用不可を表示する。

SpeechAnalyzerの文字起こしモジュールにはSFSpeechRecognizerと同じ音声認識権限要求は適用されないが、マイク入力にはマイク権限が必要。参照：[音声認識の権限](https://developer.apple.com/documentation/speech/asking-permission-to-use-speech-recognition)、[マイク権限](https://developer.apple.com/documentation/avfaudio/avaudioapplication/requestrecordpermission(completionhandler:))。

## 6. 解析は意味の保持を優先する

Phase 2では、「対象を＋動作」の形をとる明確な作業が読点でつながる場合に、対応する動詞の語尾を整えて原文順に分割する。「最初に」「それから」などの順序指定も残す。条件・否定・日時・数量・場所・対象物がある指示は、その意味が前後の項目から切り離されないよう、必要に応じて原文のまま一項目にする。

複数の文、引用、対応する規則がない構文は、原文を一項目として残して「要確認」と理由を表示する。「書類を日付順に並べて、番号を確認して、終わったら棚に戻してください」は、終わる条件が前の作業とつながっているため、全文を残して条件の範囲の確認を促す。

「間違いがあったら職員に報告してください」や「確認が終わるまでファイルを削除しないでください」は、そのまま一項目にする。「適当に整理しておいてください」は、具体的な作業の確認が必要だと表示する。

生成時の原文を保存し、各項目には参照元の文言を保持する。全体の原文はチェックリスト画面で、各項目の参照元は項目の編集画面で確認できる。同じ原文から再生成した場合も、新しいチェックリストとして扱う。

## 7. 編集内容を保存し、履歴から開き直す

項目の追加・編集・削除・並べ替え、完了チェック、すべての項目を未完了に戻す操作に対応する。削除・リセット・未保存の変更の破棄には確認を出す。「保存」を押すと編集内容と完了状態が履歴に反映される。

SwiftDataにID、作成日時、原文、項目の配列を保存する。項目の配列はJSONのデータとして保持し、配列の順序を表示順に使う。各項目にはID、表示文、完了状態、参照元の文言、確認理由を持たせる。参照元がない項目は手動追加と表示する。

端末内に保存し、SwiftDataのCloudKit同期を無効にする。履歴には作成日時と完了数を表示し、再開・再編集・削除に対応する。保存に失敗した場合は編集中の内容を画面に残し、保存を再試行できるようにする。

## 8. 標準UIで負担の少ない操作にする

入力画面から原文の確認、チェックリストの作成、履歴の表示に進める。チェックリストは編集中も原文を参照できる。画面は標準の文字サイズ設定と配色に従う。

完成形のメイン画面には、録音開始／停止、録音・認識状態、編集できる原文、生成操作を置く。チェックリストでは大きなチェック領域と文字で完了状態を伝え、原文表示に切り替えられるようにする。履歴は独立した画面にする。機能追加時も一画面に判断を詰め込まない。

- VoiceOver：操作ラベル、チェック状態、結果通知、読み上げ順序を検証する。
- 視覚：Dynamic Type、高コントラスト、ライト／ダーク表示。色・アイコンだけに依存しない。
- 認知：予測できる操作、誤操作の取り消し、不確かな指示の確認を用意する。
- 聴覚：音だけで知らせず、録音中を含むすべての状態を文字でも表示する。

## 9. ビルド・テストを実行する

`Kikitori.xcodeproj` をXcodeで開き、Scheme「Kikitori」とiPhoneシミュレーターを選ぶ。プロジェクト設定を変更したときだけ `xcodegen generate` を実行する。リモートパッケージの取得は不要。

```sh
# シミュレーター向けビルド
xcodebuild -project Kikitori.xcodeproj -scheme Kikitori \
  -configuration Debug -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /private/tmp/Kikitori-DerivedData \
  CODE_SIGNING_ALLOWED=NO build

# 利用可能な端末を確認
xcrun simctl list devices available

# 単体・UIテスト（端末名とOSは環境に合わせて変更）
xcodebuild -project Kikitori.xcodeproj -scheme Kikitori \
  -destination 'platform=iOS Simulator,name=iPhone 17e,OS=27.2' \
  -derivedDataPath /private/tmp/Kikitori-DerivedData \
  -resultBundlePath /private/tmp/Kikitori-tests.xcresult \
  CODE_SIGNING_ALLOWED=NO test
```

同じ結果出力先が存在する場合は別名を指定する。実機ビルドでは署名を無効化せず、Development TeamとBundle IDを設定する。

### 原文テストと解析テストを混同しない

次の6文について、入力の保持・復元に加え、Phase 2の解析結果、確認表示の要否、参照元をテストする。

| 指示文 | Phase 2で確認すること |
| --- | --- |
| 書類を並べて、番号を確認してください | 明確な作業の分割と順序 |
| 間違いがあったら報告してください | 条件の保持 |
| 確認が終わるまでファイルを削除しないでください | 期限条件と否定の保持 |
| 最初に画像を確認して、それから名前を変更してください | 作業順序の保持 |
| 明日の午前10時までに3枚の書類を提出してください | 日時・数量・対象物の保持 |
| 適当に整理しておいてください | 曖昧な指示を勝手に具体化せず確認対象にする |

Phase 3では権限拒否・制限、認識不能、無音、途中中断、端末内認識非対応、言語モデル未準備を検証する。Phase 2では保存失敗と再読み込み、再生成時の原文・項目対応も検証する。

### 実機での完了判定は後続フェーズで行う

1. Phase 2：保守的な解析、チェックリスト編集、SwiftData保存と履歴、関連テスト。
2. Phase 3：端末内音声認識、日本語入力との接続、権限・エラー・中断処理。
3. Phase 4：VoiceOverの読み上げ順序と通知、最大文字サイズ、片手操作を検証し改善。
4. Phase 5：対象iPhoneで日本語精度、通信を切った音声入力、保存の再読込、中断・再開、長時間動作を検証。

## 10. 初回の検証結果（2026年11月8日）

| 検証 | 結果 |
| --- | --- |
| iOS Simulator向けDebugビルド | 成功 |
| iPhone 17e / iOS 27.2でのビルド・起動 | 成功 |
| Swift Testing | 4テスト成功。パラメーター展開を含め11ケース。指定された6文、空白、改行、消去と復元、新規入力の保護を確認 |
| XCTest UIテスト | 2テスト成功。日本語入力・原文表示・再編集と、消去のキャンセル・実行・復元を確認 |
| plist / pbxprojの構文 | `plutil -lint` 成功 |
| 初期画面の表示 | 通常文字サイズ・ライト表示と、アクセシビリティ最大文字サイズ・ダーク表示を目視確認。後者は末尾までスクロールして文字の折り返しを確認 |

テスト結果は `/private/tmp/Kikitori-tests-final.xcresult` に出力した。途中でUIテストが失敗したため、消去確認をキャンセルボタンが明示されるアラートへ変更し、編集テストのカーソル位置に関する誤った前提も修正した。上表は修正後の結果。

UIテストのキーボード表示時に `Invalid frame dimension (negative or non-finite)` というSwiftUIの警告が2件残った。操作テストは成功したが、警告の発生元は特定できていない。iOS 18実機での入力・キーボード表示と併せて確認する。通常表示と最大文字サイズの確認だけで、全画面・全状態のレイアウト検証が済んだとは扱わない。

Phase 1時点で、iOS 18実機、VoiceOverの実際の読み上げと順序、横画面の操作、音声入力とオフライン認識、永続保存、署名付き実機ビルドは未検証だった。

## 11. Phase 2の検証結果（2026年11月9日）

iPhone 17e（iOS 27.2）シミュレーターでビルドし、単体8テストとUI 3テストが成功した。

- 指定6例の解析結果と参照元を確認した。複数の作業に条件や否定がかかる文、引用、動作を特定できない文は、一項目のまま確認対象になることも確認した。
- SwiftDataのストアを開き直し、編集内容、並び順、完了状態、原文が保持されることを確認した。読み取り専用のストアへの書き込みを試み、失敗しても編集中の内容と以前の保存内容が残ることを確認した。
- UIから原文を照合して項目を編集し、完了にして保存した。アプリを再起動し、履歴から保存内容を再表示して削除できることを確認した。

結果は `/private/tmp/Kikitori-Phase2-tests-2.xcresult` に出力した。キーボードを表示したUIテストで、Phase 1と同じ種類のSwiftUIレイアウト警告が3件残った。iOS 18実機での動作とVoiceOverの読み上げは未検証。

### キーボード表示時のレイアウト警告を解消した

iOS 27.2シミュレーターでは、原文入力欄がフォーカスされた直後に `Invalid frame dimension (negative or non-finite)` が発生した。キーボードツールバーから `Spacer` だけを外しても、同じ警告が3件出た。ツールバーを画面下部の `safeAreaInset` に置き換えたところ、警告は0件になった。「入力を終える」ボタンは、原文入力欄にフォーカスがある間、画面下部に表示する。

修正後は単体8テストとUI 3テストが成功した。結果は `/private/tmp/Kikitori-Keyboard-safe-area.xcresult` に出力した。発生条件はキーボードツールバーのレイアウトまで絞り込めた。SwiftUI内部で不正になった寸法の値と、iOS 18実機での動作は未確認。
