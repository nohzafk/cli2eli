# cli2eli

Emacs package that dynamically generates interactive Emacs functions from JSON configuration files describing CLI tools.

## Quick Start

```elisp
;; Load a tool configuration
(cli2eli-load-tool "/path/to/tool-config.json")

;; Generated functions become available as interactive commands
;; M-x my-tool-command
```

## Project Structure

```
cli2eli.el           # Complete implementation (single file)
cli2eli-schema.json  # JSON Schema for configuration validation
README.md            # Documentation with usage examples
```

## Key Concepts

**Code Generation Pattern**: JSON configuration → Parse → Generate Emacs functions at runtime via `fset`

**Argument Types**: Supports `string`, `directory`, `current-file`, `choices`, and `dynamic-select` (runs shell command to generate options)

**Working Directory**: Resolves via `git-root`, `default`, or explicit paths. Special handling for Docker containers via TRAMP.

**Command Chaining**: `chain-call` executes commands sequentially; `chain-pass` passes output as arguments.

## Architecture

All logic lives in `cli2eli.el`:

1. **Entry Point**: `cli2eli-load-tool` - loads and parses JSON config
2. **Generator**: `cli2eli--generate-functions` - iterates commands, creates functions
3. **Command Builder**: `cli2eli--define-command` - builds interactive lambda with `fset`
4. **Interactive Specs**: `cli2eli--generate-interactive-spec` - creates completion systems using closures

## Naming Conventions

- Public functions: `cli2eli-*` (no dash prefix)
- Private functions: `cli2eli--*` (double dash)
- Generated function names: lowercase, non-alphanumeric replaced with hyphens

## State Variables

- `cli2eli--generated-functions` - registry of generated function symbols
- `cli2eli--current-tool` - current tool configuration alist

## Common Development Tasks

**Add new argument type**: Extend the `cond` in `cli2eli--generate-interactive-spec` (~line 220)

**Modify command execution**: Update `cli2eli--define-command` (~line 115)

**Add configuration options**: Update JSON schema in `cli2eli-schema.json`, then handle in parsing logic

## Terminal Backend

Configurable via `cli2eli-terminal-backend`:
- `'auto` (default) - auto-detect: eat > term
- `'eat` - use eat (recommended)
- `'term` - use term

## Dependencies

Required (core Emacs):
- `json`, `cl-lib`, `ansi-color`, `term`

Optional:
- `eat` - recommended terminal emulator (good performance, pure Emacs Lisp)
- `tramp` - for Docker/remote container support

## Testing

No automated tests. Verify changes manually:
1. Create a test JSON config based on README examples
2. Load with `cli2eli-load-tool`
3. Run generated commands and verify behavior

## Variable Replacement

Arguments support `$$` placeholders that reference other argument values:
```json
{"name": "container", "type": "string"},
{"name": "path", "prompt": "Path in $$container$$:"}
```