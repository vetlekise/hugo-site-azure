---
title: Manage Multiple Terraform Environments
description: A deep dive into managing multiple environments in Infrastructure as Code with Terraform, OpenTofu, and Terragrunt.
slug: multi-environment-terraform
date: 2025-10-06
categories:
- How-To
---

## Introduction

Every project starts simple, but when managing infrastructure for `dev`, `test`, and `prod`, let alone multiple customers, it quickly becomes complex. How can we solve this chaos?

We'll tackle the common issues of scalable IaC, and go through a clear journey from basic patterns to an advanced *infrastructure factory*, showing you how to choose the right tool for the job.

## Isolated Folders
This is the classic starting point when trying to figure out multi-environment setups. Its the simplest way to manage multiple environments by giving each one its own dedicated directory. 

### Why?
#### Pros
- Projects where maximum safety and state file isolation are top priorities.
- Simpler applications where the overhead of duplicating a few files is negligible.
- Teams new to IaC, as the logic is very easy to follow.

#### Cons
The primary drawback of this pattern is code duplication. Since each environment is a distinct project, you must repeat boilerplate code, the most notorious being the `variables.tf` file in each folder. It feels tedious and violate the *Don't Repeat Yourself* (DRY) principle as your project grows.

### Project Structure
Your repository will typically be organized into `dev`, `test`, and `prod` directories. Each environment then calls the modules from versioned repositories.

> **Note**: Instead of using separate repositories for your modules, you could create a `modules` directory. Problem with this is versioning and its difficult for others to reuse your module.

```
application/
├── dev/
│   ├── main.tf           # Calls the versioned 'app-core-module'
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

This is where the duplicate code comes in. The variables you're declaring in `dev/variables.tf` has already been declared in the module you're calling, so this is duplicate number one (read more to find reason). You then want to deploy the same module to the `prod` environment, so now you have to duplicate the variables once again, duplicating it a second time.

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

Why not hardcode values in the module call you ask? 

A `.tfvars` file acts as a clean, simple *input sheet* for an environment. Someone less familiar with Terraform would immediately see all the key parameters instead of needing to look in the configuration files. You can also easily override them using `terraform apply -var="location=westeurope"` which makes automation easier.

### Local Workflow
To deploy the `dev` environment, navigate into its folder within the `application` repo:
```bash
# 1. Clone the live application repo and change into it
git clone git@github.com:your-org/application.git
cd application/dev

# 2. Initialize OpenTofu/Terraform (this will download the module from Git)
terraform init

# 3. Plan and Apply
terraform plan
terraform apply
```

### CI/CD Pipeline (GitHub Actions)
The following workflow example is dynamic. It looks at the changed environments and builds a matrix to dynamically run plan and apply to the correct environment.
```yaml
nname: 'Dynamic Terraform Plan & Apply'

on:
  pull_request:
    branches: [main]
    paths: ['dev/**', 'test/**', 'prod/**']
  push:
    branches: [main]
    paths: ['dev/**', 'test/**', 'prod/**']

jobs:
  detect-changes:
    name: 'Detect Changed Environments'
    runs-on: ubuntu-latest
    outputs:
      # Output a JSON array of the changed folders (e.g., ["dev", "prod"])
      environments: ${{ steps.filter.outputs.changes }}

    steps:
      - name: 'Checkout Code'
        uses: actions/checkout@v4

      - name: 'Find changed environment folders'
        id: filter
        uses: tj-actions/changed-files@v44
        with:
          files: |
            dev
            test
            prod

  plan:
    name: 'Plan for ${{ matrix.environment }}'
    runs-on: ubuntu-latest
    needs: detect-changes
    if: github.event_name == 'pull_request' && needs.detect-changes.outputs.environments != '[]'

    strategy:
      matrix:
        environment: ${{ fromJson(needs.detect-changes.outputs.environments) }}

    steps:
      - name: 'Checkout Code'
        uses: actions/checkout@v4

      - name: 'Setup Terraform'
        uses: hashicorp/setup-terraform@v3

      - name: 'Terraform Init & Plan'
        run: |
          terraform init
          terraform plan -out=tfplan
        working-directory: ./${{ matrix.environment }}

      - name: 'Upload Plan Artifact'
        uses: actions/upload-artifact@v4
        with:
          name: tfplan-${{ matrix.environment }}
          path: ./${{ matrix.environment }}/tfplan


  apply:
    name: 'Apply for ${{ matrix.environment }}'
    runs-on: ubuntu-latest
    needs: detect-changes
    if: github.event_name == 'push' && needs.detect-changes.outputs.environments != '[]'

    strategy:
      matrix:
        environment: ${{ fromJson(needs.detect-changes.outputs.environments) }}

    steps:
      - name: 'Checkout Code'
        uses: actions/checkout@v4

      - name: 'Setup Terraform'
        uses: hashicorp/setup-terraform@v3

      - name: 'Download Plan Artifact'
        uses: actions/download-artifact@v4
        with:
          name: tfplan-${{ matrix.environment }}-${{ github.event.before }}

      - name: 'Terraform Apply'
        run: |
          terraform init
          terraform apply -auto-approve "tfplan"
        working-directory: ./${{ matrix.environment }}
