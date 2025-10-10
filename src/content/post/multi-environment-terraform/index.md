---
title: Manage Multiple Terraform Environments
description: A deep dive into managing multiple environments in Infrastructure as Code with Terraform, OpenTofu, and Terragrunt.
slug: multi-environment-terraform
date: 2025-10-10
categories:
- How-To
tags:
- Terraform
- OpenTofu
- Terragrunt
- GitHub Actions
---

## Introduction

Every project starts simple, but when managing infrastructure for `dev`, `test`, and `prod`, let alone multiple customers, it quickly becomes complex. How can we solve this chaos?

We'll tackle the common issues of scalable IaC, and go through a clear journey from basic patterns to something more advanced, showing you how to choose the right tool for the job.

## Isolated Folders
This is the classic starting point when trying to figure out multi-environment setups. Its the simplest way to manage multiple environments by giving each one its own dedicated directory. 

### Pros
- Each environment has its own dedicated directory and state file, providing the highest level of safety and preventing accidental cross-environment changes.
- The structure is straightforward and very easy to understand, making it an excellent starting point for new projects or teams.
- The logic is intuitive, which is ideal for those new to Infrastructure as Code (IaC).

### Cons
- You must repeat boilerplate code (like providers and variables) for each environment, which violates the Don't Repeat Yourself (DRY) principle.
- As the project grows, making a change to a shared component requires updating it in every single folder, which is tedious and error-prone.
- This pattern quickly becomes unmanageable and inefficient when dealing with a large number of environments.

### Project Structure
Your repository will typically be organized into `dev`, `test`, and `prod` directories. Each environment then calls the modules from versioned repositories.

> **Note**: Instead of using separate repositories for your modules, you could create a `modules` directory. Problem with this is versioning and its difficult for others to reuse your module.

```
application/
├── dev/
│   ├── main.tf           # Calls the versioned 'core-infra'
│   ├── variables.tf      # Declares variables for the dev environment
│   └── terraform.tfvars  # Assigns values for dev
│
└── prod/
    ├── main.tf
    ├── variables.tf
    └── terraform.tfvars
```

### Configuration Examples
Let's say you have another repository acting as a Terraform module called `core-infra` and you want this deployed to the `dev` environment. This module has its own `variables.tf` with variable declarations (aka. input parameters). You then declare the required variables in your application repo `dev/variables.tf`:

```terraform
variable "vm_count" {
  description = "Number of Azure Virtual Machines."
  type        = number
}

variable "vm_size" {
  description = "The Azure VM size."
  type        = string
}

variable "location" {
  description = "The Azure region where resources will be deployed."
  type        = string
}
```

This is where the duplicate code comes in. You've now declared variables in `dev/variables.tf`, but now you want to deploy the same module to the `prod` environment, so now you have to duplicate the variables in `prod/variables.tf`

To provide values to the variables you add the following to `dev/terraform.tfvars`:

```terraform
vm_count = 1
vm_size  = "Standard_B1s"
location = "Norway East"
```

In `dev/main.tf` is where you would call your reusable module `core-infra`.

```terraform
module "core_infra" {
  # Source points to a separate Git repo and a specific version tag
  source = "git@github.com:your-org/core-infra.git?ref=v1.0.0"

  # Pass values to the module
  environment = "dev"
  vm_count    = var.vm_count
  vm_size     = var.vm_size
  location    = var.location
}
```

Why not hardcode all the values in the module call you ask? 

A `.tfvars` file acts as a clean, simple *input sheet* for an environment. Someone less familiar with Terraform would immediately see all the key parameters instead of needing to look in the configuration files. You can also easily override them using `terraform apply -var="location=westeurope"` which makes automation easier.

### Local Workflow
To deploy the `dev` environment, navigate into its folder within the `application` repo and apply the configuration:
```bash
# 1. Clone the live application repo and change into it
git clone git@github.com:your-org/application.git
cd application/dev

# 2. Initialize Terraform (this will download the module from Git)
terraform init

# 3. Plan and Apply
terraform plan
terraform apply
```

