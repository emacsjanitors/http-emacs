;;; simple-wiki-edit.el --- edit wiki pages in raw mode

;; Copyright (C) 2002, 2003 Alex Schroeder

;; Author: Alex Schroeder <alex@gnu.org>
;; Maintainer: Pierre Gaston <pierre@gaston-karlaouzou.com>
;; Version: 1.0.8
;; Keywords: hypermedia
;; URL: http://www.emacswiki.org/cgi-bin/wiki.pl?SimpleWikiEditMode

;; This file is not part of GNU Emacs.

;; This is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; This is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;;; Commentary:

;; Use `simple-wiki-edit' to browse and edit a raw wiki page.  Usually
;; you need a save function as well, so `simple-wiki-edit' is not used
;; interactively.  See the wiki page for examples.

;; If your auto-fill-mode is usually on, you might want to turn it off
;; Also consider using longlines.el
;; (add-hook 'simple-wiki-edit-mode-hook 'turn-off-auto-fill)
;; (add-hook 'simple-wiki-edit-mode-hook 'longlines-mode-on)
;; (add-hook 'simple-wiki-save-before-hooks 'longlines-mode-off)

;; using pcomplete within the page:
;;  (add-hook 'simple-wiki-edit-mode-hooks  'pcomplete-simple-wiki-setup)
;; and thereafter, use  C-/ to pcomplete pages at point and M-/ for
;; dabbrev-completion
;; Consider also (setq pcomplete-ignore-case t)

;;; ChaneLog:

;; 1.0.9
;;   - Added "Connection: close" header to http-get call for HTTP/1.1.
;;   - `simple-wiki-edit-mode' now is called when the http-get process
;;     finished.  There is no need for `simple-wiki-delayed-longlines-mode-on'
;;     anymore.  Call `longlines-mode-on' in `simple-wiki-edit-mode-hook'.
;;   - Removed `simple-wiki-fill-columns'
;;   - Moved custom variables to group simple-wiki.
;; 1.0.8
;;   - Removed all referenced to simple-wiki-edit-mode-hooks and replaced
;;     them with simple-wiki-edit-mode-hook.
;; 1.0.7
;;   - Added simple-wiki-content-type.
;; 1.0.6
;;   - Added simple-wiki-http-version 1.1.
 
;;; Code:

(require 'thingatpt)
(require 'http-get)
(require 'simple-wiki)

(defvar simple-wiki-edit-version "1.0.9")

(defvar simple-wiki-url nil
  "The URL of the current buffer.")

(defvar simple-wiki-time nil
  "Time the request for the current buffer was sent.")

(defvar simple-wiki-save-function nil
  "The function to use to save the current buffer.")

(defvar simple-wiki-http-version nil
  "The HTTP version of the WiKi of the current buffer.")

(defvar simple-wiki-content-type nil
  "The content type of the WiKi of the current buffer.")

(defcustom simple-wiki-minor-p nil
  "Whether to label changes as minor.  This can be changed by
pressing C-c C-t during edits."
  :group 'simple-wiki)

(make-variable-buffer-local 'simple-wiki-minor-p)

(defcustom simple-wiki-edit-mode-hook nil
  "Hook run when entering Wiki-Edit mode."
  :group 'simple-wiki)

(defcustom simple-wiki-save-before-hooks nil ""
  :group 'simple-wiki)

(defun simple-wiki-minor-value ()
  (if simple-wiki-minor-p "on" "off"))


(add-to-list 'minor-mode-alist
	     '(simple-wiki-minor-p " [MINOR]"))


(define-derived-mode simple-wiki-edit-mode simple-wiki-mode "Wiki-Edit"
  "Edit URL using `simple-wiki-mode'.

