# SPDX-License-Identifier: MIT
{ lib, ... }:
{
  options.overrides = lib.mkOption {
    type = lib.types.listOf (lib.types.functionTo (lib.types.functionTo lib.types.attrs));
    default = [ ];
    example = lib.literalExpression ''
      [
        (final: prev: {
          my-package = final.nemacsBuild {
            pname = "my-package";
            version = "0.1";
            src = ./my-package;
            packageRequires = [ final.dash ];
          };
        })
      ]
    '';
    description = ''
      Overlays on the Emacs package set, each `final: prev:` over it,
      applied in list order. Every module can contribute one, and all of
      them share one fixed point, so a package one module adds can
      depend on a package another module adds.

      The package set carries `nemacsBuild`, the builder for packages
      kept beside a configuration. It byte-compiles with warnings as
      errors against the package's `packageRequires`, and it generates
      the autoloads that put the package on the load path.
    '';
  };
}
