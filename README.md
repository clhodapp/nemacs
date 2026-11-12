# nemacs

An Emacs configured through the Nix module system. A nemacs
configuration is a set of modules; evaluating them builds an editor:
Emacs, the packages the configuration needs, and its init compiled
into a separate package.

## A configuration

```nix
{ lib, pkgs, ... }:
{
  package = pkgs.emacs-pgtk;

  bundles.magit = {
    enable = lib.mkDefault true;
    init = "(keymap-global-set \"C-x g\" #'magit-status)";
    packages = epkgs: [ epkgs.magit ];
  };

  earlyInit = "(setq inhibit-startup-screen t)";
}
```

A **bundle** is a feature turned on as a unit: the init that configures
it and the packages that init needs. An enabled bundle adds both to the
configuration, and a disabled one adds nothing. Because a bundle is an
option value, any module can define one, turn one off, or append to the
init of one another module defined (`bundles.magit.init = lib.mkAfter
"..."`).

The options:

| Option | What it holds |
|---|---|
| `package` | The Emacs the editor is built on. Defaults to `pkgs.emacs`. |
| `bundles.<name>` | `enable`, `init`, `packages`, and `order`, which places the bundle's init. |
| `init` | The init. Bundles contribute here; a direct definition can too. |
| `packages` | The packages the init requires, as a function of the package set. |
| `overrides` | Overlays on the Emacs package set, all sharing one fixed point. |
| `earlyInit` | The contents of `early-init.el`. |
| `build.epkgs` | The package set with every overlay applied (read-only). |
| `build.initPackage` | The init, byte-compiled into the package `nemacs-init` (read-only). |
| `build.package` | The editor (read-only). |

The init is joined in priority order. A bundle's init takes the
priority its `order` names (1000 by default), bundles of equal order
follow in name order, and a definition made on `init` directly can use
`lib.mkBefore` and `lib.mkAfter` to land before or after them.

The init is compiled with warnings as errors, against every package the
configuration lists, so a misspelled function or a missing package
fails the build rather than the startup.

Packages kept beside the configuration go into the package set through
`overrides`, built with `nemacsBuild`, which the package set carries:

```nix
{
  overrides = [
    (final: _prev: {
      my-package = final.nemacsBuild {
        pname = "my-package";
        version = "0.1";
        src = ./my-package;
        packageRequires = [ final.dash ];
      };
    })
  ];
  bundles.mine = {
    enable = true;
    packages = epkgs: [ epkgs.my-package ];
    init = "(require 'my-package)";
  };
}
```

## The built editor

`build.package` holds Emacs and every package the configuration needs.
Its `emacs` starts on an init directory in the store: `early-init.el`
holds `earlyInit`, and `init.el` requires `nemacs-init` once startup
has activated the packages. The init files of the user are not read.
`user-emacs-directory` is moved back to `$XDG_CONFIG_HOME/emacs/` (or
`~/.emacs.d/`) before anything else runs, so packages still keep their
state where they normally would. `emacs -q` starts with the packages
available and without the init.

When the Emacs in `package` has native compilation, the editor runs no
Lisp of its configuration from source and compiles nothing at run time:

- The packages come native-compiled from nixpkgs, as every package of
  the Emacs package set does.
- The init package, `early-init.el` and `init.el` are byte-compiled and
  native-compiled at build time.
- Package activation loads a quickstart file, which
  `package-quickstart-refresh` generates at build time from the editor's
  packages and which nemacs compiles, instead of each package's
  autoloads file.
- A trampoline is compiled at build time for every primitive. Emacs
  compiles one at run time the first time Lisp advises a primitive, and
  finds it instead. The trampolines depend on the Emacs alone, so they
  are built once per Emacs.

The wrapper puts the directories of these `.eln` files on
`EMACSNATIVELOADPATH`. What still loads as source are files of Emacs
itself, such as its character tables, and the `subdirs.el` files that
extend the load path.

## Use it

Without a framework, from any flake:

```nix
{
  inputs.nemacs.url = "github:clhodapp/nemacs";

  outputs = { nixpkgs, nemacs, ... }: {
    packages.x86_64-linux.default =
      (nemacs.lib.nemacs.evalNemacs {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        modules = [ ./emacs.nix ];
      }).config.build.package;
  };
}
```

`evalNemacs` returns the result of `lib.evalModules`, so `options`
documents every option the modules declare, and `config` holds the rest
of the configuration for a check to read.

In a Home Manager configuration, import `nemacs.modules.homeManager.nemacs`:

```nix
{
  programs.nemacs.enable = true;
  programs.nemacs.settings.imports = [ ./emacs.nix ];
}
```

`nemacs.modules.nixos.nemacs` is the same for a NixOS configuration. Either
way, `programs.nemacs.settings` is evaluated as nemacs modules on the
package set of the configuration around it, and its `build.package` is
installed while `enable` is set. The settings are evaluated whether or
not `enable` is set, so another module can read what they build.

A framework that evaluates nemacs modules itself imports
`nemacs.lib.nemacs.modules`, the core modules, and supplies `pkgs` as a
module argument, under the module class `nemacs`.

## Development

`nix flake check` builds a fixture configuration (`tests/fixture`),
starts it as a daemon and reads back what each of its options left in
the running editor, checks the order the init is joined in, and
evaluates the Home Manager and NixOS modules. `nix fmt` formats.

## License

MIT, see [`LICENSE`](LICENSE).
