# Why should you embrace GitOps for your data streams?

GitOps, it’s a term you’ve probably heard floating around the industry for some time now. You’d be forgiven for dismissing it as another *SomethingOps* that will magically solve all your problems. After all, we’ve already had DevOps, SecOps and even NoOps, where do you begin? Why not just set up your streaming infrastructure manually, get backups in place and be done with it?

The truth is, sadly, that managing Apache Kafka clusters can very rapidly go from straightforward to complex. As organizations grow, so do the operational challenges. What happens when one Kafka cluster becomes five? When a small DevOps team scales to dozens of developers? How do you guarantee that staging mirrors production, or instantly roll back a breaking change made on a Friday? 

A UI such as the StreamsHub Console is a great tool for visualizing, debugging and exploring your data streams as it can give you deep insight into the state of your topics, brokers and consumer groups etc. Yet, it can’t give you everything you need to manage scaling your infrastructure effectively. It doesn’t give you *reproducibility, auditability, effective collaboration or disaster recovery,* things you **will**  need as you grow. 

This is where GitOps comes into the picture, it gives you the reliable, automated workflow you need to define and manage your infrastructure safely and predictable at scale. If you combine this with the real-time insight the console provides, it will empower you to manage your Kafka clusters with confidence.

# What is GitOps, really?

To understand GitOps, we first need to understand its evil twin ClickOps\! Ok, so it’s not evil per se, we’ve all done ClickOps at some point in our lives. Have you ever opened up a dashboard, clicked through some menus, or run a few commands to spin up a cluster and deploy your application? Everyone has, right? And with good reason, it works… that is until you need to recreate the same setup somewhere else. Which default options did you change? Did you remember to note down what tweaks you made during the last incident post-mortem? Your team member said they toggled an option but they don’t remember which one…

GitOps helps you avoid issues like these. At its core, GitOps applies the proven principles of version control and CI/CD to infrastructure i.e. treating operations the same way we treat code.

With GitOps, you skip clicking through menus and checking boxes. Instead, you describe your system in a set of configuration files stored in a git repository. This repository becomes your **single source of truth** for how everything should look. You then rely on automation to turn your description into reality.

From this we can say that GitOps is built on three core principles:

* **Use a fully declarative approach:** Everything, from Kafka topics & users to the clusters themselves should be described in code, ensuring consistency across environments.  
* **Use version control:** Every change goes through Git commits and pull requests, giving you a full history and easy rollbacks.  
* **Automatic reconciliation:** A Continuous Deployment (CD) agent automatically rolls out changes you commit to your git repository.

Following these principles will make your operations more reliable, auditable and automated helping teams move faster, with greater confidence.But to truly understand why this shift is necessary, we need to look at what happens when these principles are missing.

**The ClickOps Trap:** Meet BillyBob, a lead engineer on a payments team. He was recently asked to migrate their Kafka cluster to a new Kubernetes environment—a task that should have been routine but quickly turned into a nightmare.

The original cluster had evolved through months of manual *ClickOps* changes, leaving no single source of truth. Some settings were adjusted during late-night incidents; others were “temporary” performance tweaks that were never documented or reverted.

When rebuilding the cluster, BillyBob had to rely on memory and outdated documentation. He unknowingly missed several critical configuration overrides the original cluster depended on for stability. Once production traffic hit, the new environment began to fail—and with no version history, the team had no clear way to see what the working configuration had actually been.

BillyBob’s weekend wasn’t ruined by a lack of skill, but by a lack of system. His story highlights the hidden tax of ClickOps: as systems grow more complex, migrations and recovery become high-stakes guessing games. GitOps addresses these challenges at the root by making configuration explicit, versioned, and auditable.

# From ClickOps to GitOps

So what are the real benefits of leaving behind ClickOps to embrace a GitOps approach? As systems scale, relying solely on a UI to manage environments introduces challenges that become difficult to ignore:

* **Reproducibility:** It’s nearly impossible to guarantee that development, staging, and production environments are identical when changes are made manually through the UI.  
* **Auditability:** When changes happen outside version control tracking “who changed what, and why” is often lost.  
* **Collaboration:** When you have multiple team members making manual updates they can easily step on each other’s changes.  
* **Disaster Recovery:** Rebuilding environments after a failure becomes a manual, stressful, and error-prone process.

