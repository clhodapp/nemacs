# nemacs: product

nemacs is the Emacs counterpart of nixvim and nvf: a module system
whose evaluation builds an editor. It holds the framework and nothing
of anyone's configuration. ch-emacs-config is a configuration written
in it, and ch-ai-workbench adds its bundles to that configuration as
further nemacs modules.

## Scope

nemacs owns what every configuration needs in order to become an
editor:

- the options a configuration is written in (`package`, `bundles`,
  `init`, `packages`, `overrides`, `earlyInit`);
- the build: the package set with the overlays applied, the init
  compiled into `nemacs-init`, and the wrapped editor;
- `nemacsBuild`, the builder for packages kept beside a configuration;
- the evaluator `evalNemacs` and the Home Manager and NixOS modules.

Anything a particular configuration decides stays in that
configuration: which packages, which init, fonts, a daemon and its
systemd unit, launchers, program pins.

## Interfaces

- `lib.nemacs.evalNemacs { pkgs, modules }` evaluates a configuration
  and returns the `evalModules` result.
- `lib.nemacs.modules` is the list of core modules, for an evaluator
  that is not `evalNemacs`. The module class is `nemacs`.
- `modules.homeManager.nemacs` and `modules.nixos.nemacs` declare
  `programs.nemacs.{enable,settings}`.

The evaluator depends on nixpkgs alone. caisson builds the outputs and
the checks of this flake. A caisson integration for the `nemacs` class
would map onto `lib.nemacs.modules` the way caisson's nvf integration
maps onto the module list of nvf.
