#!/usr/bin/env bash
# =============================================================================
# BookVerse Platform - GitHub Repository Configuration Cleanup Script
# =============================================================================
#
# This script removes all GitHub repository variables, secrets, and PRs created
# by the Switch Platform workflow, completely resetting GitHub configuration
# back to the original state.
#
# Usage:
#   ./cleanup_github_config.sh <GITHUB_ORG>
#
# Example:
#   ./cleanup_github_config.sh yonatanp-jfrog
#
# Prerequisites:
#   - GitHub CLI (gh) installed and authenticated
#   - Admin access to all BookVerse service repositories
#   - Appropriate permissions to delete variables, secrets, and PRs
#
# =============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Validate GitHub org argument
if [[ -z "${1:-}" ]]; then
    log_error "GitHub organization is required"
    echo ""
    echo "Usage: $0 <GITHUB_ORG>"
    echo ""
    echo "Example:"
    echo "  $0 yonatanp-jfrog"
    echo ""
    exit 1
fi

GH_ORG="$1"

# List of all BookVerse repositories
REPOS=(
    "bookverse-inventory"
    "bookverse-recommendations"
    "bookverse-checkout"
    "bookverse-platform"
    "bookverse-web"
    "bookverse-helm"
    "bookverse-demo-init"
)

# Variables set by Switch Platform workflow
VARS=(
    "JFROG_URL"
    "DOCKER_REGISTRY"
    "PROJECT_KEY"
    "EVIDENCE_KEY_ALIAS"
    "EVIDENCE_PUBLIC_KEY"
)

# Secrets set by Switch Platform workflow
SECRETS=(
    "JFROG_ADMIN_TOKEN"
    "EVIDENCE_PRIVATE_KEY"
    "GH_REPO_DISPATCH_TOKEN"
)

# Validate GitHub CLI is available
if ! command -v gh &> /dev/null; then
    log_error "GitHub CLI (gh) is not installed"
    log_info "Install from: https://cli.github.com/"
    exit 1
fi

# Validate GitHub CLI authentication
if ! gh auth status &> /dev/null; then
    log_error "GitHub CLI is not authenticated"
    log_info "Run: gh auth login"
    exit 1
fi

# Confirm before proceeding
echo ""
log_warning "This script will remove ALL GitHub configuration created by Switch Platform workflow"
echo ""
log_info "Repositories to clean: ${#REPOS[@]}"
log_info "Variables to remove: ${#VARS[@]}"
log_info "Secrets to remove: ${#SECRETS[@]}"
echo ""
read -p "Type 'CLEAN' to confirm cleanup: " confirm
if [[ "$confirm" != "CLEAN" ]]; then
    log_warning "Cleanup cancelled"
    exit 0
fi

echo ""
log_info "Starting GitHub configuration cleanup..."
echo ""

# Track statistics
TOTAL_VARS_REMOVED=0
TOTAL_SECRETS_REMOVED=0
TOTAL_PRS_CLOSED=0
FAILED_OPERATIONS=0

# =============================================================================
# Step A: Remove Repository Variables
# =============================================================================
log_info "Step A: Removing repository variables..."
echo ""

for repo in "${REPOS[@]}"; do
    full_repo="$GH_ORG/$repo"
    log_info "Processing $full_repo..."
    
    # Check if repository exists
    if ! gh repo view "$full_repo" &>/dev/null; then
        log_warning "  Repository $full_repo not found, skipping..."
        continue
    fi
    
    vars_removed=0
    for var in "${VARS[@]}"; do
        if gh variable delete "$var" --repo "$full_repo" 2>/dev/null; then
            log_success "  ✅ Removed variable: $var"
            ((vars_removed++))
            ((TOTAL_VARS_REMOVED++))
        else
            # Variable might not exist, which is fine
            log_info "  ℹ️  Variable $var not found or already removed"
        fi
    done
    
    if [[ $vars_removed -eq 0 ]]; then
        log_info "  ℹ️  No variables to remove in $repo"
    fi
    echo ""
done

# =============================================================================
# Step B: Remove Repository Secrets
# =============================================================================
log_info "Step B: Removing repository secrets..."
echo ""

for repo in "${REPOS[@]}"; do
    full_repo="$GH_ORG/$repo"
    log_info "Processing $full_repo..."
    
    # Check if repository exists
    if ! gh repo view "$full_repo" &>/dev/null; then
        log_warning "  Repository $full_repo not found, skipping..."
        continue
    fi
    
    secrets_removed=0
    for secret in "${SECRETS[@]}"; do
        if gh secret delete "$secret" --repo "$full_repo" 2>/dev/null; then
            log_success "  ✅ Removed secret: $secret"
            ((secrets_removed++))
            ((TOTAL_SECRETS_REMOVED++))
        else
            # Secret might not exist, which is fine
            log_info "  ℹ️  Secret $secret not found or already removed"
        fi
    done
    
    if [[ $secrets_removed -eq 0 ]]; then
        log_info "  ℹ️  No secrets to remove in $repo"
    fi
    echo ""
done

# =============================================================================
# Step C: Clean Up Code Changes (PRs)
# =============================================================================
log_info "Step C: Cleaning up Switch Platform PRs..."
echo ""

