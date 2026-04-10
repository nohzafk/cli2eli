;;; cli2eli-test.el --- Tests for cli2eli -*- lexical-binding: t; -*-

;;; Commentary:
;; Run with: emacs --batch -l cli2eli.el -l test/cli2eli-test.el -f cli2eli-test-run

;;; Code:
(require 'cl-lib)

(defvar cli2eli-test--passed 0)
(defvar cli2eli-test--failed 0)
(defvar cli2eli-test--errors nil)

(defmacro cli2eli-test (name &rest body)
  "Define a test NAME that runs BODY and reports pass/fail."
  (declare (indent 1))
  `(condition-case err
       (progn ,@body
              (setq cli2eli-test--passed (1+ cli2eli-test--passed))
              (message "  PASS  %s" ,name))
     (error
      (setq cli2eli-test--failed (1+ cli2eli-test--failed))
      (push (cons ,name (error-message-string err)) cli2eli-test--errors)
      (message "  FAIL  %s: %s" ,name (error-message-string err)))))

;; ── Template Engine ────────────────────────────────────────────

(cli2eli-test "parse-template-vars: extracts vars in order"
  (let ((vars (cli2eli--parse-template-vars "just ${recipe} ${extra}")))
    (cl-assert (equal vars '("recipe" "extra")))))

(cli2eli-test "parse-template-vars: returns nil for no vars"
  (let ((vars (cli2eli--parse-template-vars "navi")))
    (cl-assert (null vars))))

(cli2eli-test "parse-template-vars: deduplicates"
  (let ((vars (cli2eli--parse-template-vars "${x} foo ${x} ${y}")))
    (cl-assert (equal vars '("x" "y")))))

(cli2eli-test "parse-template-vars: handles built-in var names"
  (let ((vars (cli2eli--parse-template-vars "glow ${file} --dir ${dir}")))
    (cl-assert (equal vars '("file" "dir")))))

(cli2eli-test "builtin-p: recognizes built-ins"
  (cl-assert (cli2eli--builtin-p "file"))
  (cl-assert (cli2eli--builtin-p "file-relative"))
  (cl-assert (cli2eli--builtin-p "dir")))

(cli2eli-test "builtin-p: rejects non-builtins"
  (cl-assert (not (cli2eli--builtin-p "recipe")))
  (cl-assert (not (cli2eli--builtin-p "args"))))

(cli2eli-test "expand-template: substitutes values"
  (let ((result (cli2eli--expand-template
                 "just ${recipe} ${extra}"
                 '(("recipe" . "test") ("extra" . "--verbose")))))
    (cl-assert (string= result "just test --verbose"))))

(cli2eli-test "expand-template: optional empty var removed"
  (let ((result (cli2eli--expand-template
                 "just ${recipe} ${extra}"
                 '(("recipe" . "test") ("extra" . ""))
                 '("extra"))))
    (cl-assert (string= result "just test"))))

(cli2eli-test "expand-template: non-optional empty var kept as empty"
  (let ((result (cli2eli--expand-template
                 "cmd ${a} ${b}"
                 '(("a" . "x") ("b" . "")))))
    (cl-assert (string= result "cmd x"))))

(cli2eli-test "expand-template: collapses multiple spaces"
  (let ((result (cli2eli--expand-template
                 "cmd ${a}  ${b}  ${c}"
                 '(("a" . "x") ("b" . "") ("c" . "z"))
                 '("b"))))
    (cl-assert (string= result "cmd x z"))))

(cli2eli-test "expand-template: literal replacement (no regex)"
  (let ((result (cli2eli--expand-template
                 "echo ${msg}"
                 '(("msg" . "hello\\nworld")))))
    (cl-assert (string= result "echo hello\\nworld"))))

;; ── Naming ─────────────────────────────────────────────────────

(cli2eli-test "sanitize-function-name: spaces to hyphens"
  (cl-assert (string= (cli2eli--sanitize-function-name "just pytest")
                       "just-pytest")))

(cli2eli-test "sanitize-function-name: lowercase"
  (cl-assert (string= (cli2eli--sanitize-function-name "MyTool")
                       "mytool")))

(cli2eli-test "sanitize-function-name: special chars to hyphens"
  (cl-assert (string= (cli2eli--sanitize-function-name "foo_bar.baz")
                       "foo-bar-baz")))

(cli2eli-test "generate-function-name: combines tool and command"
  (cl-assert (string= (cli2eli--generate-function-name "cli-quickrun" "just pytest")
                       "cli-quickrun-just-pytest")))

;; ── Value Conversion ───────────────────────────────────────────

(cli2eli-test "value-to-bool: falsy values"
  (cl-assert (not (cli2eli--value-to-bool nil)))
  (cl-assert (not (cli2eli--value-to-bool "")))
  (cl-assert (not (cli2eli--value-to-bool "false")))
  (cl-assert (not (cli2eli--value-to-bool json-false)))
  (cl-assert (not (cli2eli--value-to-bool 0))))

(cli2eli-test "value-to-bool: truthy values"
  (cl-assert (cli2eli--value-to-bool t))
  (cl-assert (cli2eli--value-to-bool "true"))
  (cl-assert (cli2eli--value-to-bool "hello"))
  (cl-assert (cli2eli--value-to-bool 1)))

;; ── JSON Loading ───────────────────────────────────────────────

(cli2eli-test "remove-comments-and-schema: strips comments"
  (let ((result (cli2eli--remove-comments-and-schema
                 "{\n  // comment\n  \"key\": \"value\"\n}")))
    (cl-assert (not (string-match-p "//" result)))
    (cl-assert (string-match-p "\"key\"" result))))

(cli2eli-test "remove-comments-and-schema: strips $schema"
  (let ((result (cli2eli--remove-comments-and-schema
                 "{\n  \"$schema\": \"http://example.com\",\n  \"key\": \"value\"\n}")))
    (cl-assert (not (string-match-p "\\$schema" result)))
    (cl-assert (string-match-p "\"key\"" result))))

(cli2eli-test "remove-comments-and-schema: fixes trailing commas"
  (let ((result (cli2eli--remove-comments-and-schema
                 "{\"a\": 1, }")))
    (cl-assert (not (string-match-p ",\\s-*}" result)))))

;; ── Function Generation (integration) ──────────────────────────

(cli2eli-test "load-tool: generates functions from test fixture"
  (let ((test-json (make-temp-file "cli2eli-test" nil ".json")))
    (unwind-protect
        (progn
          (with-temp-file test-json
            (insert "{
  \"tool\": \"test-tool\",
  \"commands\": [
    {\"name\": \"simple\", \"command\": \"echo hello\", \"description\": \"A simple test\"},
    {\"name\": \"with template\", \"command\": \"echo ${msg}\"},
    {\"name\": \"with builtin\", \"command\": \"cat ${file}\"},
    {\"name\": \"with stdin\", \"command\": \"sort\", \"stdin\": \"region\", \"output\": \"replace\"}
  ]
}"))
          (cli2eli-load-tool test-json)

          ;; All functions should exist
          (cl-assert (fboundp 'test-tool-simple))
          (cl-assert (fboundp 'test-tool-with-template))
          (cl-assert (fboundp 'test-tool-with-builtin))
          (cl-assert (fboundp 'test-tool-with-stdin))

          ;; Docstring preserved
          (cl-assert (string= (documentation 'test-tool-simple) "A simple test"))

          ;; Clean up generated functions
          (dolist (sym '(test-tool-simple test-tool-with-template
                         test-tool-with-builtin test-tool-with-stdin))
            (fmakunbound sym)))
      (delete-file test-json))))

(cli2eli-test "load-tool: replaces functions on reload"
  (let ((test-json (make-temp-file "cli2eli-test" nil ".json")))
    (unwind-protect
        (progn
          ;; First load
          (with-temp-file test-json
            (insert "{\"tool\": \"reload-test\", \"commands\": [
              {\"name\": \"cmd\", \"command\": \"echo v1\", \"description\": \"version 1\"}]}"))
          (cli2eli-load-tool test-json)
          (cl-assert (string= (documentation 'reload-test-cmd) "version 1"))

          ;; Second load with updated description
          (with-temp-file test-json
            (insert "{\"tool\": \"reload-test\", \"commands\": [
              {\"name\": \"cmd\", \"command\": \"echo v2\", \"description\": \"version 2\"}]}"))
          (cli2eli-load-tool test-json)
          (cl-assert (string= (documentation 'reload-test-cmd) "version 2"))

          (fmakunbound 'reload-test-cmd))
      (delete-file test-json))))

(cli2eli-test "remove-generated-functions: cleans up all"
  (let ((test-json (make-temp-file "cli2eli-test" nil ".json"))
        (saved-funcs cli2eli--generated-functions))
    (unwind-protect
        (progn
          (with-temp-file test-json
            (insert "{\"tool\": \"cleanup-test\", \"commands\": [
              {\"name\": \"a\", \"command\": \"echo a\"},
              {\"name\": \"b\", \"command\": \"echo b\"}]}"))
          (cli2eli-load-tool test-json)
          (cl-assert (fboundp 'cleanup-test-a))
          (cl-assert (fboundp 'cleanup-test-b))

          (cli2eli-remove-generated-functions)
          (cl-assert (not (fboundp 'cleanup-test-a)))
          (cl-assert (not (fboundp 'cleanup-test-b)))
          (cl-assert (null cli2eli--generated-functions)))
      (delete-file test-json)
      (setq cli2eli--generated-functions saved-funcs))))

;; ── Test Runner ────────────────────────────────────────────────

(defun cli2eli-test-run ()
  "Print test summary and exit with appropriate code."
  (message "\n══════════════════════════════════════")
  (message " %d passed, %d failed" cli2eli-test--passed cli2eli-test--failed)
  (when cli2eli-test--errors
    (message "")
    (dolist (err (nreverse cli2eli-test--errors))
      (message " FAIL %s: %s" (car err) (cdr err))))
  (message "══════════════════════════════════════")
  (kill-emacs (if (> cli2eli-test--failed 0) 1 0)))

;;; cli2eli-test.el ends here
