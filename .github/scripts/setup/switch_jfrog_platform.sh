#!/usr/bin/env bash

set -Eeuo pipefail


if [[ "${BASH_XTRACE_ENABLED:-0}" == "1" ]]; then
    set -x
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

if [[ -n "${NO_COLOR:-}" || ! -t 1 ]]; then
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

on_error() {
    local exit_code=$?
    local failed_command=${BASH_COMMAND}
    local src=${BASH_SOURCE[1]:-$0}
    local line=${BASH_LINENO[0]:-0}
    local func=${FUNCNAME[1]:-main}
    echo
    log_error "Command failed with exit code ${exit_code}"
    log_error "Location: ${src}:${line} (in ${func}())"
    log_error "Failed command: ${failed_command}"
    echo
    log_info "GitHub CLI status:" 
    if ! gh auth status 2>&1; then
        log_warning "gh auth status failed. Ensure GH_TOKEN is set with repo admin scopes."
    fi
    exit ${exit_code}
}

trap on_error ERR


NEW_JFROG_URL="${NEW_JFROG_URL}"
JFROG_ADMIN_TOKEN="${JFROG_ADMIN_TOKEN}"

# Setup mode detection: "initial_setup" or "platform_switch" (default)
SETUP_MODE="${SETUP_MODE:-platform_switch}"
# Project key for JFrog Platform (default: bookverse)
PROJECT_KEY="${PROJECT_KEY:-bookverse}"
# Evidence key configuration
GENERATE_EVIDENCE_KEYS="${GENERATE_EVIDENCE_KEYS:-false}"
EVIDENCE_KEY_ALIAS="${EVIDENCE_KEY_ALIAS:-bookverse-signing-key}"
EVIDENCE_KEY_TYPE="${EVIDENCE_KEY_TYPE:-rsa}"
# Code URL replacement control (from workflow: UPDATE_CODE_URLS)
# If UPDATE_CODE_URLS is false, skip code updates
UPDATE_CODE_URLS="${UPDATE_CODE_URLS:-true}"
SKIP_CODE_UPDATES="false"
if [[ "$UPDATE_CODE_URLS" == "false" ]]; then
    SKIP_CODE_UPDATES="true"
fi

BOOKVERSE_REPOS=(
    "bookverse-inventory"
    "bookverse-recommendations" 
    "bookverse-checkout"
    "bookverse-platform"
    "bookverse-web"
    "bookverse-helm"
    "bookverse-infra"
    "bookverse-demo-assets"
    "bookverse-demo-init"
)

if [[ -n "$GITHUB_REPOSITORY" ]]; then
    GITHUB_ORG=$(echo "$GITHUB_REPOSITORY" | cut -d'/' -f1)
else
    GITHUB_ORG="${GITHUB_ORG:-$(gh api user --jq .login)}"
fi

log_info "GitHub Organization: $GITHUB_ORG"

declare -a SUCCEEDED_REPOS=()
declare -a FAILED_REPOS=()
AUTH_FAILED=0
SERVICES_FAILED=0


validate_inputs() {
    # NOTE: Validating Inputs in Workflow directly, not needed here.
    #log_info "Validating inputs..."
    #
    #if [[ -n "$NEW_JFROG_URL" ]]; then
    #    log_info "NEW_JFROG_URL length: ${#NEW_JFROG_URL}"
    #    log_info "NEW_JFROG_URL starts with: ${NEW_JFROG_URL:0:8}..."
    #    log_info "NEW_JFROG_URL ends with: ...${NEW_JFROG_URL: -10}"
    #else
    #    log_error "NEW_JFROG_URL is required"
    #    exit 1
    #fi
    #
    #if [[ -z "$JFROG_ADMIN_TOKEN" ]]; then
    #    log_error "JFROG_ADMIN_TOKEN is required"
    #    exit 1
    #fi
    #
    #if [[ -z "$GH_TOKEN" ]]; then
    #    log_error "GH_TOKEN is required for updating repositories"
    #    exit 1
    #fi
    #
    #log_success "All required inputs provided"
    log_info "skip validate_inputs"
}