### CI/CD Pipeline (GitHub Actions)
The following workflow example is dynamic. It looks at the changed environments and builds a matrix to dynamically run plan and apply to the correct environment.
```yaml
name: 'Terraform Folders'

on:
  pull_request:
    types: [opened, synchronize, reopened]
    branches: [main]
    paths:
      - 'dev/**'
      - 'prod/**'
  push:
    branches: [main]
    paths:
      - 'dev/**'
      - 'prod/**'

# Add permissions for writing PR comments.
# You may need to add more permissions here for your cloud provider's OIDC.
permissions:
  pull-requests: write
  # Example for OIDC:
  # id-token: write
  # contents: read

jobs:
  detect-changes:
    name: 'Detect Changed Environments'
    runs-on: ubuntu-latest
    outputs:
      environments: ${{ steps.filter.outputs.all_changed_files }}
    steps:
      - name: 'Checkout Code'
        uses: actions/checkout@v5
        with:
          fetch-depth: 0

      - name: 'Find changed environment folders'
        id: filter
        uses: tj-actions/changed-files@v44
        with:
          # Since dev/prod are in root, the base path is the repository root
          path: '.'
          dir_names: "true"
          json: true
          escape_json: false
          # Define the environment folders to watch for changes
          files: |
            dev/**
            prod/**

      - name: 'Debug Output'
        run: |
            echo "Detected changes: ${{ steps.filter.outputs.all_changed_files }}"

  plan:
    name: 'Plan for ${{ matrix.environment }}'
    runs-on: ubuntu-latest
    needs: detect-changes
    if: needs.detect-changes.outputs.environments != '[]'

    strategy:
      matrix:
        environment: ${{ fromJson(needs.detect-changes.outputs.environments) }}

    steps:
      - name: 'Checkout Code'
        uses: actions/checkout@v5

      - name: 'Setup Terraform'
        uses: hashicorp/setup-terraform@v3
    
      # Add your cloud provider login step here.

      - name: 'Terraform Init'
        id: init
        working-directory: ${{ matrix.environment }}
        run: terraform init -no-color
      
      - name: 'Terraform Plan'
        id: plan
        working-directory: ${{ matrix.environment }}
        run: terraform plan -no-color -out=tfplan

      - name: 'Upload Plan Artifact'
        uses: actions/upload-artifact@v4
        with:
          name: tfplan-${{ matrix.environment }}
          path: ${{ matrix.environment }}/tfplan

      - name: Post Plan Comment to PR
        if: steps.plan.outcome == 'success' && github.event_name == 'pull_request'
        uses: actions/github-script@v8
        env:
          PLAN: "${{ steps.plan.outputs.stdout }}"
        with:
          script: |
            const { PLAN } = process.env;
            
            const output = `#### Terraform Plan for \`${{ matrix.environment }}\`
            <details><summary>Show Plan</summary>
            
            \`\`\`terraform
            ${PLAN}
            \`\`\`
            
            </details>
            
            *Pushed by: @${{ github.actor }}, Action: \`${{ github.event_name }}\`*`;
            
            await github.rest.issues.createComment({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.issue.number,
              body: output
            });

  apply:
    name: 'Apply for ${{ matrix.environment }}'
    runs-on: ubuntu-latest
    needs: [detect-changes, plan]
    if: github.event_name == 'push' && github.ref == 'refs/heads/main' && needs.detect-changes.outputs.environments != '[]'

    strategy:
      matrix:
        environment: ${{ fromJson(needs.detect-changes.outputs.environments) }}

    steps:
      - name: 'Checkout Code'
        uses: actions/checkout@v5

      - name: 'Setup Terraform'
        uses: hashicorp/setup-terraform@v3

      # Add your cloud provider login step here (same as in the plan job).

      - name: 'Download Plan Artifact'
        uses: actions/download-artifact@v5
        with:
          name: tfplan-${{ matrix.environment }}
          path: ${{ matrix.environment }}

      - name: 'Terraform Init'
        id: init
        working-directory: ${{ matrix.environment }}
        run: terraform init -no-color

      - name: 'Terraform Apply'
        id: apply
        working-directory: ${{ matrix.environment }}
        run: terraform apply -auto-approve "tfplan"
```

![Comments in pull requests](folders-pr.png)
![Completed pull request](folders-merge.png)

## OpenTofu Workspaces
Terraform has a feature called [Workspaces](https://developer.hashicorp.com/terraform/language/state/workspaces) that's used to deploy the same code to multiple environments, keeping your configuration DRY. It still uses one backend but creates separate states for better isolation.

While Terraform workspaces *work*, we are going to leverage an exclusive OpenTofu feature `early variable evaluation` to make our lives easier.

**FAILS** in Terraform:
```terraform
# You cannot enable or disable a module based on the workspace.
module "monitoring_alerts" {
  source = "./modules/monitoring"

  count  = terraform.workspace == "prod" ? 1 : 0 # ERROR
}
```

**WORKS** in OpenTofu:
```terraform
# You can enable or disable a modules based on the workspace.
module "monitoring_alerts" {
  source = "./modules/monitoring"

