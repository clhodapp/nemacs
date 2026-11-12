;;; descriptor.el --- Write the -pkg.el of a nemacsBuild package -*- lexical-binding: t -*-
;; SPDX-License-Identifier: MIT

;;; Commentary:

;; Usage: emacs --batch -l descriptor.el PKG-DIR NAME VERSION [DEP-DIR...]
;;
;; Writes NAME-pkg.el into PKG-DIR with the writer of package.el, so the
;; package carries the descriptor package.el would have installed.  The
;; summary and the other metadata come from the library headers of
;; NAME.el when it has them; the summary falls back to the one on its
;; first line, then to "Local build of NAME".  The version is VERSION, the one the
;; package directory is named for.  The requirements are the packages
;; the build supplies, each DEP-DIR being the installed package
;; directory of one, with the version it was built at, plus the Emacs
;; version the headers require.  A requirement the build does not
;; supply would make `package-activate' refuse the package, so the
;; other `Package-Requires' entries of the headers are not copied.

;;; Code:

(require 'package)
(require 'lisp-mnt)

(let* ((dir (pop command-line-args-left))
       (name (pop command-line-args-left))
       (version (pop command-line-args-left))
       (dep-dirs command-line-args-left)
       (main (expand-file-name (concat name ".el") dir))
       (header (and (file-exists-p main)
                    (with-temp-buffer
                      (insert-file-contents main)
                      (ignore-errors (package-buffer-info)))))
       ;; `package-buffer-info' wants a Version header; a file without
       ;; one still names its summary on its first line.
       (summary (or (and header (package-desc-summary header))
                    (and (file-exists-p main)
                         (with-temp-buffer
                           (insert-file-contents main)
                           (lm-summary)))
                    (format "Local build of %s" name)))
       (emacs-req (assq 'emacs (and header (package-desc-reqs header))))
       (dep-reqs (delq nil
                       (mapcar (lambda (dep-dir)
                                 (when-let* ((desc (package-load-descriptor dep-dir)))
                                   (list (package-desc-name desc)
                                         (package-desc-version desc))))
                               dep-dirs)))
       (desc (package-desc-create
              :name (intern name)
              :version (version-to-list version)
              :summary summary
              :reqs (append (and emacs-req (list emacs-req)) dep-reqs)
              :kind 'single
              :extras (and header (package-desc-extras header)))))
  (package-generate-description-file
   desc (expand-file-name (concat name "-pkg.el") dir)))

;;; descriptor.el ends here
