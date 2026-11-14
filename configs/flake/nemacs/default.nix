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

  # The `nemacs` command is the `default` entry of this flake's package
  # overlay registry (pkg-overlays/, registered on mkLib): the package
  # set applies it by default, and the flake exports it as `pkgOverlays`,
  # as the plain `overlays.default` and as `packages.<system>.nemacs`.
  caisson.nixpkgs.packages.export.enabled = true;

  perSystem =
    { config, ... }:
    {
      packages.default = config.packages.nemacs;
    };

  caisson.modules = {
    homeManager.exported = modules: { inherit (modules) nemacs; };
    nixos.exported = modules: { inherit (modules) nemacs; };
    nemacs.exported = modules: { inherit (modules) core; };
  };

  partitionedAttrs.checks = "checks";
  partitionedAttrs.formatter = "formatter";

  partitions.formatter = {
    extraInputs = (lib.caisson.pins.flake-compat ../../../tests/dependencies).dependencies;
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
    extraInputs = (lib.caisson.pins.flake-compat ../../../tests/dependencies).dependencies;
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

            homeManagerConfiguration = inputs.home-manager.lib.homeManagerConfiguration {
              inherit pkgs;
              modules = [
                self.modules.homeManager.nemacs
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
                self.modules.nixos.nemacs
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

              # package.el reads the package built with `nemacsBuild` as
              # it reads one it installed itself: its descriptor, its
              # requirements, its autoloads.
              nemacs-package-descriptor = pkgs.runCommand "nemacs-package-descriptor" { } ''
                export HOME="$TMPDIR"
                ${lib.getExe standalone.config.build.package} --batch \
                  -l ${testsSrc}/emacs/descriptor-probe.el
                touch $out
              '';

              # The Home Manager module installs the editor the settings
              # build, and the whole home-manager configuration evaluates.
              home-manager-module =
                assert lib.elem homeManagerConfiguration.config.programs.nemacs.settings.build.package
                  homeManagerConfiguration.config.home.packages;
                homeManagerConfiguration.activationPackage;

              # The NixOS module installs the editor the settings build.
              # Only the package list is forced: building the NixOS
              # configuration would build a whole system for a single
              # assertion.
              nixos-module =
                let
                  editor = nixosConfiguration.config.programs.nemacs.settings.build.package;
                in
                assert lib.elem editor nixosConfiguration.config.environment.systemPackages;
                pkgs.runCommand "nixos-module" { } ''
                  test -x ${editor}/bin/emacs
                  touch $out
                '';

              # The `nemacs` command calls `nix` as it should. A stand-in
              # for `nix` records its arguments, and the activation
              # package it hands back records that its `activate` ran.
              nemacs-cli =
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
            };
            treefmt.programs.nixfmt.enable = true;
          };
      };
  };

}
