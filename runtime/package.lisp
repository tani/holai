(defpackage :hol2cl.runtime
  (:use :cl)
  (:shadow :funcall :compare :partial := :< :> :<= :>= :Some :formatter :list-length)
  (:export :defunc :lambdac :labelsc :fletc :function-value :funcall :partial :tuple :tuple-items :tuple-ref
    :unit :match :match-failure :ocaml-condition :raise :define-exception
    :defvariant :variant-value :variant-tag :variant-fields :variant-type
    :ref :ref-contents :deref :assign := :<> :== :!= :compare :< :> :<= :>=
    :failure :invalid_argument :end_of_file :sys_error :failwith
    :make-failure :make-invalid_argument :make-sys_error :make-end_of_file
    :Some :None :make-Some :make-None
    :invalid-arg :fst :snd :int-div :int-mod :string-concat :string-length
    :string-sub :string-join :string-get :num :numdom :gcd-num :abs-num
    :power-num :quo-num :mod-num :int-of-num :string-of-num :string-of-int
    :string-of-float :print-string :print-newline :print-flush :pp-print-string
    :std-formatter :cpu-time :exception-string :structural-hash
    :open-in :open-in-bin :open-out :input-line :close-channel
    :output-string :channel-length :really-input-string
    :char-chr :string-make :string-escaped :int-of-string :array-make :array-get
    :array-set :array-fold-left :array-of-list :array-map :gc-control :make-gc-control
    :gc-get :gc-set :catch-break :sys_break :make-sys_break
    :list-fold-left :list-exists :bool-or :bool-and
    :defrecord :record-field :record-update :record-assign :table-remove :table-fold
    :Not_found :make-Not_found
    :buffer-create :buffer-contents :buffer-reset :formatter-of-buffer :get-margin
    :pp-print-char :pp-print-int :pp-print-cut :pp-open-vbox :open-vbox :open-box :close-box :print-break
    :pp-print-as :pp-open-box :pp-open-hbox :pp-open-hvbox :pp-close-box
    :pp-print-space :pp-print-break :pp-print-flush :pp-set-margin :pp-set-max-boxes
    :set-margin :set-max-boxes :format-printf :format-fprintf :format-asprintf
    :pp-get-max-boxes :pp-print-newline :printf-printf :printf-sprintf
    :lazy-create :lazy-force :lazy-undefined :make-lazy-undefined :ocaml-max-int :assert_failure :make-assert_failure :assert-true :ref-incr :ref-decr :print-endline :ignore-value :int-lsl :int-lsr :int-asr :float-of-int :int-of-float :float-floor :table-create :table-clear :table-add :table-replace :table-find :random-init :random-bits :random-int :list-length :list-hd :list-tl :list-nth :list-rev :list-rev-append :list-map :list-map2 :list-mapi :list-rev-map :list-iter :list-concat :list-fold-left2 :list-fold-right2 :list-fold-right :list-for-all :list-for-all2 :list-mem :list-mem-assoc :list-assoc :list-find :list-filter :list-filter-map :list-partition :list-sort))
