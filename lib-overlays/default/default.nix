# SPDX-License-Identifier: MIT
#
# The nemacs library: the function that evaluates a nemacs
# configuration. A configuration is a module evaluation of the class
# `nemacs`; its result holds the built editor at `config.build.package`.
{ closure-lib, ... }:
{

  imports = [ ];

  overlay = final: prev: {
    nemacs = (prev.nemacs or { }) // {
      # `{ pkgs, modules }` to the evaluated configuration.
      evalNemacs = import ./evalNemacs.nix {
        lib = final;
        core = closure-lib.caisson.modules.nemacs.core;
      };
    };
  };

}