validate_host_format() {
    # NOTE: No reason to not support self-hosted JPDs.
    #log_info "Validating host format..."
    #
    #NEW_JFROG_URL=$(echo "$NEW_JFROG_URL" | sed 's:/*$::')
    #
    #if [[ ! "$NEW_JFROG_URL" =~ ^https://[a-zA-Z0-9.-]+\.jfrog\.io$ ]]; then
    #    log_error "Invalid host format. Expected: https://host.jfrog.io"
    #    log_error "Received: $NEW_JFROG_URL"
    #    exit 1
    #fi
    #
    #log_success "Host format is valid: $NEW_JFROG_URL"
    log_info "skip validate_host_format"
}

detect_setup_mode() {
    log_info "Detecting setup mode..."
    
    if [[ "$SETUP_MODE" == "initial_setup" ]]; then
        log_info "Mode: Initial Setup"
        log_info "  - Will configure repositories for first-time setup"
        if [[ "$UPDATE_CODE_URLS" == "false" ]] || [[ "$SKIP_CODE_UPDATES" == "true" ]]; then
            log_info "  - Will skip code URL replacement (no old URLs to replace)"
            SKIP_CODE_UPDATES=true
        else
            log_info "  - Will update code URLs (UPDATE_CODE_URLS=true)"
            SKIP_CODE_UPDATES=false
        fi
        echo ""
        return 0
    fi
    
    # Auto-detect: check if any repo has JFROG_URL variable set
    local current_url="${GITHUB_REPOSITORY_VARS_JFROG_URL:-}"
    local has_existing_config=false
    
    # Try to get JFROG_URL from first repo
    local first_repo="${BOOKVERSE_REPOS[0]}"
    local full_repo="$GITHUB_ORG/$first_repo"
    if gh repo view "$full_repo" >/dev/null 2>&1; then
        current_url=$(get_variable_value "$full_repo" "JFROG_URL" 2>/dev/null || echo "")
        if [[ -n "$current_url" ]]; then
            has_existing_config=true
        fi
    fi
    
    if [[ "$has_existing_config" == false ]]; then
        log_info "Mode: Initial Setup (auto-detected)"
        log_info "  - No existing JFROG_URL found in repositories"
        log_info "  - Will configure repositories for first-time setup"
        SKIP_CODE_UPDATES=true
        SETUP_MODE="initial_setup"
    else
        log_info "Mode: Platform Switch (auto-detected)"
        log_info "  - Existing configuration found"
        SETUP_MODE="platform_switch"
        check_same_platform
    fi
    echo ""
}

check_same_platform() {
    log_info "Checking for same-platform switch..."
    
    local current_url="${GITHUB_REPOSITORY_VARS_JFROG_URL:-}"
    
    # Try to get from first repo if not set
    if [[ -z "$current_url" ]]; then
        local first_repo="${BOOKVERSE_REPOS[0]}"
        local full_repo="$GITHUB_ORG/$first_repo"
        if gh repo view "$full_repo" >/dev/null 2>&1; then
            current_url=$(get_variable_value "$full_repo" "JFROG_URL" 2>/dev/null || echo "")
        fi
    fi
    
    current_url=$(echo "$current_url" | sed 's:/*$::')
    local new_url=$(echo "$NEW_JFROG_URL" | sed 's:/*$::')
    
    if [[ "$current_url" == "$new_url" ]]; then
        log_warning "Same-platform switch detected!"
        log_warning "Current: $current_url"
        log_warning "Target:  $new_url"
        log_info "This will refresh all repository configurations with the same platform"
        log_info "Useful for troubleshooting or resetting to a good state"
        echo ""
    else
        log_info "Platform migration detected:"
        log_info "From: $current_url"
        log_info "To:   $new_url"
        echo ""
    fi
}

test_platform_connectivity() {
    # NOTE: Moving to a CLI check in the workflow directly
    #log_info "Testing platform connectivity..."
    #
    #if ! curl -s --fail --max-time 10 "$NEW_JFROG_URL" > /dev/null; then
    #    log_error "Cannot reach JPD platform: $NEW_JFROG_URL"
    #    exit 1
    #fi
    #
    #log_success "Platform is reachable"
    log_info "skip test_platform_connectivity"
}

