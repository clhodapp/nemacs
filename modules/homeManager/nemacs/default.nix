# SPDX-License-Identifier: MIT
#
# A nemacs configuration inside a Home Manager configuration:
# `programs.nemacs.settings` is evaluated as nemacs modules, on the
# package set of the Home Manager configuration, and the editor it
# builds is installed into the profile.
{ closure-lib, ... }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.nemacs;
in
{
  options.programs.nemacs = {
    enable = lib.mkEnableOption "nemacs, an Emacs configured through the nemacs modules in `settings`";

    settings = lib.mkOption {
      type = lib.types.submoduleWith {
        class = "nemacs";
        modules = closure-lib.nemacs.modules ++ [
          {
            key = "nemacs.homeManager.pkgs";
            _module.args.pkgs = lib.mkDefault pkgs;
          }
        ];
      };
      default = { };
      description = ''
        The nemacs configuration, as nemacs modules. Its `build.package`
        is the editor installed while `enable` is set. The settings are
        evaluated either way, so another module can read what they build.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.settings.build.package ];
  };
}
