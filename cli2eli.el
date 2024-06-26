;;; cli2eli.el --- CLI to Emacs Lauch Interface Generator -*- lexical-binding: t; -*-

;; Author: nohzafk
;; Version: 0.1
;; Package-Requires: ((emacs "26.1"))
;; Keywords: tools, convenience
;; URL: https://github.com/nohzafk/cli2eli

;;; Commentary:

;; CLI2ELI (Command Line Interface to Emacs Lauch Interface) is a package
;; that generates Emacs Lisp functions from JSON configuration files
;; describing CLI tools.
;;
;; It allows users to interact with command-line tools directly from within
;; Emacs, providing a seamless integration between Emacs and various CLI
;; utilities.

;;; Code:
(require 'ansi-color)
(require 'cl-lib)
(require 'json)

(defgroup cli2eli nil
  "Command line interface to Emacs Lauch interface."
  :group 'eamcs)


(defcustom cli2eli-output-buffer-name "*CLI2ELI Output*"
  "Buffer name for dedicated buffer."
  :group 'cli2eli
  :type 'string)

(define-derived-mode cli2eli--output-mode special-mode "CLI2ELI"
  "Major mode for displaying CLI2ELI output."
  (buffer-disable-undo)
  (setq-local truncate-lines t)
  (setq-local word-wrap nil))

(defun cli2eli--insert-output (output)
  "Insert OUTPUT into the current buffer with some formatting."
  (let ((inhibit-read-only t))
    (erase-buffer)
    (insert (ansi-color-apply output))
    (goto-char (point-min))))

(defun cli2eli--remove-comments (json-string)
  "Remove JSON5-style comments from JSON-STRING."
  (with-temp-buffer
    (insert json-string)
    (goto-char (point-min))
    (while (re-search-forward "//.*$" nil t)
      (replace-match ""))
    (buffer-string)))

(defvar cli2eli--current-tool nil
  "Store the current tool configuration.")

(defun cli2eli-load-tool (json-file &optional relative-p)
  "Load a CLI tool configuration from JSON-FILE.
If RELATIVE-P is non-nil, treat JSON-FILE as relative to the package directory."
  (interactive "fSelect JSON configuration file: ")
  (let* ((file-path (if relative-p
                        (expand-file-name json-file (file-name-directory (locate-library "cli2eli")))
                      (expand-file-name json-file)))
         (json-object-type 'alist)
         (json-array-type 'vector)
         (json-key-type 'symbol)
         (json-string (with-temp-buffer
                        (insert-file-contents file-path)
                        (buffer-string)))
         (cleaned-json-string (cli2eli--remove-comments json-string)))
    (setq cli2eli--current-tool (json-read-from-string cleaned-json-string))
    (cli2eli--generate-functions cli2eli--current-tool)))

(defun cli2eli--generate-functions (tool)
  "Generate Emacs functions for the CLI TOOL.
TOOL is an alist containing the tool configuration."
  (let* ((tool-name (alist-get 'tool tool))
         (commands-vector (alist-get 'commands tool))
         (commands (append commands-vector nil)))  ; Convert vector to list
    (message "[CLI2ELI] Generating emacs functions for tool: %S" tool-name)
    (dolist (cmd commands)
      (let ((cmd-name (alist-get 'name cmd))
            (cmd-desc (alist-get 'description cmd))
            (args (append (alist-get 'arguments cmd) nil)) ; Convert arguments vector to list
            (cmd-extra-arguments (alist-get 'extra_arguments cmd)))
        (cli2eli--define-command tool-name cmd-name cmd-desc cmd-extra-arguments args)))))

(defun cli2eli--define-command (tool-name cmd-name cmd-desc cmd-extra-arguments args)
  "Define an Emacs function for a CLI command.
TOOL-NAME is the name of the CLI tool.
CMD-NAME is the name of the specific command.
CMD-DESC is the description of the command.
ARGS is a list of argument specifications."
  (let* ((func-name (intern (concat tool-name "-" cmd-name)))
         (interactive-spec (cli2eli--generate-interactive-spec args cmd-extra-arguments)))
    (message "[CLI2ELI] Generating function: %s" func-name)
    (fset func-name
          `(lambda (&rest arg-values)
             ,(concat "Run " tool-name " " cmd-name " command. " cmd-desc)
             (interactive ,interactive-spec)
             (let* ((required-args
                     (cl-subseq arg-values 0 ,(length args)))
                    (additional-args
                     ,(if cmd-extra-arguments
                          `(nth ,(length args) arg-values)
                        nil))
                    (processed-args
                     (string-trim
                      (concat
                       (mapconcat
                        #'identity
                        (cl-remove-if
                         #'string-empty-p
                         (cl-mapcar
                          (lambda (arg arg-value)
                            (let ((arg-name (alist-get 'name arg)))
                              (if (or (not arg-value) (string-empty-p arg-value))
                                  ""
                                (if (string-match-p "\\$\\$" arg-name)
                                    (replace-regexp-in-string "\\$\\$" arg-value arg-name)
                                  (format "%s %s" arg-name arg-value)))))
                          ',args
                          required-args))
                        " ")
                       " "
                       additional-args))))
               (cli2eli--run-command ,tool-name ,cmd-name processed-args))))
    (message "[CLI2ELI] Generation Done.")))

(defun cli2eli--generate-interactive-spec (args cmd-extra-arguments)
  "Generate the interactive specification for command arguments.
ARGS is a list of argument specifications.
CMD-EXTRA-ARGUMENTS is a boolean indicating whether extra arguments are needed."
  `(list
    ,@(mapcar
       (lambda (arg)
         (let* ((arg-name (alist-get 'name arg))
                (arg-desc (replace-regexp-in-string "\n" " " (alist-get 'description arg)))
                (arg-type (alist-get 'type arg))
                (choices (alist-get 'choices arg)))
           (cond
            ((string= arg-type "directory")
             `(directory-file-name
               (file-truename
                (expand-file-name
                 (read-directory-name ,(format "%s (%s): " arg-name arg-desc))))))
            (choices
             `(let ((completion-ignore-case t)
                    (choices (mapcar (lambda (choice)
                                       (cond
                                        ((eq choice t) "true")
                                        ((eq choice json-false) "false")
                                        (t (format "%s" choice))))
                                     ',choices)))
                (completing-read ,(format "%s (%s): " arg-name arg-desc)
                                 choices
                                 nil t)))
            (t
             `(read-string ,(format "%s (%s): " arg-name arg-desc))))))
       args)
    ,@(when cmd-extra-arguments
        '((read-string "Extra arguments: ")))))

(defun cli2eli--get-working-directory ()
  "Get the working directory based on the tool configuration."
  (let ((cwd (alist-get 'cwd cli2eli--current-tool)))
    (cond
     ((null cwd) default-directory)
     ((string= cwd "") default-directory)
     ((string= cwd "default") default-directory)
     ((string= cwd "git-root") (or (locate-dominating-file "." ".git") default-directory))
     (t (expand-file-name cwd)))))

(defun cli2eli--run-command (tool-name cmd-name &optional args)
  "Run a CLI command asynchronously and display output in a dedicated buffer.
TOOL-NAME is the name of the CLI tool.
CMD-NAME is the name of the specific command.
ARGS is an optional string of additional arguments."
  (message "[CLI2ELI] Running command with tool-name: %S, cmd-name: %S, args: %S" tool-name cmd-name args)
  (let* ((output-buffer (get-buffer-create cli2eli-output-buffer-name))
         (args (or args ""))
         (command (format "%s %s %s" tool-name cmd-name args))
         (cwd (cli2eli--get-working-directory)))
    (with-current-buffer output-buffer
      (cli2eli--output-mode)
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (format "Working Directory: %s\nRunning: %s\n\n" cwd command))))

    (display-buffer output-buffer '(display-buffer-at-bottom . ((window-height . 0.3))))
    (make-process
     :name "cli2eli-process"
     :buffer output-buffer
     :command (split-string command)
     :directory cwd
     :filter (lambda (proc string)
               (when (buffer-live-p (process-buffer proc))
                 (with-current-buffer (process-buffer proc)
                   (let ((inhibit-read-only t)
                         (window (get-buffer-window (current-buffer) t)))
                     (save-excursion
                       (goto-char (point-max))
                       (insert (ansi-color-apply (replace-regexp-in-string "\r" "" string))))
                     (when window
                       (with-selected-window window
                         (goto-char (point-max))
                         (recenter -1)))))))
     :sentinel (lambda (process event)
                 (when (string= event "finished\n")
                   (with-current-buffer (process-buffer process)
                     (let ((inhibit-read-only t)
                           (window (get-buffer-window (current-buffer) t)))
                       (goto-char (point-max))
                       (insert "\nProcess finished")
                       (when window
                         (with-selected-window window
                           (goto-char (point-max))
                           (recenter -1)))
                       (message "[CLI2ELI] Command finished."))))))))


(provide 'cli2eli)

;;; cli2eli.el ends here