test_platform_authentication() {
    # NOTE: Moving to a CLI check in the workflow directly
    #log_info "Testing platform authentication..."
    #
    #local response
    #local was_xtrace=0
    #if [[ -o xtrace ]]; then was_xtrace=1; set +x; fi
    #log_info "Command: curl -s --max-time 10 --header 'Authorization: Bearer ***' --write-out '%{http_code}' '$NEW_JFROG_URL/artifactory/api/system/ping'"
    #response=$(curl -s --max-time 10 \
    #    --header "Authorization: Bearer $JFROG_ADMIN_TOKEN" \
    #    --write-out "%{http_code}" \
    #    "$NEW_JFROG_URL/artifactory/api/system/ping")
    #if [[ $was_xtrace -eq 1 ]]; then set -x; fi
    #
    #local http_code="${response: -3}"
    #local body="${response%???}"
    #
    #if [[ "$http_code" != "200" ]]; then
    #    log_error "Authentication failed (HTTP $http_code)"
    #    log_error "Response: $body"
    #    echo
    #    log_info "Reproduce locally:"
    #    echo "curl -i -s --max-time 10 --header 'Authorization: Bearer ***' '$NEW_JFROG_URL/artifactory/api/system/ping'"
    #    if [[ "${CONTINUE_ON_AUTH_FAILURE:-0}" == "1" ]]; then
    #        AUTH_FAILED=1
    #        log_warning "Continuing despite authentication failure to update GitHub repo secrets/variables"
    #        return 0
    #    fi
    #    exit 1
    #fi
    #
    #log_success "Authentication successful"
    log_info "skip test_platform_authentication"
}

test_platform_services() {
    # NOTE: This is redundant.  If access is offline or inaccessible, then the JPD is broken and it's not this scripts issue
    #log_info "Testing platform services..."
    #
    #local was_xtrace=0
    #if [[ -o xtrace ]]; then was_xtrace=1; set +x; fi
    #log_info "Command: curl -s --fail --max-time 10 --header 'Authorization: Bearer ***' '$NEW_JFROG_URL/artifactory/api/system/ping'"
    #if ! curl -s --fail --max-time 10 \
    #    --header "Authorization: Bearer $JFROG_ADMIN_TOKEN" \
    #    "$NEW_JFROG_URL/artifactory/api/system/ping" > /dev/null; then
    #    log_error "Artifactory service is not available"
    #    if [[ $was_xtrace -eq 1 ]]; then set -x; fi
    #    if [[ "${CONTINUE_ON_AUTH_FAILURE:-0}" == "1" ]]; then
    #        SERVICES_FAILED=1
    #        log_warning "Continuing despite service check failure to update GitHub repo secrets/variables"
    #        return 0
    #    fi
    #    exit 1
    #fi
    #
    #log_info "Command: curl -s --fail --max-time 10 --header 'Authorization: Bearer ***' '$NEW_JFROG_URL/access/api/v1/system/ping'"
    #if ! curl -s --fail --max-time 10 \
    #    --header "Authorization: Bearer $JFROG_ADMIN_TOKEN" \
    #    "$NEW_JFROG_URL/access/api/v1/system/ping" > /dev/null; then
    #    log_warning "Access service is not available (may be expected for some deployments)"
    #fi
    #if [[ $was_xtrace -eq 1 ]]; then set -x; fi
    #
    #log_success "Core services are available"
    log_info "skip test_platform_services"
}


extract_docker_registry() {
    # NOTE: This returns the value inline... Probably a cleaner way to do this.
    echo "$NEW_JFROG_URL" | sed 's|https://||'
}

validate_gh_auth() {
    # NOTE: This is already validated by the calling workflow, not needed here.
    #log_info "Validating GitHub CLI authentication..."
    #gh config set prompt disabled true >/dev/null 2>&1 || true
    #if gh auth status >/dev/null 2>&1; then
    #    local gh_user
    #    gh_user=$(gh api user --jq .login 2>/dev/null || echo "unknown")
    #    log_success "GitHub CLI authenticated as: ${gh_user}"
    #else
    #    log_error "GitHub CLI not authenticated. Set GH_TOKEN with required scopes (repo, actions, admin:repo_hook)."
    #    exit 1
    #fi
    log_info "skip validate_gh_auth"
}

trim_whitespace() {
    local s="$1"
    s=$(echo "$s" | sed 's/^\s*//;s/\s*$//')
    echo "$s"
}

get_variable_value() {
    local full_repo="$1"
    local name="$2"
    local value
    value=$(gh api -H "Accept: application/vnd.github+json" \
        "repos/$full_repo/actions/variables/$name" --jq .value 2>/dev/null || echo "")
    if [[ -z "$value" ]]; then
        value=$(gh variable get "$name" --repo "$full_repo" 2>/dev/null || echo "")
    fi
    value=$(trim_whitespace "$value")
    echo "$value"
}

