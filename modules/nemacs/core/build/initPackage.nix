# SPDX-License-Identifier: MIT
{
  config,
  lib,
  pkgs,
  ...
}:
let
  epkgs = config.build.epkgs;
  version = config.package.version or "0";

  initEl = lib.concatStringsSep "\n" [
    ";;; nemacs-init.el --- The init of a nemacs configuration -*- lexical-binding: t -*-"
    ";;; Code:"
    ""
    config.init
    ""
    "(provide 'nemacs-init)"
    ";;; nemacs-init.el ends here"
    ""
  ];
in
{
  options.build.initPackage = lib.mkOption {
    type = lib.types.package;
    readOnly = true;
    description = ''
      The package `nemacs-init`: the configuration's `init`, compiled
      against every package of `packages`, which it requires. The
      `init.el` of the built editor requires the feature `nemacs-init`.
    '';
  };

  config.build.initPackage = epkgs.nemacsBuild {
    pname = "nemacs-init";
    inherit version;
    src = pkgs.writeTextDir "nemacs-init.el" initEl;
    packageRequires = config.packages epkgs;
  };
}