As we’ll see, the core principles of GitOps we looked at earlier elegantly solve these problems. 

Firstly, by embracing the *declarative* approach to defining your infrastructure as code, you gain reproducibility. If you want your staging environment to exactly mirror production, but with fewer replicas perhaps, or a different storage class, you only need to describe the differences from your base environment. This is also where disaster recovery comes in, you’ve already defined the blueprints for your infrastructure, there’s no need to attempt to manually redeploy and configure each system in a panic by following documentation that’s probably long out of date.

Secondly, by committing to storing your configuration in a Git repository, you now have a full audit trail. This centralized history transforms your infrastructure from a "black box" of manual updates into a transparent timeline of events:

* what changes were made:  By looking at the "diff," you see exactly which lines of code were altered.  
* when they were made: Every commit is timestamped, allowing you to correlate infrastructure changes with application performance or system spikes.  
* why where they made: The PR description and commit messages provide the business context for the change.  
* who made them: The Git history identifies the specific developer who proposed the modification, ensuring accountability.  
* who signed off on these changes: The PR approval history shows which team members reviewed and authorized the update before it hit production.

What’s more, you get several powerful collaboration features for free directly in your Git commit log:

* Effective Team Collaboration**:** Multiple team members can work on the same infrastructure simultaneously without "stepping" on each other’s changes or erasing work made earlier in the day.  
* Built-in Conflict Resolution**:** If two people attempt to modify the same configuration, Git will automatically flag the conflict and require a resolution before the changes can be merged.

Convinced yet? If not, hopefully seeing what the third principle of GitOps gives you will seal the deal. As we mentioned earlier, *automatic reconciliation* is an essential part of the philosophy. By automating the rollout of changes merged to your git repository, you remove the time consuming and error prone process of manually effecting these changes to your infrastructure. Who wants to change the same base config in *every* Kafka cluster you manage? Also, the benefits of this automation roll forward to future processes, whether deploying a new service, handling updates, or recovering from a systems failure.

At this point, we hope the power of GitOps is clear.

## Applying GitOps to Strimzi-Managed Kafka

Now that we’ve made the general case for using GitOps to manage your operations, let’s take a look at how this applies to your Strimzi-managed Kafka cluster. The Strimzi project, which provides the foundation for managing Kafka on Kubernetes, is a natural fit for a GitOps workflow.

Strimzi provides a full set of Kubernetes Custom Resource Definitions (CRDs) for configuring all aspects of your Kafka cluster. You can write your own Custom Resources as YAML files that describe exactly *what* you want your Kafka infrastructure to look like.

To illustrate this idea with an example, instead of creating a topic manually, you would create a KafkaTopic resource in a YAML file and let the Strimzi operator make it a reality. Your git repository then becomes home for all of your resource definitions:

* Your Kafka cluster definition (define e.g. brokers, storage)  
* Your KafkaTopic resources (e.g. partitions, replication factors)  
* Your KafkaUser resources (for authentication and authorization)  
* Your KafkaConnector and KafkaConnect resources (for connecting with external data systems)

These Strimzi resources let you specify exactly how your Kafka cluster should be configured and operate.

Let’s look at a practical example. In our hypothetical scenario, a developer on the **Payments** team needs to increase a topic's data retention from **7 days** to **14 days** to satisfy a new audit compliance requirement.

1. The Edit: The developer navigates to the team’s Git repository `kafka-config` and locates and finds the file: `dev/payments-cluster/topics/payments.yaml`.  
2. The Change**:** They edit the file, changing `retention.ms: 604800000` (7 days) to `retention.ms: 1209600000` (14 days).  
3. The PR: They open a Pull Request: 'Extend payments topic retention to 14 days for audit compliance.  
4. Linting: A GitHub Action automatically lints the YAML file to ensure it is valid Strimzi syntax.  
5. Review: A teammate reviews the PR, sees the specific configuration change, and merges it.  
6. GitOps Sync: A GitOps agent (like Argo CD) detects the merge, pulls the new `KafkaTopic` definition, and applies it to the cluster.  
7. Operator Execution: The Strimzi Topic Operator detects the updated resource and dynamically reconfigures the Kafka broker without any downtime or partition disruption.  
8. Verification: The developer opens the StreamsHub console to verify the 'Retention Time' property has been updated.

