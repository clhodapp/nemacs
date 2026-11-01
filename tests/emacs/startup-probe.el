;;; startup-probe.el --- Read back what the fixture configuration left -*- lexical-binding: t -*-
;; SPDX-License-Identifier: MIT

;;; Commentary:

;; Loaded into a daemon started from the editor built from
;; tests/fixture.  `nemacs-test-probe' returns "OK" when every trace the
;; fixture declares is present, and otherwise a string naming the first
;; one that is missing.

;;; Code:

(defun nemacs-test-probe ()
  "Return \"OK\", or a description of the first missing trace."
  (cond
   ((not (bound-and-true-p nemacs-test-early-init))
    "FAIL: earlyInit did not run")
   ((string-prefix-p "/nix/store/" user-emacs-directory)
    (format "FAIL: user-emacs-directory is still in the store: %s" user-emacs-directory))
   ((not (featurep 'nemacs-init))
    "FAIL: nemacs-init was not loaded during startup")
   ((not (equal (bound-and-true-p nemacs-test-order) '(after local)))
    (format "FAIL: init ran in the wrong order: %S" (bound-and-true-p nemacs-test-order)))
   ((not (equal (bound-and-true-p nemacs-test-sum) 6))
    (format "FAIL: the local package did not compute: %S" (bound-and-true-p nemacs-test-sum)))
   (t "OK")))

;;; startup-probe.el ends here
