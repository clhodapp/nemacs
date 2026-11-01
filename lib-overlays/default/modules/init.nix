# SPDX-License-Identifier: MIT
{ lib, ... }:
{
  options.init = lib.mkOption {
    type = lib.types.lines;
    default = "";
    description = ''
      The Elisp of the init. It is byte-compiled into the package
      `nemacs-init`, with warnings as errors, and loaded at startup once
      the packages are activated, where a user's `init.el` would load.

      The definitions are joined in priority order. An enabled bundle
      contributes its `init` at the priority its `order` names. A
      definition made here directly takes the default priority, 1000,
      unless it is wrapped in `lib.mkBefore`, `lib.mkAfter` or
      `lib.mkOrder`.
    '';
  };
}
