---
title: Deploy a Hugo Website To Azure Using Terraform And GitHub Actions For Free
description: Learn how to deploy an Azure Web App for hosting a static website using Hugo, set up deployment pipelines using GitHub Actions, and host it on Azure-all at no cost. Also learn how to configure a custom domain.
slug: hugo-site-azure
date: 2025-09-17
image: cover.jpg
categories:
    - How-To
tags:
    - Hugo
    - Azure
    - Terraform
    - IaC
    - GitHub
    - GitHub Actions
    - Domain
    - CI/CD
---

## Prerequisites
To complete this guide, you need the following already set up:
- An **Azure Tenant** with a **subscription**.
- An **Entra ID** account with the `Application Administrator` role, and the **Azure** `Owner` role on the subscription.
- A **GitHub** account with a repository.
- Required software installed locally:
    - Git