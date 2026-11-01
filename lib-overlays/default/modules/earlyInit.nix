# SPDX-License-Identifier: MIT
{ lib, ... }:
{
  options.earlyInit = lib.mkOption {
    type = lib.types.lines;
    default = "";
    description = ''
      Elisp for `early-init.el`, which Emacs loads before the package
      system and the first frame. The built editor starts with
      `--init-directory` pointing at a store directory that holds this
      file. nemacs puts a form first that moves `user-emacs-directory`
      back to `$XDG_CONFIG_HOME/emacs/`, or to `~/.emacs.d/` when that
      variable is unset, so packages can still write their state.
    '';
  };
}
