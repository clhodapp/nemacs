# SPDX-License-Identifier: MIT
#
# A bundle is a feature turned on as a unit: the init that configures it
# and the packages that init needs. An enabled bundle adds its init to
# `init` and its packages to `packages`; a disabled one adds nothing.
{ config, lib, ... }:
let
  enabled = lib.filterAttrs (_name: bundle: bundle.enable) config.bundles;
in
{
  options.bundles = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ./bundle.nix);
    default = { };
    example = lib.literalExpression ''
      {
        magit = {
          enable = true;
          init = "(keymap-global-set \"C-x g\" #'magit-status)";
          packages = epkgs: [ epkgs.magit ];
        };
      }
    '';
    description = ''
      The bundles of the configuration, by name. A module that defines a
      bundle usually sets its `enable` with `lib.mkDefault`, so another
      module can turn the bundle off with a plain definition.
    '';
  };

  config = {
    # Bundles of equal order follow in name order: `mapAttrsToList`
    # walks the names sorted, and definitions of equal priority keep
    # their order.
    init = lib.mkMerge (
      lib.mapAttrsToList (_name: bundle: lib.mkOrder bundle.order bundle.init) enabled
    );
    packages = lib.mkMerge (lib.mapAttrsToList (_name: bundle: bundle.packages) enabled);
  };
}
