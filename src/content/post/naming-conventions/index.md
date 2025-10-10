---
title: Why Your Naming Convention Is Slowing You Down
description: Complex naming conventions, specifically for cloud resources, create more problems than they solve. This post covers the hidden costs and an alternative approach.
slug: naming-conventions
date: 2025-09-21
categories:
- Discuss
---

## Introduction

Yep. I hate naming things.

Most, if not all companies, loves to create global naming conventions for their resources. These conventions often become counterproductive and make creating resources a chore. Also, when you're working with multiple customers at once, this becomes an even greater challenge. 

## The Hidden Costs of Complex Names

- **Cognitive overhead**
    - A name like `app-p-nwe-rg` isn't easy to read; it's a code that needs deciphering. This adds mental friction for everyone who interacts with the system.
- **Brittleness and lies**
    - Cloud resources are dynamic. What happens when the app in `nwe` (Norway East) is migrated to West Europe? Renaming is often impossible, so the name becomes a lie, making it even harder to understand.
- **Maintenance and enforcement**
    - You have to write extensive documentation for the naming convention, build complex validation rules (e.g., regex in pipelines), and constantly update both. This is a time sink that doesn't deliver value.
- **Different world views**
    - People are different. Some will try to change it to support their specific view of the world. This adds friction.

## Names for Humans, Tags for Machines
Resource names should describe its **purpose**, while its metadata should be handled by **tags**.
- **Meaningful names**
    - A developer should be able to name a resource without consulting a document. For globally unique resources, appending a random string or integer is an effective solution.
- **Structured metadata with tags**
    - Tags are the native cloud solution for metadata. They are key-value pairs that are searchable, can be used for cost allocation, and can trigger automated policies.
- **Example**
    - Instead of `app-p-nwe-rg`, the resource would simply be named `my-application`. The metadata is captured in tags:

| Key | Value |
|--|--|
| environment | production |
| cost_center | 12345 |
| owner | team-alpha |
| application | my-application |

The resource's type (`Resource Group`) and location (`Norway East`) are already first-class properties of the resource, so embedding them in the name is redundant.

## How to Make it Work
**Automate enforcement**: use cloud-native tools like **Azure Policy** or **AWS Service Control Policies (SCPs)** to enforce the presence of required tags. You can create policies that deny the creation of any resource missing a tag. This is far more effective than manual enforcement.

**Keep it simple**, start with a minimal set of required tags and only add more as a clear need arises.

## Conclusion
By letting names be simple identifiers and using tags for metadata, teams can move faster, reduce maintenance overhead, and build a more flexible and understandable  environment.

*Let names be names, and let metadata be tags*