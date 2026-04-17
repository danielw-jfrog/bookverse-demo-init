# AppTrust Features Showcase Guide

## 🎯 Overview

This guide outlines the AppTrust features available in BookVerse and provides recommendations for showcasing them effectively. All necessary infrastructure has been automated and provisioned - you're ready to demonstrate AppTrust capabilities!

---

## ✅ What's Been Automated & Provisioned

### Infrastructure (Complete)
- ✅ **JFrog Project**: `bookverse` project configured
- ✅ **14 Repositories**: All service repositories across package types
- ✅ **12 Users**: Users with appropriate role assignments
- ✅ **4 Lifecycle Stages**: DEV → QA → STAGING → PROD
- ✅ **4 AppTrust Applications**: inventory, recommendations, checkout, platform
- ✅ **5 OIDC Integrations**: GitHub Actions OIDC configured for all services
- ✅ **Evidence Keys**: Cryptographic keys generated and distributed to repositories

### Policies (Complete)
- ✅ **14-16 Unified Policies**: Comprehensive governance framework
  - **DEV Entry Gates** (5 policies): Jira, SLSA Provenance, Build Quality, Docker SAST, Unit Tests
  - **DEV Exit Gates** (1 policy): Smoke Tests
  - **QA Entry Gates** (3 policies): DEV Completion (BLOCKING), SBOM, Integration Tests
  - **QA Exit Gates** (2 policies): DAST Scanning, Postman Collection
  - **STAGING Entry Gates** (3 policies): Pentest, Change Management, IaC Scanning
  - **PROD Release Gates** (3 policies): DEV/QA/STAGING Completion (all BLOCKING)

### Automation Scripts (Complete)
- ✅ **Repository Forking**: `create-clean-repos.sh`
- ✅ **Evidence Key Management**: `update_evidence_keys.sh`
- ✅ **Secrets Configuration**: `configure-service-secrets.sh`
- ✅ **Platform Setup**: GitHub Actions workflow `🚀-setup-platform.yml`

---

## 🚀 AppTrust Features Available for Showcase

### 1. **Evidence Collection & Cryptographic Signing** ⭐⭐⭐
**What it is**: Automated evidence collection with cryptographic signing for supply chain security

**How to Showcase**:
- **In CI/CD Pipelines**: Show evidence being collected during builds
  ```bash
  # Evidence is automatically collected in GitHub Actions workflows
  # Show evidence attachment in CI logs
  jf evd create-evidence \
    --predicate evidence.json \
    --predicate-type "https://pytest.org/evidence/results/v1" \
    --package-name "bookverse-inventory" \
    --package-version "1.2.3"
  ```

- **In JFrog Platform**: Navigate to AppTrust → Applications → Evidence
  - Show evidence attached to application versions
  - Show cryptographic signatures
  - Show evidence types: SLSA Provenance, SAST scans, test results, etc.

**Key Talking Points**:
- "Every build automatically collects evidence with cryptographic signatures"
- "Evidence provides tamper-proof audit trail for compliance"
- "Evidence types include security scans, test results, and build provenance"

---

### 2. **Unified Policy Framework** ⭐⭐⭐
**What it is**: 14 automated policies enforcing quality gates across lifecycle stages

**How to Showcase**:
- **Policy Dashboard**: Navigate to Unified Policy → Policies
  - Show all 14 policies configured
  - Show policy modes (BLOCK vs WARNING)
  - Show lifecycle stage assignments

- **Policy Evaluation**: Demonstrate policy evaluation during promotion
  ```bash
  # Show policy evaluation API
  curl -X POST "${JFROG_URL}/unifiedpolicy/api/v1/pdp/evaluate" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
      "action": {"type": "certify_to_gate", "stage": {"key": "qa", "gate": "entry"}},
      "resource": {"type": "application_version", "key": "bookverse-inventory", "version": "1.0.0"}
    }'
  ```

**Key Talking Points**:
- "14 automated policies enforce quality gates at every stage"
- "Policies can BLOCK or WARN based on evidence requirements"
- "Real-time policy evaluation prevents non-compliant deployments"

---

### 3. **Lifecycle Management** ⭐⭐⭐
**What it is**: Automated promotion through DEV → QA → STAGING → PROD with evidence gates

**How to Showcase**:
- **Application Versions**: Navigate to AppTrust → Applications → Versions
  - Show versions at different lifecycle stages
  - Show promotion history
  - Show evidence attached at each stage

