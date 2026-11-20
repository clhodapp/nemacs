# SPDX-License-Identifier: MIT
#
# The checks of nemacs: a flake-parts configuration declared inside the
# flake-parts caisson top (configs/flake/nemacs), whose dependencies are
# those of the caisson top with the pins of tests/dependencies beside
# them. The caisson top gathers the checks declared here into its
# `checks` output. A flake that lists nemacs as an input reads nothing
# of this configuration, so it locks none of the pins of
# tests/dependencies.
#
# `self` is the flake of this configuration, and `self.outPath` is the
# source tree of nemacs. The modules under test are read from the
# module registry of the composition, where the caisson top exports
# them from.
{ closure-lib, ... }:
{
  inputs,
  lib,
  self,
  ...
}:
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

      withFonts = closure-lib.nemacs.evalNemacs {
        inherit pkgs;
        modules = [
          fixtureSettings
          {
            key = "nemacs.checks.fonts";
            fonts = [ pkgs.dejavu_fonts ];
          }
        ];
      };

      withExtraPaths = closure-lib.nemacs.evalNemacs {
        inherit pkgs;
        modules = [
          fixtureSettings
          {
            key = "nemacs.checks.extra-paths";
            extraPaths = [ (pkgs.writeShellScriptBin "nemacs-test-launcher" "exit 0") ];
          }
        ];
      };

      homeManagerConfiguration = inputs.home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          lib.caisson.modules.homeManager.nemacs
          {
            key = "nemacs.checks.homeManagerConfiguration";
            home.username = "tester";
            home.homeDirectory = "/home/tester";
            home.stateVersion = "25.05";
            programs.nemacs.enable = true;
            programs.nemacs.settings = fixtureSettings;
          }
        ];
      };

      nixosConfiguration = inputs.nixpkgs.lib.nixosSystem {
        modules = [
          lib.caisson.modules.nixos.nemacs
          {
            key = "nemacs.checks.nixosConfiguration";
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
      # Duplicated in the formatter partition of configs/flake/nemacs:
      # the partition and this configuration are separate evaluations.
      treefmt.programs.nixfmt.enable = true;

      caisson.checks = {
        treefmt = {
          category = "format";
          description = "the Nix files are formatted with nixfmt";
        };

        nemacs = {
          derivation = standalone.config.build.package;
          category = "build";
          description = "the editor that the fixture settings evaluate to builds";
        };

        nemacs-init-order = {
          derivation =
            assert ordering.config.init == "z\na\nb\nafter";
            pkgs.runCommand "nemacs-init-order" { } "touch $out";
          category = "eval";
          description = "bundles of equal order follow in name order, a lower order comes first, and `mkAfter` on `init` comes last";
        };

        nemacs-fonts = {
          derivation =
            let
              editor = withFonts.config.build.package;
              plain = standalone.config.build.package;
            in
            pkgs.runCommand "nemacs-fonts" { } ''
              # The editor holds the font files of the package in `fonts`.
              test -e ${editor}/share/fonts/truetype/DejaVuSans.ttf
              # An editor with no `fonts` holds no font file.
              test -z "$(find -L ${plain}/share/fonts -type f 2>/dev/null)"
              touch $out
            '';
          category = "build";
          description = "the editor holds the font files of the packages in `fonts` under `share/fonts`, and an editor with no `fonts` holds none";
        };

        nemacs-extra-paths = {
          derivation =
            let
              editor = withExtraPaths.config.build.package;
              plain = standalone.config.build.package;
            in
            pkgs.runCommand "nemacs-extra-paths" { } ''
              # The editor holds the program of the package in `extraPaths`.
              test -x ${editor}/bin/nemacs-test-launcher
              # An editor with no `extraPaths` holds no such program.
              test ! -e ${plain}/bin/nemacs-test-launcher
              touch $out
            '';
          category = "build";
          description = "the editor holds the files of the packages in `extraPaths`, and an editor with no `extraPaths` holds none of them";
        };

        # The probe expression must stay free of single quotes for the
        # shell quoting to hold.
        nemacs-startup = {
          derivation =
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
          category = "build";
          description = "a daemon of the built editor runs the whole startup path and reads back what the fixture configuration left";
        };

        nemacs-package-descriptor = {
          derivation = pkgs.runCommand "nemacs-package-descriptor" { } ''
            export HOME="$TMPDIR"
            ${lib.getExe standalone.config.build.package} --batch \
              -l ${testsSrc}/emacs/descriptor-probe.el
            touch $out
          '';
          category = "build";
          description = "package.el reads the package built with `nemacsBuild` as it reads a package it installed: its descriptor, requirements and autoloads";
        };

        home-manager-module = {
          derivation =
            assert lib.elem homeManagerConfiguration.config.programs.nemacs.settings.build.package
              homeManagerConfiguration.config.home.packages;
            homeManagerConfiguration.activationPackage;
          category = "build";
          description = "the home-manager module installs the editor the settings build, and the home-manager configuration builds";
        };

        # Only the package list is forced: building the NixOS
        # configuration would build a whole system for a single
        # assertion.
        nixos-module = {
          derivation =
            let
              editor = nixosConfiguration.config.programs.nemacs.settings.build.package;
            in
            assert lib.elem editor nixosConfiguration.config.environment.systemPackages;
            pkgs.runCommand "nixos-module" { } ''
              test -x ${editor}/bin/emacs
              touch $out
            '';
          category = "build";
          description = "the NixOS module installs the editor the settings build";
        };

        # A stand-in for `nix` records its arguments, and the activation
        # package it hands back records that its `activate` ran.
        nemacs-cli = {
          derivation =
            pkgs.runCommand "nemacs-cli"
              {
                nativeBuildInputs = [ pkgs.nemacs.nemacs ];
              }
              ''
                export HOME="$TMPDIR/home"
                export LOG="$TMPDIR/log"
                export ACTIVATION="$TMPDIR/activation"
                mkdir -p "$HOME" "$TMPDIR/bin" "$ACTIVATION"
                : > "$LOG"

                cat > "$ACTIVATION/activate" <<'EOF'
                #!/bin/sh
                echo activate >> "$LOG"
                EOF

                cat > "$TMPDIR/bin/nix" <<'EOF'
                #!/bin/sh
                echo "nix $*" >> "$LOG"
                case "$1" in
                eval)
                  case "$*" in
                  *currentSystem*) echo x86_64-linux ;;
                  *profile.path*) printf '%s' '$HOME/.local/state/caisson/profiles/nemacs/editor' ;;
                  esac
                  ;;
                build)
                  case "$*" in
                  *--print-out-paths*) echo "$ACTIVATION" ;;
                  esac
                  ;;
                esac
                EOF

                chmod +x "$ACTIVATION/activate" "$TMPDIR/bin/nix"
                export PATH="$TMPDIR/bin:$PATH"

                nemacs build --flake ./cfg#editor --out-link out
                nemacs switch -f .#editor
                nemacs generations -f .#editor
                nemacs rollback -f .#editor
                nemacs build
                nemacs switch -- --option cores 1

                status=0
                nemacs bogus 2>/dev/null || status=$?
                [ "$status" = 1 ]
                status=0
                nemacs 2>/dev/null || status=$?
                [ "$status" = 2 ]

                cat > "$TMPDIR/expected" <<EOF
                nix eval --impure --raw --expr builtins.currentSystem
                nix build ./cfg#nemacsConfigurations.x86_64-linux."editor".activationPackage --out-link out
                nix eval --impure --raw --expr builtins.currentSystem
                nix build .#nemacsConfigurations.x86_64-linux."editor".activationPackage --no-link --print-out-paths
                activate
                nix eval --impure --raw --expr builtins.currentSystem
                nix eval --raw .#nemacsConfigurations.x86_64-linux."editor".profile.path
                nix profile history --profile $HOME/.local/state/caisson/profiles/nemacs/editor
                nix eval --impure --raw --expr builtins.currentSystem
                nix eval --raw .#nemacsConfigurations.x86_64-linux."editor".profile.path
                nix profile rollback --profile $HOME/.local/state/caisson/profiles/nemacs/editor
                nix eval --impure --raw --expr builtins.currentSystem
                nix build .#nemacsConfigurations.x86_64-linux."default".activationPackage --out-link result
                nix eval --impure --raw --expr builtins.currentSystem --option cores 1
                nix build .#nemacsConfigurations.x86_64-linux."default".activationPackage --no-link --print-out-paths --option cores 1
                activate
                EOF
                diff -u "$TMPDIR/expected" "$LOG"
                touch $out
              '';
          category = "unit";
          description = "the `nemacs` command makes the `nix` calls it should, passes arguments after `--` on, and refuses an unknown command and a missing one with the exit codes 1 and 2";
        };
      };
    };
}
