BookVerse Example
=================

[//]: <> (FIXME: Give an executive summary here.)

[What is BookVerse Example?](docs/what_is_bookverse_example.md)

[Indepth Documentation](docs/index.md)


Quick Start
-----------

1. Fork `bookverse-demo-init` repository (this one) to your user or organization.  This repository contains all of the
   actions and script necessary to setup and cleanup the workflows and JFrog Platform.  Only forking this repository is
   required as the first action to run will fork the remaining git repositories.

1. Set necessary secrets for the workflows.  These secrets can be set on the *Settings -> Secrets and variables ->
   Actions* page in the *Repository Secrets* section.

   * `JFROG_ADMIN_TOKEN` - An admin level token for the JFrog Platform installation that will be used.

   * `GH_TOKEN` - A GitHub Personal Access Token (PAT) classic with *repo*, *workflow*, and *admin:repo_hook*
                  permissions.  This is required to fork the other repositories and setup the project.

1. Run the `Step 1: Initialize Repositories` action.  This can be found on the `Actions` tab.  Use the settings below to
   configure the initial setup run.

   * Setup Mode: `initial_setup`

   * JFrog Platform Host: `https://<JPD_URL>`  This will be the URL for your JFrog Platform.
     e.g. `https://example.jfrog.io`

[//]: <> (FIXME: Should the Platform Host / URL be moved to a secret?)

   * Admin Token: Leave empty as it has been configured in a secret.

[//]: <> (FIXME: Should this value be removed and the secret forced?)

   * Generate Evidence Keys: `true`

   * Evidence Key Type: `rsa`  Can be `rsa`, `ec`, or `ed25519`.

   * Evidence Key Alias: `bookverse-signing-key`

   * Update Code URLs: `false` Set this to false to skip this step for the initial run.

[//]: <> (FIXME: What does this do?  Should it be removed?)

1. Run the `Step 2: Setup Platform` action.

1. Run the `Step 3: Initial Build Actions` action.

[//]: <> (FIXME: This should be created to run each of the build actions in each of the sub projects.)











---

### Step 3: Provision JFrog Platform Infrastructure

After Switch Platform completes successfully, run the **🚀 Setup Platform** workflow to provision JFrog infrastructure:

1. Navigate to: `https://github.com/YOUR-ORG/bookverse-demo-init/actions`
2. Select **"🚀 Setup Platform"** workflow
3. Click **"Run workflow"** (no inputs required)

**What the Setup Platform workflow does:**
- ✅ Creates the `bookverse` project in JFrog Platform
- ✅ Sets up artifact repositories (Docker, PyPI, npm, etc.)
- ✅ Configures AppTrust applications with lifecycle stages (DEV, QA, STAGING, PROD)
- ✅ Creates OIDC integrations for GitHub authentication
- ✅ Sets up users and role-based access control

---

### ✅ Setup Complete!

After both workflows complete successfully, your BookVerse platform is ready! 

**📋 Next Steps**: Continue with the [Getting Started Guide](docs/GETTING_STARTED.md) for complete setup instructions including Kubernetes deployment.

---

### Alternative: Legacy Local Scripts (Deprecated)

**⚠️ Note**: The old approach using local scripts (`update_evidence_keys.sh`, `configure-service-secrets.sh`) is **deprecated** and only available for backward compatibility. 

**Why use Switch Platform workflow instead?**
- ✅ Better error handling and validation
- ✅ Integrated evidence key generation
- ✅ Automated configuration across all repositories
- ✅ Code URL updates (for platform migrations)
- ✅ Single workflow for all configuration
- ✅ No local environment setup required
- ✅ Workflow-based with comprehensive logging
- ✅ Automatic retry logic for failed operations

---

## 🎯 Where Do You Want to Start?

Choose your path based on your needs:

- **🚀 Quick Start**: Follow the [Getting Started Guide](docs/GETTING_STARTED.md) for rapid deployment
- **🏗️ Deep Dive**: Explore the [Platform Architecture Overview](docs/ARCHITECTURE.md) for detailed system understanding  
- **🎮 Demo**: Run through the [Demo Runbook](docs/DEMO_RUNBOOK.md) for hands-on experience

---

## 🏗️ Platform Architecture

BookVerse consists of seven integrated components that work together to deliver a complete microservices ecosystem, each showcasing different CI/CD patterns and deployment strategies:

### 📦 **Inventory Service**

#### Product catalog and stock management

- Real-time inventory tracking and availability management
- RESTful API for catalog operations and stock queries
- SQLite database with comprehensive book metadata
- Automated stock level monitoring and alerts

**Build Pattern**: Single-container application - demonstrates basic containerized service deployment with minimal complexity

### 🤖 **Recommendations Service**

#### AI-powered personalized recommendations

- Machine learning recommendation engine with configurable algorithms
- Real-time recommendation generation (sub-200ms response times)
- Scalable worker architecture for background processing
- Configurable recommendation models and scoring factors

**Build Pattern**: Multi-container orchestration - showcases complex service deployment with multiple Docker images, worker processes, and supporting artifacts

### 💳 **Checkout Service**

#### Order processing and payment management

- Complete order lifecycle management from cart to fulfillment
- Integrated payment processing with mock and real payment gateways
- Order state tracking and inventory coordination
- Event-driven architecture with order notifications

**Build Pattern**: Service with dependencies - demonstrates deployment coordination with external services and database migrations

### 🌐 **Web Application**

#### Modern responsive frontend

- Single-page application built with vanilla JavaScript
- Responsive design with mobile-first approach
- Real-time integration with all backend services
- Client-side routing and state management

**Build Pattern**: Static asset deployment - showcases frontend build pipelines with asset optimization and CDN distribution

### 🏢 **Platform Service**

#### Integration testing and validation

- Cross-service integration testing as a unified platform
- End-to-end validation of service interactions
- Platform-wide health verification and monitoring
- Component compatibility and version validation

**Build Pattern**: Aggregation service - demonstrates platform-level testing patterns that validate multiple services working together

### 🏗️ **Infrastructure Libraries**

#### Shared libraries and DevOps tooling

- Core business logic shared across services (bookverse-core)
- DevOps automation and deployment scripts (bookverse-devops)
- Common utilities and configuration management
- Evidence collection and compliance frameworks

**Build Pattern**: Multi-artifact library publishing - showcases shared library management with separate core and DevOps build pipelines

### ⎈ **Helm Charts**

#### Kubernetes deployment automation

- Production-ready Helm charts for all services
- Environment-specific configuration management
- GitOps deployment workflows with ArgoCD integration
- Automated scaling and resource management

**Build Pattern**: Infrastructure as Code - demonstrates versioned deployment artifacts and environment promotion strategies

### 🚀 **Demo Orchestration Layer**

#### Platform setup and configuration automation (Demo Infrastructure)

- Automated JFrog Platform provisioning and configuration
- GitHub repository creation and CI/CD setup
- OIDC integration and security configuration
- Environment validation and health checking

**Build Pattern**: Setup automation - showcases demo environment provisioning and platform configuration (not part of the BookVerse application itself)

### Summary

| Component | Purpose | Technology Stack | Deployment | Build Pattern |
|-----------|---------|------------------|------------|---------------|
| **Inventory** | Product catalog & inventory management | Python, FastAPI, SQLite | Container + K8s | Single-container |
| **Recommendations** | AI-powered recommendation engine | Python, scikit-learn, FastAPI | Container + K8s | Multi-container |
| **Checkout** | Order processing & payments | Python, FastAPI, PostgreSQL | Container + K8s | Service dependencies |
| **Web App** | Frontend user interface | Vanilla JS, Vite, HTML5 | Static + CDN | Static assets |
| **Platform** | Integration testing & validation | Python, FastAPI | Container + K8s | Aggregation service |
| **Infrastructure** | Shared libraries & DevOps tooling | Python, Shell | Multi-artifact | Library publishing |
| **Helm Charts** | K8s deployment automation | Helm 3, YAML | GitOps | Infrastructure as Code |
| **Demo Orchestration** | Platform setup automation | Python, Shell, GitHub Actions | Automation | Setup automation |

---

## 🎯 Use Cases

### 🏢 **Enterprise Development Teams**

- Reference architecture for microservices transformation
- Secure CI/CD pipeline implementation
- Container orchestration and deployment automation
- DevSecOps practices and compliance automation

### 🔧 **DevOps Engineers**

- Complete GitOps workflow implementation
- Multi-environment deployment strategies
- Infrastructure as Code patterns
- Monitoring and observability setup

### 🔐 **Security Teams**

- Software supply chain security implementation
- Zero-trust CI/CD pipeline design
- Vulnerability management workflows
- Compliance and audit trail automation

### 🏗️ **Platform Engineers**

- Microservices architecture patterns
- Service mesh and API gateway configuration
- Cross-service communication strategies
- Platform engineering best practices

---

## 📚 Documentation

### 🚀 **Platform Setup & Architecture**

- [📖 **Getting Started**](docs/GETTING_STARTED.md) - Complete setup and deployment instructions
- [🏗️ **Platform Architecture Overview**](docs/ARCHITECTURE.md) - System design and component relationships
- [🎮 **Demo Runbook**](docs/DEMO_RUNBOOK.md) - Step-by-step demo execution guide
- [⚙️ **Repository Architecture**](docs/REPO_ARCHITECTURE.md) - Code organization and structure

### ⚙️ **Operations & Integration**

- [🔄 **CI/CD Deployment**](docs/CICD_DEPLOYMENT_GUIDE.md) - Pipeline configuration and automation
- [🔐 **OIDC Authentication**](docs/OIDC_AUTHENTICATION.md) - Zero-trust authentication setup
- [🏗️ **Setup Automation**](docs/SETUP_AUTOMATION.md) - Platform provisioning and configuration
- [📈 **Evidence Collection**](docs/EVIDENCE_COLLECTION.md) - Compliance and audit trail automation
- [🚀 **GitOps Deployment**](docs/GITOPS_DEPLOYMENT.md) - Continuous deployment workflows
- [🔗 **JFrog Integration**](docs/JFROG_INTEGRATION.md) - Artifact management and security
- [⭐ **AppTrust Showcase Guide**](docs/APPTRUST_SHOWCASE_GUIDE.md) - How to demonstrate AppTrust features

### 🔧 **Advanced Topics**

- [🔄 **Promotion Workflows**](docs/PROMOTION_WORKFLOWS.md) - Multi-stage deployment strategies
- [🔑 **Evidence Key Deployment**](docs/EVIDENCE_KEY_DEPLOYMENT.md) - Cryptographic key management
- [🔧 **JFrog Platform Switch**](docs/SWITCH_JFROG_PLATFORM.md) - Platform migration procedures

---

## 🌟 Platform Highlights

- **Zero-Trust Security**: OIDC authentication, cryptographic evidence, SBOM generation, and vulnerability scanning
- **Advanced CI/CD**: Multi-stage promotion, intelligent filtering, and comprehensive audit trails  
- **Cloud-Native**: Container-first deployment with Kubernetes and GitOps integration
- **Enterprise Ready**: Scalable architecture with monitoring, automated testing, and multi-environment support

---

## 🚀 Ready to Get Started?

BookVerse provides everything you need to implement enterprise-grade microservices with secure, automated software delivery.

**Choose your next step:**
- **New to BookVerse?** Start with the [Getting Started Guide](docs/GETTING_STARTED.md)
- **Want to understand the architecture?** Read the [Platform Architecture Overview](docs/ARCHITECTURE.md)
- **Ready to run a demo?** Follow the [Demo Runbook](docs/DEMO_RUNBOOK.md)
- **Want to showcase AppTrust features?** See the [AppTrust Showcase Guide](docs/APPTRUST_SHOWCASE_GUIDE.md)

For additional support and documentation, explore the comprehensive guides above or visit the individual service repositories.

---

> **Note**: Individual service documentation is available in each service repository:
> - [Inventory Service](https://github.com/yonatanp-jfrog/bookverse-inventory)
> - [Recommendations Service](https://github.com/yonatanp-jfrog/bookverse-recommendations)  
> - [Checkout Service](https://github.com/yonatanp-jfrog/bookverse-checkout)
> - [Platform Service](https://github.com/yonatanp-jfrog/bookverse-platform)
> - [Web Application](https://github.com/yonatanp-jfrog/bookverse-web)
> - [Helm Charts](https://github.com/yonatanp-jfrog/bookverse-helm)
> - [Infrastructure Libraries](https://github.com/yonatanp-jfrog/bookverse-infra)
