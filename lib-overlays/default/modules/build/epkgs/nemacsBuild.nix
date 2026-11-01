# SPDX-License-Identifier: MIT
#
# The builder for an Emacs package kept beside a configuration: the
# arguments of `trivialBuild` (`pname`, `version`, `src`,
# `packageRequires`), byte-compiled with warnings as errors, and
# installed as a package.el package with generated autoloads, so
# package activation puts it on the load path and loads its autoloads.
# A `src` that is a path is filtered to its `.el` files.
{ lib, trivialBuild }:
args:
let
  # The -L flags for each dependency's elisp directories, collected at
  # build time, where the dependency outputs are present as build
  # inputs. Scanning them at evaluation time (builtins.pathExists or
  # readDir on an output) would force the dependencies to be built
  # during evaluation, which is import from derivation in effect. That
  # breaks evaluation-only workflows (nix flake check --no-build,
  # allow-import-from-derivation = false) whenever the outputs have been
  # garbage-collected.
  collectLoadFlags = lib.concatMapStrings (dep: ''
    for d in ${dep}/share/emacs/site-lisp/elpa/*/ ${dep}/share/emacs/site-lisp; do
      if [ -d "$d" ]; then
        lispLoadFlags="$lispLoadFlags -L $d"
      fi
    done
  '') (args.packageRequires or [ ]);
in
trivialBuild (
  args
  // {
    src = if lib.isPath args.src then lib.sourceFilesBySuffices args.src [ ".el" ] else args.src;

    preBuild = ''
      lispLoadFlags=""
      ${collectLoadFlags}
      # The add-to-list form is the one package-generate-autoloads of
      # package.el embeds. Activating the package must put its own
      # directory on load-path, or (require 'this-package) from a
      # dependent package finds nothing.
      emacs $lispLoadFlags -L . --batch \
        --eval "(loaddefs-generate \".\" \"${args.pname}-autoloads.el\" nil \";;; ${args.pname}-autoloads.el --- automatically generated\n(add-to-list 'load-path (or (and load-file-name (directory-file-name (file-name-directory load-file-name))) (car load-path)))\n\")"
    '';

    buildPhase = ''
      runHook preBuild

      emacs $lispLoadFlags -l package -f package-initialize \
        --eval "(setq byte-compile-debug t)" \
        --eval "(setq byte-compile-error-on-warn t)" \
        -L . --batch -f batch-byte-compile *.el

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      local lispDir="$out/share/emacs/site-lisp/elpa/${args.pname}-${args.version}"
      install -d "$lispDir"
      install *.el *.elc "$lispDir"

      cat > "$lispDir/${args.pname}-pkg.el" <<EOF
      ;; -*- no-byte-compile: t -*-
      (define-package "${args.pname}" "${args.version}" "Local build of ${args.pname}")
      EOF

      runHook postInstall
    '';
  }
)
