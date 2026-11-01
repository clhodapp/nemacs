# SPDX-License-Identifier: MIT
{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.build.epkgs = lib.mkOption {
    type = lib.types.raw;
    readOnly = true;
    description = ''
      The Emacs package set of `package`, with `nemacsBuild` added and
      then every overlay in `overrides` applied. The init package and
      every package of `packages` come from it, so a module that reads a
      package from here gets the same build the editor loads.
    '';
  };

  config.build.epkgs = (pkgs.emacsPackagesFor config.package).overrideScope (
    lib.composeManyExtensions (
      [
        (final: _prev: {
          nemacsBuild = final.callPackage ./nemacsBuild { };
        })
      ]
      ++ config.overrides
    )
  );
}
