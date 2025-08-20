# Azure DevOps Build Templates

Collection of useful templates for Azure DevOps YAML pipelines. This repository provides reusable pipeline templates that standardize common build and deployment tasks in Azure DevOps.

| Description | Status |
|-------------|--------|
| Quality Gate | [![Quality Gate Status](https://sonarcloud.io/api/project_badges/measure?project=almguru_build-templates&metric=alert_status)](https://sonarcloud.io/summary/new_code?id=almguru_build-templates) |
| Bugs | [![Bugs](https://sonarcloud.io/api/project_badges/measure?project=almguru_build-templates&metric=bugs)](https://sonarcloud.io/summary/new_code?id=almguru_build-templates) |
| Code Smells | [![Code Smells](https://sonarcloud.io/api/project_badges/measure?project=almguru_build-templates&metric=code_smells)](https://sonarcloud.io/summary/new_code?id=almguru_build-templates) |
| Maintainability Rating | [![Maintainability Rating](https://sonarcloud.io/api/project_badges/measure?project=almguru_build-templates&metric=sqale_rating)](https://sonarcloud.io/summary/new_code?id=almguru_build-templates) |
| Security Rating | [![Security Rating](https://sonarcloud.io/api/project_badges/measure?project=almguru_build-templates&metric=security_rating)](https://sonarcloud.io/summary/new_code?id=almguru_build-templates) |
| CodeQL | ![CodeQL](https://github.com/almguru/build-templates/actions/workflows/codeql.yml/badge.svg) |

## Table of Contents

- [Overview](#overview)
- [Available Templates](#available-templates)
- [Quick Start](#quick-start)
- [Documentation](#documentation)
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

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test the templates in your pipeline
5. Submit a pull request

For questions or issues, please create an issue in this repository.
