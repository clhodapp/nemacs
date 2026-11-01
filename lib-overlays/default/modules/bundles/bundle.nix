# SPDX-License-Identifier: MIT
{ lib, ... }:
{
  options = {
    enable = lib.mkEnableOption "this bundle";

    init = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = ''
        The Elisp this bundle adds to the configuration's `init` while it
        is enabled. Several modules can contribute, and their definitions
        are joined in priority order, so a module can append to a bundle
        another module defines with `lib.mkAfter`.
      '';
    };

    packages = lib.mkOption {
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      default = _epkgs: [ ];
      example = lib.literalExpression "epkgs: [ epkgs.magit ]";
      description = ''
        The Emacs packages this bundle's init requires, as a function of
        the configuration's package set.
      '';
    };

    order = lib.mkOption {
      type = lib.types.int;
      default = 1000;
      description = ''
        Where this bundle's init falls in the configuration's `init`, as
        the priority of `lib.mkOrder`: a lower number comes first.
        Bundles of equal order follow in name order. 1000 is also the
        priority of a definition made directly on `init`, so a bundle
        that has to come before such definitions takes a lower number.
      '';
    };
  };
}
