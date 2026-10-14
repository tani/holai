> Relocation note: this narrative and its measurements describe their original revision, not a new run. Raw evidence, hashes and old API/path attribution are preserved. Current layout/API is specified in docs/REPOSITORY-LAYOUT.md (repository-root relative); current scripts live in misc/scripts/ and Lisp tests in holai/tests/. Historical baseline commands/packages require their matching old checkout; rt: is explanatory shorthand, not an installed nickname.

# defuncだけによる関数適用の実験

元の1.0.0を保存し、別コピーで `defunc`・`lambdac`・`labelsc`・`fletc` を実装しました。
関数自身が可変長引数を受け取り、定義に埋め込んだarityで部分適用・飽和・余剰引数を処理します。
生成した関数値は通常のCL関数です。関数参照・呼び出し時のsource関数arity表はありません。
固定arityの組み込み関数と構成子には境界でadapterを作り、そこだけ弱くcacheします。
そのadapterも呼び出し時には表を参照しません。

## 実測

| 項目 | 元の1.0.0 | defunc実験版 |
| --- | ---: | ---: |
| 新しいプロセスのFASL読み込み・初期化・終了 | 273.191秒 | 119.039秒 |
| 読み込んだコア入力 | 46 | 46 |
| 計測中のsource再コンパイル | 0 | 0 |
| コア読み込みのGC時間 | 約38.3秒 | 約6.5秒 |
| コア読み込みの累計割り当て | 約86.1 GB | 約124.0 GB |

経過時間は約2.295倍の速度、56.43%の短縮です。計測は各1回で、中央値ではありません。
GC・割り当ての旧値は別のCPUプロファイル実行時の値です。新値は非プロファイル実行で、
双方とも46コアcomponentの読み込み合計です。割り当ては累計で、最大常駐メモリではありません。
プロセス起動から終了までをmonotonic clockで計測し、コンパイルを要求するASDF処理は即座に失敗させました。
初期化済みheapは使っていません。原版OCamlバイトコードの61.832秒も参考値として記録しています。

sourceの算法、再帰、名前、束縛と宣言順、実際のTrivia、元入力の固定digestは保持しました。
新しい固定引数workerや、呼び出しの引数個数に基づく翻訳時のcase選択は追加していません。
大域・局所の生成source関数は常に可変長のentryを使います。既存のnative組み込み境界のloweringは維持しています。

## 検証

- 全46入力の翻訳・SBCLコンパイル・初期化、既存のnative検査122件成功。
- 原版との比較1,124行が一致。既存の名前正規化、初期化の診断2行の差を同じ規則で検査。
- 初期状態の型22・定数303・定義263・元の公理3が一致。仮の標準コア定理は追加していません。
- 適用規約の単独検査27件成功。段階的・grouped・空・余剰適用、返された関数への連続適用、
  escaping closure、相互再帰、非再帰の遮蔽、関数alias、bodyの一度だけの実行、scalarへの余剰適用のエラーを検査。
- live adapterのGC後の同一性、不要なnative adapterの回収、GCをまたぐ部分適用を検査。
- ソースマップ194,839件、11fixture込み205,341件、拒否10件の出力保護、固定入力と再生成の一致を確認。

## 使い方

```lisp
(hol2cl.runtime:defunc foo (a b c)
  (+ (* 100 a) (* 10 b) c))

(foo 1 2 3)                          ; 123
(funcall (funcall (foo 1) 2) 3)       ; 123
(funcall (foo 1 2) 3)                ; 123

(hol2cl.runtime:lambdac (x y) (+ x y))

(hol2cl.runtime:labelsc
    ((even-p (x) (if (zerop x) t (odd-p (1- x))))
     (odd-p (x) (if (zerop x) nil (even-p (1- x)))))
  (even-p 10))
```

通常のCLのoperator位置には、そのまま`(((foo 1) 2) 3)`とは書けません。
関数値の適用には上のように`funcall`を使います。

## 再現と判断

```sh
make test
make clean-build
python3 scripts/measure-startup.py
make release
```

検証したtoolchainは従来のOCaml 4.14.1、Camlp5 8.02.01、Num、SBCL 2.2.9です。
最初に`make test`でFASL cacheを作ります。計測scriptはfile再コンパイルが発生すると失敗します。
`defunc-experiment.json`、`defunc-baseline.json`、生の計測logとprotocol検査logを同梱しています。
保存した数値は納品時の実測で、再計測の時間は環境によって変わります。

defuncだけで大きな改善が得られました。一方、累計割り当て量は増えており、
可変長の引数list生成が次の候補です。静的な飽和呼び出しの選択や固定引数workerは、別の実験として扱います。

## ピークメモリの追加計測

Linuxのプロセス別wait4.ru_maxrssで、全46ファイルのFASL読み込み・初期化・終了を各1回計測しました。

| プロセス全体のピークRSS | 元の1.0版 | defunc実験版 |
| --- | ---: | ---: |
| KiB | 245,556 | 205,384 |
| MiB | 239.801 | 200.570 |

実験版は約16.36%低いピークRSSでした。再コンパイルは両方0件、保存heapは使わず、
初期の型22・定数303・定義263・公理3を確認しました。累計割り当て量の増加は、
ピーク占有量の増加を意味しません。RSSはコード・heap・実際に常駐するstack等を含み、
GC後のlive heapとは別の指標です。256 MiBの制御stack設定は全領域の常駐を意味しません。
今回の経過時間は元版286.730秒、実験版114.337秒でした。各1回の測定で中央値ではありません。

```sh
python3 scripts/measure-peak-memory.py --baseline /path/to/original/hol2cl
```

事前に両方のディレクトリでmake test等によりFASL cacheを作ります。コンパイルが発生すると計測は失敗します。
比較JSONと両プロセスの生logを同梱しています。
