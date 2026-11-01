;;; trampolines.el --- Compile subr trampolines ahead of time -*- lexical-binding: t -*-
;; SPDX-License-Identifier: MIT

;;; Commentary:

;; Usage: emacs --batch -l trampolines.el NATIVE-LISP-DIR SHARD SHARDS
;;
;; Advising or redefining a primitive makes Emacs install a trampoline,
;; a native-compiled stub that lets native callers reach the new
;; definition.  `comp-subr-trampoline-install' looks for an existing
;; trampoline along `native-comp-eln-load-path' and compiles one at run
;; time only when none is found.  This compiles a trampoline for every
;; primitive that function would accept, into the version directory
;; under NATIVE-LISP-DIR, so none is ever compiled at run time.  The
;; primitives are split into SHARDS groups by position, and this run
;; compiles group SHARD, so several runs can share the work.

;;; Code:

(require 'comp)

(let* ((native-lisp (pop command-line-args-left))
       (shard (string-to-number (pop command-line-args-left)))
       (shards (string-to-number (pop command-line-args-left)))
       (native-comp-enable-subr-trampolines
        (expand-file-name comp-native-version-dir native-lisp))
       (eligible nil))
  (mapatoms
   (lambda (sym)
     (when (fboundp sym)
       (let ((f (symbol-function sym)))
         ;; The conditions `comp-subr-trampoline-install' checks before
         ;; it compiles a trampoline.
         (when (and (subr-primitive-p f)
                    (not (special-form-p f))
                    (string= (symbol-name sym) (subr-name f))
                    (not (memq sym native-comp-never-optimize-functions)))
           (push sym eligible))))))
  (make-directory native-comp-enable-subr-trampolines t)
  (let ((index 0))
    (dolist (sym (sort eligible #'string<))
      (when (= (% index shards) shard)
        (unless (comp-trampoline-compile sym)
          (error "No trampoline compiled for `%s'" sym)))
      (setq index (1+ index)))))

;;; trampolines.el ends here
