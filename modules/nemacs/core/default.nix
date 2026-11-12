# SPDX-License-Identifier: MIT
#
# The core module of a nemacs configuration. Every nemacs evaluation
# imports it, and `pkgs` must be supplied as a module argument. Each
# file it imports declares one top-level option.
{ ... }:
{
  imports = [
    ./package.nix
    ./overrides.nix
    ./packages.nix
    ./init.nix
    ./earlyInit.nix
    ./bundles
    ./build
  ];
}