Using this workflow, our team gains the following:

* Safety: The configuration change was reviewed and approved by a peer before being applied to the cluster.  
* Auditing: You have a permanent record of who, what, and why the change was made.  
* Consistency: The retention policy is now defined as code, ensuring that the same configuration can be tested in staging before being promoted to production.  
* Easy Rollbacks:  If the increased retention time causes unexpected disk pressure, the team can simply revert the Pull Request in Git. The GitOps agent will detect the revert and automatically restore the topic's retention to its previous 7-day setting, allowing Kafka to immediately begin cleaning up older data segments.


This is the power of combining an automated Git-based workflow for managing state with the StreamsHub console for visualising and monitoring that state.

## The GitOps Toolkit

There are a wide variety of great OpenSource tools available to help you define your infrastructure as code and to automate deployment and testing of changes your team makes to it. In a future article we’ll take you through using these tools to bootstrap your GitOps workflow with examples, but for now let’s take a high-level look at some of what’s on offer.

### Manifest and Configuration Tools

These tools enable you to create, manage and template the configuration files that define your resources. As your project grows, you’ll find you don’t want to copy and paste the same 50-line KafkaTopic definition for your development, staging and production environments. Let’s look at two of the popular ones for Kubernetes.

#### Kustomize

This tool is built directly into kubectl (the cli for Kubernetes) and is excellent for managing environment specific configurations. It lets you define a common base set of yaml files and then apply small patches (called “overlays”) for each environment, such as changing the replica count for production or the storage class for staging, without messy templating.

#### Helm

Helm markets itself as “The package manager for Kubernetes”. It’s useful for bundling complex applications into a single, configurable “chart” that you can deploy and manage as one unit. Under the hood, it relies on templating: your YAML manifests are written with placeholders that get substituted with values at install time, so the same chart can produce a lightweight development deployment or a fully scaled production one just by swapping out a values file.

#### Ansible

Ansible is more generalised than the first two tools we’ve looked at. It is an automation language that can be used to describe any IT environment. You could use it by itself to manage your entire infrastructure and application deployments, however it’s often used alongside one of the above tools to define and bootstrap the underlying platform infrastructure, like your OS and Kubernetes nodes, whilst leaving your application definition to Kustomize or Helm.

#### Terraform

Terraform also focuses on the underlying infrastructure and whilst there is overlap with Ansible, its specialty is in configuring and managing the lifecycle of your cloud infrastructure, think VMs, networks, security groups, and the Kubernetes cluster. 

### Automation Tools 

Let’s take a look at some tools that can help you get the most out of your GitOps workflow by automating validation and rollout of the changes you make to your configuration. You will probably already be familiar with many of these tools as they’re already industry standards for Continuous Integration / Continuous Deployment. They give you the “bang for your buck”, so to speak, by reducing the engineering effort and error rates inherent to rolling out changes to your infrastructure manually.

#### Argo CD

Argo CD is a declarative, GitOps continuous delivery (CD) tool specifically for Kubernetes.

Its main job is to run inside your Kubernetes cluster, constantly monitor a Git repository, and automatically sync your live application state to match the "desired state" defined in that repository. It's best known for its powerful web UI, which gives you a real-time, visual dashboard to see sync status, application health, and any differences between what's in Git and what's running in the cluster.

#### Flux

Flux fulfills the same role as Argo CD however, Flux is "API-centric" and doesn't come with a built-in UI; it's a collection of specialized controllers (for managing Git repos, Helm charts, Kustomizations, etc.) that you can compose together, making it highly flexible and a favorite for teams who want to build a more custom, lightweight GitOps platform.

# Wrapping Up

While  the StreamsHub console is a fantastic tool for monitoring, exploring, and debugging your streaming infrastructure to effectively manage it at scale, application environments, configurations, and definitions need to be declarative and version-controlled. Also, managing your application lifecycle and its deployment should be automated, easy to understand, and completely auditable. This is what GitOps brings to the table, by adopting it, you’re establishing a powerful, resilient workflow for your operations.

## Next Steps

To get some hands-on experience and to see the GitOps principles we looked at in action you can try our three part interactive tutorial series on the fundamentals of GitOps in action.

\[PLACEHOLDER LINK TO THE THREE LESSONS WHEN COMPLETE\]

