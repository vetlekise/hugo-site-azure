---
title: Solve Terraform Drift With a Reconciliation Pipeline
description: Build an automated reconciliation pipeline with GitHub Actions to periodically detect and correct Terraform drift.
slug: terraform-drift-reconcile-pipeline
date: 2025-10-05
categories:
- How-To
---

## What is Terraform Drift?
Here's a description from [HashiCorp](https://www.hashicorp.com/en/blog/detecting-and-managing-drift-with-terraform) themselves:
> *Drift is the term for when the real-world state of your infrastructure differs from the state defined in your configuration.*

It can be caused by many things, but urgent hotfixes and teams being unfamiliar with Infrastructure as Code (IaC) practices is the most likely cause. Its a significant problem because it undermines the core benefits of IaC. 

The main issue is the loss of a single source of truth. When your code and infra tell different stories, you can no longer trust your code to be an accurate representation of your environment.

## Applying GitOps Prinicples to Infrastructure
This is where GitOps comes in. As [GitLab](https://about.gitlab.com/topics/gitops/) defines it:
> *GitOps is an operational framework that takes DevOps best practices used for application development such as version control, collaboration, compliance, and CI/CD, and applies them to infrastructure automation*

The core idea is simple:
1. **Describe** your entire desired infrastructure in a Git repository using declarative code.
2. **Automate** a process that coninuously compares this desired state with the actual state of your live infrastructure.
3. **Correct** any detected differences, ensuring the live environment always reflects the state defined in Git.

By adopting this workflow, you treat your infrastructure the same as your application code. Changes are made via pull requests, reviewed by peers, and automatically deployed. This creates an audit trail and, most importantly, provides a mechanism for automatically correcting drift.

## Designing the Reconciliation Pipeline
To combat drift, we can build an automated reconciliation pipeline. This pipeline will periodically check for discrepancies and take actions. Here's two primary approaches:
1. **Detection-only**
    - The pipeline runs `terraform plan` on a schedule. If it detects any differences, it doesn't apply them. Instead, it sends an alert to your team via Slack, creates a GitHub issue, or logs a warning. This approach is safer and gives your team full control over when and how to resolve the drift.
2. **Auto-correction**
    - This is the full GitOps approach. The pipeline runs `terraform plan` to detect drift and, if any is found, immediately runs `terraform apply` to automatically revert the infrastructure to the state defined in your code. This ensures your infrastructure is always in sync but requires a high degree of confidence in your automation and testing.

## Building the Pipeline with GitHub Actions
Our goal is to create a pipeline that runs on a schedule, checks for drift, and automatically applies the correct config if any drift is found.

Create a new file in your repository at `.github/workflows/terraform-reconcile.yml` and add the following code:
```yaml
name: 'Terraform Drift Reconciliation'

on:
  # Allows you to run this workflow manually from the Actions tab
  workflow_dispatch:

  # Runs on a schedule (e.g., every day at 2:00 AM UTC)
  schedule:
    - cron: '0 2 * * *'

jobs:
  terraform-reconcile:
    name: 'Terraform Reconcile'
    runs-on: ubuntu-latest
    defaults:
      run:
        shell: bash

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_wrapper: false

      # Replace this step with the appropriate setup for your cloud (Azure, AWS, GCP).
      # - name: Configure Credentials

      - name: Terraform Init
        id: init
        run: terraform init

      # The -detailed-exitcode flag provides specific exit codes:
      # 0 = No changes, 1 = Error, 2 = Changes detected.
      - name: Terraform Plan
        id: plan
        run: terraform plan -no-color -detailed-exitcode -out=tfplan
        continue-on-error: true

      # This step only runs if the previous `plan` step had an exit code of 2
      - name: Terraform Apply
        if: steps.plan.exitcode == 2
        run: terraform apply -auto-approve tfplan

      # Show a summary
      - name: Post-run summary for drift
        if: steps.plan.exitcode == 2
        run: |
          echo "## Terraform Drift Reconciliation Report" >> $GITHUB_STEP_SUMMARY
          echo "Drift was detected and automatically corrected at $(date)." >> $GITHUB_STEP_SUMMARY
          echo "The `terraform apply` command was executed to bring infrastructure back in sync." >> $GITHUB_STEP_SUMMARY
      - name: No Drift Found
        if: steps.plan.exitcode == 0
        run: |
          echo "## Terraform Drift Reconciliation Report" >> $GITHUB_STEP_SUMMARY
          echo "No infrastructure drift was detected at $(date)." >> $GITHUB_STEP_SUMMARY
```

This workflow uses the `-detailed-exitcode` flag for `terraform plan`. This makes the `plan` step return a code. We use this exist code in a conditional step to ensure that the `terraform apply` runs or not.

## Best Practices and Considerations
Before deploying this in a production environment, consider the following:
- **Start with** `detection-only`
    - Begin by removing the `terraform apply` step and adding a notification step instead. Let the pipeline run for a while to see how often drift occurs.
- **Limit scope**
    - Initially, run this pipeline only on non-critical environments, like development.
- **Secure your credentials**
    - OIDC is the most secure way to authenticate with your provider, as it provides short-lived, automatically rotating credentials.
- **Use notifications**
    - Even with auto-correction, you can still notify your team when drift is detected and corrected. Consider adding a step to send a message to a Slack channel to keep everyone informed.
- **Role-based access control (RBAC)**
    - The user that did a manual change (ClickOps), do they really need permission to do so?

## Conclusion
Drift is natural when managing complex systems, expecially in immature environments where processes haven't been fully developed. By implementing an automated reconciliation pipeline, you eliminate configuration drift that also leeads to more stable and predictable environments. It's a good step towards a mature environment.