- **Promotion Workflow**: Trigger a promotion workflow
  ```bash
  # Trigger promotion via GitHub Actions
  gh workflow run promote.yml -R your-org/bookverse-inventory \
    -f target_stage=QA \
    -f version=1.0.0
  ```

- **Stage Gates**: Show how policies block/warn at each gate
  - DEV Entry: Requires SLSA, Jira, tests
  - QA Entry: Requires DEV completion (BLOCKING)
  - STAGING Entry: Requires pentest, change approval
  - PROD Release: Requires all previous stage completions (BLOCKING)

**Key Talking Points**:
- "Automated lifecycle management with evidence-based gates"
- "Each stage has specific evidence requirements"
- "BLOCKING policies prevent promotion without required evidence"

---

### 4. **Blocking vs Warning Modes** ⭐⭐
**What it is**: Policies can either BLOCK promotions or WARN while allowing promotion

**How to Showcase**:
- **Demonstrate Blocking**: Try to promote without required evidence
  - Show how DEV Completion policy BLOCKS QA entry
  - Show error message and policy evaluation result

- **Demonstrate Warning**: Show warnings that don't block
  - Show SBOM evidence warning (if missing)
  - Show integration test warning (if missing)
  - Promotion still proceeds with warnings

**Key Talking Points**:
- "BLOCKING policies enforce critical requirements"
- "WARNING policies provide visibility without blocking"
- "Flexible policy configuration for different risk levels"

---

### 5. **Evidence Transparency (Web UI)** ⭐⭐
**What it is**: Trust panel in web application showing evidence to end users

**How to Showcase**:
- **Web Application**: Navigate to BookVerse web app
  - Click trust panel button (usually bottom-right)
  - Show evidence display
  - Show container images with digests
  - Show service configuration

- **Evidence Endpoint**: Show evidence API endpoint
  ```bash
  curl http://bookverse.demo/.well-known/apptrust/evidence.json
  ```

**Key Talking Points**:
- "End users can see evidence transparency in the web UI"
- "Builds trust through supply chain visibility"
- "Shows container images, versions, and security evidence"

---

### 6. **Rollback Capabilities** ⭐⭐
**What it is**: Automated rollback to previous application versions

**How to Showcase**:
- **Rollback Workflow**: Trigger rollback via GitHub Actions
  ```bash
  gh workflow run rollback.yml -R your-org/bookverse-inventory \
    -f target_version=1.0.0
  ```

- **AppTrust API**: Show rollback via AppTrust API
  - Navigate to application versions
  - Show version history
  - Demonstrate rollback to previous version

**Key Talking Points**:
- "Automated rollback to known-good versions"
- "Service-specific rollback logic (e.g., payment system safety)"
- "Maintains audit trail of rollback operations"

---

### 7. **Platform Aggregation** ⭐⭐
**What it is**: Platform service aggregates multiple microservices into platform releases

**How to Showcase**:
- **Platform Application**: Navigate to `bookverse-platform` application
  - Show aggregated versions from all services
  - Show platform version creation
  - Show bi-weekly aggregation cycle

- **Aggregation Script**: Show platform aggregation logic
  ```bash
  # Platform aggregation automatically collects latest PROD versions
  python bookverse-platform/app/main.py --aggregate
  ```

**Key Talking Points**:
- "Platform aggregates microservices into coordinated releases"
- "Bi-weekly aggregation cycle with hotfix support"
- "Complete audit trail of platform composition"

---

### 8. **OIDC Zero-Trust Authentication** ⭐⭐⭐
**What it is**: Passwordless authentication from GitHub Actions to JFrog Platform

**How to Showcase**:
- **GitHub Actions**: Show workflow without stored secrets
  ```yaml
  # No JFROG_TOKEN secret needed!
  - uses: jfrog/setup-jfrog-cli@v4
    with:
      version: latest
    env:
      JF_URL: ${{ vars.JFROG_URL }}
      JF_PROJECT: ${{ vars.PROJECT_KEY }}
  ```

- **OIDC Configuration**: Show OIDC integrations in JFrog Platform
  - Navigate to Access → OIDC Providers
  - Show GitHub integrations configured

**Key Talking Points**:
- "Zero-trust authentication eliminates stored secrets"
- "OIDC provides secure, auditable authentication"
- "Repository-specific permissions for fine-grained access"

---

### 9. **SBOM Generation** ⭐⭐
**What it is**: Automated Software Bill of Materials generation

**How to Showcase**:
- **SBOM in Artifacts**: Show SBOM attached to artifacts
  - Navigate to Artifactory → Repositories
  - Show SBOM files alongside Docker images
  - Show CycloneDX format

