# SPDX-License-Identifier: MIT
#
# Evaluates a nemacs configuration: the core module, the package set
# the editor is built from, and the caller's modules. The result is the
# `evalModules` result, so `config.build.package` is the editor and
# `options` documents every option the modules declare.
{ lib, core }:
{
  pkgs,
  modules ? [ ],
}:
lib.evalModules {
  class = "nemacs";
  modules = [
    core
    {
      key = "nemacs.evalNemacs.pkgs";
      _module.args.pkgs = pkgs;
    }
  ]
  ++ modules;
}
