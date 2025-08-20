# Branch Naming Convention

This repository follows a structured branch naming convention to maintain consistency and clarity.

## Branch Naming Format

All feature branches should follow this format:
```
features/<descriptive-name>
```

### Examples
- `features/add-user-authentication`
- `features/update-deployment-pipeline`
- `features/fix-bicep-template-parsing`
- `features/integrate-sonar`

### Other Branch Types
- `hotfix/<issue-description>` - For urgent production fixes
- `bugfix/<issue-description>` - For bug fixes
- `docs/<documentation-update>` - For documentation updates
- `chore/<maintenance-task>` - For maintenance and cleanup tasks

## Why This Convention?

1. **Clarity**: Easy to identify the purpose of each branch
2. **Organization**: Groups related branches together
3. **Automation**: Enables automated workflows based on branch patterns
4. **Team Collaboration**: Makes it easier for team members to understand ongoing work

## Creating a New Branch

When creating a new branch, use:
```bash
git checkout -b features/your-feature-name
```

Replace `your-feature-name` with a brief, descriptive name using kebab-case (lowercase with hyphens).