  count  = tofu.workspace == "prod" ? 1 : 0
}
```

### Pros
- It keeps your codebase clean by using a single set of configuration files for all environments, eliminating boilerplate code.
- Workspaces provide a safe way to manage separate state files for each environment while using the same backend configuration.
- You can efficiently manage a single application or service across multiple similar environments from one place.

### Cons
- As environments diverge, the code can become cluttered with complex conditional logic (`count`, `for_each`), making it hard to read and maintain.
- A mistake in the single codebase can potentially affect all environments, as they are not fully isolated at the code level.
- The pattern is less suitable for managing vastly different environments, as forcing all variations into one set of files leads to overly complicated configurations.

### Project Structure
With workspaces, your directory structure becomes quite simple. All your config for the application lives in a single folder:
```
application/
├── main.tf              # The main logic.
├── variables.tf         # A SINGLE declaration of all variables
├── dev.tfvars           # Values for the 'dev' environment
├── prod.tfvars          # Values for the 'prod' environment
└── backend.tf           # Defines the remote state backend
```

> **Note**: Example above only uses a main.tf file, but there's nothing stopping you from creating more configurations!

### Configuration Examples
`variables.tf`

Variables are declared only once.
```terraform
variable "vm_count" {
  description = "The number of Azure Virtual Machines."
  type        = number
}

variable "vm_size" {
  description = "The Azure VM size (e.g., 'Standard_B1s')."
  type        = string
}

variable "location" {
  description = "The Azure region where resources will be deployed."
  type        = string
}
```

`<insert_env>.tfvars`

Provides specific values for each environment.
```terraform
vm_count = 1
vm_size = "Standard_B1s"
location = "Norway East"
```

`main.tf`

Handle resource creation with conditionals.
```terraform
# This main module is enabled for all workspaces
module "core_infra" {
  source = "git@github.com:your-org/core-infra.git?ref=v1.0.0"

  vm_count    = var.vm_count
  vm_size     = var.vm_size
  location    = var.location
  environment = tofu.workspace # The workspace name is used to tag resources
}

# The monitoring module is conditionally enabled only in the 'prod' environment
module "monitoring_alerts" {
  source = "git@github.com:your-org/monitoring-alerts.git?ref=v1.2.0"
  
  # This works perfectly in OpenTofu, allowing dynamic environments
  count  = tofu.workspace == "prod" ? 1 : 0
}
```

### Local Workflow
The workflow involves selecting the correct workspace context before applying.
```bash
# 1. Clone the application repo and change into it
git clone git@github.com:your-org/application.git
cd application

# 2. Initialize OpenTofu (this will download the module from Git)
tofu init

# 3. Create workspaces
tofu workspace new dev
tofu workspace new prod

# 4. Deploy to 'dev'
# 4.1 Switch to the 'dev' workspace
tofu workspace select dev

# 4.2 Plan and apply, specifying the correct .tfvars file
tofu plan -var-file="dev.tfvars"
tofu apply -var-file="dev.tfvars"
```

### CI/CD Pipeline (GitHub Actions)
This pipeline uses a GitHub Actions feature called **reusable workflows** to keep your pipeline DRY and easy to manage. The logic is split into two files: a reusable **worker** that performs the deployment, and a main **orchestrator** that defines the release process.

`reusable-worker.yml`

Contains all the steps to deploy to any single environment. It accepts an `environment` name as an input, which it uses to dynamically select the correct OpenTofu workspace and `tfvars` file. This means you only have to define your deployment logic once.

```yaml
name: 'Tofu Reusable Worker'

on:
  workflow_call:
    inputs:
      environment:
        required: true
        type: string
      plan_only:
        required: false
        type: boolean
        default: false

permissions:
  id-token: write
  contents: read
  pull-requests: write

