# SPDX-License-Identifier: MIT
#
# The nemacs configuration the checks build: one of each thing a
# configuration can declare, each leaving a trace that
# tests/emacs/startup-probe.el reads back from a running editor.
{ lib, ... }:
{
  earlyInit = "(defvar nemacs-test-early-init t)";

  # A package kept beside the configuration, built with `nemacsBuild`
  # against a package of the set.
  overrides = [
    (final: _prev: {
      nemacs-test-local = final.nemacsBuild {
        pname = "nemacs-test-local";
        version = "0";
        src = ./local;
        packageRequires = [ final.dash ];
      };
    })
  ];

  bundles = {
    # Lower order than the default, so its init comes before the bundle
    # below although its name sorts after it.
    trace = {
      enable = true;
      order = 500;
      init = "(defvar nemacs-test-order nil)";
    };

    local = {
      enable = true;
      packages = epkgs: [ epkgs.nemacs-test-local ];
      init = ''
        (require 'nemacs-test-local)
        (defvar nemacs-test-sum (nemacs-test-local-sum '(1 2 3)))
        (push 'local nemacs-test-order)
      '';
    };

    # Disabled: neither its init nor its packages may reach the editor,
    # and its package function is never called.
    disabled = {
      init = ''(error "The disabled bundle's init ran")'';
      packages = _epkgs: throw "The disabled bundle's packages were read";
    };
  };

  init = lib.mkAfter "(push 'after nemacs-test-order)";
}
