> Relocation note: this narrative and its measurements describe their original revision, not a new run. Raw evidence, hashes and old API/path attribution are preserved. Current layout/API is specified in docs/REPOSITORY-LAYOUT.md (repository-root relative); current scripts live in misc/scripts/ and Lisp tests in holai/tests/. Historical baseline commands/packages require their matching old checkout; rt: is explanatory shorthand, not an installed nickname.

# defunc版：次の速度ボトルネック調査

翻訳器・ランタイム・生成コードは変更していない。SBCL 2.2.9、既存FASLのみ、復元ヒープなし、46入力の初期化をCPUサンプリングした。0.01秒間隔、深度128、11,370サンプル。初期状態22型/303定数/263定義/3公理を確認した。

## 結果

| 項目 | 自身のサンプル比率 | 呼出先込み | 解釈 |
|---|---:|---:|---|
| runtime:compare | 6.1% | 13.4% | 汎用構造比較、文字列比較、タグ・フィールド参照 |
| runtime:tuple | 2.2% | 10.4% | &restリスト→coerce vector→構造体 |
| compare-vectors | 1.8% | 9.7% | compareと重複。汎用配列参照・長さ・再帰比較 |
| pthread_sigmask | 11.9% | 11.9% | sets呼出グラフではGC開始経路 |
| make-condition | 0.9% | 4.7% | Failure等の条件構築。ERROR/RAISEと重複 |
| partialの返すクロージャ | 1.3% | 2.7% | appendを含む部分適用処理 |
| runtime:funcall | 1.0% | 1.0% | 以前のアリティ表ロックは上位にない |

包括比率は重複するため加算禁止。関数別サンプルからは、各defuncに分散した&rest形成・length・引数取り出しの総費用は切り出せない。したがって「関数呼出し全体が1%」とは言えない。

プロファイル付き初期化は壁時計125.031秒、CPU124.969秒、GC10.889秒、累積割り当て124,025,193,904バイト。従来の未プロファイル測定119.039秒/GC6.495秒とは採取負荷が異なる。GC時間には開始経路全体が必ず含まれるとは限らず、pthread比率をGC秒数に足しても正しい時間分解にはならない。ピークRSSは今回測定していない。

未プロファイル記録ではsets.mlがCPU35.521秒、iterate.mlが29.206秒で、合計は初期化CPUの54.5%。この2ファイルを改善検証の代表負荷にできる。証明探索やmap等の包括時間は呼出先を含み、ソースアルゴリズムの変更を示唆するものではない。

## GC開始経路の確認

最重量sets.mlのみの別プロファイルは3,312サンプル、壁時計36.729秒/GC3.205秒。pthread_sigmaskは401サンプル（12.1%）。呼出グラフは `interrupt_handle_pending -> maybe_gc -> pthread_sigmask`。例外処理・旧ハッシュ表ロックと誤認してはいけない。GCの開始・割り当て圧が候補だが、サンプラーの影響を含み、ここから改善率は断定できない。SBCLのローカルAPI説明による既定nurseryは53,687,091バイト。閾値を増やす案はピークメモリとの交換になるため未実施。

## タプル生成の因果を確認する小規模実験

現在 `tuple` は `(make-tuple-value (coerce items 'vector))`。setsグラフではtuple→REPLACEのエッジに261サンプル（sets全体の7.9%）があり、リストから汎用ベクタ変換が主要部分。型情報不足のため配列参照・境界検査・汎用REPLACEも残る。

200万個の二要素タプルを作る処理を3回ずつ比較した。現行tuple呼出しと、候補 `(make-tuple-value (vector a b))` は同じ構造体・ベクタ表現を使う。notinlineラッパーとグローバルsinkで結果を保持し、毎回full GC後にCPUとbytes-consedを測定した。

| 構築方法 | CPU中央値 | 累積割り当て/回 |
|---|---:|---:|
| 現行tuple | 0.095996秒 | 159,970,384バイト |
| 直接vector | 0.029002秒 | 95,986,800バイト |

この限定的負荷で3.31倍、割り当て約40%削減。初期化全体の改善率ではない。二要素のみ・非常に短い実験なので大きなタプルや高階利用にも一般化しない。

## 推奨する順番

1. **翻訳時に要素数が分かるタプル式の構築経路**を実験する。直接vectorを構築し、現在のtuple-value表現を維持する。高階関数として渡すtupleは既存関数を残す。ソースの名前・スコープ・再帰・アルゴリズムを変えず、left-to-right評価を保つ。上限の目安は現在tuple包括約10%で、全部を除去できるわけではない。割り当て削減がGCにも波及する可能性は未検証。
2. **compareとフィールド配列の型情報**を調べる。simple-vector等の宣言は表現不変条件を先に確認する。`=` を単にEQUALへ置換するのは数値・例外・可変値などの互換性を壊しうる。専用等値比較は別設計と差分テストが必要。
3. **例外オブジェクトの構築**は二次候補。make-condition約4.7%だが、キャッシュ・軽量化は捕捉範囲、再送出、例外値の同一性を保持する設計が必要。
4. **飽和適用の固定アリティ経路**は引き続き候補。ただし今回のサンプルで効果の総量は測れず、優先順位を上げる根拠はタプルより弱い。本体への採用は行っていない。

## 再現

ツールチェーンのbinをPATHに追加し、プロジェクト直下で実行する。既存FASLが必要。制限600秒、スタック256MiB。

```sh
sbcl --control-stack-size 256 --noinform --non-interactive --load tests/profile-performance.lisp
sbcl --control-stack-size 256 --noinform --non-interactive --load tests/profile-sets.lisp
sbcl --noinform --non-interactive --load tests/probe-tuple.lisp
```

sets診断は当該ファイル終了時にcatch/throwで意図的にロードを打ち切るため、ログ末尾にSBCLのcompilation unit abortedが出る。終了コード0とSETS_PROFILE_COMPLETEを確認する。完全初期化成功の証拠には使わない。完全初期化は別のCPU_PROFILE_COMPLETE/INITIAL_COUNTSログで確認した。

生データはdefunc-cpu-self.txt、defunc-cpu-inclusive.txt、defunc-cpu-startup.txt、defunc-sets-graph.txt、defunc-sets-startup.txt、tuple-probe.txt。機械可読結果はnext-bottlenecks.json。実装変更なしのため既存27プロトコル/122native/1,124比較行の検証は再実行していない。
