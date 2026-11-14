# SPDX-License-Identifier: MIT
#
# The `nemacs` command, which builds and activates a nemacs
# configuration published by a flake. It runs the `nix` and `nix-env`
# found on the PATH, so it uses the Nix of the machine it runs on.
{ lib, writeShellApplication }:
writeShellApplication {
  name = "nemacs";
  text = builtins.readFile ./nemacs.bash;
  meta = {
    description = "Build and activate a nemacs configuration";
    license = lib.licenses.mit;
    mainProgram = "nemacs";
  };
}
