# SPDX-License-Identifier: MIT
{ lib, ... }:
{
  options.extraPaths = lib.mkOption {
    type = lib.types.listOf lib.types.package;
    default = [ ];
    example = lib.literalExpression "[ launchers ]";
    description = ''
      Packages whose files the built editor holds as they are, next to
      the files of `package`: a launcher script in `bin`, a data file in
      `share`. A profile that points at the editor then carries them, and
      a new editor generation brings the version of each that it was
      built with. A package listed here cannot refer to the editor, which
      is built from it. The definitions of every module are concatenated.
    '';
  };
}
