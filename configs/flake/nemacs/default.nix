# SPDX-License-Identifier: MIT
{ ... }:
{
  inputs,
  lib,
  ...
}:
{

  imports = [ inputs.flake-parts.flakeModules.partitions ];

  debug = false;

  caisson.libOverlays.exported = libOverlays: { inherit (libOverlays) default; };

  caisson.modules = {
    homeManager.exported = modules: { inherit (modules) nemacs; };
    nixos.exported = modules: { inherit (modules) nemacs; };
    nemacs.exported = modules: { inherit (modules) core; };
  };

  # The checks of nemacs, with the pins of tests/dependencies that only
  # the checks need (configs/flake/checks). The caisson top gathers the
  # checks of every configuration declared inside it into its `checks`
  # output. This selector passes the configuration up to nothing, so a
  # flake that reads the exports of nemacs evaluates neither the
  # configuration nor its pins.
  caisson.flake-parts.configurations.checks = lib.caisson.flake-parts.mkConfiguration {
    inherit (lib.caisson.pins.flake-compat ../../../tests/dependencies) dependencies;
  };
  caisson.flake-parts.exported = _: { };

  partitionedAttrs.formatter = "formatter";

  partitions.formatter = {
    extraInputs = (lib.caisson.pins.flake-compat ../../../tests/dependencies).dependencies;
    module =
      { inputs, ... }:
      {
        imports = [ inputs.treefmt-nix.flakeModule ];
        # treefmt reads the perSystem `pkgs`, which caisson's nixpkgs
        # module supplies from the `default` package config declared on
        # mkLib (configs/nixpkgsConfig/default).
        perSystem.treefmt.programs.nixfmt.enable = true;
      };
  };

}
