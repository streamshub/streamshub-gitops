+++
title = 'GitOps Tutorial Series: Lesson 3'
+++

# Introduction

In lesson 1, you made your first GitOps change: you edited a configuration file, pushed it to your Git repository, and watched ArgoCD reconcile the cluster to match. 
In lesson 2, you scaled that workflow across multiple environments using Kustomize overlays, promoting a change from staging to production with nothing more than a configuration change and Git commit.

But what happens when a change that looks perfectly valid turns out to be wrong? 
The YAML is well-formed, Kubernetes accepts it, and ArgoCD reports a successful sync. 
Yet underneath, the system is broken. 
The configuration you pushed describes something the underlying platform cannot actually do. 
This is not a hypothetical edge case. 
It is a failure mode that every team running production infrastructure will encounter sooner or later.

This lesson tackles that scenario head-on. 
You will learn how to distinguish between a successful sync and a genuinely healthy deployment, and when things go wrong, how to roll back safely with a single commit.

# Core Concepts

## Sync Status vs Health Status

ArgoCD tracks two independent statuses for every Application it manages. 
*Sync status* tells you whether ArgoCD successfully applied the configuration files from your Git repository to Kubernetes. 
When the Kubernetes API accepts the YAML, the Application is `Synced`. 
*Health status* tells you whether the resources are actually functioning correctly.

These two statuses are independent. 
A resource can be `Synced` but `Degraded` or stuck in `Progressing` indefinitely. 
This happens when Kubernetes stores the desired state without complaint, but the controller responsible for that resource cannot fulfil it. 
A deployment is only truly complete when it is both Synced and Healthy. 
Treating sync alone as a green light is a common and dangerous mistake.

## Why "Synced but Unhealthy" Matters

ArgoCD's responsibility ends at the Kubernetes API server. 
It renders your manifests, applies them and confirms that Kubernetes accepted the request. 
But whether the underlying platform, be it a message broker, a database, or any operator-managed system, can actually honour the change is a separate concern entirely.

Consider a configuration change that the Kubernetes API accepts but the platform rejects. 
The Custom Resource is stored, so ArgoCD reports `Synced`. 
But the operator that manages that resource inspects the change, determines it violates a constraint of the system it manages and marks the resource as not ready. 
ArgoCD sees this and reports `Progressing` or `Degraded`, but it cannot fix the problem. 
The system is now in a state where the GitOps engine has done its job, yet the deployment is broken. 
This is precisely the situation that demands a rollback.

## Rollback as a Git Commit

As you saw in Lesson 2, promotion was not a special operation, it was a change in configuration, pushed to a Git repository. 
In precisely the same vein, a rollback is not a special operation. 
There is no dedicated rollback command, no emergency cluster access, and no deployment pipeline to trigger. 
The Git repository is the single source of truth, so fixing the cluster means fixing the configuration in the repository. 
You simply create a new commit that returns the configuration to a known-good state, push it, and the reconciliation loop does the rest.

This is the same workflow you used to deploy the original change. 
The only difference is that the commit undoes something rather than introducing something new. 
From Git's perspective, and from ArgoCD's, it is just another commit.

## `git revert` vs `git reset --hard`

There are two ways to undo a commit in Git, and they have very different implications in a GitOps context.

`git revert <commit hash>` creates a new commit that applies the exact inverse of the target commit. 
The breaking change stays in the history and the record of the rollback sits on top of it, maintaining an intact audit trail.
This approach is additive and safe on shared branches because it does not alter any existing commits.

`git reset --hard` followed by a force-push takes the opposite approach. 
It rewrites history, removing the bad commit as if it never happened. 
This is an anti-pattern as the audit trail is destroyed, leaving no record of the incident or its resolution. 

The correct choice is `git revert`. 
It preserves the full sequence of events and keeps the repository in a state that every collaborator can safely pull from.

## Self-Healing Reconciliation

Once the revert commit is pushed, the recovery is automatic. 
ArgoCD detects the new commit on its next poll cycle and applies them to the cluster. 
The operator sees the resource return to a valid state and marks it healthy. 
No manual intervention on the cluster side is required.

The complete sequence of the breaking change, failure and recovery is preserved in the Git commit history for anyone to inspect. 
This is the power of treating your Git repository as the single source of truth: even incidents become part of the auditable record.

# What to watch for in the lesson

Now that you have explored the core concepts behind rollback and health monitoring, it is time to dive in. 
As you do, look out for these moments where the concepts become concrete:

* When ArgoCD shows `Synced` but `Progressing` after you push the breaking change, you are seeing the sync/health distinction in action. ArgoCD did its job, but the underlying system did not accept the change.
* When you inspect the resource and see `Ready: False` with a reason explaining why the operation was rejected, you are seeing the platform enforce its own constraints independently of Kubernetes.
* When you run `git revert` and push, you are performing a GitOps rollback. It is a new additive commit, it doesn't re-write history and the audit trail remains intact.
* When the Application returns to `Synced` and `Healthy` without any kubectl commands, you are watching the self-healing reconciliation close the loop.

Now you are ready to try the third lesson. 
If you haven't already, clone the tutorial repository from GitHub:

```bash
git clone https://github.com/streamshub/streamshub-gitops.git
cd streamshub-gitops
```

If this is your first lesson, follow the setup guide at `lessons/00-setup` to deploy a local Kubernetes cluster with all the required components. 
This takes about eight minutes and only needs to be done once. 
If you have already completed the setup as part of a previous lesson, you can skip this step.

When you're ready, open the lesson 3 README at `lessons/03-lesson-3/README.md` and work through the tutorial.
