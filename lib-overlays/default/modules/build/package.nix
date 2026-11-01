# SPDX-License-Identifier: MIT
{
  config,
  lib,
  pkgs,
  ...
}:
let
  version = config.package.version or "0";

  # `--init-directory` makes this store directory `user-emacs-directory`,
  # which is read-only, so the first form moves it back to where Emacs
  # would have put it before any package reads it.
  earlyInitEl = ''
    ;;; early-init.el --- The early init of a nemacs configuration -*- lexical-binding: t -*-
    (when (string-prefix-p "/nix/store/" user-emacs-directory)
      (setq user-emacs-directory
            (if-let* ((xdg (getenv "XDG_CONFIG_HOME")))
                (expand-file-name "emacs/" xdg)
              (expand-file-name ".emacs.d/" (getenv "HOME")))))

    ${config.earlyInit}
  '';

  # Emacs loads `init.el` from the init directory once startup has
  # activated the packages, so every package the init requires is on the
  # load path by then. `emacs -q` skips it and starts with the packages
  # available and no init. The byte compiler loads the feature of a
  # top-level `require` while compiling; inside `unless` the `require`
  # only runs at startup, so compiling this file loads no init.
  initEl = ''
    ;;; init.el --- Loads the init of a nemacs configuration -*- lexical-binding: t -*-
    (unless (featurep 'nemacs-init)
      (require 'nemacs-init))
  '';

  # The init directory, compiled ahead of time. Emacs loads `early-init`
  # and `init` preferring the `.elc`, and finds the `.eln` of each along
  # `native-comp-eln-load-path`. The `.eln` files are compiled at the
  # path the sources keep in the store, which their file names hash, and
  # land in `share/emacs/native-lisp`; listing this derivation among the
  # editor's packages puts that directory in the package-deps tree, which
  # the load path holds from early-init on.
  initDirectory =
    pkgs.runCommand "nemacs-init-directory-${version}"
      {
        nativeBuildInputs = [ config.package ];
        passAsFile = [
          "earlyInitEl"
          "initEl"
        ];
        inherit earlyInitEl initEl;
      }
      ''
        export HOME="$TMPDIR"
        mkdir -p "$out/init" "$out/share/emacs/native-lisp"
        cp "$earlyInitElPath" "$out/init/early-init.el"
        cp "$initElPath" "$out/init/init.el"
        emacs --batch \
          --eval '(setq byte-compile-error-on-warn t)' \
          -f batch-byte-compile "$out/init/early-init.el" "$out/init/init.el"
        if emacs --batch --eval '(kill-emacs (if (native-comp-available-p) 0 1))'; then
          emacs --batch \
            --eval "(setq native-comp-eln-load-path (list \"$out/share/emacs/native-lisp/\"))" \
            -f batch-native-compile "$out/init/early-init.el" "$out/init/init.el"
        fi
      '';

  emacsWithPackages = config.build.epkgs.withPackages (_epkgs: [
    config.build.initPackage
    initDirectory
  ]);
in
{
  options.build.package = lib.mkOption {
    type = lib.types.package;
    readOnly = true;
    description = ''
      The editor: `package` with the init package and every package it
      requires, its `emacs` binaries started on an init directory that
      holds `earlyInit` and an `init.el` that requires `nemacs-init`.
      Both files are byte-compiled, and native-compiled when `package`
      supports it, so startup loads no Lisp source of this
      configuration's own. The other binaries of `package`, `emacsclient`
      among them, are carried as they are.
    '';
  };

  config.build.package = pkgs.symlinkJoin {
    name = "nemacs-${version}";
    paths = [ emacsWithPackages ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      for bin in "$out/bin/emacs" "$out/bin/emacs-${version}"; do
        if [ -e "$bin" ]; then
          rm "$bin"
          makeWrapper ${emacsWithPackages}/bin/emacs "$bin" \
            --add-flags "--init-directory ${initDirectory}/init"
        fi
      done
    '';
    passthru = {
      inherit version;
    };
    meta.mainProgram = "emacs";
  };
}
