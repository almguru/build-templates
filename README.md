# Azure DevOps Build Templates

Collection of useful templates for Azure DevOps YAML pipelines. This repository provides reusable pipeline templates that standardize common build and deployment tasks in Azure DevOps.

## Table of Contents

- [Overview](#overview)
- [Templates](#templates)
  - [Azure CLI Template](#azure-cli-template)
  - [Bicep Deploy Template](#bicep-deploy-template)
  - [Docker Build Template](#docker-build-template)
- [Usage Examples](#usage-examples)
- [Contributing](#contributing)

## Overview

These templates are designed to be reusable across multiple projects and provide standardized patterns for:
- Running Azure CLI commands with different script types
- Deploying Bicep templates across different Azure scopes
- Building and pushing Docker images

## Templates

### Azure CLI Template

**Location:** `pipelines/lib/azure-cli.yml`

A reusable template for executing Azure CLI commands in Azure DevOps pipelines with configurable script types and execution options.

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `azureSubscription` | string | `''` | Azure service connection name |
| `defaultDisplayName` | string | `'Azure CLI script'` | Default display name for the task |
| `defaultScriptType` | string | `'bash'` | Default script type (`bash`, `ps`, `pscore`, `batch`) |
| `script` | object | `{}` | Script configuration object |

#### Script Object Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `type` | string | No | Script type (overrides `defaultScriptType`) |
| `location` | string | No | Script location (`inlineScript` or `scriptPath`) |
| `script` | string | Yes | Script content or file path |
| `arguments` | string | No | Arguments for script files |
| `displayName` | string | No | Custom display name |
| `workingDirectory` | string | No | Working directory (defaults to `$(System.DefaultWorkingDirectory)`) |
| `addSpnToEnvironment` | boolean | No | Add service principal to environment variables |

### Bicep Deploy Template

**Location:** `pipelines/lib/bicep-deploy.yml`

Template for deploying Azure Bicep templates across different scopes (Subscription, Resource Group, Management Group, or Tenant) with parameter override support and automatic output variable creation.

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `azureSubscription` | string | Required | Azure service connection name |
| `deploymentScope` | string | `'Subscription'` | Deployment scope (`Subscription`, `ResourceGroup`, `ManagementGroup`, `Tenant`) |
| `deploymentName` | string | `"Bicep-Deploy-$(System.DefinitionId)-$(Build.BuildId)-$(System.JobAttempt)"` | Name for the deployment |
| `location` | string | Required* | Azure location for Subscription/Management Group/Tenant scopes |
| `resourceGroupName` | string | `"rg-my-resource-group"` | Resource group name for ResourceGroup scope |
| `managementGroupId` | string | `"mg-my-management-group"` | Management group ID for ManagementGroup scope |
| `file` | string | Required | Path to the Bicep file to deploy |
| `overrideParameters` | string | `""` | Override parameters for deployment |
| `deploymentOutputs` | string | `"Bicep"` | Prefix for output variables |

*Required for Subscription, Management Group, and Tenant scopes

#### Features

- **Multi-Scope Deployment:** Supports all Azure deployment scopes
- **Parameter Processing:** Advanced parameter parsing with JSON support and proper escaping
- **Output Variables:** Automatically creates Azure DevOps variables from Bicep outputs
- **Variable Naming:** Follows structured naming convention: `{deploymentOutputs}.{outputName}.name` and `{deploymentOutputs}.{outputName}.value`
- **Portal Integration:** Provides deployment details URL for Azure Portal
- **Error Handling:** Comprehensive error handling and validation

#### Parameter Override Examples

```yaml
# Simple parameters
overrideParameters: 'environmentName=production resourceGroupName=myRG'

# JSON parameter with escaped quotes
overrideParameters: 'config="{\"database\":{\"name\":\"db\",\"tier\":\"premium\"}}"'

# JSON parameter with backtick escaping
overrideParameters: 'settings={`"logging`":{`"level`":`"info`",`"enabled`":true}}'

# Mixed parameter types
overrideParameters: 'env=prod tags="{\"project\":\"app\",\"team\":\"engineering\"}" debug=false'
```

#### Output Variables

The template automatically creates pipeline variables from Bicep deployment outputs:
- **Individual Variables:** `{deploymentOutputs}.{outputName}.name` and `{deploymentOutputs}.{outputName}.value`
- **Consolidated JSON:** Single variable with the `deploymentOutputs` parameter name containing all outputs as JSON

### Docker Build Template

**Location:** `pipelines/lib/docker.yml`

Template for building and pushing Docker images to container registries with support for multiple images and custom configurations.

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `images` | object | Required | Collection of Docker image configurations |
| `containerRegistry` | string | Required | Container registry service connection |
| `defaultImageTag` | string | `'$(GitVersion.SemVer)'` | Default tag for images |

#### Image Object Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `name` | string | Yes | Name of the Docker image |
| `dockerFile` | string | Yes | Path to the Dockerfile |
| `buildContext` | string | Yes | Build context directory |
| `repositoryName` | string | Yes | Repository name in registry |
| `buildArguments` | string | No | Docker build arguments |
| `tag` | string | No | Custom tag (overrides `defaultImageTag`) |

## Usage Examples

### Using the Azure CLI Template

```yaml
# azure-pipelines.yml
resources:
  repositories:
  - repository: templates
    type: github
    name: almguru/build-templates
    endpoint: MyGitHubServiceConnection
    ref: main

stages:
- stage: Deploy
  jobs:
  - job: RunAzureCLI
    steps:
    - template: pipelines/lib/azure-cli.yml@templates
      parameters:
        azureSubscription: 'my-azure-connection'
        script:
          type: 'bash'
          location: 'inlineScript'
          script: |
            az group list --output table
            az account show
          displayName: 'List Resource Groups'
```

### Using the Bicep Deploy Template

```yaml
# azure-pipelines.yml
resources:
  repositories:
  - repository: templates
    type: github
    name: almguru/build-templates
    endpoint: MyGitHubServiceConnection 
    ref: main

stages:
- stage: DeployInfrastructure
  jobs:
  - job: Deploy
    steps:
    # Deploy to Resource Group
    - template: pipelines/lib/bicep-deploy.yml@templates
      parameters:
        azureSubscription: 'my-azure-connection'
        deploymentScope: 'ResourceGroup'
        resourceGroupName: 'my-resource-group'
        file: 'infrastructure/main.bicep'
        overrideParameters: 'environmentName=production location=eastus'
        deploymentOutputs: 'Infrastructure'
    
    # Use outputs from previous deployment
    - script: |
        echo "Storage Account: $(Infrastructure.storageAccountName.value)"
        echo "App Service URL: $(Infrastructure.appServiceUrl.value)"
      displayName: 'Display Deployment Outputs'
```

#### Subscription Scope Deployment

```yaml
- template: pipelines/lib/bicep-deploy.yml@templates
  parameters:
    azureSubscription: 'my-azure-connection'
    deploymentScope: 'Subscription'
    location: 'eastus'
    file: 'infrastructure/subscription.bicep'
    overrideParameters: 'subscriptionName=Production resourceGroupLocation=eastus'
```

#### Management Group Scope Deployment

```yaml
- template: pipelines/lib/bicep-deploy.yml@templates
  parameters:
    azureSubscription: 'my-azure-connection'
    deploymentScope: 'ManagementGroup'
    managementGroupId: 'mg-production'
    location: 'eastus'
    file: 'infrastructure/management-group.bicep'
```

### Using the Docker Build Template

```yaml
# azure-pipelines.yml
resources:
  repositories:
  - repository: templates
    type: github
    name: almguru/build-templates
    endpoint: MyGitHubServiceConnection 
    ref: main

stages:
- stage: BuildDocker
  jobs:
  - job: Build
    steps:
    - template: pipelines/lib/docker.yml@templates
      parameters:
        containerRegistry: 'my-registry-connection'
        defaultImageTag: '$(Build.BuildNumber)'
        images:
        - name: 'api'
          dockerFile: './src/api/Dockerfile'
          buildContext: './src/api'
          repositoryName: 'myproduct'
          buildArguments: '--build-arg VERSION=$(GitVersion.SemVer)'
        - name: 'worker'
          dockerFile: './src/worker/Dockerfile'
          buildContext: './src/worker'
          repositoryName: 'myproduct'
          tag: 'latest'
```

### Complete Pipeline Example

```yaml
# azure-pipelines.yml
trigger:
- main

resources:
  repositories:
  - repository: templates
    type: github
    name: almguru/build-templates
    endpoint: MyGitHubServiceConnection
    ref: main

variables:
  productName: 'myapp'
  resourceGroupName: 'rg-myapp-prod'

stages:
- stage: Build
  displayName: 'Build Stage'
  jobs:        
  - job: BuildDocker
    displayName: 'Build Docker Images'
    steps:
    - template: pipelines/lib/docker.yml@templates
      parameters:
        containerRegistry: 'registry-connection'
        images:
        - name: 'webapp'
          dockerFile: './Dockerfile'
          buildContext: '.'
          repositoryName: 'myapp'

- stage: Deploy
  displayName: 'Deploy Stage'
  dependsOn: Build
  jobs:
  - job: DeployInfrastructure
    displayName: 'Deploy Infrastructure'
    steps:
    # Deploy infrastructure using Bicep
    - template: pipelines/lib/bicep-deploy.yml@templates
      parameters:
        azureSubscription: 'azure-connection'
        deploymentScope: 'ResourceGroup'
        resourceGroupName: '$(resourceGroupName)'
        file: 'infrastructure/main.bicep'
        overrideParameters: 'appName=$(productName) environment=production'
        deploymentOutputs: 'Infrastructure'
    
    # Deploy application using Azure CLI with infrastructure outputs
    - template: pipelines/lib/azure-cli.yml@templates
      parameters:
        azureSubscription: 'azure-connection'
        script:
          type: 'bash'
          location: 'inlineScript'
          script: |
            # Use outputs from Bicep deployment
            APP_SERVICE_NAME=$(Infrastructure.appServiceName.value)
            CONTAINER_REGISTRY=$(Infrastructure.containerRegistry.value)
            
            # Deploy container to App Service
            az webapp config container set \
              --name $APP_SERVICE_NAME \
              --resource-group $(resourceGroupName) \
              --docker-custom-image-name $CONTAINER_REGISTRY/myapp/webapp:$(Build.BuildNumber)
          displayName: 'Deploy Application'
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test the templates in your pipeline
5. Submit a pull request

For questions or issues, please create an issue in this repository.
