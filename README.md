# Azure DevOps Build Templates

Collection of useful templates for Azure DevOps YAML pipelines. This repository provides reusable pipeline templates that standardize common build and deployment tasks in Azure DevOps.

| Description | Status |
|-------------|--------|
| Quality Gate | [![Quality Gate Status](https://sonarcloud.io/api/project_badges/measure?project=almguru_build-templates&metric=alert_status)](https://sonarcloud.io/summary/new_code?id=almguru_build-templates) |
| Bugs | [![Bugs](https://sonarcloud.io/api/project_badges/measure?project=almguru_build-templates&metric=bugs)](https://sonarcloud.io/summary/new_code?id=almguru_build-templates) |
| Code Smells | [![Code Smells](https://sonarcloud.io/api/project_badges/measure?project=almguru_build-templates&metric=code_smells)](https://sonarcloud.io/summary/new_code?id=almguru_build-templates) |
| Maintainability Rating | [![Maintainability Rating](https://sonarcloud.io/api/project_badges/measure?project=almguru_build-templates&metric=sqale_rating)](https://sonarcloud.io/summary/new_code?id=almguru_build-templates) |
| Security Rating | [![Security Rating](https://sonarcloud.io/api/project_badges/measure?project=almguru_build-templates&metric=security_rating)](https://sonarcloud.io/summary/new_code?id=almguru_build-templates) |
| CodeQL | [![CodeQL](https://github.com/almguru/build-templates/actions/workflows/github-code-scanning/codeql/badge.svg)](https://github.com/almguru/build-templates/actions/workflows/github-code-scanning/codeql) |

## Table of Contents

- [Overview](#overview)
- [Available Templates](#available-templates)
- [Quick Start](#quick-start)
- [Documentation](#documentation)
- [Template Testing](#template-testing)
- [Contributing](#contributing)

## Overview

These templates are designed to be reusable across multiple projects and provide standardized patterns for:
- Running Azure CLI commands with different script types
- Deploying Bicep templates across different Azure scopes
- Building and pushing Docker images
- Running acceptance tests with .NET support
- Managing template repository resources

## Available Templates

| Template | Purpose | Documentation |
|----------|---------|--------------|
| `build-dotnet.yml` | Build, test, and publish .NET projects | [View Details](pipelines/lib/README.md#build-dotnet-template) |
| `azure-cli.yml` | Execute Azure CLI commands | [View Details](pipelines/lib/README.md#azure-cli-template) |
| `bicep-deploy.yml` | Deploy Azure Bicep templates | [View Details](pipelines/lib/README.md#bicep-deploy-template) |
| `docker.yml` | Build and push Docker images | [View Details](pipelines/lib/README.md#docker-build-template) |
| `run-acceptance-tests.yml` | Run acceptance tests | [View Details](pipelines/lib/README.md#run-acceptance-tests-template) |
| `use-template-files.yml` | Checkout template repository | [View Details](pipelines/lib/README.md#use-template-files-template) |

## Quick Start

### 1. Required Repository Setup

**⚠️ REQUIRED:** All templates require the repository to be referenced as `almguru-templates`. Add this to your pipeline's resources section:

```yaml
resources:
  repositories:
  - repository: almguru-templates
    type: github
    name: almguru/build-templates
    endpoint: MyGitHubServiceConnection
    ref: main
```

### 2. Basic Usage Example

```yaml
# azure-pipelines.yml
trigger:
- main

resources:
  repositories:
  - repository: almguru-templates
    type: github
    name: almguru/build-templates
    endpoint: MyGitHubServiceConnection
    ref: main

stages:
- stage: Deploy
  jobs:
  - job: DeployInfrastructure
    steps:
    - template: pipelines/lib/bicep-deploy.yml@almguru-templates
      parameters:
        azureSubscription: 'my-azure-connection'
        deploymentScope: 'ResourceGroup'
        resourceGroupName: 'my-resource-group'
        file: 'infrastructure/main.bicep'
```

## Documentation

📖 **[Complete Template Documentation](pipelines/lib/README.md)** - Detailed documentation with parameters, examples, and usage patterns for all templates.

## Template Testing

This repository includes an automated Azure Pipeline (`azure-pipelines.yml`) that tests all templates in the `/pipelines/lib` directory by actually executing them. The pipeline ensures:

- **Template Execution Tests**: Each template is called with various parameter combinations
- **Parameter Validation**: Templates correctly validate and handle parameters
- **Script Execution**: PowerShell scripts used by templates execute without errors
- **Integration Tests**: Template dependencies and cross-references work correctly
- **Accessibility Verification**: All templates are accessible and can be referenced

### Templates Tested

The pipeline actively tests these templates with real execution:

- **azure-cli.yml** - Tested with bash, PowerShell Core, and environment variables
- **use-template-files.yml** - Tested with repository checkout operations
- **docker.yml** - Tested with parameter validation scenarios
- **PowerShell scripts** - Tested with various input conditions

**Note**: Templates requiring Azure service connections (bicep-deploy.yml, run-acceptance-tests.yml) are validated structurally and tested in consuming pipelines.

The testing pipeline runs automatically on:
- Pull requests to the main branch
- Commits to the main branch
- When templates or scripts are modified

This ensures that all templates execute correctly and are ready for use in production pipelines.

## Contributing

We welcome contributions to improve these templates! Please follow our guidelines:

### Branch Naming Convention

This repository follows a structured branch naming convention. All branches must use one of these prefixes:

- `features/` - For new features or enhancements
- `bugfix/` - For bug fixes
- `hotfix/` - For urgent production fixes
- `docs/` - For documentation updates
- `chore/` - For maintenance and cleanup tasks

**Examples:**
- `features/add-docker-template`
- `bugfix/fix-bicep-parameter-parsing`
- `docs/update-readme`

📖 **[Complete Branch Naming Guide](.github/BRANCH_NAMING.md)** - Detailed information about our branch naming conventions.

### How to Contribute

1. Fork the repository
2. Create a feature branch following our naming convention: `git checkout -b features/your-feature-name`
3. Make your changes
4. Test the templates in your pipeline
5. Submit a pull request

Our automated checks will verify that your branch follows the naming convention.

For questions or issues, please create an issue in this repository.
