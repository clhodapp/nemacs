# SPDX-License-Identifier: MIT
{ closure-lib, ... }:
{
  inputs,
  lib,
  ...
}:
{

  imports = [ inputs.flake-parts.flakeModules.partitions ];

  debug = false;

  caisson.libOverlays.exported = libOverlays: { inherit (libOverlays) default; };

  caisson.modules = {
    homeManager.exported = modules: { inherit (modules) nemacs; };
    nixos.exported = modules: { inherit (modules) nemacs; };
  };

  partitionedAttrs.checks = "checks";
  partitionedAttrs.formatter = "formatter";

  partitions.formatter = {
    extraInputs = (lib.caisson.pins.flake-compat ../../../tests/dependencies).sources;
    module =
      { inputs, ... }:
      {
        imports = [ inputs.treefmt-nix.flakeModule ];
        # treefmt reads the perSystem `pkgs`, which caisson's nixpkgs
        # module supplies from the `default` package config declared on
        # mkLib (configs/nixpkgsConfig/default).
        perSystem.treefmt.programs.nixfmt.enable = true;
      };
  };

  partitions.checks = {
    extraInputs = (lib.caisson.pins.flake-compat ../../../tests/dependencies).sources;
    module =
      { inputs, self, ... }:
      {
        imports = [ inputs.treefmt-nix.flakeModule ];
        perSystem =
          { pkgs, ... }:
          let
            testsSrc = self.outPath + "/tests";

            # The fixture on the terminal build of Emacs, which the binary
            # cache carries and which needs no display.
            fixtureSettings = {
              key = "nemacs.checks.fixture-settings";
              imports = [ (testsSrc + "/fixture") ];
              package = pkgs.emacs-nox;
            };

            standalone = closure-lib.nemacs.evalNemacs {
              inherit pkgs;
              modules = [ fixtureSettings ];
            };

            # Bundles of equal order follow in name order, a bundle of
            # lower order comes first whatever its name, and `mkAfter` on
            # `init` comes after every bundle.
            ordering = closure-lib.nemacs.evalNemacs {
              inherit pkgs;
              modules = [
                {
                  key = "nemacs.checks.ordering";
                  init = lib.mkAfter "after";
                  bundles = {
                    b.enable = true;
                    b.init = "b";
                    a.enable = true;
                    a.init = "a";
                    z.enable = true;
                    z.order = 10;
                    z.init = "z";
                    off.init = "off";
                  };
                }
              ];
            };

            home = inputs.home-manager.lib.homeManagerConfiguration {
              inherit pkgs;
              modules = [
                self.modules.homeManager.nemacs
                {
                  key = "nemacs.checks.home";
                  home.username = "tester";
                  home.homeDirectory = "/home/tester";
                  home.stateVersion = "25.05";
                  programs.nemacs.enable = true;
                  programs.nemacs.settings = fixtureSettings;
                }
              ];
            };

            machine = inputs.nixpkgs.lib.nixosSystem {
              modules = [
                self.modules.nixos.nemacs
                {
                  key = "nemacs.checks.machine";
                  nixpkgs.pkgs = pkgs;
                  boot.loader.grub.enable = false;
                  fileSystems."/" = {
                    device = "none";
                    fsType = "tmpfs";
                  };
                  system.stateVersion = "25.05";
                  programs.nemacs.enable = true;
                  programs.nemacs.settings = fixtureSettings;
                }
              ];
            };
          in
          {
            checks = {
              nemacs = standalone.config.build.package;

              nemacs-init-order =
                assert ordering.config.init == "z\na\nb\nafter";
                pkgs.runCommand "nemacs-init-order" { } "touch $out";

              # Start a daemon from the built editor, the full startup
              # path (early-init, package activation, the init package),
              # and read back what the fixture configuration left. The
              # probe expression must stay free of single quotes for the
              # shell quoting to hold.
              nemacs-startup =
                let
                  editor = standalone.config.build.package;
                in
                pkgs.runCommand "nemacs-startup" { } ''
                  export HOME="$TMPDIR/home"
                  export XDG_RUNTIME_DIR="$TMPDIR/run"
                  mkdir -p "$HOME"
                  mkdir -p -m 700 "$XDG_RUNTIME_DIR"
                  ${lib.getExe editor} --daemon=probe
                  result="$(${editor}/bin/emacsclient -s probe --eval \
                    '(progn (load "${testsSrc}/emacs/startup-probe.el") (nemacs-test-probe))')"
                  ${editor}/bin/emacsclient -s probe --eval '(kill-emacs 0)' 2>/dev/null || true
                  echo "$result"
                  [[ "$result" == '"OK"' ]]
                  touch $out
                '';

              # The Home Manager module installs the editor the settings
              # build, and the whole home configuration evaluates.
              home-manager-module =
                assert lib.elem home.config.programs.nemacs.settings.build.package home.config.home.packages;
                home.activationPackage;

              # The NixOS module installs the editor the settings build.
              # Only the package list is forced: building the machine
              # would build a whole system for one assertion.
              nixos-module =
                let
                  editor = machine.config.programs.nemacs.settings.build.package;
                in
                assert lib.elem editor machine.config.environment.systemPackages;
                pkgs.runCommand "nixos-module" { } ''
                  test -x ${editor}/bin/emacs
                  touch $out
                '';
            };
            treefmt.programs.nixfmt.enable = true;
          };
      };
  };

}
