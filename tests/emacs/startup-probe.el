;;; startup-probe.el --- Read back what the fixture configuration left -*- lexical-binding: t -*-
;; SPDX-License-Identifier: MIT

;;; Commentary:

;; Loaded into a daemon started from the editor built from
;; tests/fixture.  `nemacs-test-probe' returns "OK" when every trace the
;; fixture declares is present, and otherwise a string naming the first
;; one that is missing.

;;; Code:

(defun nemacs-test--source-loads ()
  "Files startup loaded as Lisp source that nemacs compiles ahead of time.
The data files of Emacs and the `subdirs.el' files that extend the load
path are loaded as source by Emacs and are not counted."
  (seq-filter (lambda (file)
                (and (stringp file)
                     (string-match-p "\\.el\\'" file)
                     (or (string-match-p "nemacs-startup" file)
                         (string-match-p "-autoloads\\.el\\'" file))))
              (mapcar #'car load-history)))

(defun nemacs-test--eln-cache-files ()
  "The `.eln' files Emacs compiled at run time into the user's eln-cache."
  (let ((cache (expand-file-name "eln-cache/" user-emacs-directory)))
    (and (file-directory-p cache)
         (directory-files-recursively cache "\\.eln\\'"))))

(defun nemacs-test--advise-primitive ()
  "Advise a primitive, which installs its trampoline, and return the advice."
  (let ((advice (lambda (f &rest args) (apply f args))))
    (advice-add 'upcase-initials :around advice)
    advice))

(defun nemacs-test-probe ()
  "Return \"OK\", or a description of the first missing trace."
  (cond
   ((not (bound-and-true-p nemacs-test-early-init))
    "FAIL: earlyInit did not run")
   ((nemacs-test--source-loads)
    (format "FAIL: startup loaded source: %S" (nemacs-test--source-loads)))
   ((not (bound-and-true-p package--quickstart-dir))
    "FAIL: package activation did not use the quickstart file")
   ((and (native-comp-available-p)
         (not (native-comp-function-p
               (symbol-function 'nemacs-test-early-function))))
    "FAIL: the early init ran without native code")
   ;; A package whose `.eln' Emacs cannot find runs byte code until the
   ;; JIT, in the background, replaces it, so byte code here means the
   ;; ahead-of-time `.eln' was missed.
   ((and (native-comp-available-p)
         (seq-remove (lambda (f) (native-comp-function-p (symbol-function f)))
                     '(-sum nemacs-test-local-sum)))
    (format "FAIL: packages ran without native code: %S"
            (seq-remove (lambda (f) (native-comp-function-p (symbol-function f)))
                        '(-sum nemacs-test-local-sum))))
   ((and (native-comp-available-p)
         (progn (nemacs-test--advise-primitive)
                (or (not (gethash 'upcase-initials comp-installed-trampolines-h))
                    (nemacs-test--eln-cache-files))))
    (format "FAIL: advising a primitive compiled at run time: %S"
            (nemacs-test--eln-cache-files)))
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