verify_variable_with_retry() {
    local full_repo="$1"
    local name="$2"
    local expected="$3"
    local attempts=0
    local max_attempts=12
    local delay_seconds=1
    local current

    expected=$(trim_whitespace "$expected")

    while (( attempts < max_attempts )); do
        current=$(get_variable_value "$full_repo" "$name")
        if [[ "$current" == "$expected" ]]; then
            log_success "  → Verified $name=$current"
            return 0
        fi
        ((attempts++))
        if (( attempts < max_attempts )); then
            sleep "$delay_seconds"
            if (( delay_seconds < 16 )); then
                delay_seconds=$(( delay_seconds * 2 ))
                if (( delay_seconds > 16 )); then delay_seconds=16; fi
            fi
        fi
    done

    log_warning "  → Verification failed for $name (expected: '$expected', got: '$current')"
    return 1
}

# NOTE: Looks like the repo name is the first argument here.
# FIXME: What's the "xtrace" stuff for?
update_repository_secrets_and_variables() {
    local repo="$1"
    local full_repo="$GITHUB_ORG/$repo"
    
    log_info "Updating $full_repo..."
    
    local docker_registry
    docker_registry=$(extract_docker_registry)

    local repo_ok=1

    log_info "  → Updating secrets..."
    local output
    local was_xtrace=0
    if [[ -o xtrace ]]; then was_xtrace=1; set +x; fi
    if ! output=$(gh secret set JFROG_ADMIN_TOKEN --repo "$full_repo" --body "$JFROG_ADMIN_TOKEN" 2>&1); then
        log_warning "  → Failed to update JFROG_ADMIN_TOKEN: ${output}"
        repo_ok=0
    fi
    if [[ $was_xtrace -eq 1 ]]; then set -x; fi

    log_info "  → Updating variables..."
    if ! output=$(gh variable set JFROG_URL --body "$NEW_JFROG_URL" --repo "$full_repo" 2>&1); then
        log_warning "  → Failed to update JFROG_URL: ${output}"
        repo_ok=0
    fi

    if ! output=$(gh variable set DOCKER_REGISTRY --body "$docker_registry" --repo "$full_repo" 2>&1); then
        log_warning "  → Failed to update DOCKER_REGISTRY: ${output}"
        repo_ok=0
    fi

    if ! output=$(gh variable set PROJECT_KEY --body "$PROJECT_KEY" --repo "$full_repo" 2>&1); then
        log_warning "  → Failed to update PROJECT_KEY: ${output}"
        repo_ok=0
    fi

    if ! verify_variable_with_retry "$full_repo" "JFROG_URL" "$NEW_JFROG_URL"; then
        log_warning "  → JFROG_URL verification failed, retrying update once..."
        gh variable set JFROG_URL --body "$NEW_JFROG_URL" --repo "$full_repo" >/dev/null 2>&1 || true
        if ! verify_variable_with_retry "$full_repo" "JFROG_URL" "$NEW_JFROG_URL"; then
            repo_ok=0
        else
            log_success "  → JFROG_URL verified after retry"
        fi
    fi
    if ! verify_variable_with_retry "$full_repo" "DOCKER_REGISTRY" "$docker_registry"; then
        log_warning "  → DOCKER_REGISTRY verification failed, retrying update once..."
        gh variable set DOCKER_REGISTRY --body "$docker_registry" --repo "$full_repo" >/dev/null 2>&1 || true
        if ! verify_variable_with_retry "$full_repo" "DOCKER_REGISTRY" "$docker_registry"; then
            repo_ok=0
        else
            log_success "  → DOCKER_REGISTRY verified after retry"
        fi
    fi

    # Update evidence keys if provided
    if [[ -n "${EVIDENCE_PRIVATE_KEY:-}" ]] && [[ -n "${EVIDENCE_PUBLIC_KEY:-}" ]]; then
        log_info "  → Updating evidence keys..."
        if printf "%s" "${EVIDENCE_PRIVATE_KEY}" | gh secret set EVIDENCE_PRIVATE_KEY --repo "$full_repo" 2>&1 >/dev/null; then
            log_success "    ✅ EVIDENCE_PRIVATE_KEY updated"
        else
            log_warning "    ⚠️  Failed to update EVIDENCE_PRIVATE_KEY"
        fi
        
        if gh variable set EVIDENCE_PUBLIC_KEY --body "${EVIDENCE_PUBLIC_KEY}" --repo "$full_repo" 2>&1 >/dev/null; then
            log_success "    ✅ EVIDENCE_PUBLIC_KEY updated"
        else
            log_warning "    ⚠️  Failed to update EVIDENCE_PUBLIC_KEY"
        fi
        
        if gh variable set EVIDENCE_KEY_ALIAS --body "${EVIDENCE_KEY_ALIAS}" --repo "$full_repo" 2>&1 >/dev/null; then
            log_success "    ✅ EVIDENCE_KEY_ALIAS updated"
        else
            log_warning "    ⚠️  Failed to update EVIDENCE_KEY_ALIAS"
        fi
    fi

    if [[ $repo_ok -eq 1 ]]; then
        log_success "  → $repo updated successfully"
        SUCCEEDED_REPOS+=("$repo")
        return 0
    else
        log_warning "  → $repo updated with errors"
        FAILED_REPOS+=("$repo")
        return 1
    fi
}

