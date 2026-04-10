# cli2eli

Emacs package that dynamically generates interactive Emacs functions from JSON configuration files describing CLI tools.

## Quick Start

```elisp
(cli2eli-load-tool "/path/to/tool-config.json")
;; Generated functions become available as M-x <tool>-<command>
```

## Project Structure

```
cli2eli.el           # Complete implementation (single file)
cli2eli-schema.json  # JSON Schema for configuration validation
README.md            # Documentation with usage examples
```

## Key Concepts

**Command Templates**: Commands use `${var}` placeholders resolved from built-in variables or declared user inputs. Example: `"command": "just ${recipe} ${extra}"`

**Built-in Variables**: `${file}`, `${file-relative}`, `${dir}` are auto-resolved from Emacs context without needing input declarations.

**Input Types**: `prompt` (free text), `choice` (static list), `shell` (dynamic from command output), `directory` (Emacs picker). Undeclared template vars default to prompt.

**Output Modes**: `terminal` (eat/term, default), `buffer` (read-only display), `replace` (in-place text replacement for stdin commands).

**Working Directory**: Resolves via `git-root`, `default`, or explicit paths. Special handling for Docker containers via TRAMP.

## Architecture

All logic lives in `cli2eli.el`:

1. **Entry Point**: `cli2eli-load-tool` - loads and parses JSON config
2. **Template Engine**: `cli2eli--parse-template-vars`, `cli2eli--expand-template` - extract `${var}` placeholders and substitute values
3. **Input Handling**: `cli2eli--generate-interactive-spec`, `cli2eli--input-form` - generate Emacs interactive specs from input declarations
4. **Command Builder**: `cli2eli--define-command` - builds interactive lambda with `fset`, wiring template expansion to the appropriate execution mode
5. **Execution**: `cli2eli--run-command` (terminal), `cli2eli--run-command-to-buffer` (buffer), `cli2eli--run-command-with-stdin` (stdin+buffer), `cli2eli--run-command-replace` (stdin+replace)

## Naming Conventions

- Public functions: `cli2eli-*` (single dash)
- Private functions: `cli2eli--*` (double dash)
- Generated function names: lowercase, non-alphanumeric replaced with hyphens

## State Variables

- `cli2eli--generated-functions` - registry of generated function symbols
- `cli2eli--current-tool` - current tool configuration alist

## Common Development Tasks

**Add new input type**: Extend the `cond` in `cli2eli--input-form`

**Add new output mode**: Add a case in `cli2eli--define-command`'s output dispatch, implement the execution function

**Add new built-in variable**: Add to `cli2eli--builtin-vars` and `cli2eli--resolve-builtin`

**Add configuration options**: Update JSON schema in `cli2eli-schema.json`, then handle in parsing logic

## Terminal Backend

Configurable via `cli2eli-terminal-backend`:
- `'auto` (default) - auto-detect: eat > term
- `'eat` - use eat (recommended)
- `'term` - use term

## Dependencies

Required (core Emacs):
- `json`, `cl-lib`, `term`

Optional:
- `eat` - recommended terminal emulator (good performance, pure Emacs Lisp)
- `tramp` - for Docker/remote container support

## Testing

No automated tests. Verify changes manually:
1. Create a test JSON config based on README examples
2. Load with `cli2eli-load-tool`
3. Run generated commands and verify behavior
