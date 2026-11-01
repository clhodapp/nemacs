;;; nemacs-test-local.el --- A package kept beside a configuration -*- lexical-binding: t -*-
;; SPDX-License-Identifier: MIT

;;; Commentary:

;; Built by the nemacs checks with `nemacsBuild', requiring a package of
;; the package set.

;;; Code:

(require 'dash)

(defun nemacs-test-local-sum (numbers)
  "Return the sum of NUMBERS."
  (-sum numbers))

(provide 'nemacs-test-local)
;;; nemacs-test-local.el ends here