generate_evidence_keys() {
    if [[ "$GENERATE_EVIDENCE_KEYS" != "true" ]]; then
        return 0
    fi
    export JFROG_CLI_AVOID_NEW_VERSION_WARNING=true
    log_info "Generating evidence keys..."
    log_info "  Key type: $EVIDENCE_KEY_TYPE"
    log_info "  Key alias: $EVIDENCE_KEY_ALIAS"
    log_info "  Skip CLI Version Check: $JFROG_CLI_AVOID_NEW_VERSION_WARNING"
    
    if ! command -v jf &> /dev/null; then
        log_error "JFrog CLI (jf) is required for key generation but not installed"
        log_info "Install from: https://jfrog.com/getcli/"
        log_info "Skipping evidence key generation"
        return 1
    fi
    
    local temp_dir
    temp_dir=$(mktemp -d)
    trap "rm -rf '$temp_dir'" EXIT
    
    log_info "  → Generating $EVIDENCE_KEY_TYPE key pair..."
    if ! jf evd generate-key-pair --key-alias "$EVIDENCE_KEY_ALIAS" --key-file-name "$EVIDENCE_KEY_ALIAS" --key-file-path "$temp_dir" --url "$NEW_JFROG_URL" --access-token "$JFROG_ADMIN_TOKEN" 2>&1; then
        log_warning "  ⚠️  Failed to generate keys with JFrog CLI, trying alternative method..."
        # Fallback to OpenSSL if JFrog CLI fails
        if ! command -v openssl &> /dev/null; then
            log_error "OpenSSL is required for key generation but not installed"
            return 1
        fi
        
        case "$EVIDENCE_KEY_TYPE" in
            rsa)
                openssl genrsa -out "$temp_dir/private.pem" 2048
                openssl rsa -in "$temp_dir/private.pem" -pubout -out "$temp_dir/public.pem"
                ;;
            ec)
                openssl ecparam -genkey -name secp256r1 -noout -out "$temp_dir/private.pem"
                openssl ec -in "$temp_dir/private.pem" -pubout -out "$temp_dir/public.pem"
                ;;
            ed25519)
                openssl genpkey -algorithm ED25519 -out "$temp_dir/private.pem"
                openssl pkey -in "$temp_dir/private.pem" -pubout -out "$temp_dir/public.pem"
                ;;
            *)
                log_error "Unsupported key type: $EVIDENCE_KEY_TYPE"
                return 1
                ;;
        esac
    else
        # JFrog CLI uses the provided base name for output files
        if [[ -f "$temp_dir/${EVIDENCE_KEY_ALIAS}.key" ]] && [[ -f "$temp_dir/${EVIDENCE_KEY_ALIAS}.pub" ]]; then
            mv "$temp_dir/${EVIDENCE_KEY_ALIAS}.key" "$temp_dir/private.pem" 2>/dev/null || true
            mv "$temp_dir/${EVIDENCE_KEY_ALIAS}.pub" "$temp_dir/public.pem" 2>/dev/null || true
        fi
    fi
    
    if [[ ! -f "$temp_dir/private.pem" ]] || [[ ! -f "$temp_dir/public.pem" ]]; then
        log_error "Failed to generate key files"
        return 1
    fi
    
    export EVIDENCE_PRIVATE_KEY=$(cat "$temp_dir/private.pem")
    export EVIDENCE_PUBLIC_KEY=$(cat "$temp_dir/public.pem")
    
    log_success "  ✅ Evidence keys generated successfully"
    
    # Upload to JFrog Platform
    upload_evidence_key_to_jfrog "$temp_dir/public.pem" "$EVIDENCE_KEY_ALIAS"
    
    return 0
}

