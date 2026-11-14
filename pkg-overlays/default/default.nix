# SPDX-License-Identifier: MIT
#
# The default package overlay: the `nemacs` command under
# `pkgs.nemacs.nemacs`. A consumer that lists this flake in `projects`
# holds it as `nemacs/default`, which its package sets apply by default.
{ closure-lib, ... }:
{
  overlay = closure-lib.caisson.nixpkgs.mkPackagesOverlay ../../pkgs "nemacs";
}
