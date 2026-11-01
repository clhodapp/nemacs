;;; descriptor-probe.el --- Read the fixture's local package through package.el -*- lexical-binding: t -*-
;; SPDX-License-Identifier: MIT

;;; Commentary:

;; Run in batch with the editor built from tests/fixture, so no init
;; file loads and `package-initialize' reads every installed package's
;; descriptor the way package.el does without a quickstart file.  Exits
;; non-zero with a message naming the first mismatch.

;;; Code:

(require 'package)

(defun descriptor-probe--fail (format-string &rest args)
  "Print FORMAT-STRING with ARGS and exit with status 1."
  (message "FAIL: %s" (apply #'format format-string args))
  (kill-emacs 1))

(package-initialize)

(let* ((desc (cadr (assq 'nemacs-test-local package-alist)))
       (dash (cadr (assq 'dash package-alist))))
  (unless desc
    (descriptor-probe--fail "package.el does not know nemacs-test-local"))
  (unless (equal (package-desc-summary desc) "A package kept beside a configuration")
    (descriptor-probe--fail "summary is %S" (package-desc-summary desc)))
  (unless (equal (package-desc-version desc) '(0))
    (descriptor-probe--fail "version is %S" (package-desc-version desc)))
  ;; The Emacs requirement of the headers, then the supplied dependency
  ;; at the version it was built at; the unsupplied header entry is gone.
  (unless (equal (package-desc-reqs desc)
                 `((emacs (29 1)) (dash ,(package-desc-version dash))))
    (descriptor-probe--fail "requirements are %S" (package-desc-reqs desc)))
  (unless (equal (cdr (assq :keywords (package-desc-extras desc))) '("lisp"))
    (descriptor-probe--fail "extras are %S" (package-desc-extras desc)))
  (unless (memq 'nemacs-test-local package-activated-list)
    (descriptor-probe--fail "nemacs-test-local was not activated"))
  ;; The autoloads open with the form `package-generate-autoloads' gives
  ;; `loaddefs-generate', and nothing else before the scraped autoloads.
  (with-temp-buffer
    (insert-file-contents
     (expand-file-name "nemacs-test-local-autoloads.el" (package-desc-dir desc)))
    (goto-char (point-min))
    (re-search-forward "^;;; Code:\n+")
    (unless (equal (read (current-buffer))
                   '(add-to-list 'load-path
                                 (or (and load-file-name
                                          (directory-file-name
                                           (file-name-directory load-file-name)))
                                     (car load-path))))
      (descriptor-probe--fail "the autoloads open with another form"))
    ;; `loaddefs-generate' opens each section with a form feed.
    (skip-chars-forward "\n\f")
    (unless (looking-at-p ";;; Generated autoloads from nemacs-test-local\\.el")
      (descriptor-probe--fail "the autoloads hold more than package.el writes"))))

(message "OK")

;;; descriptor-probe.el ends here