upload_evidence_key_to_jfrog() {
    local public_key_file="$1"
    local alias="$2"
    
    log_info "  → Uploading public key to JFrog Platform..."
    
    local public_key_content
    public_key_content=$(cat "$public_key_file")
    
    local payload
    payload=$(jq -n \
        --arg alias "$alias" \
        --arg public_key "$public_key_content" \
        '{
            "alias": $alias,
            "public_key": $public_key
        }' 2>/dev/null)
    
    if [[ -z "$payload" ]]; then
        log_warning "    ⚠️  jq not available, skipping JFrog upload"
        return 0
    fi
    
    local response
    local http_code
    response=$(curl -s -w "%{http_code}" \
        -X POST \
        -H "Authorization: Bearer $JFROG_ADMIN_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$NEW_JFROG_URL/artifactory/api/security/keys/trusted" 2>/dev/null)
    
    http_code="${response: -3}"
    
    if [[ "$http_code" == "200" ]] || [[ "$http_code" == "201" ]]; then
        log_success "    ✅ Public key uploaded to JFrog Platform"
        return 0
    elif [[ "$http_code" == "409" ]]; then
        log_info "    ℹ️  Key '$alias' already exists in JFrog Platform"
        return 0
    else
        log_warning "    ⚠️  Failed to upload public key (HTTP $http_code)"
        return 1
    fi
}