jobs:
  tofu:
    name: "Tofu ${{ inputs.plan_only && 'Plan' || 'Apply' }} on ${{ inputs.environment }}"
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment }}

    steps:
      - name: 'Checkout Code'
        uses: actions/checkout@v4

      - name: 'Setup OpenTofu'
        uses: opentofu/setup-opentofu@v1

      # Add your cloud provider login here.

      - name: 'Tofu Init'
        run: tofu init

      - name: 'Select or Create Workspace'
        run: tofu workspace select -or-create ${{ inputs.environment }}

      - name: 'Tofu Validate'
        run: tofu validate -no-color

      - name: 'Tofu Plan'
        id: plan
        run: tofu plan -var-file="${{ inputs.environment }}.tfvars" -no-color -out=tfplan
        continue-on-error: ${{ inputs.plan_only }}

      - name: 'Post Plan Comment to PR'
        if: inputs.plan_only && github.event_name == 'pull_request'
        uses: actions/github-script@v7
        env:
          PLAN: "tofu\n${{ steps.plan.outputs.stdout }}"
        with:
          script: |
            const { PLAN } = process.env;
            const output = `#### OpenTofu Plan 📖 \`${{ github.event.pull_request.head.sha }}\` for \`${{ inputs.environment }}\`
            <details><summary>Show Plan</summary>

            \`\`\`\n${PLAN}\n\`\`\`

            </details>

            *Pushed by: @${{ github.actor }}, Action: \`${{ github.event_name }}\`*`;

            await github.rest.issues.createComment({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.issue.number,
              body: output
            });

            if ("${{ steps.plan.outcome }}" == "failure") {
              process.exit(1);
            }

      - name: 'Tofu Apply'
        if: inputs.plan_only == false && steps.plan.outcome == 'success'
        run: tofu apply -auto-approve "tfplan"
```

`deploy-orchestrator.yml`

The main pipeline orchestrates the release by calling the reusable workflow for each stage. The `needs:` keyword creates a promotion chain, ensuring `dev` deploys first, followed by `test`, and finally `prod`. Each job simply passes the correct `environment` name to the reusable workflow.

```yaml
name: 'Tofu Deploy Orchestrator'

on:
  push:
    branches:
      - main
  pull_request:
    branches:
      - main

permissions:
  id-token: write
  contents: read
  pull-requests: write

jobs:
  plan:
    name: 'Plan for PR'
    if: github.event_name == 'pull_request'
    uses: ./.github/workflows/opentofu_workspaces_reusable.yml
    with:
      environment: dev
      plan_only: true

  deploy-dev:
    name: 'Deploy to DEV'
    if: github.event_name == 'push'
    uses: ./.github/workflows/opentofu_workspaces_reusable.yml
    with:
      environment: dev

  deploy-test:
    name: 'Promote to TEST'
    if: github.event_name == 'push'
    needs: deploy-dev
    uses: ./.github/workflows/opentofu_workspaces_reusable.yml
    with:
      environment: test

  deploy-prod:
    name: 'Promote to PROD'
    if: github.event_name == 'push'
    needs: deploy-test
    uses: ./.github/workflows/opentofu_workspaces_reusable.yml
    with:
      environment: prod
```

![Completed pull request with promotions](workspaces-merge.png)

## Terragrunt Stacks
As your application grows, its infrastructure often evolves from a single component into a **stack** of several interdependent services; like a virtual network, a database, and the application servers that rely on them. The OpenTofu workspace pattern can become cumbersome when managing the deployment order and dependencies of such a stack.

This is where Terragrunt, a thin wrapper for OpenTofu and Terraform, becomes essential. It excels at managing multi-component applications and keeping your configurations DRY.

### Pros
- Terragrunt can deploy infrastructure components in the correct order, which is perfect for complex applications with multiple layers (e.g., network, then database, then app).
- It centralizes configurations like the backend, providers, and even common variables, so you only have to define them once for all your modules.
- It simplifies running commands across multiple modules at once, allowing you to deploy an entire environment with a single command (`terragrunt apply-all`).

### Cons
- It introduces another layer of abstraction and its own set of HCL files (`terragrunt.hcl`), which can be overkill for simpler projects.
- Teams need to learn both Terraform/OpenTofu and Terragrunt's specific syntax and functions, which can slow down onboarding.
- It's another binary to install, manage, and keep in sync with your Terraform/OpenTofu version, adding a step to your development and CI/CD setup.

### Project Structure
Terragrunt uses a hierarchical repository where each component of your stack is defined in its own folder.
```
application/
├── terragrunt.hcl         # Root config (backend, common variables)
│
└── dev/
    ├── terragrunt.stack.hcl # Defines the entire stack for 'dev'
    │
    ├── vnet/
    │   └── terragrunt.hcl   # Calls the vnet module
    ├── database/
    │   └── terragrunt.hcl   # Calls the database module
    └── app/
        └── terragrunt.hcl   # Calls the app module
```

### Configuration Examples
`terragrunt.hcl`

This file, at the top of your repository, defines configurations that are inherited by all other modules, eliminating repetition.

```terraform
# Configure the remote state backend ONCE for all modules.
remote_state {
  backend = "azurerm"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    resource_group_name  = "tfstate-rg"
    storage_account_name = "mycompanytfstate"
    container_name       = "tfstate"
    key                  = "${path_relative_to_include()}/terraform.tfstate"
  }
}