for repo in "${REPOS[@]}"; do
    full_repo="$GH_ORG/$repo"
    log_info "Processing $full_repo..."
    
    # Check if repository exists
    if ! gh repo view "$full_repo" &>/dev/null; then
        log_warning "  Repository $full_repo not found, skipping..."
        continue
    fi
    
    # Find PRs created by Switch Platform workflow
    # Look for PRs with "switch platform" in the title
    prs=$(gh pr list --repo "$full_repo" --search "switch platform host" --json number,title,state 2>/dev/null || echo "[]")
    
    if [[ "$prs" == "[]" ]] || [[ -z "$prs" ]]; then
        log_info "  ℹ️  No Switch Platform PRs found in $repo"
        echo ""
        continue
    fi
    
    pr_count=$(echo "$prs" | jq -r 'length')
    log_info "  Found $pr_count PR(s) to process"
    
    # Process each PR
    echo "$prs" | jq -r '.[] | "\(.number)|\(.title)|\(.state)"' | while IFS='|' read -r pr_number pr_title pr_state; do
        if [[ "$pr_state" == "CLOSED" ]] || [[ "$pr_state" == "MERGED" ]]; then
            log_warning "  ⚠️  PR #$pr_number is already $pr_state: \"$pr_title\""
            log_info "     If merged, you may need to revert code changes manually"
        else
            log_info "  Closing PR #$pr_number: \"$pr_title\""
            if gh pr close "$pr_number" --repo "$full_repo" --delete-branch 2>/dev/null; then
                log_success "    ✅ PR #$pr_number closed and branch deleted"
                ((TOTAL_PRS_CLOSED++))
            else
                log_warning "    ⚠️  Failed to close PR #$pr_number (may need manual cleanup)"
                ((FAILED_OPERATIONS++))
            fi
        fi
    done
    echo ""
done

# =============================================================================
# Step D: Clean Up bookverse-demo-init Repository Variables
# =============================================================================
log_info "Step D: Cleaning up bookverse-demo-init repository variables and secrets..."
echo ""

demo_init_repo="$GH_ORG/bookverse-demo-init"

# Check if repository exists
if gh repo view "$demo_init_repo" &>/dev/null; then
    log_info "Processing $demo_init_repo..."
    
    # Additional variables that might be in bookverse-demo-init
    DEMO_VARS=(
        "JFROG_URL"
        "PROJECT_KEY"
        "DOCKER_REGISTRY"
        "GH_REPOSITORY_OWNER"
    )
    
    vars_removed=0
    for var in "${DEMO_VARS[@]}"; do
        if gh variable delete "$var" --repo "$demo_init_repo" 2>/dev/null; then
            log_success "  ✅ Removed variable: $var"
            ((vars_removed++))
            ((TOTAL_VARS_REMOVED++))
        else
            log_info "  ℹ️  Variable $var not found or already removed"
        fi
    done
    
    # Additional secrets that might be in bookverse-demo-init
    DEMO_SECRETS=(
        "JFROG_ADMIN_TOKEN"
        "GH_TOKEN"
    )
    
    secrets_removed=0
    for secret in "${DEMO_SECRETS[@]}"; do
        if gh secret delete "$secret" --repo "$demo_init_repo" 2>/dev/null; then
            log_success "  ✅ Removed secret: $secret"
            ((secrets_removed++))
            ((TOTAL_SECRETS_REMOVED++))
        else
            log_info "  ℹ️  Secret $secret not found or already removed"
        fi
    done
    
    if [[ $vars_removed -eq 0 ]] && [[ $secrets_removed -eq 0 ]]; then
        log_info "  ℹ️  No additional variables or secrets to remove"
    fi
else
    log_warning "Repository $demo_init_repo not found, skipping..."
fi

echo ""

# =============================================================================
# Summary
# =============================================================================
log_info "Cleanup Summary"
echo "=========================================="
log_success "Variables removed: $TOTAL_VARS_REMOVED"
log_success "Secrets removed: $TOTAL_SECRETS_REMOVED"
log_success "PRs closed: $TOTAL_PRS_CLOSED"

if [[ $FAILED_OPERATIONS -gt 0 ]]; then
    log_warning "Failed operations: $FAILED_OPERATIONS"
    echo ""
    log_warning "⚠️  Some operations failed. You may need to clean up manually."
fi

echo ""
log_info "Next Steps:"
echo "  1. Verify all variables and secrets are removed"
echo "  2. Check for any remaining PRs that need manual cleanup"
echo "  3. If PRs were merged, revert code changes manually"
echo "  4. Run JFrog Platform cleanup workflow to remove platform resources"
echo ""

if [[ $FAILED_OPERATIONS -eq 0 ]] && [[ $TOTAL_VARS_REMOVED -gt 0 ]] || [[ $TOTAL_SECRETS_REMOVED -gt 0 ]] || [[ $TOTAL_PRS_CLOSED -gt 0 ]]; then
    log_success "✅ GitHub configuration cleanup completed successfully!"
else
    log_warning "⚠️  Cleanup completed, but no changes were made (resources may already be clean)"
fi
