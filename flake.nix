{
  description = "Holai OCaml/Camlp5 and Common Lisp development shell";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";

  outputs = { nixpkgs, ... }:
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
              pkgs.sbcl
              pkgs.python3
              pkgs.gnumake
            ];

            CAMLPLIB = "${siteLib camlp5}/camlp5";
            STREAMLIB = "${siteLib streams}/camlp-streams";

            # Direct bytecode execution needs Num's dynamically loaded stub.
            # Keep the wrapped compiler ahead of transitively supplied raw OCaml.
            shellHook = ''
              export PATH="${compiler}/bin:$PATH"
              export CAML_LD_LIBRARY_PATH="${numLib}''${CAML_LD_LIBRARY_PATH:+:$CAML_LD_LIBRARY_PATH}"
            '';
          };
        });
    };
}
