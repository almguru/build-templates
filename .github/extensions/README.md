# Copilot Extensions

This directory contains Copilot extensions that enhance the development workflow for this repository.

## Branch Naming Validator

**File**: `branch-naming-validator.mjs`

A Copilot extension that validates branch names against the repository's naming conventions before pushing changes.

### Usage

The validator provides a single tool: `branch-naming-validator_check`

```bash
# Validate current branch (automatic if no branch name provided)
branch-naming-validator_check

# Validate a specific branch name
branch-naming-validator_check branch_name="features/my-feature"
```

### Valid Branch Patterns

The validator enforces the following naming conventions (from `.github/BRANCH_NAMING.md`):

- `features/<descriptive-name>` - Feature branches
- `bugfix/<descriptive-name>` - Bug fixes
- `hotfix/<descriptive-name>` - Production hotfixes
- `docs/<descriptive-name>` - Documentation updates
- `chore/<descriptive-name>` - Maintenance tasks
- `dependabot/<dependency-update>` - Automated dependency updates

All branch name parts must use kebab-case (lowercase letters, numbers, and hyphens).

### Invalid Examples

- ❌ `almguru/add-release-stage` - Custom prefix not allowed
- ❌ `features/addReleaseStage` - camelCase not allowed
- ❌ `feature/add-release-stage` - Wrong prefix (should be `features/`)

### Correct Examples

- ✅ `features/add-release-stage`
- ✅ `bugfix/fix-pipeline-timeout`
- ✅ `hotfix/security-patch`
- ✅ `docs/update-readme`

### Why This Matters

Enforcing branch naming conventions provides:

1. **Clarity** - Team members instantly understand the purpose of each branch
2. **Automation** - Workflows can be triggered based on branch patterns
3. **Organization** - Related branches are grouped together in git UI
4. **CI/CD Integration** - Branch names can drive pipeline decisions

### Installation

To use this extension in your Copilot workspace:

1. Copy the extension file to your Copilot extensions directory:
   ```bash
   cp .github/extensions/branch-naming-validator.mjs ~/.copilot/extensions/
   ```

2. Reload extensions in Copilot:
   ```
   extensions_reload
   ```

3. The validator is now available as `branch-naming-validator_check` tool

### Integration with Workflow

Before pushing a new branch:

```bash
# 1. Validate the branch name
branch-naming-validator_check

# 2. Push if valid
git push -u origin <branch-name>
```

If validation fails, use the suggested correction to rename your branch before pushing.

### For Developers

To extend or modify the validator:

1. Edit `branch-naming-validator.mjs`
2. Update the `ALLOWED_PATTERNS` array to add/modify allowed prefixes
3. Reload extensions: `extensions_reload`
4. Test against known good and bad branch names

---

**Convention Source**: See `.github/BRANCH_NAMING.md` for authoritative naming rules.
