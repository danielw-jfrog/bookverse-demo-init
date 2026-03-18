#!/usr/bin/env bash

# 🏷️ Core Project Identity Configuration
# These variables define the fundamental project identification used throughout
# the BookVerse platform for consistent naming and branding across all systems
export PROJECT_KEY="bookverse"           # Primary project identifier for all platform operations
export PROJECT_DISPLAY_NAME="BookVerse"  # Human-readable project name for UI and documentation
# GH_REPOSITORY_OWNER is required and must be provided via environment variable
if [[ -z "${GH_REPOSITORY_OWNER:-}" ]]; then
  echo "❌ GH_REPOSITORY_OWNER is required (no default provided)" >&2
  echo "   Please set GH_REPOSITORY_OWNER environment variable with your GitHub organization/owner" >&2
  exit 2
fi
export GH_REPOSITORY_OWNER  # GitHub repository owner/organization (required)

# 🔗 JFrog Platform Integration Configuration
# Critical configuration for JFrog Platform connectivity and authentication
# JFROG_URL is required and must be provided via environment variable for security
if [[ -z "${JFROG_URL:-}" ]]; then
  echo "❌ JFROG_URL is required (no default provided for security)" >&2
  echo "   Please set JFROG_URL environment variable with your JFrog Platform endpoint" >&2
  exit 2
fi
export JFROG_URL                                    # JFrog Platform endpoint URL (required)
export JFROG_ADMIN_TOKEN="${JFROG_ADMIN_TOKEN}"    # Admin authentication token (required)

# 📦 Repository Management Configuration
# Standardized artifact repository organization and naming conventions
# for Docker containers, Python packages, and multi-environment deployment
export DOCKER_INTERNAL_REPO="docker-internal"           # Internal Docker repository for development and staging
export DOCKER_INTERNAL_PROD_REPO="docker-internal-prod" # Production Docker repository for internal services
export DOCKER_EXTERNAL_PROD_REPO="docker-external-prod" # Production Docker repository for external dependencies
export PYPI_LOCAL_REPO="pypi-local"                     # Local PyPI repository for Python package management

# 🎯 Environment Lifecycle Stage Configuration
# Deployment stage definitions for application promotion and lifecycle management
# Supports enterprise-grade environment promotion with proper governance
export NON_PROD_STAGES=("DEV" "QA" "STAGING")  # Non-production stages for development and testing
export PROD_STAGE="PROD"                       # Production stage for live customer-facing deployments

# 🔐 Security and Authentication Configuration
# OIDC and security parameter configuration for secure platform operations
# and enterprise-grade authentication across all platform integrations
export GITHUB_ACTIONS_ISSUER_URL="https://token.actions.githubusercontent.com/"  # GitHub OIDC issuer endpoint
export JFROG_CLI_SERVER_ID="bookverse-admin"                                    # JFrog CLI server configuration ID
export DEFAULT_RSA_KEY_SIZE=2048                                                 # RSA key size for cryptographic operations

# ⚙️ Operational Performance Configuration
# API interaction parameters for optimal performance and reliability
# across all platform operations and external service integrations
export DEFAULT_API_RETRIES=3      # Number of API retry attempts for resilient operations
export API_TIMEOUT=30             # API timeout in seconds for reliable service interactions

# 🗂️ Temporary File and Cache Management Configuration
# Operational parameters for temporary file handling and cache optimization
# to ensure clean operations and optimal performance during setup procedures
export TEMP_DIR_PREFIX="bookverse_cleanup"  # Prefix for temporary directories during cleanup operations
export CACHE_TTL_SECONDS=300                # Cache time-to-live in seconds for performance optimization


