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
  # available and no init.
  initEl = ''
    ;;; init.el --- Loads the init of a nemacs configuration -*- lexical-binding: t -*-
    (require 'nemacs-init)
  '';

  initDirectory = pkgs.linkFarm "nemacs-init-directory" {
    "early-init.el" = pkgs.writeText "early-init.el" earlyInitEl;
    "init.el" = pkgs.writeText "init.el" initEl;
  };
in
{
  options.build.package = lib.mkOption {
    type = lib.types.package;
    readOnly = true;
    description = ''
      The editor: `package` with the init package and every package it
      requires, its `emacs` binaries started on an init directory that
      holds `earlyInit` and an `init.el` that requires `nemacs-init`. The other binaries of `package`, `emacsclient`
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
            --add-flags "--init-directory ${initDirectory}"
        fi
      done
    '';
    passthru = {
      inherit version;
    };
    meta.mainProgram = "emacs";
  };
}
