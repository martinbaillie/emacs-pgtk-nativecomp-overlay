let
  sources = import ./nix/sources.nix;
  nixpkgs = sources."nixos-unstable";
  pkgs = import nixpkgs { };
  emacs-pgtk-nativecomp = sources."emacs-pgtk-nativecomp";
  emacs-nativecomp = sources."emacs-nativecomp";
  mkGitEmacs = attrs:
    builtins.foldl' (drv: fn: fn drv) pkgs.emacs [

      (drv: drv.override { srcRepo = true; })
      (drv:
        if attrs.usePgtk then
          drv.overrideAttrs (old: {
            name = "emacsGccPgtk";
            version = "28.0.50";
            src = pkgs.fetchFromGitHub {
              inherit (emacs-pgtk-nativecomp) owner repo rev sha256;
            };

            configureFlags = old.configureFlags ++ [ "--with-pgtk" ];
          })
        else
          drv.overrideAttrs (old: {
            name = "emacsGcc";
            version = "28.0.50";
            src = pkgs.fetchFromGitHub {
              inherit (emacs-nativecomp) owner repo rev sha256;
            };
          }))

      (drv:
        drv.overrideAttrs (old: {
          patches = [
            (pkgs.fetchpatch {
              name = "clean-env.patch";
              url =
                "https://raw.githubusercontent.com/nix-community/emacs-overlay/master/patches/clean-env.patch";
              sha256 = "0lx9062iinxccrqmmfvpb85r2kwfpzvpjq8wy8875hvpm15gp1s5";
            })
            (pkgs.fetchpatch {
              name = "tramp-detect-wrapped-gvfsd.patch";
              url =
                "https://raw.githubusercontent.com/nix-community/emacs-overlay/master/patches/tramp-detect-wrapped-gvfsd.patch";
              sha256 = "19nywajnkxjabxnwyp8rgkialyhdpdpy26mxx6ryfl9ddx890rnc";
            })
          ];

          preConfigure = optionalString isDarwin ''
            export ac_cv_func_aligned_alloc=no
          '';

          postPatch = old.postPatch + ''
            substituteInPlace lisp/loadup.el \
            --replace '(emacs-repository-get-version)' '"${emacs-pgtk-nativecomp.rev}"' \
            --replace '(emacs-repository-get-branch)' '"master"'
          '';

        }))
      (drv: drv.override { nativeComp = true; })
    ];
  inherit (pkgs.stdenv) isDarwin;
  inherit (pkgs.lib) optionalString;
in _: _: {
  ci = (import ./nix { }).ci;

  emacsGccPgtk = (mkGitEmacs { usePgtk = true; });
  emacsGcc = (mkGitEmacs { usePgtk = false; });

}
