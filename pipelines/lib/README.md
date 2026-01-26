# Azure DevOps Pipeline Templates

This directory contains reusable Azure DevOps YAML pipeline templates for common build and deployment tasks.

## Templates Overview

| Template | Purpose | Key Features |
|----------|---------|--------------|
| [build-dotnet.yml](#build-dotnet-template) | Build, test, and publish .NET projects | Multi-framework support, code signing, test coverage reporting |
| [azure-cli.yml](#azure-cli-template) | Execute Azure CLI commands | Multi-script support, configurable environments |
| [bicep-deploy.yml](#bicep-deploy-template) | Deploy Azure Bicep templates | Multi-scope deployment, automatic output variables |
| [docker.yml](#docker-build-template) | Build and push Docker images | Multi-image support, configurable registries |
| [run-acceptance-tests.yml](#run-acceptance-tests-template) | Run acceptance tests | .NET support, Key Vault integration, custom hooks |
| [use-template-files.yml](#use-template-files-template) | Checkout template repository | Template resource management |

## Required Repository Setup

All examples in this documentation require the templates repository to be referenced as `almguru-templates`. Add this to your pipeline's resources section:

```yaml
resources:
  repositories:
  - repository: almguru-templates
    type: github
    name: almguru/build-templates
    endpoint: MyGitHubServiceConnection
    ref: main
```

## Build .NET Template

**Location:** `pipelines/lib/build-dotnet.yml`

A comprehensive template for building, testing, publishing, and packaging .NET projects with support for multi-framework scenarios, code signing, coverage reporting, and artifact staging.

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `buildAction` | string | `'build'` | Action to perform: `build` (compile only) or `publish` (compile and package for deployment) |
| `buildSpec` | string | `''` | Project or solution file(s) to build. Supports wildcards and multiple projects |
| `buildConfiguration` | string | `'Release'` | Build configuration (`Debug` or `Release`) |
| `buildAdditionalArguments` | string | `''` | Additional arguments passed to `dotnet build/publish` commands |
| `buildNoRestoreArgument` | string | `''` | Arguments to skip restore if already performed |
| `buildVersionProperties` | string | `'Version=$(GitVersion_SemVer);...'` | MSBuild properties for versioning. Uses GitVersion variables |
| `feedsToUse` | string | `'none'` | NuGet feed strategy: `none` (no restore), `config` (nuget.config), `select` (specific VSTS feed) |
| `vstsFeed` | string | `'innersource'` | VSTS feed name when `feedsToUse` is `'select'` |
| `testSpec` | string | `''` | Glob pattern to locate compiled test assemblies in artifacts (e.g., `'**/*Tests.dll'`, `'**/bin/Release/**/*Tests.dll'`) |
| `unitTestArguments` | string | `''` | Additional arguments for `dotnet test` command |
| `beforeTestsSteps` | stepList | `[]` | Custom steps to execute before running tests |
| `zipAfterPublish` | boolean | `true` | Whether to zip published output folders |
| `deploymentFolder` | string | `'app'` | Subfolder within artifact staging directory for deployment artifacts |
| `beforePublishSteps` | stepList | `[]` | Custom steps to execute before publish |
| `publishNuGetPackages` | boolean | `false` | Whether to publish .nupkg packages as artifacts |
| `nuGetPackagesPublishingFilter` | string | `'**/*.nupkg\n!/**/*.symbols.nupkg'` | Glob pattern for packages to publish |
| `nuGetPackagesDeploymentFolder` | string | `'packages'` | Subfolder within artifact staging directory for NuGet packages |
| `signFiles` | string | `''` | File glob pattern for files to sign. Leave empty to skip signing |
| `codeSigningServiceConnection` | string | `''` | Azure service connection for Key Vault access |
| `codeSigningKeyVaultName` | string | `''` | Azure Key Vault name containing signing certificate |
| `codeSigningCertificateSecretName` | string | `''` | Key Vault secret name containing the base64-encoded certificate |
| `versionSpec` | string | `'10.x'` | .NET SDK version to install |
| `nuGetVersionSpec` | string | `'7.x'` | NuGet tool version to install |
| `beforeBuildSteps` | stepList | `[]` | Custom steps to execute before build |

### Features

- **Multi-Action Support:** Build-only or build+publish workflows
- **Flexible Feed Management:** Support for multiple NuGet feed strategies
- **Code Coverage:** Automatic code coverage collection in Cobertura format
- **Code Signing:** Optional Authenticode signing with Azure Key Vault integration
- **Symbol Publishing:** Automatic PDB publishing to symbol server
- **Artifact Organization:** Structured artifact staging with separate folders for binaries and packages
- **Test Publishing:** Automatic test results publishing in VSTest format
- **Extensibility:** Before/after hooks at critical pipeline stages
- **Version Management:** GitVersion integration for semantic versioning

### Usage Examples

#### Basic Build

```yaml
- template: pipelines/lib/build-dotnet.yml@almguru-templates
  parameters:
    buildSpec: 'src/MyApp.csproj'
    testSpec: '**/*Tests.dll'
```

#### Build and Publish with NuGet Packages

```yaml
- template: pipelines/lib/build-dotnet.yml@almguru-templates
  parameters:
    buildAction: 'publish'
    buildSpec: 'src/MyApp.sln'
    testSpec: '**/bin/Release/**/*Tests.dll'
    publishNuGetPackages: true
    zipAfterPublish: true
```

#### Build with Code Signing

```yaml
- template: pipelines/lib/build-dotnet.yml@almguru-templates
  parameters:
    buildSpec: 'src/MyApp.csproj'
    buildConfiguration: 'Release'
    signFiles: '**/*.exe|**/*.dll'
    codeSigningServiceConnection: 'azure-key-vault-connection'
    codeSigningKeyVaultName: 'my-keyvault'
    codeSigningCertificateSecretName: 'CodeSigningCert'
```

#### Build with Custom Feed and Build Arguments

```yaml
- template: pipelines/lib/build-dotnet.yml@almguru-templates
  parameters:
    buildSpec: 'src/MyApp.sln'
    feedsToUse: 'select'
    vstsFeed: 'my-custom-feed'
    buildConfiguration: 'Release'
    buildAdditionalArguments: '--property:TreatWarningsAsErrors=true'
    testSpec: '**/bin/Release/**/*Tests.dll'
    unitTestArguments: '--filter Category=Unit'
```

#### Build with Test Hooks

```yaml
- template: pipelines/lib/build-dotnet.yml@almguru-templates
  parameters:
    buildSpec: 'src/**/*.csproj'
    testSpec: '**/*Tests.dll'
    unitTestArguments: '--filter Category!=Integration'
    beforeTestsSteps:
      - script: |
          echo "Preparing test environment"
          docker run --name test-db -d postgres:latest
        displayName: 'Start Test Database'
```

#### Full CI/CD Pipeline with Code Signing and Publishing

```yaml
- template: pipelines/lib/build-dotnet.yml@almguru-templates
  parameters:
    buildAction: 'publish'
    buildSpec: 'src/MyApp.sln'
    buildConfiguration: 'Release'
    versionSpec: '9.x'
    feedsToUse: 'select'
    vstsFeed: 'innersource'
    testSpec: '**/bin/Release/**/*Tests.dll'
    signFiles: '**/*.exe'
    codeSigningServiceConnection: 'AzureKeyVaultConnection'
    codeSigningKeyVaultName: 'my-keyvault'
    codeSigningCertificateSecretName: 'CodeSigningCert'
    publishNuGetPackages: true
    zipAfterPublish: true
    deploymentFolder: 'app'
    nuGetPackagesDeploymentFolder: 'packages'
```

## Azure CLI Template

**Location:** `pipelines/lib/azure-cli.yml`

A reusable template for executing Azure CLI commands in Azure DevOps pipelines with configurable script types and execution options.

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `azureSubscription` | string | `''` | Azure service connection name |
| `defaultDisplayName` | string | `'Azure CLI script'` | Default display name for the task |
| `defaultScriptType` | string | `'bash'` | Default script type (`bash`, `ps`, `pscore`, `batch`) |
| `script` | object | `{}` | Script configuration object |

### Script Object Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `type` | string | No | Script type (overrides `defaultScriptType`) |
| `location` | string | No | Script location (`inlineScript` or `scriptPath`) |
| `script` | string | Yes | Script content or file path |
| `arguments` | string | No | Arguments for script files |
| `displayName` | string | No | Custom display name |
| `workingDirectory` | string | No | Working directory (defaults to `$(System.DefaultWorkingDirectory)`) |
| `addSpnToEnvironment` | boolean | No | Add service principal to environment variables |

### Usage Example

```yaml
- template: pipelines/lib/azure-cli.yml@almguru-templates
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

## Bicep Deploy Template

**Location:** `pipelines/lib/bicep-deploy.yml`

Template for deploying Azure Bicep templates across different scopes (Subscription, Resource Group, Management Group, or Tenant) with parameter override support and automatic output variable creation.

### Parameters

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

### Features

- **Multi-Scope Deployment:** Supports all Azure deployment scopes
- **Parameter Processing:** Advanced parameter parsing with JSON support and proper escaping
- **Output Variables:** Automatically creates Azure DevOps variables from Bicep outputs
- **Variable Naming:** Follows structured naming convention: `{deploymentOutputs}.{outputName}.name` and `{deploymentOutputs}.{outputName}.value`
- **Portal Integration:** Provides deployment details URL for Azure Portal
- **Error Handling:** Comprehensive error handling and validation

### Parameter Override Examples

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

### Output Variables

The template automatically creates pipeline variables from Bicep deployment outputs:
- **Individual Variables:** `{deploymentOutputs}.{outputName}.name` and `{deploymentOutputs}.{outputName}.value`
- **Consolidated JSON:** Single variable with the `deploymentOutputs` parameter name containing all outputs as JSON

### Usage Examples

#### Resource Group Deployment

```yaml
- template: pipelines/lib/bicep-deploy.yml@almguru-templates
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
- template: pipelines/lib/bicep-deploy.yml@almguru-templates
  parameters:
    azureSubscription: 'my-azure-connection'
    deploymentScope: 'Subscription'
    location: 'eastus'
    file: 'infrastructure/subscription.bicep'
    overrideParameters: 'subscriptionName=Production resourceGroupLocation=eastus'
```

#### Management Group Scope Deployment

```yaml
- template: pipelines/lib/bicep-deploy.yml@almguru-templates
  parameters:
    azureSubscription: 'my-azure-connection'
    deploymentScope: 'ManagementGroup'
    managementGroupId: 'mg-production'
    location: 'eastus'
    file: 'infrastructure/management-group.bicep'
```

## Docker Build Template

**Location:** `pipelines/lib/docker.yml`

Template for building and pushing Docker images to container registries with support for multiple images and custom configurations.

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `images` | object | Required | Collection of Docker image configurations |
| `containerRegistry` | string | Required | Container registry service connection |
| `defaultImageTag` | string | `'$(GitVersion.SemVer)'` | Default tag for images |

### Image Object Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `name` | string | Yes | Name of the Docker image |
| `dockerFile` | string | Yes | Path to the Dockerfile |
| `buildContext` | string | Yes | Build context directory |
| `repositoryName` | string | Yes | Repository name in registry |
| `buildArguments` | string | No | Docker build arguments |
| `tag` | string | No | Custom tag (overrides `defaultImageTag`) |

### Usage Example

```yaml
- template: pipelines/lib/docker.yml@almguru-templates
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

## Run Acceptance Tests Template

**Location:** `pipelines/lib/run-acceptance-tests.yml`

Template for running acceptance tests in Azure DevOps pipelines with support for .NET test assemblies, Azure Key Vault integration, and custom test configuration.

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `azureSubscription` | string | `''` | Azure service connection name for Key Vault access |
| `environmentName` | string | Required | Target environment name (e.g., Development, Staging, Production) |
| `keyVaultName` | string | `''` | Azure Key Vault name for retrieving secrets |
| `keyVaultValuesFilter` | string | `'*'` | Filter pattern for Key Vault secrets (e.g., 'ConnectionString*') |
| `beforeTestsSteps` | stepList | `[]` | Custom steps to execute before running tests |
| `afterTestsSteps` | stepList | `[]` | Custom steps to execute after running tests |
| `suiteName` | string | `''` | Descriptive name for the test suite |
| `runtimeType` | string | `'none'` | Runtime environment (`none`, `dotnet`) |
| `runtimeVersion` | string | `''` | .NET version (e.g., '8.x', '9.x') |
| `artifactName` | string | `'deploy'` | Pipeline artifact containing test assemblies |
| `files` | string | `'**/*Tests.dll'` | Glob pattern to locate test assemblies |
| `arguments` | string | `''` | Additional arguments for test runner |
| `environment` | object | `{}` | Environment variables for test execution |

### Features

- **Multi-Runtime Support:** Supports .NET test assemblies with configurable versions
- **Azure Key Vault Integration:** Automatically retrieves secrets and configuration
- **Custom Hooks:** Before/after test step hooks for setup/teardown
- **Test Result Publishing:** Automatic publishing in .trx format
- **Environment Variables:** Support for custom environment configuration
- **Template Files Integration:** Works with `use-template-files.yml` template

### Usage Examples

#### Basic .NET Acceptance Tests

```yaml
- template: pipelines/lib/use-template-files.yml@almguru-templates

- template: pipelines/lib/run-acceptance-tests.yml@almguru-templates
  parameters:
    environmentName: 'Development'
    runtimeType: 'dotnet'
    runtimeVersion: '9.x'
    suiteName: 'API Tests'
    files: '**/*AcceptanceTests.dll'
```

#### With Azure Key Vault Integration

```yaml
- template: pipelines/lib/use-template-files.yml@almguru-templates

- template: pipelines/lib/run-acceptance-tests.yml@almguru-templates
  parameters:
    azureSubscription: 'MyAzureConnection'
    environmentName: 'Staging'
    keyVaultName: 'my-keyvault'
    keyVaultValuesFilter: 'ConnectionString*'
    runtimeType: 'dotnet'
    suiteName: 'Integration Tests'
```

#### With Custom Environment Variables and Test Arguments

```yaml
- template: pipelines/lib/use-template-files.yml@almguru-templates

- template: pipelines/lib/run-acceptance-tests.yml@almguru-templates
  parameters:
    environmentName: 'Production'
    runtimeType: 'dotnet'
    suiteName: 'E2E Tests'
    arguments: '--filter Category=Smoke'
    environment:
      API_BASE_URL: 'https://api.myapp.com'
      TEST_TIMEOUT: '300'
```

#### With Custom Setup/Teardown Steps

```yaml
- template: pipelines/lib/use-template-files.yml@almguru-templates

- template: pipelines/lib/run-acceptance-tests.yml@almguru-templates
  parameters:
    environmentName: 'Testing'
    runtimeType: 'dotnet'
    suiteName: 'Database Tests'
    beforeTestsSteps:
      - script: echo "Setting up test database"
        displayName: 'Database Setup'
    afterTestsSteps:
      - script: echo "Cleaning up test data"
        displayName: 'Database Cleanup'
```

## Use Template Files Template

**Location:** `pipelines/lib/use-template-files.yml`

Template for checking out template repository files to make scripts and resources available to other templates in the pipeline.

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `repositoryResourceName` | string | `'almguru-templates'` | Repository resource name to checkout |
| `repositoryLocalPath` | string | `'almguru-templates'` | Local path for checked out files |

### Features

- **Repository Checkout:** Downloads all template resource files
- **Variable Setup:** Sets `almguruTemplateFilesPath` variable for other templates
- **Resource Management:** Ensures template dependencies are available

### Usage Example

```yaml
# Must be called before other templates that require template files
- template: pipelines/lib/use-template-files.yml@almguru-templates
  parameters:
    repositoryResourceName: 'almguru-templates'
    repositoryLocalPath: 'build-templates'
```

## Complete Pipeline Examples

### Build and Test Pipeline

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
    - template: pipelines/lib/docker.yml@almguru-templates
      parameters:
        containerRegistry: 'registry-connection'
        images:
        - name: 'webapp'
          dockerFile: './Dockerfile'
          buildContext: '.'
          repositoryName: 'myapp'

- stage: Test
  displayName: 'Test Stage'
  dependsOn: Build
  jobs:
  - job: AcceptanceTests
    displayName: 'Run Acceptance Tests'
    steps:
    - template: pipelines/lib/use-template-files.yml@almguru-templates

    - template: pipelines/lib/run-acceptance-tests.yml@almguru-templates
      parameters:
        environmentName: 'Testing'
        runtimeType: 'dotnet'
        runtimeVersion: '9.x'
        suiteName: 'Acceptance Tests'
        files: '**/*AcceptanceTests.dll'

- stage: Deploy
  displayName: 'Deploy Stage'
  dependsOn: [Build, Test]
  jobs:
  - job: DeployInfrastructure
    displayName: 'Deploy Infrastructure'
    steps:
    # Deploy infrastructure using Bicep
    - template: pipelines/lib/bicep-deploy.yml@almguru-templates
      parameters:
        azureSubscription: 'azure-connection'
        deploymentScope: 'ResourceGroup'
        resourceGroupName: '$(resourceGroupName)'
        file: 'infrastructure/main.bicep'
        overrideParameters: 'appName=$(productName) environment=production'
        deploymentOutputs: 'Infrastructure'
    
    # Deploy application using Azure CLI with infrastructure outputs
    - template: pipelines/lib/azure-cli.yml@almguru-templates
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

### Multi-Environment Pipeline with Tests

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

variables:
  productName: 'myapp'

stages:
- stage: Build
  displayName: 'Build'
  jobs:
  - job: Build
    steps:
    - template: pipelines/lib/docker.yml@almguru-templates
      parameters:
        containerRegistry: 'registry-connection'
        images:
        - name: 'api'
          dockerFile: './Dockerfile'
          buildContext: '.'
          repositoryName: '$(productName)'

- stage: DeployDev
  displayName: 'Deploy to Development'
  dependsOn: Build
  jobs:
  - job: Deploy
    steps:
    - template: pipelines/lib/bicep-deploy.yml@almguru-templates
      parameters:
        azureSubscription: 'azure-dev-connection'
        deploymentScope: 'ResourceGroup'
        resourceGroupName: 'rg-$(productName)-dev'
        file: 'infrastructure/main.bicep'
        overrideParameters: 'appName=$(productName) environment=development'

- stage: TestDev
  displayName: 'Test Development'
  dependsOn: DeployDev
  jobs:
  - job: AcceptanceTests
    steps:
    - template: pipelines/lib/use-template-files.yml@almguru-templates

    - template: pipelines/lib/run-acceptance-tests.yml@almguru-templates
      parameters:
        azureSubscription: 'azure-dev-connection'
        environmentName: 'Development'
        keyVaultName: 'kv-$(productName)-dev'
        runtimeType: 'dotnet'
        suiteName: 'Development Tests'
        environment:
          API_BASE_URL: 'https://$(productName)-dev.azurewebsites.net'

- stage: DeployProd
  displayName: 'Deploy to Production'
  dependsOn: TestDev
  condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
  jobs:
  - job: Deploy
    steps:
    - template: pipelines/lib/bicep-deploy.yml@almguru-templates
      parameters:
        azureSubscription: 'azure-prod-connection'
        deploymentScope: 'ResourceGroup'
        resourceGroupName: 'rg-$(productName)-prod'
        file: 'infrastructure/main.bicep'
        overrideParameters: 'appName=$(productName) environment=production'

- stage: TestProd
  displayName: 'Test Production'
  dependsOn: DeployProd
  jobs:
  - job: SmokeTests
    steps:
    - template: pipelines/lib/use-template-files.yml@almguru-templates

    - template: pipelines/lib/run-acceptance-tests.yml@almguru-templates
      parameters:
        azureSubscription: 'azure-prod-connection'
        environmentName: 'Production'
        keyVaultName: 'kv-$(productName)-prod'
        runtimeType: 'dotnet'
        suiteName: 'Production Smoke Tests'
        arguments: '--filter Category=Smoke'
        environment:
          API_BASE_URL: 'https://$(productName).azurewebsites.net'
```