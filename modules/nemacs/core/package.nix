# SPDX-License-Identifier: MIT
{ lib, pkgs, ... }:
{
  options.package = lib.mkOption {
    type = lib.types.package;
    default = pkgs.emacs;
    defaultText = lib.literalExpression "pkgs.emacs";
    description = ''
      The Emacs the configuration is built on. Its package set is the one
      the configuration's packages come from, and its binary is the one
      the built editor runs.
    '';
  };
}
