+++
title = 'GitOps Tutorial Series: Lesson 1 Companion Guide'
+++

# Introduction

In our introductory article, “Why should you embrace GitOps for your data streams?” we explained how GitOps applies the proven principles of version control and CI/CD to infrastructure, allowing you to treat operations the same way you treat code. 
With GitOps, you skip clicking through menus and checking boxes. 
Instead, you describe your system in a set of configuration files stored in a git repository. 
This repository becomes your *single source of truth* for how everything should look. 
You then rely on automation to turn your description into reality.

This tutorial aims to give you a practical demonstration of two key GitOps concepts, Infrastructure as Code and the reconciliation loop, alongside two tools that bring them to life: Kustomize and Argo CD.

# Core Concepts

## Infrastructure as Code

Infrastructure as Code (IaC) is the practice of managing and provisioning your infrastructure using configuration files rather than manual processes, e.g. ClickOps. 
By treating infrastructure as code, you define your system's desired state in configuration files and check them into a version control system like a git repository. 
This approach transforms operations, allowing you to track changes, collaborate, and automate deployments.

Key benefits of adopting IaC include:

* **Consistency and eliminating configuration drift**: By using versioned configuration files, you ensure environments remain consistent, effectively eliminating the manual changes that cause configuration drift.  
* **Disaster recovery**: Because your infrastructure state is codified in version control, rebuilding your environment in the event of a failure is as straightforward as applying your existing configurations.  
* **Reproducible builds**: IaC enables reliable, repeatable infrastructure deployments, ensuring that the same configuration results in the same environment every time.

## Kustomize

Kustomize is a configuration management tool built directly into kubectl that simplifies managing Kubernetes objects. 
It enables Infrastructure as Code by allowing you to define a common "base" set of configuration files and then apply "overlays" to patch them for different environments, such as staging or production, without relying on messy templating. 
This ensures that your configurations remain clean, consistent, and reproducible. 

Throughout these lessons you will create, edit and deploy Kustomize manifests to effect changes to the deployed cluster. 
You can learn more in the [official Kustomize documentation](https://kustomize.io/).

## The Reconciliation Loop

The reconciliation loop is the mechanism that transforms Infrastructure as Code into actual, running infrastructure by continuously monitoring and automatically applying changes to reach the desired state. 
By choosing off-the-shelf tooling, you gain significant speed and operational efficiency from this automation. 
Popular tools that implement this reconciliation pattern include ArgoCD and Flux.

## Argo CD

ArgoCD is an open-source, continuous delivery tool that runs inside your Kubernetes cluster and implements the reconciliation loop described above. 
It is the CI/CD technology you will be working with in all the lessons in this series. 

You tell ArgoCD what to watch by creating an *Application* resource, a small piece of configuration that says: "monitor this Git repository, look at this directory path, and deploy whatever you find there into this namespace." 
ArgoCD then polls the repository on a regular interval (every three minutes by default, however in our tutorial series we’ve reduced that to thirty seconds for convenience), renders the manifests it finds, and syncs the cluster to match.

ArgoCD exposes the state of this process through two key concepts: *sync status* and *health status*. 
*Sync status* tells you whether the cluster matches the configuration in your Git repository; *Synced* means they match, whereas *OutOfSync* means ArgoCD has detected a difference and will act on it. 
In the lesson, you will see this status transition when you push a change: it moves from *Synced* to *OutOfSync* (ArgoCD noticed the new commit) and back to *Synced* (ArgoCD applied the change). 
Health status is a separate concern that tells you whether the resources themselves are functioning correctly, we’ll explore health status in more detail in Lesson 3\. 

# What to watch for in the lesson

Now that you’ve looked at the core concepts and technologies you’ll be working with in this lesson, it’s almost time to dive in, but as you do look out for these moments where the concepts above become concrete:

\- When you edit \`kustomization.yaml\`, you are declaratively changing the desired state of the cluster.  
\- When you run \`git push\`, you are updating the single source of truth. From this moment, the configuration in the repository says a topic should exist.  
\- When ArgoCD's status transitions from \`Synced\` to \`OutOfSync\` and back to \`Synced\`, you are watching the reconciliation loop complete a full cycle: observe the change, calculate the required changes and then roll them out.  

Now you’re ready to try the first lesson, run through the setup guide to deploy a local Kubernetes cluster and then check out the lesson 1 readme to run through the tutorial. 
