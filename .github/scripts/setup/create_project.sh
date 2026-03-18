#!/usr/bin/env bash

# Import shared utilities and error handling framework
source "$(dirname "$0")/common.sh"

# Initialize script with comprehensive error handling and environment validation
init_script "$(basename "$0")" "Creating BookVerse project"

build_project_payload() {
    local project_key="$1"
    local display_name="$2"
    local storage_quota="${3:--1}"
    
    jq -n \
        --arg key "$project_key" \
        --arg name "$display_name" \
        --argjson quota "$storage_quota" \
        '{
            "project_key": $key,
            "display_name": $name,
            "admin_privileges": {
                "manage_members": true,
                "manage_resources": true,
                "index_resources": true
            },
            "storage_quota_bytes": $quota
        }'
}

finalize_script() {
    local script_name="${1:-$(basename "$0")}"
    
    echo ""
    if [[ "$FAILED" == "true" ]]; then
        log_error "$script_name completed with errors!"
        exit 1
    else
        log_success "$script_name completed successfully!"
        echo ""
    fi
}

# Construct JSON payload for project creation using standardized template
# Configures project with unlimited storage and full administrative privileges
project_payload=$(build_project_payload \
    "$PROJECT_KEY" \
    "$PROJECT_DISPLAY_NAME" \
    -1)  # -1 indicates unlimited storage quota for enterprise operations

# Display project configuration for verification and audit trail
log_config "Project Key: ${PROJECT_KEY}"
log_config "Display Name: ${PROJECT_DISPLAY_NAME}"
log_config "Admin Privileges: Full management enabled"
log_config "Storage Quota: Unlimited (-1)"

# Execute project creation via JFrog Access API with error handling
response_code=$(jfrog_api_call POST \
    "${JFROG_URL}/access/api/v1/projects" \
    "$project_payload")

# Process API response and handle success, conflict, or error conditions
handle_api_response "$response_code" "Project '${PROJECT_KEY}'" "creation"

# Finalize script execution with success/failure reporting
finalize_script "$(basename "$0")"
