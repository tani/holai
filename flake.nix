{
  description = "Holai OCaml/Camlp5 and Common Lisp development shell";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs = { self, nixpkgs, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      # Inspect broken-package metadata, but select only usable candidates below.
      packagesFor = system: import nixpkgs {
        inherit system;
        config.allowBroken = true;
      };
    in
    {
      devShells = nixpkgs.lib.genAttrs systems (system:
        let
          pkgs = packagesFor system;
          ocamlPackages = pkgs.ocaml-ng.ocamlPackages_4_14;
          candidates = [ "abcl" "sbcl" "ecl" "ccl" "mkcl" "clisp" "cmucl_binary" "clasp-common-lisp" ];
          adapters = [ "sbcl" "ecl" "abcl" "clisp" ];
          status = id:
            let attempt = builtins.tryEval pkgs.${id};
            in if !attempt.success then { available = false; reason = "Package attribute missing or evaluation failed"; }
            else if !(pkgs.lib.meta.availableOn pkgs.stdenv.hostPlatform attempt.value)
              then { available = false; reason = "Unsupported platform ${system}"; }
            else if attempt.value.meta.broken or false
              then { available = false; reason = "Package marked broken in pinned nixpkgs"; }
            else if !(builtins.elem id adapters)
              then { available = false; reason = "Package available; no implemented runtime adapter"; }
            else { available = true; reason = null; };
          available = builtins.filter (id: (status id).available) candidates;
          inherit (ocamlPackages) ocaml;
          streams = ocamlPackages.camlp-streams;
          # pa_j_4.xx_8.02.ml requires this parser API, not nixpkgs' newer Camlp5.
          camlp5 = ocamlPackages.camlp5.overrideAttrs (_: {
            version = "8.02.01";
            src = pkgs.fetchFromGitHub {
              owner = "camlp5";
              repo = "camlp5";
              rev = "8.02.01";
              hash = "sha256-qSA2559vqWLU+0ns7LPUGI2K5f8sfu+QQ0sCH8sR6To=";
            };
            propagatedBuildInputs = [ streams ];
            preConfigure = ''
              configureFlagsArray=(--strict --libdir $out/lib/ocaml/${ocaml.version}/site-lib)
              patchShebangs ./config/find_stuffversion.pl etc/META.pl
            '';
            postInstall = "";
          });

          # Keep the project's Num 1.5 prerequisite and modern installation target.
          num = ocamlPackages.num.overrideAttrs (_: {
            version = "1.5";
            src = pkgs.fetchFromGitHub {
              owner = "ocaml";
              repo = "num";
              rev = "v1.5";
              hash = "sha256-60yT7BN+E93LJWKlO3v55Lbb11pNLPzdf1wrNXkLtmk=";
            };
            patches = [ ];
            postPatch = "";
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
          default = assert (status "sbcl").available; pkgs.mkShell {
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
            ] ++ map (id: pkgs.${id}) available;

            CAMLPLIB = "${siteLib camlp5}/camlp5";
            STREAMLIB = "${siteLib streams}/camlp-streams";
            HOLAI_LISPS = builtins.concatStringsSep "," available;
            HOLAI_REQUIRED_LISPS = "sbcl";
            HOLAI_LISP_AVAILABILITY = builtins.toJSON (builtins.listToAttrs (map (id: {
              name = id; value = status id;
            }) candidates));
            HOLAI_LISP_VERSIONS = builtins.toJSON (builtins.listToAttrs (map (id: {
              name = id; value = pkgs.${id}.version;
            }) available));
            HOLAI_LISP_EXECUTABLES = builtins.toJSON (builtins.listToAttrs (map (id: {
              name = id; value = "${pkgs.${id}}/bin/${id}";
            }) available));
            HOLAI_TOOLCHAIN_VERSIONS = builtins.toJSON {
              ocaml = ocaml.version;
              camlp5 = camlp5.version;
              camlp-streams = streams.version;
              num = num.version;
            };

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
          pkgs = packagesFor system;
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
          pkgs = packagesFor system;
          ids = nixpkgs.lib.splitString "," self.devShells.${system}.default.HOLAI_LISPS;
          binaries = { cmucl_binary = "lisp"; clasp-common-lisp = "clasp"; };
          evalFlags = { clisp = "-x"; cmucl_binary = "-eval"; mkcl = "-eval"; };
        in builtins.listToAttrs (map (id: {
          name = "asdf-${id}";
          value = pkgs.runCommand "holai-asdf-${id}" { nativeBuildInputs = [
            pkgs.${id}
          ]; } ''
            export HOME=$TMPDIR
            ${binaries.${id} or id} ${evalFlags.${id} or "--eval"} \
              '(progn (require "asdf") (funcall (intern "QUIT" "UIOP") 0))'
            touch "$out"
          '';
        }) ids));
    };
}
