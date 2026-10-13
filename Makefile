OCAMLC ?= ocamlc
CAMLPP ?= camlp5r
CAMLPLIB ?= $(shell $(CAMLPP) -where)
STREAMLIB ?= $(dir $(CAMLPLIB))camlp-streams
OCAMLFLAGS = -g -I $(CAMLPLIB) -I $(STREAMLIB) -I _build
SOURCE = src/sexp.ml src/scope.ml src/compiler.ml src/frontend.ml src/cli.ml
CORE = system lib fusion basics nets printer preterm parser equal bool drule tactics itab simp theorems ind_defs class trivia canon meson firstorder metis thecops quot impconv pair compute nums recursion arith wf calc_num normalizer grobner ind_types lists realax calc_int realarith real calc_rat int sets iterate cart define
CORE_FILES = $(addprefix vendor/hol-light/,$(addsuffix .ml,$(CORE)))

.PHONY: all build regenerate scan inventory test clean-build release clean
all: build
build: bin/hol2cl
_build/pa_j.cmo: vendor/hol-light/pa_j_4.xx_8.02.ml
	mkdir -p _build
	test "$$($(CAMLPP) -version | cut -d. -f1-2)" = "8.02"
	$(OCAMLC) $(OCAMLFLAGS) -pp "$(CAMLPP) -I $(CAMLPLIB) pa_lexer.cmo pa_extend.cmo q_MLast.cmo" -c -o $@ $<
bin/hol2cl: $(SOURCE) _build/pa_j.cmo
	mkdir -p bin
	$(OCAMLC) $(OCAMLFLAGS) -c -o _build/sexp.cmo src/sexp.ml
	$(OCAMLC) $(OCAMLFLAGS) -c -o _build/scope.cmo src/scope.ml
	$(OCAMLC) $(OCAMLFLAGS) -c -o _build/compiler.cmo src/compiler.ml
	$(OCAMLC) $(OCAMLFLAGS) -c -o _build/frontend.cmo src/frontend.ml
	$(OCAMLC) $(OCAMLFLAGS) -c -o _build/cli.cmo src/cli.ml
	$(OCAMLC) $(OCAMLFLAGS) unix.cma camlp_streams.cma camlp5.cma _build/pa_j.cmo _build/sexp.cmo _build/scope.cmo _build/compiler.cmo _build/frontend.cmo _build/cli.cmo -o $@
regenerate: build
	ocamlrun bin/hol2cl translate --output-dir generated $(CORE_FILES)
scan: build
	ocamlrun bin/hol2cl scan $(CORE_FILES)
inventory: build
	python3 scripts/scan_core.py
test: regenerate
	python3 tests/run.py
clean-build: regenerate
	python3 scripts/check-clean-build.py
release: test
	python3 scripts/scan_core.py
	python3 scripts/check-clean-build.py
	python3 scripts/release.py
clean:
	rm -rf _build bin
