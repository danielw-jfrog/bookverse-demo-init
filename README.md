BookVerse Example
=================

BookVerse Example is a cloud-native microservices reference application that demonstrates secure software delivery using
the JFrog Platform.  Built as an online bookstore, it comprises an inventory service for product catalog management, a
recommendations service powered by machine learning, a checkout service for order processing, a vanilla JavaScript web
application, shared infrastructure libraries, helm charts for Kubernetes deployment, and a platform service for
integration testing — each showcasing distinct CI/CD build patterns ranging from single-container deployments to
multi-artifact library publishing.

The project's primary purpose is to provide a complete, end-to-end reference architecture for JFrog's enterprise-grade
software supply chain security.  It leverages JFrog AppTrust with 14 automated policy gates spanning four lifecycle
stages (DEV, QA, STAGING, and PROD), cryptographically signed evidence collection, SLSA provenance verification, and
multi-layer security scanning (SAST, DAST, penetration testing, and IaC).  Deployments are managed through GitOps
workflows with ArgoCD, and the entire environment — including JFrog Platform provisioning, GitHub repository creation,
and OIDC integration — can be stood up automatically through the orchestration workflows in this repository.

[What is BookVerse Example?](docs/what_is_bookverse_example.md)

[Documentation](docs/index.md)

[Getting Started Guide](docs/GETTING_STARTED.md)

[Application Architecture Overview](docs/application_architecture.md)

[Delivery Architecture Overview](docs/delivery_architecture.md)

[Demo Runbook](docs/DEMO_RUNBOOK.md)

[AppTrust Showcase Guide](docs/apptrust_showcase_guide.md)


Demonstration Notice
--------------------

This is a demonstration project designed to showcase JFrog AppTrust integration patterns and modern DevOps workflows.
The architecture described in this repository may be more aspirational than what is actually implemented.  As a demo
project, some features and capabilities described here may be simplified or not fully implemented.

For production deployments, additional enterprise-grade features such as comprehensive monitoring, distributed tracing,
advanced security controls, and high-availability configurations would typically be required.


Quick Start
-----------

1. Fork `bookverse-demo-init` repository (this one) to your user or organization.  This repository contains all of the
   actions and script necessary to setup and cleanup the workflows and JFrog Platform.  Only forking this repository is
   required as the first action to run will fork the remaining git repositories.

2. Set necessary secrets for the workflows.  These secrets can be set on the _Settings -> Secrets and variables ->
   Actions_ page in the _Repository Secrets_ section.

   * `JFROG_ADMIN_TOKEN` - An admin level token for the JFrog Platform installation that will be used.

   * `GH_TOKEN` - A GitHub Personal Access Token (PAT) classic with _'repo'_, _'workflow'_, and _'admin:repo_hook'_
                  permissions.  This is required to fork the other repositories and setup the project.

3. Set necessary variables for the workflows.  These variables can be set on the _Settings -> Secrets and variables ->
   Actions_ page in the _Repository Variables_ section.

   * `JFROG_URL` - The URL of the JFrog Platform installation that will be used.  This should start with _https://_ as
                   all good HTTPS URLs should.

   * `PROJECT_KEY` - The Project Key that will be used on the JFrog Platform when setting up the example project.

3. Run the _Step 1: Initialize Repositories_ action.  This can be found on the _Actions_ tab.  Use the settings below to
   configure the initial setup run.

   * Generate Evidence Keys: `false`

   * Evidence Key Alias: `bookverse-signing-key`

   * Update K8s: `false` Set this to false to skip configuring Kubernetes for the initial run.

4. Run the _Step 2: Setup Platform_ action.  This can be found on the _Actions_ tab.  No settings are required for this
   action.

5. Run the _Step 3: Setup Kubernetes and ArgoCD_ actin. NOTE: THIS DOESN'T EXIST YET!

[//]: <> (FIXME: This should be created to split the Kubernetes and ArgoCD setup to a separate action.)

6. Run the _Step 3: Initial Build Actions_ action.  NOTE: THIS DOESN'T EXIST YET!

[//]: <> (FIXME: This should be created to run each of the build actions in each of the sub projects.)


Cleanup
-------

1. Run the _Cleanup (Preview & Execute)_ action.  If running the preview, there's not arguments required.  If performing
   the actual cleanup, type the word `DELETE` into the box and change the Operation Mode to `execute`.

2. The BookVerse Example can be redeployed by starting again at the second step of the Quick Start above.  Or the
   repository forks for BookVerse Example can be deleted to removed to fully cleanup the project.


Component Repositories
----------------------

More information is available in the [Application Architecture](docs/application_architecture.md) and
[Delivery Architecure](docs/delivery_architecture.md) documentation.

**NOTE**: Individual service documentation is available in each service repository:

* [Checkout Service](https://github.com/bookverse-example/bookverse-checkout)

* [Demo Assets](https://github.com/bookverse-example/bookverse-demo-assets)

* [Helm Charts](https://github.com/bookverse-example/bookverse-helm)

* [Infrastructure Libraries](https://github.com/bookverse-example/bookverse-infra)

* [Inventory Service](https://github.com/bookverse-example/bookverse-inventory)

* [Platform Service](https://github.com/bookverse-example/bookverse-platform)

* [Recommendations Service](https://github.com/bookverse-example/bookverse-recommendations)

* [Web Application](https://github.com/bookverse-example/bookverse-web)