\\{simple-wiki-edit-mode-map}"
  (make-local-variable 'simple-wiki-url)
  (make-local-variable 'simple-wiki-time)
  (make-local-variable 'simple-wiki-save-function))


(define-key simple-wiki-edit-mode-map (kbd "C-c C-c") 'simple-wiki-save)
(define-key simple-wiki-edit-mode-map (kbd "C-c C-o") 'simple-wiki-open)
(define-key simple-wiki-edit-mode-map (kbd "C-c C-g") 'simple-wiki-follow)
(define-key simple-wiki-edit-mode-map (kbd "C-c C-m")
  'simple-wiki-minor-toggle)
(define-key simple-wiki-edit-mode-map (kbd "C-c C-n") 'simple-wiki-next)
(define-key simple-wiki-edit-mode-map (kbd "C-c C-p") 'simple-wiki-prev)
(define-key simple-wiki-edit-mode-map (kbd "C-/") 'pcomplete)
(define-key simple-wiki-edit-mode-map (kbd "C-c C-/") 'pcomplete)
(define-key simple-wiki-edit-mode-map (kbd "C-c C-_") 'pcomplete)
(define-key simple-wiki-edit-mode-map (kbd "C-c TAB") 'pcomplete)


(defun simple-wiki-minor-toggle (&optional arg)
  (interactive)
  (let ((num (prefix-numeric-value arg)))
    (cond
     ((or (not arg) (equal num 0))
      (setq simple-wiki-minor-p (not simple-wiki-minor-p)))
     ((> num 0) (set 'simple-wiki-minor-p t))
     ((< num 0) (set 'simple-wiki-minor-p nil)))
    (message "simple-wiki-minor-p set to %S" simple-wiki-minor-p)
    simple-wiki-minor-p))

(defun simple-wiki-next ()
  "Goto the next WikiName."
  (interactive)
  (let ((case-fold-search nil))
    (re-search-forward
     simple-wiki-link-pattern
     nil t)))

(defun simple-wiki-prev ()
  "Goto the previous WikiName."
  (interactive)
  (let ((case-fold-search nil))
    (re-search-backward
     simple-wiki-link-pattern
     nil t)))

(defun simple-wiki-edit-sentinel (proc message)
  "Sentinel for the http-get process."

  (switch-to-buffer (process-buffer proc))
  ;; local variables get destroyed when running
  ;; `simple-siki-edit-mode'.  Setting the globals
  ;; works around this problem.
  (setq-default simple-wiki-url simple-wiki-url)
  (setq-default simple-wiki-time simple-wiki-time)
  (setq-default simple-wiki-save-function simple-wiki-save-function)
  (setq-default simple-wiki-http-version simple-wiki-http-version)
  (setq-default simple-wiki-content-type simple-wiki-content-type)

  (simple-wiki-edit-mode))

;;;###autoload
(defun simple-wiki-edit (url &optional save-func bufname
                             http-version content-type)
  "Edit URL using `simple-wiki-edit-mode'.
Optional SAVE-FUNC is a function to use when saving."
  (let ((headers) (proc))
    (when (and http-version (= http-version 1.1))
      (setq headers '(("Connection" . "close"))))
    (unless content-type
      (setq content-type 'iso-8859-1))
    (setq proc (http-get url headers 'simple-wiki-edit-sentinel
                         http-version bufname content-type))
    (with-current-buffer (process-buffer proc)
      ;; don't set the default values heres as another call to
      ;; `simple-wiki-edit' might happen before we got the full
      ;; page (OK, very unlikely but not impossible).  These (and
      ;; setting the globals again in the sentinel) looks a bit
      ;; fishy but i don't have a better idea.
      (set (make-local-variable 'simple-wiki-url) url)
      (set (make-local-variable 'simple-wiki-time) (current-time))
      (set (make-local-variable 'simple-wiki-http-version) http-version)
      (set (make-local-variable 'simple-wiki-content-type) content-type)
      (set (make-local-variable 'simple-wiki-save-function) save-func))))

(defun simple-wiki-follow ()
  "Follow the WikiName at point."
  (interactive)
  (let ((page (word-at-point))
	(case-fold-search nil))
    (if (and page
	     (string-match
	      simple-wiki-link-pattern
	      page))
	(simple-wiki-edit (simple-wiki-link page) simple-wiki-save-function)
      (error "No WikiName at point"))))

(defun simple-wiki-link (page)
  "Return a new URL for PAGE.
This takes `simple-wiki-url' and replaces everything after the
last equal sign with PAGE."
  (if (string-match "^.*=" simple-wiki-url)
      (concat (match-string 0 simple-wiki-url) page)
    (error "Cannot determine current page name in %s"
	   simple-wiki-url)))

(defun simple-wiki-page ()
  "Return the page name for the current buffer.
This takes `simple-wiki-url' and returns everything after the
last equal sign."
  (if (string-match "^.*=\\(.*\\)" simple-wiki-url)
      (match-string 1 simple-wiki-url)
    (error "Cannot determine current page name in %s"
	   simple-wiki-url)))

(defun simple-wiki-save-link ()
  "Return a new URL to save the current buffer.
This takes `simple-wiki-url' and returns everything up
to the first \"?\"."
  (unless simple-wiki-url
    (error "Current buffer is not associated with an URL"))
  (if (string-match "^\\(.*?\\)\\?" simple-wiki-url)
      (match-string 1 simple-wiki-url)
    (error "Cannot determine current script name in %s"
	   simple-wiki-url)))

(defun simple-wiki-open (page)
  "Open a new page on the same wiki."
  (interactive "sPage: ")
  (simple-wiki-edit (simple-wiki-link page) simple-wiki-save-function))

(defun simple-wiki-save ()
  "Save the current buffer to the wiki."
  (interactive)
  (run-hooks 'simple-wiki-save-before-hooks)
  (unless simple-wiki-save-function
    (error "No save function specified"))
  (save-excursion
    (funcall simple-wiki-save-function)))

;; remove this
(defun simple-wiki-delayed-longlines-mode-on ()
  "Braindead and obsolete function.
Use (add-hook 'simple-wiki-edit-mode-hook 'longlines-mode-on) instead."
  (require 'longlines)
  (let ((buf (current-buffer)))
    (run-with-idle-timer 1 nil
			 (lambda ()
			   (save-excursion
			     (set-buffer buf)
			     (longlines-mode-on))))))

(defun pcomplete-simple-wiki-setup ()
  (set (make-local-variable 'pcomplete-parse-arguments-function)
   'pcomplete-parse-simple-wiki-arguments)
  (set (make-local-variable 'pcomplete-default-completion-function)
       'pcomplete-simple-wiki-default-completion))

(defun pcomplete-parse-simple-wiki-arguments ()
  (save-excursion
    (let* ((thispt (point))
	   (pt (search-backward-regexp "[ \t\n]" nil t))
	   (ptt (if pt (+ pt 1) thispt)))

      (list
       (list "dummy" (buffer-substring-no-properties ptt thispt))
       (point-min) ptt))))

(defun pcomplete-simple-wiki-default-completion ()
  (pcomplete-here swc-pages-completion))

(provide 'simple-wiki-edit)

;;; simple-wiki-edit.el ends here