- **SBOM Evidence**: Show SBOM as evidence type
  - Navigate to AppTrust → Evidence
  - Show SBOM evidence attached to versions

**Key Talking Points**:
- "Automated SBOM generation for all artifacts"
- "CycloneDX format for industry compatibility"
- "SBOM evidence required for QA stage entry"

---

### 10. **Security Scanning Integration** ⭐⭐
**What it is**: Integration with Xray for vulnerability scanning

**How to Showcase**:
- **Xray Scans**: Show vulnerability scan results
  - Navigate to Xray → Security
  - Show scan results for artifacts
  - Show critical CVE blocking policy

- **Policy Integration**: Show how Xray findings trigger policies
  - Show Critical CVE Check policy (BLOCKING)
  - Show how vulnerabilities block promotion

**Key Talking Points**:
- "Automated security scanning integrated with policies"
- "Critical vulnerabilities block promotion automatically"
- "Complete security posture visibility"

---

## 🎬 Recommended Demo Flow

### Quick Demo (20 minutes)
1. **Platform Overview** (3 min)
   - Show JFrog Project structure
   - Show 4 AppTrust applications
   - Show 14 unified policies

2. **Evidence Collection** (5 min)
   - Trigger a build in GitHub Actions
   - Show evidence collection in CI logs
   - Show evidence in JFrog Platform

3. **Policy Enforcement** (7 min)
   - Show policy evaluation during promotion
   - Demonstrate BLOCKING vs WARNING
   - Show promotion blocked by missing evidence

4. **Lifecycle Management** (5 min)
   - Show application versions at different stages
   - Show promotion workflow
   - Show evidence requirements at each stage

### Comprehensive Demo (45 minutes)
1. **Platform Overview** (5 min)
   - Complete infrastructure walkthrough
   - Policy framework explanation
   - OIDC authentication setup

2. **Evidence Collection** (10 min)
   - Full CI/CD pipeline walkthrough
   - Multiple evidence types
   - Cryptographic signing demonstration

3. **Policy Framework** (10 min)
   - All 14 policies explained
   - Policy evaluation API
   - Blocking vs warning demonstration

4. **Lifecycle Management** (10 min)
   - Complete promotion workflow
   - Stage gate enforcement
   - Evidence requirements

5. **Advanced Features** (10 min)
   - Platform aggregation
   - Rollback capabilities
   - Evidence transparency (web UI)

---

## 📋 Next Steps Checklist

### Before Your Demo
- [ ] Verify all services have evidence keys configured
- [ ] Verify OIDC integrations are working
- [ ] Test a promotion workflow end-to-end
- [ ] Prepare example evidence files
- [ ] Review policy configurations

### During Your Demo
- [ ] Start with platform overview
- [ ] Show evidence collection in action
- [ ] Demonstrate policy enforcement
- [ ] Show blocking vs warning behavior
- [ ] Highlight OIDC zero-trust authentication

### After Your Demo
- [ ] Document any issues encountered
- [ ] Update runbook based on feedback
- [ ] Refresh demo environment if needed

---

## 🔍 Key Metrics to Highlight

- **14 Unified Policies**: Comprehensive governance framework
- **4 Lifecycle Stages**: Complete promotion workflow
- **4 AppTrust Applications**: Microservices with lifecycle management
- **5 OIDC Integrations**: Zero-trust authentication
- **Multiple Evidence Types**: SLSA, SAST, DAST, tests, SBOM, etc.
- **BLOCKING Policies**: Critical requirements enforcement
- **Automated Workflows**: End-to-end automation

---

## 💡 Pro Tips

1. **Start Simple**: Begin with evidence collection, then build to policies
2. **Show Real Examples**: Use actual builds and promotions, not just screenshots
3. **Demonstrate Blocking**: Show how policies prevent bad deployments
4. **Highlight Automation**: Emphasize that everything is automated
5. **Show Transparency**: Demonstrate evidence visibility in web UI
6. **Tell a Story**: Walk through a complete promotion from DEV to PROD

---

## 📚 Related Documentation

- [Demo Runbook](DEMO_RUNBOOK.md) - Step-by-step demo execution
- [Evidence Guide](EVIDENCE_GUIDE.md) - Complete evidence documentation
- [Architecture Guide](ARCHITECTURE.md) - System architecture
- [Promotion Workflows](PROMOTION_WORKFLOWS.md) - Promotion workflow details
- [Unified Policy API Reference](UNIFIED_POLICY_API_REFERENCE.md) - Policy API documentation

---

**Last Updated**: 2024-12-11
**Version**: 1.0.0
