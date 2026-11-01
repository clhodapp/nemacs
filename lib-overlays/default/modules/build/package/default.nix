# SPDX-License-Identifier: MIT
{
  config,
  lib,
  pkgs,
  ...
}:
let
  version = config.package.version or "0";

  emacsWithPackages = config.build.epkgs.withPackages (_epkgs: [ config.build.initPackage ]);

  # `--init-directory` makes the init directory `user-emacs-directory`,
  # which is read-only, so the first form moves it back to where Emacs
  # would have put it before any package reads it. The second points
  # package activation at the quickstart file built below, so startup
  # loads that compiled file instead of every package's autoloads.
  earlyInitEl = ''
    ;;; early-init.el --- The early init of a nemacs configuration -*- lexical-binding: t -*-
    (when (string-prefix-p "/nix/store/" user-emacs-directory)
      (setq user-emacs-directory
            (if-let* ((xdg (getenv "XDG_CONFIG_HOME")))
                (expand-file-name "emacs/" xdg)
              (expand-file-name ".emacs.d/" (getenv "HOME")))))
    (defvar package-quickstart-file)
    (setq package-quickstart-file "@quickstart@")

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

  # The Lisp startup loads outside the packages, compiled ahead of time:
  # the init directory, and the quickstart file `package-quickstart-refresh`
  # generates from the editor's packages, which holds every package's
  # autoloads in one file. Each is byte-compiled and, when the Emacs
  # supports it, native-compiled at the store path it keeps, which the
  # `.eln` file names hash, into `share/emacs/native-lisp`. Emacs loads
  # the `.elc` of each and finds its `.eln` through the wrapper below.
  startup =
    pkgs.runCommand "nemacs-startup-${version}"
      {
        passAsFile = [
          "earlyInitEl"
          "initEl"
        ];
        inherit earlyInitEl initEl;
      }
      ''
        export HOME="$TMPDIR"
        emacs=${emacsWithPackages}/bin/emacs
        mkdir -p "$out/init" "$out/share/emacs/native-lisp"
        cp "$earlyInitElPath" "$out/init/early-init.el"
        substituteInPlace "$out/init/early-init.el" \
          --replace-fail '@quickstart@' "$out/package-quickstart.el"
        cp "$initElPath" "$out/init/init.el"

        # Generates and byte-compiles the quickstart file.
        "$emacs" --batch --eval "(progn
          (require 'package)
          (setq package-quickstart-file \"$out/package-quickstart.el\")
          (package-quickstart-refresh))"
        test -f "$out/package-quickstart.elc"

        "$emacs" --batch \
          --eval '(setq byte-compile-error-on-warn t)' \
          -f batch-byte-compile "$out/init/early-init.el" "$out/init/init.el"

        if "$emacs" --batch --eval '(kill-emacs (if (native-comp-available-p) 0 1))'; then
          "$emacs" --batch \
            --eval "(setq native-comp-eln-load-path (list \"$out/share/emacs/native-lisp/\"))" \
            -f batch-native-compile \
            "$out/init/early-init.el" "$out/init/init.el" "$out/package-quickstart.el"
        fi
      '';

  # A trampoline for every primitive, compiled ahead of time
  # (./trampolines.el says why). Trampolines depend on the Emacs alone,
  # so this is built once per `package` and shared by every
  # configuration on it.
  trampolines =
    pkgs.runCommand "nemacs-trampolines-${version}"
      {
        nativeBuildInputs = [ config.package ];
      }
      ''
        export HOME="$TMPDIR"
        mkdir -p "$out/share/emacs/native-lisp"
        if emacs --batch --eval '(kill-emacs (if (native-comp-available-p) 0 1))'; then
          shards=''${NIX_BUILD_CORES:-1}
          [ "$shards" -ge 1 ] || shards=1
          pids=()
          for shard in $(seq 0 $((shards - 1))); do
            emacs --batch -l ${./trampolines.el} \
              "$out/share/emacs/native-lisp" "$shard" "$shards" &
            pids+=($!)
          done
          for pid in "''${pids[@]}"; do
            wait "$pid"
          done
        fi
      '';
in
{
  options.build.package = lib.mkOption {
    type = lib.types.package;
    readOnly = true;
    description = ''
      The editor: `package` with the init package and every package it
      requires, its `emacs` binaries started on an init directory that
      holds `earlyInit` and an `init.el` that requires `nemacs-init`.

      Everything startup loads beyond Emacs itself is compiled ahead of
      time: the init directory, a quickstart file holding every
      package's autoloads, which package activation loads in their
      place, and a trampoline for every primitive, which Emacs would
      otherwise compile at run time the first time Lisp advises that
      primitive. Their `.eln` directories are added to
      `EMACSNATIVELOADPATH`. The other binaries of `package`,
      `emacsclient` among them, are carried as they are.
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
          # The wrapper of `emacsWithPackages` adds the packages' own
          # native-lisp tree at an empty element of EMACSNATIVELOADPATH,
          # or alone when the variable is unset, so the value keeps an
          # empty element after these two directories. `--prefix` would
          # trim it.
          makeWrapper ${emacsWithPackages}/bin/emacs "$bin" \
            --run 'export EMACSNATIVELOADPATH="${startup}/share/emacs/native-lisp:${trampolines}/share/emacs/native-lisp:''${EMACSNATIVELOADPATH:+:$EMACSNATIVELOADPATH}"' \
            --add-flags "--init-directory ${startup}/init"
        fi
      done
    '';
    passthru = {
      inherit version;
    };
    meta.mainProgram = "emacs";
  };
}
