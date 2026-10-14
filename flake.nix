{
  description = "Holai OCaml/Camlp5 and Common Lisp development shell";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
  inputs.lispPkgs.url = "github:NixOS/nixpkgs/cd2812de55cf87df88a9e09bf3be1ce63d50c1a6";

  outputs = { self, nixpkgs, lispPkgs, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
    in
    {
      devShells = nixpkgs.lib.genAttrs systems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          ocamlPackages = pkgs.ocaml-ng.ocamlPackages_4_14;
          # Inspect broken-package metadata without making those packages runnable.
          newer = import lispPkgs { inherit system; config.allowBroken = true; };
          candidates = [ "abcl" "sbcl" "ecl" "ccl" "mkcl" "clisp" "cmucl_binary" "clasp-common-lisp" ];
          source = id: if builtins.elem id [ "sbcl" "ecl" ] then pkgs else newer;
          status = id:
            let attempt = builtins.tryEval ((source id).${id});
            in if !attempt.success then { available = false; reason = "Package attribute missing or evaluation failed"; }
            else if !(pkgs.lib.meta.availableOn pkgs.stdenv.hostPlatform attempt.value)
              then { available = false; reason = "Unsupported platform ${system}"; }
            else if attempt.value.meta.broken or false
              then { available = false; reason = if id == "mkcl" && system == "aarch64-linux"
                then "Marked broken; actual allowBroken MKCL1.1.11 build failed: tinycc/lib-arm64.c:17 implicit declaration __arm64_clear_cache"
                else "Package marked broken in pinned nixpkgs"; }
            else { available = true; reason = null; };
          available = builtins.filter (id: (status id).available) candidates;
          inherit (ocamlPackages) ocaml camlp5;
          streams = ocamlPackages.camlp-streams;

          # nixpkgs ships Num 1.1; keep the project's Num 1.5 prerequisite.
          # Its modern installation target replaces the old nixpkgs patch.
          num = ocamlPackages.num.overrideAttrs (_: {
            version = "1.5";
            src = pkgs.fetchFromGitHub {
              owner = "ocaml";
              repo = "num";
              rev = "v1.5";
              hash = "sha256-60yT7BN+E93LJWKlO3v55Lbb11pNLPzdf1wrNXkLtmk=";
            };
            patches = [ ];
            installTargets = [ "findlib-install" ];
          });

          siteLib = package: "${package}/lib/ocaml/${ocaml.version}/site-lib";
          numLib = "${siteLib num}/num";

          # OCAMLPATH is for findlib, not direct ocamlc/ocamlopt archive lookup.
          # Preserve the existing nums.cma/nums.cmxa callers without rewriting them.
          compiler = pkgs.symlinkJoin {
            name = "holai-ocaml-${ocaml.version}";
            paths = [ ocaml ];
            nativeBuildInputs = [ pkgs.makeWrapper ];
            postBuild = ''
              for command in ocaml ocamlc ocamlc.opt ocamlopt ocamlopt.opt; do
                wrapProgram "$out/bin/$command" --add-flags "-I ${numLib}"
              done
            '';
          };
        in
        {
          default = pkgs.mkShell {
            packages = [
              compiler
              ocamlPackages.findlib
              camlp5
              num
              streams
              (pkgs.writeTextFile {
                name = "holai-lisp-matrix";
                destination = "/share/holai/lisp-availability.json";
                text = builtins.toJSON (builtins.listToAttrs (map (id: {
                  name = id; value = status id;
                }) candidates));
              })
              pkgs.python3
              pkgs.gnumake
            ] ++ map (id: (source id).${id}) available;

            CAMLPLIB = "${siteLib camlp5}/camlp5";
            STREAMLIB = "${siteLib streams}/camlp-streams";
            HOLAI_LISPS = builtins.concatStringsSep "," available;
            HOLAI_REQUIRED_LISPS = "sbcl";
            HOLAI_LISP_AVAILABILITY = builtins.toJSON (builtins.listToAttrs (map (id: {
              name = id; value = status id;
            }) candidates));

            # Direct bytecode execution needs Num's dynamically loaded stub.
            # Keep the wrapped compiler ahead of transitively supplied raw OCaml.
            shellHook = ''
              export PATH="${compiler}/bin:$PATH"
              export CAML_LD_LIBRARY_PATH="${numLib}''${CAML_LD_LIBRARY_PATH:+:$CAML_LD_LIBRARY_PATH}"
            '';
          };
        });
      apps = nixpkgs.lib.genAttrs systems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          shell = self.devShells.${system}.default;
          ids = nixpkgs.lib.splitString "," shell.HOLAI_LISPS;
          app = id: mode: {
            name = "${mode}-${id}";
            value = {
              type = "app";
              program = toString (pkgs.writeShellScript "holai-${mode}-${id}" ''
                exec ${pkgs.nix}/bin/nix develop .#default --command \
                  env HOLAI_LISP=${id} ${pkgs.python3}/bin/python3 \
                  ${if mode == "main" then "misc/scripts/lisp_host.py"
                    else if mode == "full-core" || id == "sbcl" then "holai/tests/run.py"
                    else "holai/tests/compatibility.py"} "$@"
              '');
            };
          };
        in builtins.listToAttrs (builtins.concatMap (id: [
          (app id "main") (app id "test") (app id "full-core")
        ]) ids));
      checks = nixpkgs.lib.genAttrs systems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          newer = lispPkgs.legacyPackages.${system};
          ids = nixpkgs.lib.splitString "," self.devShells.${system}.default.HOLAI_LISPS;
          binaries = { cmucl_binary = "lisp"; clasp-common-lisp = "clasp"; };
          evalFlags = { clisp = "-x"; cmucl_binary = "-eval"; mkcl = "-eval"; };
        in builtins.listToAttrs (map (id: {
          name = "asdf-${id}";
          value = pkgs.runCommand "holai-asdf-${id}" { nativeBuildInputs = [
            (if builtins.elem id [ "sbcl" "ecl" ] then pkgs.${id} else newer.${id})
          ]; } ''
            export HOME=$TMPDIR
            ${binaries.${id} or id} ${evalFlags.${id} or "--eval"} \
              '(progn (require "asdf") (funcall (intern "QUIT" "UIOP") 0))'
            touch "$out"
          '';
        }) ids));
    };
}
