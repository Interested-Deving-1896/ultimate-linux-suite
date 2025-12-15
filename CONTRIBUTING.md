# Contributing to Ultimate Linux Suite

Thank you for your interest in contributing.

## Quick Start

```bash
git clone https://github.com/Nerds489/ultimate-linux-suite.git
cd ultimate-linux-suite
make test  # Verify syntax
```

## Development Setup

1. Fork and clone the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Make changes and test on at least one supported distribution
4. Run `make test` to verify shell syntax
5. Commit and push
6. Open a pull request

## Code Style

- Use `bash` shebang: `#!/usr/bin/env bash`
- Prevent multiple sourcing with guard variables
- Use `local` for function variables
- Quote all variable expansions: `"$var"` not `$var`
- Use `[[ ]]` for tests, not `[ ]`
- Add error handling for critical operations
- Log using `log_info`, `log_success`, `log_warn`, `log_error`

### Example Module Structure

```bash
#!/usr/bin/env bash
# mymodule.sh - Description

[[ -n "${_MYMODULE_LOADED:-}" ]] && return 0
readonly _MYMODULE_LOADED=1

mymodule_init() {
    log_debug "Module initialized"
}

mymodule_main() {
    # Module logic here
}
```

## Adding Features

### New Application

Add to `apps/database.sh`:

```
"appname|category|Description|apt-pkg|dnf-pkg|pacman-pkg|zypper-pkg|flatpak-id|check-cmd"
```

### New Module

1. Create `modules/modulename.sh`
2. Implement `modulename_init()` and `modulename_main()` functions
3. Source in `ultimate.sh`
4. Add menu entry in `menus/main_menu.sh`

### New Distribution

1. Create `backends/distroname.sh`
2. Implement package name mappings
3. Add detection in `lib/os_detect.sh`

## Security Guidelines

- Never use `eval` with user input
- Validate all inputs before use
- Use whitelists for system operations (sysctl keys, service names)
- Prefer safe helpers over raw shell commands
- Quote all variables to prevent word splitting

## Testing Checklist

Before submitting:

- [ ] `make test` passes (shellcheck)
- [ ] Tested on target distribution
- [ ] No hardcoded paths (use variables)
- [ ] Error handling for critical operations
- [ ] Logging for user visibility
- [ ] Queue integration for system changes

## Pull Request Process

1. Describe changes clearly
2. Reference any related issues
3. Include testing details (which distro, what was tested)
4. Wait for review

## Questions?

Open an issue at https://github.com/Nerds489/ultimate-linux-suite/issues