```

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

### Why?
#### Pros
- Managing a single application or self-contained service across multiple environments.
- Teams that want to minimize boilerplate and avoid duplicating `variables.tf` files.
- Workflows where environments are mostly similar, with differences that can be controlled by variables or simple logic.

#### Cons
While the workspace pattern keeps your code DRY, it may not work when your needs grow and the differences between environments multiply. Your configurations can become filled with complex conditional logic. For example, you might start with one conditional. But soon, you add a `dev` environment that also needs autoscaling. Then `test` needs a specific feature flag.

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
This CI/CD setup uses a powerful GitHub Actions feature called reusable workflows to keep your pipeline DRY and easy to manage. The logic is split into two files: a reusable **worker** that performs the deployment, and a main **orchestrator** that defines the release process.

`reusable-deploy.yml`

Contains all the steps to deploy to any single environment. It accepts an `environment` name as an input, which it uses to dynamically select the correct OpenTofu workspace and `tfvars` file. This means you only have to define your deployment logic once.

```yaml
name: 'Reusable Deploy'

on:
  workflow_call:
    inputs:
      environment:
        required: true
        type: string

jobs:
  deploy:
    name: 'Deploy to ${{ inputs.environment }}'
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment }}

    steps:
      - name: 'Checkout Code'
        uses: actions/checkout@v4

      - name: 'Deploy'
        run: |
          tofu workspace select ${{ inputs.environment }}
          tofu apply -var-file="${{ inputs.environment }}.tfvars" -auto-approve
```

`deploy.yml`

The main pipeline orchestrates the release by calling the reusable workflow for each stage. The `needs:` keyword creates a promotion chain, ensuring `dev` deploys first, followed by `test`, and finally `prod`. Each job simply passes the correct `environment` name to the reusable workflow.

```yaml
name: 'Deploy'

on:
  push:
    branches:
      - main

jobs:
  deploy-dev:
    name: 'Deploy to DEV'
    uses: ./.github/workflows/reusable-deploy.yml
    with:
      environment: dev

  deploy-test:
    name: 'Promote to TEST'
    needs: deploy-dev
    environment: test
    uses: ./.github/workflows/reusable-deploy.yml
    with:
      environment: test

  deploy-prod:
    name: 'Promote to PROD'
    needs: deploy-test
    environment: production
    uses: ./.github/workflows/reusable-deploy.yml
    with:
      environment: prod
```

## Terragrunt Stacks
As your application grows, its infrastructure often evolves from a single component into a **stack** of several interdependent services; like a virtual network, a database, and the application servers that rely on them. The OpenTofu workspace pattern can become cumbersome when managing the deployment order and dependencies of such a stack.

This is where Terragrunt, a thin wrapper for OpenTofu and Terraform, becomes essential. It excels at managing multi-component applications and keeping your configurations DRY.

### Why?
#### Pros
- Applications with multiple, interdependent infrastructure components.
- Scenarios where deployment order is critical (e.g., the network must be created before the database).
- Teams wanting to maximize DRY principles by centralizing backend, provider, and variable configurations.

#### Cons
- **SOMETHING**

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