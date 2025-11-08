# Shared golangci-lint Configurations

This directory contains shared golangci-lint configurations for all Go projects in the ecommerce monorepo.

## Available Configurations

### 📦 base.yml
**For:** All Go projects
**Contains:** Essential linters that every project should use
- Correctness checks (govet, errcheck, staticcheck)
- Code quality (unused, gosimple, ineffassign)
- Best practices (errname, errorlint, nilnil, nilerr)
- Performance (prealloc, bodyclose)
- Security (gosec)
- Style (revive, stylecheck)

### 🎯 service.yml
**For:** Microservices (product-service, category-service, etc.)
**Extends:** base.yml
**Adds:**
- `exhaustive` - Ensures all switch cases are handled (important for event-driven services)
- Additional exclusions for HTTP handlers

**Use when:**
- Building event-driven microservices
- Using sealed interfaces (like `events.Event`)
- Need exhaustiveness checking for domain events

### 📚 library.yml (to be created)
**For:** Shared libraries (ecommerce-commons)
**Stricter than services:**
- Documentation requirements (godot)
- Export naming conventions
- More strict style checks

## Usage

Since golangci-lint doesn't support remote config extends yet, each project has a local `.golangci.yml` file.

### For Services

Copy this to your service (product-service, category-service, etc.):

```yaml
# .golangci.yml
# This configuration is based on ecommerce-infrastructure/configs/golangci/service.yml
# To update: copy the latest version from infrastructure repo

linters:
  enable:
    - exhaustive
    - govet
    - errcheck
    # ... see service.yml for full list

linters-settings:
  exhaustive:
    explicit-exhaustive-switch: true  # For sealed Event interfaces
  # ... see service.yml for full settings
```

### For Commons Library

Copy from `base.yml` with stricter documentation requirements.

## Updating Configurations

### Option 1: Manual Copy (Current)

```bash
# Update a specific service
cd ecommerce-product-service
cp ../ecommerce-infrastructure/configs/golangci/service.yml .golangci.yml

# Update all services
for dir in ecommerce-*-service; do
  cp ecommerce-infrastructure/configs/golangci/service.yml "$dir/.golangci.yml"
done
```

### Option 2: Makefile Command (Recommended)

Add to each service's Makefile:

```makefile
.PHONY: update-lint-config
update-lint-config:
	curl -sSL https://raw.githubusercontent.com/Sokol111/ecommerce-infrastructure/master/configs/golangci/service.yml -o .golangci.yml
```

### Option 3: CI/CD Check (Future)

Add a GitHub Action to verify configs are in sync:

```yaml
- name: Check lint config is up to date
  run: |
    diff .golangci.yml ../ecommerce-infrastructure/configs/golangci/service.yml
```

## Linter Categories

### 🔴 Critical (Always Enabled)
- `govet` - Official Go analyzer
- `errcheck` - Unchecked errors
- `staticcheck` - Advanced static analysis

### 🟡 Recommended (Enabled by Default)
- `gosimple` - Code simplifications
- `unused` - Unused code
- `gosec` - Security issues

### 🟢 Optional (Enable as Needed)
- `exhaustive` - For event-driven services
- `godot` - For public libraries
- `nolintlint` - Enforce lint directives have reasons

## Project-Specific Overrides

Each project can add specific exclusions in their `.golangci.yml`:

```yaml
issues:
  exclude-rules:
    # Project-specific exclusion
    - path: internal/legacy/
      linters:
        - all
      text: "legacy code, will be refactored"
```

## Running Linters

```bash
# Run linter
make lint

# Or directly
golangci-lint run

# With auto-fix
golangci-lint run --fix
```

## Common Issues

### "context deadline exceeded"
Increase timeout in `run.timeout` section.

### "too many issues"
Either fix issues or add exclusions (carefully!).

### "linter not found"
Install golangci-lint: `go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest`

## Links

- [golangci-lint docs](https://golangci-lint.run/)
- [Available linters](https://golangci-lint.run/usage/linters/)
- [Configuration reference](https://golangci-lint.run/usage/configuration/)