# Define common inputs for all modules in this repo
inputs = {
  location    = "Norway East"
}
```

`dev/terragrunt.stack.hcl`

This file orchestrates the deployment for the `dev` environment. It defines the components and their relationships.

```terraform
# This block tells Terragrunt to deploy the modules in this specific order.
# Terragrunt is smart enough to pass outputs from 'vnet' to 'database', etc.
dependencies {
  paths = ["../vnet", "../database", "../app"]
}
```

`dev/app/terragrunt.hcl`

Configurations for each component become simple. They just point to the correct versioned module and inherit everything else.
```terraform
# Include the root configuration to inherit the backend and common inputs
include "root" {
  path = find_in_parent_folders()
}

# Define the source of the OpenTofu module for this component
terraform {
  source = "git@github.com:your-org/app.git?ref=v1.0.0"
}

# Define inputs specific to this component
inputs = {
  vm_count = 2
  vm_size  = "Standard_B2s"
}

# Define dependencies on other components in the stack.
# Terragrunt will automatically fetch the outputs from the 'database' module.
dependency "database" {
  config_path = "../database"
}

# Use the outputs from the dependency
inputs = {
  db_connection_string = dependency.database.outputs.connection_string
}
```

### Local Workflow
To deploy the entire `dev` stack in the correct order, you run a command from the environment's directory:
```bash
# Navigate to the environment folder
cd application/dev

# This command plans/applies all modules in the order defined in terragrunt.stack.hcl
terragrunt run-all plan
terragrunt run-all apply
```

### CI/CD Pipeline (GitHub Actions)
This workflow uses a change detection action to find modified Terragrunt folders. When a component like `app` is changed, it will run `terragrunt plan` in that directory. Terragrunt is smart enough to automatically include any dependencies (like `database`) in its plan to ensure everything is consistent.

```yaml
name: 'Dynamic Terragrunt CI/CD'

on:
  pull_request:
    branches: [main]
    paths: ['dev/**', 'prod/**']
  push:
    branches: [main]
    paths: ['dev/**', 'prod/**']

jobs:
  plan:
    name: 'Terragrunt Plan'
    runs-on: ubuntu-latest
    if: github.event_name == 'pull_request'

    steps:
      - name: 'Checkout Code'
        uses: actions/checkout@v4

      - name: 'Setup OpenTofu'
        uses: opentofu/setup-opentofu@v1

      - name: 'Setup Terragrunt'
        uses: gruntwork-io/setup-terragrunt@v2

      - name: 'Find changed Terragrunt directories'
        id: changed-dirs
        uses: tj-actions/changed-files@v44
        with:
          # Get a space-separated string of all changed directories
          dir_names: true

      - name: 'Run Terragrunt Plan on Changed Dirs'
        # This step runs 'terragrunt plan' in each directory that was changed.
        # It will post a comment to the PR for each plan.
        if: steps.changed-dirs.outputs.all_changed_files != ''
        run: |
          for dir in ${{ steps.changed-dirs.outputs.all_changed_files }}; do
            terragrunt plan -out=${dir//\//-}.plan --terragrunt-working-dir ${dir}
          done

  apply:
    name: 'Terragrunt Apply'
    runs-on: ubuntu-latest
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    needs: plan

    steps:
      - name: 'Checkout Code'
        uses: actions/checkout@v4

      - name: 'Setup OpenTofu'
        uses: opentofu/setup-opentofu@v1

      - name: 'Setup Terragrunt'
        uses: gruntwork-io/setup-terragrunt@v2

      - name: 'Find changed Terragrunt directories'
        id: changed-dirs
        uses: tj-actions/changed-files@v44
        with:
          dir_names: true

      - name: 'Run Terragrunt Apply on Changed Dirs'
        if: steps.changed-dirs.outputs.all_changed_files != ''
        run: |
          for dir in ${{ steps.changed-dirs.outputs.all_changed_files }}; do
            terragrunt apply --terragrunt-working-dir ${dir} --terragrunt-non-interactive
          done
```

## Conclusion
There is no single **best** solution, only the right one for your project's current scale and complexity.

- **Starting a new, self-contained application?**
    - **Start with OpenTofu Workspaces**. It's the cleanest, most modern approach that keeps your code DRY from day one.
- **Is your application a "stack" of multiple, interdependent services?**
    - **Level up to Terragrunt with** `terragrunt.stack.hcl`. It gives you the powerful dependency management and orchestration that workspaces lack.
- **Prefer maximum simplicity and explicit configuration over DRY principles?**
    - **The classic Isolated Folders pattern** is always a reliable and safe choice.