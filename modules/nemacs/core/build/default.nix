# SPDX-License-Identifier: MIT
#
# What a configuration builds, as read-only options computed from the
# rest of it.
{
  imports = [
    ./epkgs
    ./initPackage.nix
    ./package
  ];
}
