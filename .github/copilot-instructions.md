# Copilot Instructions for build-templates

This is a **reusable Azure DevOps pipeline templates library** providing standardized build and deployment patterns for team projects.

## Project Architecture

**Core Pattern**: Modular YAML template components in `pipelines/lib/` that are referenced from consuming pipelines via the `almguru-templates` repository alias. Each template is independently callable and focuses on a single responsibility.

**Template Categories**:
- **Build**: `build-dotnet.yml` - Complete .NET lifecycle (compile, test, publish, code signing, artifact staging)
- **Infrastructure**: `bicep-deploy.yml` - Azure Resource Manager deployments with multi-scope support
- **Container**: `docker.yml` - Docker image building and registry pushes
- **CLI**: `azure-cli.yml` - Orchestrates Azure CLI script execution with multiple shell types
- **Testing**: `run-acceptance-tests.yml` - Acceptance test runner with Key Vault integration
- **Setup**: `use-template-files.yml` - Template repository checkout helper

**Testing Strategy**: The `azure-pipelines.yml` (root) is a **meta-pipeline** that tests all templates by actually executing them with various parameter combinations. Tests verify structure, parameter validation, and execution without side effects.

## Critical Developer Workflows

### Building and Testing Locally
```bash
dotnet build src                    # Build the solution (see `azure-pipelines.yml` for task definitions)
dotnet test **/bin/Debug/**/*Tests  # Run unit tests using Microsoft.Testing.Platform runner (global.json)
```

### Template Validation
Templates are YAML files; validate syntax using Azure DevOps YAML schema or by dry-running in pipelines. PowerShell verification scripts in `azure-pipelines.yml` (lines 40+) show how to parse and validate template parameters.

### Directory Layout
- `pipelines/lib/` - Template definitions (consumers reference these)
- `src/` - Test fixtures and sample projects proving template functionality
- `scripts/` - PowerShell helpers (e.g., `Invoke-TestRunner.ps1` for test orchestration)

## Key Patterns and Conventions

### 1. Template Parameter Style
Templates use **named parameters** with type safety (`type: string|boolean|stepList|object`). Always define:
- **Default values** (even if empty string)
- **Allowed values** where applicable (enums like `buildAction: ['build', 'publish']`)
- **Clear documentation** in YAML comments explaining the parameter's purpose and examples

Example (from `build-dotnet.yml`):
```yaml
parameters:
  - name: buildAction
    type: string
    default: 'build'
    values: ['build', 'publish']
```

### 2. Configuration and Build Properties
- **Directory.Build.props/targets** define project-wide compilation rules (`src/Directory.Build.props`):
  - Enforces code analyzers and style enforcement (`EnforceCodeStyleInBuild`)
  - Configures artifact output paths (`ArtifactsPath`)
  - Enables SARIF error logs for static analysis
  - Uses Microsoft.Testing.Platform for tests (not xUnit/NUnit directly)
- **SonarCloud integration** (`sonar-project.properties`) scans YAML templates and test code

### 3. Code Signing Flow
When implementing code signing features:
- Retrieve certificate from Azure Key Vault as base64-encoded secret
- Use `Authenticode` signing task (part of `build-dotnet.yml`)
- Store certificate path in intermediate variable for robustness
- Template must handle empty `signFiles` parameter gracefully (skip signing if not specified)

### 4. NuGet Feed Management
Templates support three feed strategies via `feedsToUse` parameter:
- `'none'` - No restore (assume packages already resolved)
- `'config'` - Uses `nuget.config` in repository
- `'select'` - Uses VSTS feed specified in `vstsFeed` parameter

### 5. Environment Variables and Template Expansion
- Azure CLI template (`azure-cli.yml`) accepts an `environment` object parameter for runtime variable injection
- Use `$(System.*)` and `$(Build.*)` variables from Azure DevOps context
- **Conditions** in templates use `${{ if condition }}` syntax for compile-time logic

## Integration Points and Dependencies

### Required Repository Setup
Consuming pipelines **MUST** declare this in their `resources` section (see README.md):
```yaml
resources:
  repositories:
  - repository: almguru-templates
    type: github
    name: almguru/build-templates
    endpoint: MyGitHubServiceConnection
    ref: main  # or specific tag/branch
```

### External Tools and Services
- **Azure CLI 2.x** - Required for `azure-cli.yml` and `bicep-deploy.yml` templates
- **Docker** - Required for `docker.yml` (assumes Docker daemon on pool agent)
- **Azure DevOps Service Connections** - Templates require Azure RM connections for authentication
- **Azure Key Vault** - For code signing certificates and secret management (in `build-dotnet.yml`)
- **SonarCloud** - Scans pull requests (via `sonar-project.properties`)

### Template Interdependencies
- `run-acceptance-tests.yml` may depend on outputs from `docker.yml` or `build-dotnet.yml`
- `use-template-files.yml` is often called first to ensure template files are available
- `bicep-deploy.yml` typically follows successful `build-dotnet.yml` execution

## Common Pitfalls and Edge Cases

1. **Missing Repository Alias**: If consuming pipeline doesn't declare `almguru-templates`, template reference fails. Always verify `resources:` section.
2. **Test Spec Glob Patterns**: When adding test filters, remember `testSpec` expects compiled assembly paths (e.g., `**/bin/Release/**/*Tests.dll`), not source files.
3. **Step Lists vs. Objects**: Parameters like `beforeTestsSteps` are `stepList` type, not `object`. Structure them as YAML arrays of task objects.
4. **Code Signing Certificate Format**: Certificate must be base64-encoded and stored as a Key Vault secret. Decoding happens in the template.
5. **Environment Scope for Deployments**: `bicep-deploy.yml` supports `ResourceGroup`, `Subscription`, `ManagementGroup`, and `Tenant` scopes. Verify scope matches your Bicep template's targetScope.

## Code Generation Guidance

When adding or modifying templates:
- **Keep templates single-purpose** - Mix concerns minimally
- **Document parameter examples** in template comments (shows up in pipeline UI)
- **Use stepList for extensibility** - Provide `before*Steps` hooks so consumers can inject custom logic
- **Validate early** - Check parameter combinations in template steps (see `azure-cli.yml` verification pattern)
- **Test parameter coverage** - Add test cases in `azure-pipelines.yml` for new parameter combinations
- **Use consistent naming** - Follow verb-noun convention for step display names and parameter names
