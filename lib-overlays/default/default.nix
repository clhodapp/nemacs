# SPDX-License-Identifier: MIT
#
# The nemacs library: the core modules of a nemacs configuration and the
# function that evaluates one. A configuration is a module evaluation of
# the class `nemacs`; its result holds the built editor at
# `config.build.package`.
{ ... }:
{

  imports = [ ];

  overlay = final: prev: {
    nemacs = (prev.nemacs or { }) // {
      # The modules every nemacs evaluation starts from, as paths. A
      # caller that evaluates nemacs modules by other means (a submodule
      # of a Home Manager or NixOS option, the evaluator of a framework)
      # imports this list and supplies `pkgs` as a module argument.
      modules = import ./modules;

      # `{ pkgs, modules }` to the evaluated configuration.
      evalNemacs = import ./evalNemacs.nix { lib = final; };
    };
  };

}
