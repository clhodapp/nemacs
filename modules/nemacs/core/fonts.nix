# SPDX-License-Identifier: MIT
{ lib, ... }:
{
  options.fonts = lib.mkOption {
    type = lib.types.listOf lib.types.package;
    default = [ ];
    example = lib.literalExpression "[ pkgs.monaspace pkgs.noto-fonts-color-emoji ]";
    description = ''
      The font packages the init names. The built editor holds the
      `share/fonts` directory of each under `share/fonts` of the editor,
      so a profile that points at the editor carries the fonts the
      editor needs, and a new editor generation brings the fonts it
      names with it. Emacs finds a font through fontconfig, which has to
      scan that directory: the configuration that puts the editor in a
      profile adds the directory to fontconfig. The definitions of every
      module are concatenated.
    '';
  };
}
