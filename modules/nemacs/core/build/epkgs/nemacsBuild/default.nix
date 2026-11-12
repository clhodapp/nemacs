# SPDX-License-Identifier: MIT
#
# The builder for an Emacs package kept beside a configuration: the
# arguments of `trivialBuild` (`pname`, `version`, `src`,
# `packageRequires`), byte-compiled with warnings as errors, and
# installed as a package.el package. The package directory holds what
# package.el itself installs: autoloads generated the way
# `package-generate-autoloads` generates them, and a `-pkg.el` written
# by `package-generate-description-file` (./descriptor.el says from
# what). A `src` that is a path is filtered to its `.el` files.
{ lib, trivialBuild }:
args:
let
  # The -L flags for each dependency's elisp directories, and the
  # installed package directory of each dependency that is a package.el
  # package, collected at build time, where the dependency outputs are
  # present as build inputs. Scanning them at evaluation time
  # (builtins.pathExists or readDir on an output) would force the
  # dependencies to be built during evaluation, which is import from
  # derivation in effect. That breaks evaluation-only workflows (nix
  # flake check --no-build, allow-import-from-derivation = false)
  # whenever the outputs have been garbage-collected.
  collectDependencies = lib.concatMapStrings (dep: ''
    for d in ${dep}/share/emacs/site-lisp/elpa/*/ ${dep}/share/emacs/site-lisp; do
      if [ -d "$d" ]; then
        lispLoadFlags="$lispLoadFlags -L $d"
      fi
    done
    for descriptor in ${dep}/share/emacs/site-lisp/elpa/*/*-pkg.el; do
      if [ -e "$descriptor" ]; then
        dependencyPackageDirs+=("$(dirname "$descriptor")")
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
      dependencyPackageDirs=()
      ${collectDependencies}
      # The header is the form `package-generate-autoloads` gives
      # `loaddefs-generate`: activating the package puts the directory
      # of the package on load-path, or (require 'this-package) from a
      # dependent package finds nothing.
      emacs $lispLoadFlags -L . --batch \
        --eval "(loaddefs-generate \".\" \"${args.pname}-autoloads.el\" nil (prin1-to-string '(add-to-list 'load-path (or (and load-file-name (directory-file-name (file-name-directory load-file-name))) (car load-path)))))"
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

      emacs --batch -l ${./descriptor.el} \
        "$lispDir" ${lib.escapeShellArg args.pname} ${lib.escapeShellArg args.version} \
        "''${dependencyPackageDirs[@]}"

      runHook postInstall
    '';
  }
)
