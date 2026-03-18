#!/usr/bin/env bash

source "$(dirname "$0")/common.sh"
source "$(dirname "$0")/config.sh"

init_script "$(basename "$0")" "Validating JFrog platform environment"


log_step "Validating JFROG_ADMIN_TOKEN"

if [[ -z "${JFROG_ADMIN_TOKEN}" ]]; then
    log_error "JFROG_ADMIN_TOKEN is empty or not configured"
    exit 1
fi

log_success "JFROG_ADMIN_TOKEN present (length: ${#JFROG_ADMIN_TOKEN})"

validate_jfrog_connectivity


log_step "Validating API permissions"

declare -a API_TESTS=(
    "GET|/access/api/v1/system/ping|System ping"
    "GET|/access/api/v1/projects|Projects API"
    "GET|/access/api/v2/lifecycle/?project_key=test|Lifecycle API"
    "GET|/api/security/users|Users API"
    "GET|/apptrust/api/v1/applications|AppTrust API"
    "GET|/access/api/v1/oidc|OIDC API"
)

for test in "${API_TESTS[@]}"; do
    IFS='|' read -r method endpoint description <<< "$test"
    
    log_info "Testing $description..."
    response_code=$(jfrog_api_call "$method" "${JFROG_URL}${endpoint}")
    
    if [[ "$response_code" -eq $HTTP_OK ]] || [[ "$response_code" -eq $HTTP_NOT_FOUND ]]; then
        log_success "$description accessible (HTTP $response_code)"
    else
        log_error "$description failed (HTTP $response_code)"
        FAILED=true
    fi
done


log_step "Environment configuration summary"
show_config

finalize_script "$(basename "$0")"
