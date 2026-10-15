# Holai 1.0.0-percent-names

## Eight-candidate selection and native Lisp interrupts

The locked NixOS 26.05 package set now selects every usable candidate, not only
the original four adapters. Metadata evaluation observed eight derivations on
x86_64-linux and four on each ARM64 host; evaluation is not runtime evidence.

| Nix candidate / selection ID | Pinned package version | Executable | x86 Linux | ARM64 Linux | ARM64 Darwin |
| --- | --- | --- | --- | --- | --- |
| abcl | 1.9.3 | abcl | selected | selected | selected |
| sbcl | 2.6.4 | sbcl | selected | selected | selected |
| ecl | 26.5.5 | ecl | selected | selected | selected |
| ccl | 1.13 | ccl | selected | unsupported | unsupported |
| mkcl | 1.1.11 | mkcl | selected | broken in pin | unsupported |
| clisp | 2.49.95-unstable-2024-12-28 | clisp | selected | selected | selected |
| cmucl_binary | 21d | lisp | selected (i686 binary) | evaluation unavailable | evaluation unavailable |
| clasp-common-lisp | 2.7.0 | clasp | selected | unsupported | unsupported |

The new versions above come from the locked package definitions, not a claim
that all binaries passed. CMUCL uses the pinned 32-bit x86 binary package.
Sources at the locked nixpkgs revision:
[CCL](https://github.com/NixOS/nixpkgs/blob/a033e66ab94a6bedf2c3d58d93a36319d3cbbbaf/pkgs/development/compilers/ccl/default.nix),
[MKCL](https://github.com/NixOS/nixpkgs/blob/a033e66ab94a6bedf2c3d58d93a36319d3cbbbaf/pkgs/development/compilers/mkcl/default.nix),
[CMUCL](https://github.com/NixOS/nixpkgs/blob/a033e66ab94a6bedf2c3d58d93a36319d3cbbbaf/pkgs/development/compilers/cmucl/binary.nix)
and [Clasp](https://github.com/NixOS/nixpkgs/blob/a033e66ab94a6bedf2c3d58d93a36319d3cbbbaf/pkgs/development/compilers/clasp/default.nix).
ARM64-hosted QEMU version probes, not native x86 verification, observed
MKCL `1.1.11`, CMUCL `21d (21D Unicode)` and Clasp
`cclasp-boehmprecise-2.7.0-cst`, all with exit 0. The initial CCL user-mode
QEMU probe failed before Lisp initialization; the later full-system kernel
reproduction below supersedes that probe, not the native-host CI requirement.
The launcher validates implementation type and primary feature independently
of its Nix ID (`:cmu` for CMUCL, `:clasp` for Clasp). Executables and versions
remain bound to exported pinned-package metadata. ASDF startup uses separate
read/evaluation steps; a host without bundled ASDF loads the pinned real ASDF
3.3.4 source dependency. No package-inferred system, generated load-order data
or readtable change is introduced.

CI crosses three hosts with all eight candidate IDs and explicitly excludes
the eight unavailable ARM cells above: **16 runnable jobs**, not 24 passes.
Every actual job requires its selected package and executable; absence fails,
never skips. SBCL runs the full release; all other implementations run the
120-second-per-process runtime/translated-fixture profile, not full HOL core.
Historical native [run 38668191870](https://github.com/tani/holai/actions/runs/38668191870)
at `d3ac15b8` passed **15/16** jobs. Only CCL's stale-consumer typed rejection
failed with exit 255; all other 15 native jobs passed, including the three SBCL
full releases. This is not a repaired CCL pass or a new 16/16 result.

### CCL compiler-host repair and measured evidence

Production matching remains the standard-CL static structural compiler, with
unchanged source bindings, algorithms and data representations and no Trivia
dependency. Declaration ABI validation must run when a compiled consumer loads;
successful matching remains independent of the declaration registry.

CCL 1.13's `compiler/nx1.lisp:1151–1164` represents compile-file
`load-time-value` as a deferred immediate. Its x86 IF compiler
(`compiler/X86/x862.lisp:8626–8628`) calls `nx2-constant-form-value`
(`compiler/nx0.lisp:1927–1935`), which treats every immediate as constant.
Consequently the original direct conditional AND/LTV test can be folded as
truthy and lose the ABI-check initializer; this is not an exit-code conversion
or a wrapped typed condition. In contrast, `compiler/nx2.lisp:376–383`
excludes deferred LTV tokens from `acode-constant-p`.
Only `#+ccl` now emits a standalone PROGN load-time ABI check followed by the
IF type test: `compiler/X86/x862.lisp:1818–1819` retains ignored deferred
immediates, and `lib/nfcomp.lisp:1918–1933` /
`level-0/nfasload.lisp:455–458` serialize and directly invoke the initializer.
The other seven implementations retain the exact original AND shape, because
CLISP can eliminate an unused standalone PROGN load-time value. No runtime
registry lookup or allocation is added; typed `pattern-declaration-changed`,
its declaration-name assertion and required child exit 17 remain mandatory.

Under a full-system x86 Linux kernel emulated by QEMU on ARM, the original CCL
consumer failed with “Stale pattern consumer unexpectedly loaded” and exit 255.
After the repair, 45 pattern checks and typed `Separate` rejection passed
(marker 1, child exit 17, VM exit 0) in **105.03 seconds**. This is
kernel-emulated evidence, not native x86 hardware or a complete compatibility
profile. The native ARM64 CLISP bounded profile passed in **9.04 seconds**,
including stale exit 17, preserving its original AND form. Fresh native CCL CI
remains required; the current-code local release result is recorded below.

Failure annotations now retain escaped head and tail within **10,000 characters**,
rather than truncating away the root error at the start of a long backtrace.
An actual failing SBCL smoke exercised this path in 1.29 seconds and preserved
head, tail and root error. Better diagnostics never count a failed process as a pass.

The real-SIGINT harness exposed a separate test-only boundary: pinned Nix
`bin/ccl` is a Bash wrapper without `exec`. Signalling its Python `Popen` PID
missed the Lisp child and produced timeout exit 143. The CCL physical fixture
now emits exactly one positive `SIGINT target pid: N` marker from `ccl::getpid`;
the Python harness validates its POSIX `ps` ancestry under the launched wrapper,
sends all three signals to that Lisp PID, and waits for wrapper exit 0.
The other seven implementations keep their original `Popen` PID targeting;
production launcher/runtime behavior is unchanged. In the full-system x86
kernel VM, the corrected physical check passed in **46.23 seconds**: wrapper
79, Lisp target 80, three real SIGINT deliveries, two Sys.Break catches,
prior-hook restoration, wrapper exit 0 and VM exit 0. This isolated emulated
pass is not a native CCL or complete compatibility pass.

The subsequent complete CCL bounded runtime/translated-fixture profile passed
in **312.43 seconds** under the full-system x86 Linux guest kernel
(`_build/ccl-vm-run.sleh3T`, VM exit 0). It recorded 45 patterns, typed
`Separate` stale rejection/exit 17, protocol 30, OPTIONAL 84, tuple 16,
Random 1,816, three direct-native interrupt checks and three real SIGINT
deliveries with two catches, prior-hook restoration and wrapper exit 0.
All three translated fixture units matched **33 exact OCaml observations**,
including nine naming rows. This is a complete bounded compatibility pass on
system-emulated x86 Linux, not native hardware, full HOL core, or a repaired
16/16 native CI matrix.

The fresh native ARM64 four-implementation `make release` passed in
**278.84 seconds**, after the matcher, interrupt-harness and logger changes.
SBCL recorded **130 native / 30 protocol / 69 PROOF** checks and **1,150**
observations: 1,147 exact, two structural registry comparisons and one Random
property row. All 52 cold production units had zero compiler diagnostics;
93 clean outputs were identical and 55 retained pins unchanged. ECL, ABCL and
CLISP passed bounded compatibility. This is current-code local release evidence,
not repaired native CCL or 16/16 hosted evidence. Final documentation repackaging
must determine the archive size and payload count; neither is fixed here.

### Previous pre-repair local release

The pre-repair native ARM64 Linux `make release` passed in 286.76 seconds with
SBCL full-core and ECL/ABCL/CLISP bounded compatibility. Observed SBCL reports
record 130 native checks, protocol 30, PROOF 69, and 1,150 corpus observations:
1,147 exact, two structural registry comparisons and one Random property row.
Map audits covered 194,839 core and 207,095 fixture-inclusive entries.
The release gate also validated all 52 cold-audited production files,
93 identical clean outputs and 55 retained input pins. All four hosts passed
three direct-native interrupt checks; real OS-SIGINT checks passed where
supported, with ABCL explicitly not applicable. This historical pass includes
the CCL generic-method, MKCL protected-hook setter and shared native-interrupt
fixture changes, but predates the deferred-LTV repair. It does not fix the final
archive's payload count or byte size, or establish a fresh post-repair release.

Additional implementation execution remains **emulated**, not native x86:
CMUCL's complete bounded runtime/fixture profile passed in 31.45 seconds under
QEMU 10.2.4 on ARM64, including 46 pattern checks, protocol 30, OPTIONAL 84,
tuple 16, Random 1,816, native interrupts 3, real SIGINT deliveries 3/two
catch cycles, and three translated fixtures with 33 exact observations
(nine naming rows). Its isolated report is under
`_build/emulated-reports/cmucl_binary/compatibility.json`, tagged with
`native_host_validation=false`; it is not native release evidence.
MKCL's complete bounded runtime/fixture profile also passed under QEMU in
138.65 seconds overall; every individual subprocess retained the 120-second
guard. Its isolated `_build/emulated-reports/mkcl/` evidence is tagged
emulated, not native release evidence.
Clasp's weak/protocol fixture passed all 30 checks in 113.91 seconds and its
direct-native interrupt fixture passed three checks in 108.34 seconds under
QEMU. These isolated results do not establish a complete compatibility pass.
CCL's later kernel-emulated repair evidence is recorded above; neither its
initial user-mode emulation failure nor the repaired VM pass substitutes for
fresh native-host CI.

The prior four-implementation matrix has observed hosted evidence:
[run 38661471081](https://github.com/tani/holai/actions/runs/38661471081),
commit `ac56ca3`, passed **12/12** jobs. That result is distinct from the
new eight-candidate changes and does not validate their new adapters.

Interrupt restoration means the exact previous native Lisp hook, not SIG_DFL
or forced process death. The mandatory direct-native fixture reports
`Native interrupt checks passed: 3`: two Sys.Break catches across re-enable
and restored independent prior-hook delivery. Its evidence is separate from
the readiness-handshaked real-OS-SIGINT fixture. ABCL's OS check is explicitly
not applicable (no native SIGINT-specific Lisp hook); its direct native Lisp
thread-interruption checks remain mandatory. No Java/OS signal rewiring is used.
The prior 12/12 policy included OS interoperability that is now removed.
Timeout cleanup may kill a
stuck child, but a cleanup kill or nonzero signal exit never counts as a pass.
Current execution results and corpus counts must come from fresh per-host
reports; earlier measurements below are historical.

## Previous checkpoint: explicit ASDF load order, dotted packages and Cartesian CI

Root `holai.asd` now handwrites ordinary serial systems `holai/runtime` and
`holai`, not package-inferred systems. Runtime-only callers load `holai/runtime`;
full-core callers load `holai`. Package names are dot-separated:
`holai.runtime.<unit>` and `holai.<stem>`, including static child packages.
Filesystem paths and ASDF system IDs retain their slashes. There are no old-name
aliases, per-source inferred systems or shared runtime facade.
Explicitly load root `holai.asd` with `asdf:load-asd` before `asdf:load-system`;
the runtime ID is `holai/runtime`, not the obsolete `holai-runtime`.
The definition package is `holai.define`. Data/registry own leaf state, pattern
owns matching, core owns calling/proof macros, format owns printing and stdlib
owns library adapters; exports come from actual owners, not compatibility reexports.

Runtime implementation order is data, pattern-registry, pattern, core, format,
stdlib, followed by the unchanged 46-file vendor order: 52 production units.
The empty holai/all entry and generated provider/load-order S-expression data
are removed. Generated output is 93 files: 46 Lisp/map pairs plus inventory.
The maintained ASD is not generated from a manifest; cold diagnostics compare
actual ASDF compile/load paths against the vendor order and require zero
compiler diagnostics. The local ARM64 Linux `make release` exited 0 in 283.44
seconds: SBCL full-core and ECL/ABCL/CLISP runtime-fixture profiles, cold audit,
93 identical clean outputs, 55 unchanged pins and packaging all passed.
Tagged SBCL evidence records 128 native/69 PROOF checks, 1,149 rows (1,146 exact,
two structural registry, one Random property), 194,839 core / 207,058
fixture-inclusive map ranges and ten protected rejections. All 52 production
paths compiled/loaded in literal ASD order, with zero compiler diagnostics.
Separate initialization accounting is zero errors/warnings, 21 style warnings
and 164 notices. The producer reported 427 payload files; ZIP bytes may change
with final documentation. Older measurements below remain historical.

At this checkpoint CI crossed three hosts (aarch64-linux on ubuntu-24.04-arm,
aarch64-darwin on macos-15, x86_64-linux on ubuntu-24.04) with four Lisps: 12 jobs.
Fail-fast is disabled. Each validates its Nix system and selected package's
exported availability; missing targets fail. SBCL runs `HOLAI_LISPS=sbcl make release`;
the other jobs build the translator and run only their runtime-fixture profile.
SHA pins, read-only permissions and checkout without persisted credentials remain;
artifact names include both host and implementation.

Hosted run 38657307376 passed 10/12 jobs: all three SBCL full releases, all
three ECL profiles, all three ABCL profiles and ARM64 Linux CLISP. x86 Linux
CLISP's threaded sigwait dispatch and Darwin CLISP's missing FFI exposed the
old OS-default restoration contract. The user-approved boundary now restores
the exact previous native Lisp hook, not SIG_DFL. Enabling twice preserves the
saved prior hook; disabling twice is inert; re-enable captures a fresh prior.
The runtime-only regression installs an independent native hook, catches two
actual OS SIGINTs as Sys.Break across re-enable, then requires the third to invoke
that prior hook on the installing thread without a Sys.Break leak and exit 0.
Release metadata names `sigint_previous_hook_restored` and the explicit
`restore-previous-native-lisp-hook` policy. Stock NixOS 26.05 packages are used
on all three targets: no CLISP thread-disable or Darwin FFI override remains.
The new policy passed the current local ARM64 Linux release in 283.44 seconds.
All four profiles measured three real deliveries and two catches, exact prior-hook
restoration across re-enable and third-signal native-hook exit 0. Additional-host
metadata records `system_interrupt_previous_hook_restored=true`; SBCL records
`sigint_previous_hook_restored=true`. Its hosted follow-up is the observed
12/12 run linked above; the expanded 16-job matrix is not yet verified.
Historical reports below retain their measured old OS-default exit -2 contract.
Failure logs and annotations remain available; no failures are masked. ECL's weak-GC regression retains
the native MP worker and join; no production cache or proof algorithms change.
SBCL uses the public `SB-EXT:*INVOKE-DEBUGGER-HOOK*`, restoring its exact old value
and forwarding every condition other than `INTERACTIVE-INTERRUPT` to that hook.
ECL saves/restores the pre-debugger `SI:TERMINAL-INTERRUPT` function entry and
forwards to the enabling process with `MP:INTERRUPT-PROCESS` on threaded builds;
it does not use the broken ECL 26.5.5 signal-handler getter or late debugger hook.
ABCL preserves its Java Signal handler and target thread; CLISP uses native
ANSI CLOS global-handler methods. No libc/LibSystem FFI, signal-mask manipulation
or special CLISP build is required. This intentionally changes only OCaml's
otherwise-unused `Sys.catch_break false` boundary to native Lisp restoration;
enabled interrupts still raise actual Sys.Break, without source proof changes.

## Historical NixOS 26.05 and three-job platform CI

The development shell now uses one locked NixOS 26.05 nixpkgs input for all
compiler tools and Lisp packages, removing the old 23.11/25.05 split. The
OCaml 4.14 scope is retained with explicit Camlp5 8.02.01 and Num 1.5 source
overrides for the existing grammar/compiler contract; pinned HOL inputs,
the 52 production paths, 94 generated outputs and corpus boundaries are unchanged.
Exact toolchain versions and host package versions/executable bindings are
exported by the shell. Release validation compares actual host identities
against those pins rather than hardcoding the previous ECL 21.2.1 version.

At that historical checkpoint, SBCL plus usable ECL/ABCL/CLISP packages were
selected; the other four candidates were excluded by the old adapter gate.
The eight-candidate cutover above removes that gate. SBCL full-core verification remains
mandatory, while each selected additional host uses the bounded 120-second
runtime-fixture profile, never an implied full-core pass.

GitHub Actions uses SHA-pinned actions and read-only repository permissions.
Independent aarch64-linux, aarch64-darwin and x86_64-linux jobs run
`nix flake check` and ordinary `make release`; platform-specific logs, reports
and source archives are uploaded even when a job fails. Additional-host
full-core runs are not added to CI. The current 26.05 profile passed locally on
ARM64 Linux: flake checks, a forced fresh translator compiler build, and
ordinary release with all four selected hosts (293.62 seconds for the combined
flake-check/release invocation). Packages were OCaml 4.14.4, Camlp5 8.02.01,
Num 1.5, camlp-streams 5.0.1, SBCL 2.6.4, ECL 26.5.5, ABCL 1.9.3 and
CLISP 2.49.95. All three platform evaluations (`--all-systems --no-build`)
and actionlint 1.7.12 passed locally. Flake checks test ASDF startup only;
release tests the production runtime. At that historical measurement, hosted
Actions results and Darwin/x86 runtime results had not yet been observed.

The implementation-tagged reports at that checkpoint under `misc/reports/implementations/`
record 128 SBCL native checks, 69 PROOF DSL checks and 1,149 differential
observations, with 94 identical clean-generated outputs and 55
unchanged input pins. The source archive contained 428 payload files before
these final documentation edits; no fixed archive byte size is asserted.

That earlier ECL 26.5.5 weak-GC helper retained all 28 assertions with a native
creator and native `GC_clear_stack` before two `SI:GC` calls; it is now replaced above.
`EXT:CATCH-SIGNAL` is proclaimed NULL in ECL source while its C implementation
returns T; restoration now relies only on its side effect to restore real
SIG_DFL, not that contradictory return value. The actual interrupt test observed
two catches across re-enable and third-signal OS-default termination (exit -2).
The 23.11/25.05 results below remain historical, not current-platform evidence.

## Previous distribution: native implementation matrix (measured profile passes)

The previous compiler and SBCL/ECL pins were retained for that measured run.
A separately pinned nix-common-lisp reference source supplied additional
candidates ABCL, CLISP, CCL, MKCL, CMUCL and Clasp. Package selection checked
evaluability, platform and broken metadata with explicit exclusion reasons.
Its aarch64-linux matrix was SBCL/ECL/ABCL/CLISP, with measured passes below.
`HOLAI_LISPS` selects hosts; only SBCL is required for the full-core profile.
Every selected additional host must pass the bounded `runtime-fixtures`
compatibility profile, with a 120-second guard per process. Its independently
recorded `compatibility_passed` status explicitly leaves full-core verification
false; compatibility does not establish full HOL Light initialization.
ASDF is required before ASDF/UIOP symbols are read.
The SIGINT gate passed on the production adapters: three actual deliveries,
two Sys.Break catches across re-enable and restored OS-default termination
with exit -2. This does not establish additional-host full-core verification.
Native-compiled NaN/EQL is
explicitly not applicable on CLISP (no representable native IEEE NaN) and ECL
(the compiler cannot externalize `#<double-float quiet NaN>` into a FASL):
both retain 45 structural checks. SBCL and ABCL retain 46. This records a native
compiler capability, not a skipped finite case or an OCaml NaN-input restriction.
Stale declaration ABI rejection is checked in a separate Lisp process on every
host by loading a real compiled consumer against a changed declaration; only
the structured stale condition, its marker and expected nonzero exit pass.
Reports and source archives retain the isolated rejection log.
Random now uses standard Common Lisp RANDOM with a private standard random-state.
Random.init ignores its integer seed and resets via MAKE-RANDOM-STATE T; integer
seed replay is not guaranteed. Tests validate explicit-state advancement,
snapshot replay and bounds without assumptions about host-internal entropy or
default-state behavior. Weak storage and SIGINT use real host adapters.

Ordinary `make release` requires SBCL's complete native/PROOF/OCaml differential
profile and cold 52-path/47-inferred manifest-order compiler diagnostic audit.
Additional hosts require actual runtime/translated-fixture compile/load and
observations, defunc/OPTIONAL/tuple-list checks, real interrupt restoration,
weak retention, standard Random and structural matching/stale FASL checks.
Packaging validates exact host identities, current source fingerprints, measured
counts and matching actual log digests; it does not require additional hosts'
full-core observation streams or cold caches. The 94 clean outputs and 55 source
pins remain gates. Evidence is tagged under `misc/reports/implementations/<id>/`;
the previous root SBCL baseline remains historical, without relabelling.

`HOLAI_LISPS=ecl,abcl,clisp make test-full-core` explicitly runs additional hosts'
complete native tests and cold diagnostics. Those full-core processes retain
the previously approved 3600-second guard; SBCL and original OCaml retain 600
seconds, ordinary checks retain 120 and negative search bounds are unchanged.
The optional aggregate is implementation-full-core-matrix.json, not the ordinary
release gate. The extended ordinary matrix was cancelled; incomplete ABCL
full-core results remain incomplete, and earlier 600-second attempts/warm probes
are retained under misc/reports/history/portable-600-second-attempt/.
The literal language_random= row is validated for its 8/8/4 group shape and
2^30/97/2^30 bounds before canonical comparison. The user additionally selected
generated-name-only structural comparison for init_constants/init_definitions,
not record/replay or a replacement random engine. A pinned-source guard rejects
authored positive `_decimal` tokens before provenance classification. One shared
generated-constant identity map and distinct tag preserve reference identity
across both rows; positive `_decimal` bound variables use actual binder indices.
Authored `_0`, free variables, explicit/unknown constant names, concrete types,
sharing, order and multiplicity remain observable. All other rows remain exact.
See DESIGN's observation boundary for the complete observer-only contract.
Fresh-counter divergence was localized around METIS at int.ml:2239; attributing
the exact two allocations remains [INFERENCE], not a reason to rewrite source.
Packages retain raw and canonical streams and hashes, actual structured
identities and separate exact/property/structural counts. The measured SBCL
corpus has 1,149 rows: 1,146 literal-exact, two structural registry comparisons
and one Random property row; raw streams are unequal. Historical seeded
SBCL/OCaml reports remain unchanged.

The previous-distribution SBCL full-core verification passed 128 native and 69 PROOF checks,
with unchanged initial registries 22/303/263/3 and the original three axioms.
Initialization has 5,519 OCaml / 5,517 SBCL rows with only the two existing
OCaml-only messages. Map audits cover 194,839 core / 207,058 fixture-inclusive
entries, including current regressions, and ten rejections preserved outputs.
The 52-path/47-inferred cold audit exited 0 with zero compiler errors, warnings,
style warnings and notices. Its load/initialization accounting is separate:
zero errors/warnings, 21 style warnings and 164 notices.

ECL, ABCL and CLISP each passed the 120-second-per-process runtime-fixtures
profile: 28 defunc protocol, 84 OPTIONAL, 16 tuple-list and 1,816 Random checks;
three translated fixtures and 33 exact differential rows; nine naming rows.
Their structural counts are respectively 45, 46 and 45. Reports record current
source fingerprints, actual exits and digest-matched logs, and all explicitly
leave full-core verification false. Fixture fingerprints cover Lisp sources,
maps, provider data and inventory only; compiled FASLs are neither captured
nor shipped. Earlier full-core timeouts and incomplete extended attempts remain
failures/incomplete evidence, not compatibility passes.

The final `nix develop path:. --command make release` exited 0 in 269.03 seconds.
It regenerated all 46 inputs, passed full tests and cold diagnostics, and used
SBCL full-core evidence for inventory. Fresh clean generation matched all 94
outputs and confirmed 55 unchanged input pins. The archive producer reported
427 payload files. The earlier inventory failure requiring a CLISP full
verification report is historical, superseded by this completed release;
older package measurements below remain historical.

Production matching no longer depends on Trivia. The new static pattern
compiler validates bindings, OR alternatives, constructor arities and record
keys, and emits standard Common Lisp type tests, field accesses and bindings.
Existing data representations and defunc/lambdac/labelsc/fletc remain unchanged.

Generated guards use runtime:guard. Character literals use character-code
patterns, avoiding synthetic variable collisions. Constructor metadata is
available during compilation and loading; FASLs detect changed declaration
signatures and require rebuilding. OR joins share bodies and guards.

DESIGN30 describes the implementation; holai/tests/pattern.lisp covers semantics,
negative expansion cases, wide/deep patterns and separate compilation. Full
core and timing evidence is recorded in misc/reports/verification.json and
misc/reports/PATTERN-MATCH.md. The old Trivia sources and licenses are available in the historical
Git revision used for comparisons.

Translator-added suffixes are now percent signs instead of stars. Original
operator stars remain unchanged. Curried parameters, MATCH input temporaries
and translated LET/LET* bindings carry IGNORABLE declarations. Scope, bindings
and source algorithms are preserved. Previous timing results are historical.

Obsolete vendor/lisp dependencies and their ASDF search entries are removed.

## Layout and API cutover

Translator sources now live directly in `ml2cl/`; use `bin/ml2cl`. Lisp runtime, generated code and tests live under `holai/`. Production packages are `holai.runtime` and `holai.<input-stem>` (including nested module packages); ASDF systems are `holai-runtime` and `holai-generated`. Update callers and rebuild FASLs; there are no compatibility aliases. Scripts and reports live under `misc/`. This supersedes the earlier organization-only retain-hol2cl policy. Algorithms, data representations, pinned input bytes and source provenance remain unchanged. Historical raw reports retain their measured old paths/names and are not evidence of a new timing run.

Validated in the pinned aarch64-linux Nix shell with `make release`: 46 core
inputs, 1,124 matching differential observations, 51 production units with
zero diagnostics, and 94 identical clean-generated files. Both relocated SBCL
launchers initialized from outside the repository. Historical timings were
not remeasured.

## Shared PROOF tactical notation

`holai.runtime:proof` now provides handwritten and generated infix tactical
composition, preserving the original binary call tree and proof algorithms.
Operators are value symbols (THEN/THENL) or named function references
(`#'ORELSE`); all fold left, with inner PROOF forms for right grouping.
THENL retains ordinary Lisp branch lists. Translation is gated by canonical
binding identity, not spelling; aliases, shadowing, partial applications and
direct goal calls keep their ordinary paths. Fragment output preserves
`proof-tactical` source ranges for joined left prefixes and child operands.
See DESIGN §33 and the README's imported development-code example; its separate
fully qualified example intentionally demonstrates the external API.

### Safe bare PROOF in development code

The readability request covers translator-generated and maintained handwritten
**software development code**, not only end-user examples. Generated tactical
heads use deferred cells finalized after completed structure lowering for the
actual reader-owner namespace, before declarations, dependency emission and
rendering. Safe owners explicitly import runtime PROOF and emit bare `proof`.
Existing owned/local/imported-symbol conflict handling plus the maker-shadow
guard keeps `holai.runtime:proof` in conflicting owners, including declarations
that appear after the first tactical. Lexical modules share their enclosing
reader owner's decision; static child packages decide separately.
No PROOF reservation or source-binder renaming is added; algorithms, binding
identities, tactical eligibility and source-map origins are preserved.

Ordinary handwritten `holai/tests/proof-dsl.lisp` cases explicitly import the
runtime macro with UIOP and use bare `proof`. The original distinct-symbol local
PROOF function versus qualified macro regression remains in its own CL-only
package and uses the original helpers/counter; no theorem checks are removed.
Intentionally qualified external-API/collision examples remain qualified.
The actual safe-bare extension release passed
`nix develop path:. --command make release` (exit 0, 227.15 seconds):
129 native and 69 independent PROOF checks passed, and all 1,149 differential
rows matched (1,142 serialized plus seven actual side-effect rows).
Native collision-symbol tests passed. All six `proof_reader_*` observations
matched OCaml/SBCL: safe_child, late_local, late_global, foreign_import, case
and lexical_module. A separate fresh theorem smoke exited 0 in 72.41 seconds:
an explicitly importing package used unqualified `proof`, `DISCH_TAC`, `THEN`,
`FIRST_ASSUM`, `ACCEPT_TAC`, `prove`, `tuple`, `hyp` and `concl`, producing an
actual closed `p ==> p` whose conclusion matched the expected term.

All 46 inputs initialized; initial registries22/303/263/3 and exactly the
three source axioms are unchanged. The 5,519 OCaml/5,517 SBCL initialization
rows retain only the two known OCaml-only messages. All 194,839 core/206,472
inclusive map entries passed audit and ten rejections preserved output.
Fresh-cache diagnostics covered 52 unique production files in compile/load
order, including 47 genuine inferred core/entry components, with zero errors,
warnings or style warnings. All 94 clean outputs matched and 55 retained pins
were unchanged. The archive contains 305 payload files plus its manifest
(306 members), with no added repository files.

Static generated inventory records 2,353 bare PROOF heads and 25 qualified
collision heads; core Lisp totals 5,942,245 bytes. These counts are inventory,
not behavioral correctness or performance evidence. Completed reader-owner
decisions remain deferred, with no eager PROOF imports or source-binder renaming.
See DESIGN §37.4. All following preceding-release measurements remain historical.

The preceding reader-inclusive PROOF variant used `nix develop path:. --command make release` on
aarch64-linux (OCaml 4.14.2, Camlp5 8.02.01, SBCL 2.3.9.nixos): all 46
inputs initialized, 122 existing native and 61 independent PROOF checks
passed, and all 1,132 differential rows matched (1,125 serialized plus seven
actual side-effect rows), including eight new tactical observations.
A separate fresh sharp-backquote handwritten smoke proved the actual closed
identity theorem. The new unit is
compiled/loaded only after observation capture and std_formatter stream
restoration; its `proof_dsl_checks` counter is isolated from observations.

The initial 22/303/263/3 registries and exactly three source axioms are
unchanged. The 5,519 OCaml/5,517 SBCL initialization rows retain the known
exact two OCaml-only differences. Audits passed for 194,839 core/205,472
inclusive map entries and ten output-preserving rejections; generated core
Lisp is 6,943,214 bytes with 9,100 `proof-tactical` map entries. All 51
production units compiled with zero errors/warnings/style warnings, all 94
clean outputs matched and all 55 retained input hashes were unchanged.
The verified ZIP includes the new unit, translator, design, generated
Lisp/maps, reports and matching streams. Version remains
1.0.0-percent-names; no publication or new performance result is claimed.

### Authorized sharp-backquote reader

Runtime `sharp-backquote-lambda-reader` now installs #` dispatch in the active
`*readtable*` at compile/load/execute time, alongside unchanged standard `#'`.
Load the runtime before reading consumer files. Copies inherit the extension;
fresh standard readtables made from NIL do not. `readtable-case` and source
identifier atoms remain unchanged.

Where `#'name` denotes a named function, sharp-backquote wraps one read
value/expression form in `CL:LAMBDA` with a gensym rest parameter. Each call
evaluates the expression anew and uses `CL:APPLY` to preserve all arguments
and multiple values. The README shows a real PROOF using
``#`holai.tactics:DISCH_TAC`` and ``#`holai.tactics:ACCEPT_TAC``.
The wrapper is an operand, not directly a PROOF operator reference; bind it
to a lexical value symbol for that role. PROOF grammar is unchanged. Generated
value-call notation now follows the separate cutover below.

The runtime-only compile/load smoke passed, covering per-call evaluation,
dynamic rebinding, zero/multiple/NIL arguments, multiple values, gensym hygiene
and unchanged `#'`. The completed reader-inclusive release measured 61 PROOF
checks, including thirteen permanent reader checks with actual zero-argument
sum, positional decimal calculation, NIL classification, floor quotient/
remainder and lexical-argument hygiene computations. This runtime addition
leaves the 1,132 differential rows, 205,472 inclusive maps and 51 production
units unchanged; no publication or performance result is claimed.

## Reader-headed generated value calls

Generated value applications now use ``(#`f arg1 arg2)`` to reduce indentation,
including structurally computed heads and foreign excess-result calls.
This is a source-preserving notation change, not a performance optimization.
Direct named calls, `#'` references and foreign partial adapters retain their
existing paths. Function values passed as arguments or captured in bindings
stay eager plain references; they are not implicitly wrapped.

The function expression is acquired once per invocation **after** left-to-right
argument evaluation. An argument that rebinds it therefore selects the new
function for the same call. Direct reader calls preserve partial currying and
multiple return values. Runtime must be loaded before consumer files are read.
PROOF recognition/grammar/tactical emission and runtime-internal funcall/API
remain unchanged. A dedicated structural ReaderPrefix output node renders the
prefix adjacent to the annotated head and preserves source-map origins;
Fragment stays PROOF-only, with no generated-string postprocessing.

Eight added native consumer checks bring the measured `proof_dsl_checks` count
to 69 in the completed combined DESIGN34/35 release. One new
`reader_computed_head` observation checks a computed head and evaluation count
without duplicating existing partial/excess paths. No fixture/load component
is added (11/51). The completed DESIGN §36 release retains these checks;
historical integrated inventories are below. No new performance result is claimed.
See DESIGN §34.

## Plain local named-function groups

DESIGN §36 replaces the historical §35 representation with ordinary entries
in one shallow `labelsc` definition list:

```lisp
(labelsc
  ((f (x) (+ x 1))
   (g (x) (f x))
   (walk (x) (if (zerop x) (g x) (walk (1- x)))))
  (walk 2))
```

All generated local named-function groups use this syntax, including isolated
nonrecursive and recursive groups. Adjacent source groups share one genuine
CL:LABELS scope. Source references remain resolved in their original RHS
environments: nonrecursive and parallel RHSs see the preceding environment;
recursive RHSs see their own original recursive group, not later groups.
The compiler/runtime metadata-decoding path is removed without a shim.
Handwritten `fletc` retains its existing nonrecursive outer-RHS behavior.

Every function target stays unique throughout the combined chain, including
hidden earlier shadows and case collisions. All entry-visible logical targets
remain reserved through chain exit, as does every newly allocated member.
Scoped reservations use the existing local percent suffix allocator, without
fake environment bindings, changed source lookup or altered source spellings.
This prevents a later local definition from capturing an earlier RHS's
reference to an outer function even after repeated shadows.

Scalar LET values, modules, match, lambda and annotations stop grouping.
Initializers retain their position and execute once; captures, partials and
physical function identities retain their source bindings. All local-let
Origins survive with coincident output spans, together with function/body
Origins, binding IDs and lowering/import/reference order. No algorithms,
direct named calls, standard `#'` references or foreign adapters change.
DESIGN §34's late reader-head acquisition is separate and unchanged.
Ordinary entries keep name/parameters together when they fit 90 columns,
then place the body on a new line.

Lexical-module named function declarations also use ordinary `LABELSC`.
Only immediately adjacent named declarations inside one structure combine;
module declarations, aliases and includes, value or mixed slots, effects and
the external continuation remain barriers, even when an alias has no runtime
output. The module combiner peels only local-module-binding Origins. RHS
environment snapshots and original right-fold wrapper compilation order stay
unchanged.

Lexical global allocation reserves entry-visible names, including qualified
module public exports, and previously allocated targets; percent collision
suffixes avoid future ordinary prefixed/versioned names. Alias public
environments are visited once; functor captured environments are not traversed.
Top-level global allocation is unchanged. This prevents a new local module
`M.f` from capturing a resolved reference to an older `M.f`. No generated
`FLETC` calls remain; handwritten `FLETC` is retained. Plain local definition
headers keep the name/parameter list together when it fits 90 columns, using
a context-specific renderer without stage markers.

Final module-inclusive full-release validation of the plain-entry cutover passed.
The six existing `language_function_*` rows remain unchanged. Three added
behavioral cases produced these matching OCaml/SBCL rows:

```text
language_function_entry_shadow=142,142,284,284,42,42,42,42:true:true:true:true:true:true:true
language_function_case_shadow=42,42,42,42:true:true
language_module_function_scope=42,42,42,142,284,42,42,42,42,42,42,1,285,42,1:42,42,42,142,284,42,42,42,42,42,42,1,285,42,1
```

They cover an outer local function separated by a scalar LET from repeated
inner shadows, full function/partial captures across all four inner shadows,
stable and distinct function identities, and hidden case-sensitive names.
The added `language_module_function_scope` observation exercises escaped
closures/partials, repeated module names, sequential and parallel dependencies,
case shadowing, imports, aliases and once-only initialization. Together with
the entry/case rows this gives 1,142 matched rows (1,135 serialized observations
and seven actual side-effect rows).

`nix develop path:. --command make release` succeeded in 218.79 seconds with
OCaml 4.14.2, Camlp5 8.02.01 and SBCL 2.3.9.nixos. All 46 inputs loaded;
122 native, 69 independent PROOF, 27 calling-protocol, 84 OPTIONAL-entry,
16 tuple and 46 structural-pattern checks passed. All 194,839 core/206,245
inclusive map entries passed audit; ten rejections preserved output.
51 fresh-cache production units had zero errors/warnings/style warnings,
94 clean outputs were identical and 55 retained input pins unchanged.
Initial registries remain 22/303/263/3 and exactly the three original axioms;
5,519 OCaml/5,517 SBCL initialization rows retain the two known OCaml-only
message differences. The release ZIP's 305 members (304 payload files plus
RELEASE-MANIFEST.json) were verified. Generated
core Lisp totals 5,727,348 bytes after final header formatting, an inventory
measurement rather than a performance result.

Separate fresh-core smoke proved a closed identity theorem, passed 69 PROOF
checks and eight ordinary function-scope cases, and ran the escaped/rebound
module closure/partial and once-only initialization case twice with exact
expected results. Static search found zero generated FLETC calls or stage tags.
The full-release gate is satisfied; the user authorizes commit/push to
`tani/holai` main. This is not a publication claim. No new performance result
is claimed.

### Historical DESIGN §§34–35 validation

The previous combined `nix develop path:. --command make release` succeeded
in 217.72 seconds with OCaml 4.14.2, Camlp5 8.02.01 and SBCL 2.3.9.nixos.
All 46 inputs loaded; 122 existing native and 69 independent PROOF checks
passed. All 1,139 differential rows matched (1,132 serialized, seven side
effects), including the computed-head row and six language-group rows
covering chains, mixed nonrecursive/recursive groups, shadows/captured
identities, parallel groups, imports and a once-only initializer barrier.
All 194,839 core/205,818 inclusive maps passed audit, retaining all scope
Origins as coincident merged spans. Ten rejections preserved output;
51 fresh-cache units had zero errors/warnings/style warnings, 94 clean outputs
were identical and 55 input pins unchanged. Initial registries22/303/263/3,
the original axioms and the two known initialization-message differences
remained unchanged. That variant's generated core totals 6,174,070 bytes.
Separate actual smokes proved a closed identity, checked the six language
rows and the former metadata-based macros. DESIGN §35 retains their original
contract and results as history, not the current runtime API or §36 evidence.

## Pending discussion

- The FUNCALL investigation is resolved by the standard bare-FUNCALL cutover below; it establishes no performance improvement or hotspot claim.

## Unified ASDF definition and UIOP package inference

DESIGN §37 replaces the previous system definitions with one root `holai.asd`.
Load `holai` for the complete core or `holai/runtime/stdlib` for runtime-only use.
Every production unit is genuinely package-inferred, including all six runtime
implementation owners; generated packages/systems use `holai/generated/<stem>`.
Register only the repository root and require ASDF before UIOP package reading.
The main `holai` system is package-inferred through `holai/all.lisp`.
There are no compatibility package/system aliases. Private constructors,
source bindings, lexical dotted prefixes and algorithms remain unchanged.

Generated `package-systems.sexp` records every physical file's root/nested/private
provider. The first UIOP root shell declares runtime, predecessor and external
dependencies, excluding same-file packages. Remaining shells precede canonical
imports. Safe CL-first foreign-input mixes shorten references without exporting
private makers or turning lexical values into inherited SPECIAL bindings.
The six inferred runtime units, 46 generated files and holai/all total 53 units.
Generated outputs remain 94; clean/release comparisons include the provider data.

The preceding cutover (historical DESIGN §37.3) passed `nix develop path:. --command make release` (exit 0,
226.10 seconds) on aarch64-linux with OCaml 4.14.2, Camlp5 8.02.01 and
SBCL 2.3.9.nixos. All 46 inputs initialized in original order; 123 native,
69 PROOF, 46 pattern, 27 protocol, 84 OPTIONAL and 16 tuple checks passed.
All 1,143 differential rows matched (1,136 serialized plus seven side-effect
rows), and 194,839 core/206,277 inclusive map entries passed audit.
Ten rejection cases preserved output. Initial registries remain 22/303/263/3
with exactly the original three source axioms; initialization retains only the
two known OCaml-only messages (5,519 OCaml/5,517 SBCL rows), not raw equality.
Fresh-cache diagnostics recorded 52 unique production paths in compile/load
order, including 47 genuine inferred core/entry components, with zero errors,
warnings, style warnings or notices. All 94 clean outputs were identical and
55 retained input hashes unchanged.

Fresh ASDF 3.3.1 smokes loaded runtime alone, the complete inferred 46-source
core and fusion without parser/later theories. The full-core smoke proved a
closed `p ==> p`, checked private constructors and retained the three axioms
after reload. Existing private/collision/parent-capture coverage and the new
lexical-module UNIT escaped-closure/native runtime-UNIT preservation check passed.
Reader-owner local shadows preserve CL control and lexical scope; prefixes
remain where ownership or collisions require them.

The archive contains 306 members (305 payload plus `RELEASE-MANIFEST.json`),
only one ASD, entry/provider data and all 92 generated Lisp/map members.
Core Lisp totals 5,980,663 bytes. The impconv runtime-prefix inventory fell from
910 to 59; meson remains 51 and metis 105. Increased shadow headers preclude
inferring smaller total source, and no performance claim is made.
Earlier §36 counts/timings remain historical. This preceding validated cutover
was already pushed as `36f3a78`. The user now explicitly authorizes committing
and pushing the verified safe-bare extension with the simple, tidy README rewrite
to `tani/holai` main. Final repackaging, review, commit and push belong to the
parent; this authorization is not a claim that publication has occurred.

## Standard FUNCALL cutover

The user-authorized current API removes the redundant runtime application
wrapper, its shadow/export and dependent imports. Maintained handwritten calls
and synthetic call forms use bare `funcall`; no alias or reexport remains.
Definition-package symbols and the translator's reserved control-name allocator
keep synthetic calls distinct from source functions/values named `funcall`.
Source binding IDs, scopes and algorithms remain unchanged.

The actual calling protocol remains in the common OPTIONAL curried entry:
NIL-versus-omitted, partial/excess application, primary-only body results,
once-only evaluation and captured function identity are unchanged. Exact native
adapters retain multiple returned values. Sharp-backquote headed applications
still evaluate arguments before acquiring the head; they are not rewritten to
eager standard calls.

Source collision behavior is covered by global value/function and local function
fixtures, including partial application. Protocol checks distinguish native
quotient/remainder returns from primary-only source entry returns. The current
benchmark labels the standard call `standard-funcall`; historical wrapper
measurements and earlier release counts above are not reinterpreted as new
measurements. Verification for this cutover must be reported from its own run.
