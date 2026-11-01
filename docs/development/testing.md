# nemacs: testing

All checks run under `nix flake check` from the repository root. They
live in the `checks` partition of `configs/flake/nemacs/default.nix`,
whose extra inputs (Home Manager, nixpkgs for the NixOS evaluation,
treefmt-nix) are pinned by `tests/dependencies/flake.lock`.

| Check | What it proves |
|---|---|
| `nemacs` | The fixture configuration (`tests/fixture`) builds. |
| `nemacs-startup` | A daemon started from that editor ran `earlyInit`, moved `user-emacs-directory` out of the store, loaded `nemacs-init`, ran the bundles in order, and loaded the package built with `nemacsBuild`. Where native compilation is available, it also loaded no startup file or package autoloads from source, activated the packages through the quickstart file, ran the early init and the packages as native code, and installed a trampoline for an advised primitive without compiling one. `tests/emacs/startup-probe.el` reads each trace back. |
| `nemacs-init-order` | The init is joined by bundle order, then bundle name, with `lib.mkAfter` on `init` after every bundle and a disabled bundle absent. |
| `home-manager-module` | The Home Manager module installs the editor its settings build, and the home configuration builds. |
| `nixos-module` | The NixOS module installs the editor its settings build. |
| `treefmt` | The tree is formatted. |

The fixture's disabled bundle throws from its package function, so a
regression that reads the packages of a disabled bundle fails
evaluation.

The checks use `pkgs.emacs-nox`, which the NixOS binary cache carries
and which starts without a display.
