# Hugo - Azure Static Web App
A Hugo static site hosted on Azure, with fully automated infrastructure and application deployments.

## Create a New Post
Follow these steps to create a new post:
1. Create a new folder inside `./src/post` named after your post title.
2. Inside your new folder, add an `index.md` file.
    -  **Optional**: Add a cover image to this folder if desired.
3. Add *frontmatter* at the top of `index.md` (see template below) and write your content.
4. Save your changes and commit to the *main* branch.

### Example Tree
```bash
post/
  └── title/
      ├── cover.jpg
      └── index.md
```

### Frontmatter Template

```yaml
---
title: About
slug: about
description: Hugo, the world's fastest framework for building websites
date: '2019-02-28'
lastmod: '2020-10-09'
categories:
    - Example
tags:
    - Example
aliases:
  - example
license: CC BY-NC-ND
image: cover.jpg # resolution: 1000 px × 667 px
weight: 1 # You can add weight to some posts to override the default sorting (date descending)
menu:
    main: 
        weight: 1
        params:
            icon: user
---
```

## Pre-defined Values

### Categories
- **How-to**  
    - Step-by-step guides for accomplishing specific tasks or resolving issues.  
    *Example titles (Setup guides): "Deploy a Hugo Site to Azure Static Web Apps", "Setting Up Automated CI/CD for Your Blog"*  
    *Recommended tag: `setup`*
    *Example titles (Troubleshooting guides): "Fix Permission Errors in Azure Static Web App Deployments", "Resolve Build Failures in Hugo Projects"*  
    *Recommended tag: `troubleshooting`*
- **Best Practices**  
    - Recommendations and tips for optimal approaches.  
    *Example titles: "Best Practices for Managing Infrastructure as Code with Terraform", "Optimizing Static Site Performance on Azure"*
- **Thoughts**  
    - Personal perspectives or commentary on technology topics.  
    *Example titles: "Why Automated Deployments Matter for Modern Web Projects", "The Case for Using Azure over Other Cloud Providers"*

### Tags
- Application (Terraform, GitHub, Python)
- Practice (CI/CD, DevOps, IaC)
- How-to (Setup, Troubleshooting)
