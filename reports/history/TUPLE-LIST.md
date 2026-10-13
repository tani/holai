# Argument-list tuple representation: 1.0.0-defunc-list-tuples

ユーザー指示に従い、タプルを生成する際の引数リストをそのまま保持するよう変更した。

```lisp
(defstruct (tuple-value (:constructor make-tuple-value (items)))
  (items nil :type list :read-only t))
(defun tuple (&rest items) (make-tuple-value items))
```

coerce/vector/copy-listを使用しない。外側のtuple-valueは通常のOCamlリストとタプルを区別するために残す。内容のリストは破壊的変更をしない。fst/snd/tuple-refはリストを参照し、tuple-refは負の添字・非整数・範囲外でtype-errorを送出する。パターンは長さが一致した場合のみ要素を取り出す。比較は従来どおり先に要素数、その後に要素ごとの辞書式順序を使う。構造ハッシュの値と等値関係は維持される。レコード・variantの内部ベクタは変更していない。

要素参照はnth、要素数取得はlengthとなるため、大きなタプルで添字参照を繰り返す場合はベクタより不利になりうる。対象コアでは今回の実測で高速化した。内部リストは読み取り専用の契約であり、CLの破壊的変更を機械的に禁止する機構ではない。

TriviaのLISTパターンをそのまま使う初回実装では、ネストしたCONS検査の展開によってSBCLのレジスタ割当中に既存1GiBヒープが不足した。最終実装は実際のTrivia guard1を使い、tuple-value型確認・一度の長さ確認・nth要素抽出を行う。ヒープ容量を増やして回避する変更はしていない。

## 検証

- 16項目の集中テスト：proper-list格納、nested tuples、要素数不一致パターン、タプルと通常リストの区別、要素数を優先する比較、辞書式比較、等値とハッシュの整合、添字の異常系、空タプル。
- 27 defunc protocol checks、122 native checks、元のOCamlとの1,124行の出力一致。
- 全46入力、初期22型/303定数/263定義/3公理。公理集合は元の3公理のみ。
- 再生成一致、10 rejection checks、194,839 core/205,341 total map entries。
- ソースからのクリーンビルドで94生成ファイル一致、pin不変。
- 前回の配布ZIPと現在のsrc/*・generated/*のバイト一致を直接確認した。翻訳器・生成構文・HOLのアルゴリズムは変更していない。

## 新しいプロセスでのFASL限定測定

復元ヒープなし、ソースファイルのコンパイル0件、全46入力、SBCLスタック容量256MiB。Linux wait4の子プロセス個別ru_maxrssを使い、ピークRSSと起動時間を同じプロセスで取得した。各値は1回の測定であり、統計的な性能保証ではない。

| 指標 | 以前のdefunc・ベクタ版 | 引数リスト版 |
|---|---:|---:|
| 起動から終了まで | 119.039秒 | 93.567秒 |
| コアload CPU合計 | 118.717秒 | 93.273秒 |
| コアload GC合計 | 6.495秒 | 5.432秒 |
| コアload累積割り当て | 123,976,654,272 bytes | 113,611,745,136 bytes |
| プロセス全体ピークRSS | 200.570 MiB | 199.230 MiB |

起動の基準値119.039秒との比較は1.272倍、21.40%短縮。累積割り当ては8.36%減少。ベクタ版のピークRSSは別の以前の測定プロセス（その起動114.337秒）で得た値であり、119.039秒の測定と同一プロセスではない。114.337秒に対しても約18.2%短縮だが、いずれも過去の単発測定との比較。ピークRSSの差は約1.34MiBなのでメモリ常駐量が大幅に減ったとは言わない。RSSはlive heapや累積割り当てではない。

今回の変更はリスト格納と照合・参照・比較経路の変更を合わせたものなので、速度差のすべてをcoerce削除のみに帰属させない。rt:funcallは変更していない。

## 再現と成果物

`make test` と `python3 scripts/check-clean-build.py` を実行してFASLキャッシュを更新後、`python3 scripts/measure-tuple-list.py` を実行する。600秒guard、コンパイル発生はエラー。機械可読結果はtuple-list-startup.json、生ログはtuple-list-startup.txt。元のベクタ版記録はreports/vector-tuples/に保存した。その他の旧defunc/CPU/peakレポートは歴史的結果であり現在の測定と混同しない。

配布ZIPにはDESIGN.md、AGENTS.md、全翻訳器・ランタイム・生成コード・テスト・測定スクリプトを含む。旧ベクタ版の配布はそのまま残し、今回の配布名はhol2cl-1.0.0-defunc-list-tuples.zipとする。