update_all_repositories() {
    log_info "Updating all BookVerse repositories..."
    
    local total_count=${#BOOKVERSE_REPOS[@]}
    local success_count=0

    for repo in "${BOOKVERSE_REPOS[@]}"; do
        if update_repository_secrets_and_variables "$repo"; then
            ((++success_count))
        fi

        # Skip code updates if requested (initial setup or UPDATE_CODE_URLS=false)
        if [[ "$SKIP_CODE_UPDATES" == "true" ]]; then
            log_info "  → Skipping code URL replacement"
            continue
        fi

        local default_branch
        default_branch=$(gh repo view "$GITHUB_ORG/$repo" --json defaultBranchRef --jq .defaultBranchRef.name 2>/dev/null || echo "main")

        local workdir
        workdir=$(mktemp -d)
        pushd "$workdir" >/dev/null
        if gh repo clone "$GITHUB_ORG/$repo" repo >/dev/null 2>&1; then
            cd repo
            git checkout -b chore/switch-platform-$(date +%Y%m%d%H%M%S) >/dev/null 2>&1 || true

            local new_registry
            new_registry=$(extract_docker_registry)

            
            local old_patterns=(
                "evidencetrial\\.jfrog\\.io"
                "apptrustswampupc\\.jfrog\\.io"
                "releases\\.jfrog\\.io"
            )
            
            local changes_made=false
            
            for pattern in "${old_patterns[@]}"; do
                if command -v rg >/dev/null 2>&1 && rg -l "$pattern" >/dev/null 2>&1; then
                    rg -l "$pattern" | xargs sed -i '' -e "s|$pattern|${new_registry}|g"
                    changes_made=true
                    log_info "  → Replaced $pattern with ${new_registry}"
                fi
            done
            
            for pattern in "${old_patterns[@]}"; do
                local url_pattern="https://$pattern"
                if command -v rg >/dev/null 2>&1 && rg -l "$url_pattern" >/dev/null 2>&1; then
                    rg -l "$url_pattern" | xargs sed -i '' -e "s|$url_pattern|${NEW_JFROG_URL}|g"
                    changes_made=true
                    log_info "  → Replaced $url_pattern with ${NEW_JFROG_URL}"
                fi
            done

            if ! git diff --quiet; then
                git add -A
                git commit -m "chore: switch platform host to ${new_registry}" >/dev/null 2>&1 || true
                git push -u origin HEAD >/dev/null 2>&1 || true
                gh pr create --title "chore: switch platform host to ${new_registry}" \
                  --body "Automated replacement of hardcoded JFrog hosts with ${NEW_JFROG_URL}." \
                  --base "$default_branch" >/dev/null 2>&1 || true
                log_success "  → Opened PR with host replacements in $repo"
            else
                log_info "  → No hardcoded host replacements needed in $repo"
            fi
        fi
        popd >/dev/null || true
        rm -rf "$workdir"
    done

    log_info "Repository update results:"
    echo "  ✓ Success: ${success_count}/${total_count}"
    echo "  ✗ Failed: $((total_count - success_count))/${total_count}"
}

final_verification_pass() {
    if [[ ${#FAILED_REPOS[@]} -eq 0 ]]; then
        return 0
    fi

    log_info "Performing final verification pass for repositories with errors..."

    local docker_registry
    docker_registry=$(extract_docker_registry)

    local to_check=("${FAILED_REPOS[@]}")
    local still_failed=()

    for repo in "${to_check[@]}"; do
        local full_repo="$GITHUB_ORG/$repo"
        log_info "  → Re-verifying $full_repo"

        sleep 2

        local ok=1
        if ! verify_variable_with_retry "$full_repo" "JFROG_URL" "$NEW_JFROG_URL"; then
            gh variable set JFROG_URL --body "$NEW_JFROG_URL" --repo "$full_repo" >/dev/null 2>&1 || true
            if ! verify_variable_with_retry "$full_repo" "JFROG_URL" "$NEW_JFROG_URL"; then
                ok=0
            fi
        fi

        if ! verify_variable_with_retry "$full_repo" "DOCKER_REGISTRY" "$docker_registry"; then
            gh variable set DOCKER_REGISTRY --body "$docker_registry" --repo "$full_repo" >/dev/null 2>&1 || true
            if ! verify_variable_with_retry "$full_repo" "DOCKER_REGISTRY" "$docker_registry"; then
                ok=0
            fi
        fi

        if [[ $ok -eq 1 ]]; then
            log_success "  → $repo verified successfully on final pass"
            SUCCEEDED_REPOS+=("$repo")
        else
            log_warning "  → $repo still failing after final pass"
            still_failed+=("$repo")
        fi
    done

    FAILED_REPOS=("${still_failed[@]}")
}

# FIXME: Should probably split the "initial_setup" and "JPD Switch" functionality to two separate scripts.
main() {
    if [[ "$SETUP_MODE" == "initial_setup" ]]; then
        echo "🚀 BookVerse Platform - Initial Setup"
        echo "======================================"
    else
        echo "🔄 JFrog Platform Deployment (JPD) Switch"
        echo "=========================================="
    fi
    echo ""
    
    validate_inputs
    echo ""
    
    validate_host_format
    echo ""
    
    detect_setup_mode
    
    test_platform_connectivity
    echo ""
    
    test_platform_authentication  
    echo ""
    
    test_platform_services
    echo ""
    
    validate_gh_auth
    echo ""
    
    # Generate evidence keys if requested
    if [[ "$GENERATE_EVIDENCE_KEYS" == "true" ]]; then
        generate_evidence_keys
        echo ""
    fi
    
    update_all_repositories
    echo ""

    final_verification_pass
    echo ""
    
    local docker_registry
    docker_registry=$(extract_docker_registry)
    
    local failed_count
    failed_count=${#FAILED_REPOS[@]}
    local success_count
    success_count=${#SUCCEEDED_REPOS[@]}

    echo "🎯 JPD Platform Switch Summary"
    echo "================================="
    echo "New Configuration:"
    echo "  JFROG_URL: $NEW_JFROG_URL"
    echo "  DOCKER_REGISTRY: $docker_registry"
    echo "  Total repositories: ${#BOOKVERSE_REPOS[@]}"
    echo "  Success: ${success_count}"
    echo "  Failed: ${failed_count}"

    if [[ ${success_count} -gt 0 ]]; then
        echo ""
        echo "✓ Updated repositories: ${SUCCEEDED_REPOS[*]}"
    fi

    if [[ ${failed_count} -gt 0 ]]; then
        echo ""
        echo "✗ Repositories with errors: ${FAILED_REPOS[*]}"
        echo ""
        log_error "Some repositories failed to update. See messages above."
        exit 1
    else
        echo ""
        log_success "All BookVerse repositories have been updated with new JPD configuration"
    fi
}

main "$@"
