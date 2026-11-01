# SPDX-License-Identifier: MIT
{ lib, ... }:
{
  options.packages = lib.mkOption {
    type = lib.types.functionTo (lib.types.listOf lib.types.package);
    default = _epkgs: [ ];
    example = lib.literalExpression "epkgs: [ epkgs.magit ]";
    description = ''
      The Emacs packages the init requires, as a function of the package
      set with every overlay in `overrides` applied. The definitions of
      every module are concatenated. An enabled bundle contributes its
      own `packages` here.
    '';
  };
}
