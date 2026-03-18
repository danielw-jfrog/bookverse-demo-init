#!/usr/bin/env bash

source "$(dirname "$0")/common.sh"
source "$(dirname "$0")/config.sh"

init_script "$(basename "$0")" "Creating AppTrust stages and lifecycle configuration"

build_stage_payload() {
    local project_key="$1"
    local stage_name="$2"
    local category="${3:-promote}"
    
    jq -n \
        --arg project "$project_key" \
        --arg name "$stage_name" \
        --arg cat "$category" \
        '{
            "name": ($project + "-" + $name),
            "scope": "project",
            "project_key": $project,
            "category": $cat
        }'
}

process_stage() {
    local stage_name="$1"
    local full_stage_name="${PROJECT_KEY}-${stage_name}"
    
    log_info "Creating stage: $full_stage_name"
    
    local stage_payload
    stage_payload=$(build_stage_payload "$PROJECT_KEY" "$stage_name")
    
    local response_code
    response_code=$(jfrog_api_call POST \
        "${JFROG_URL}/access/api/v2/stages/" \
        "$stage_payload")
    
    handle_api_response "$response_code" "Stage '$full_stage_name'" "creation"
}

create_lifecycle_configuration() {
    local project_stages=()
    
    for stage_name in "${NON_PROD_STAGES[@]}"; do
        project_stages+=("${PROJECT_KEY}-${stage_name}")
    done
    
    log_step "Updating lifecycle with promote stages"
    log_info "Promote stages: ${project_stages[*]}"
    
    local lifecycle_payload
    lifecycle_payload=$(jq -n \
        --argjson promote_stages "$(printf '%s\n' "${project_stages[@]}" | jq -R . | jq -s .)" \
        --arg project_key "$PROJECT_KEY" \
        '{
            "promote_stages": $promote_stages,
            "project_key": $project_key
        }')
    
    local response_code
    response_code=$(jfrog_api_call PATCH \
        "${JFROG_URL}/access/api/v2/lifecycle/?project_key=${PROJECT_KEY}" \
        "$lifecycle_payload")
    
    handle_api_response "$response_code" "Lifecycle configuration" "update"
}


log_config "Project: ${PROJECT_KEY}"
log_config "Local stages to create: ${NON_PROD_STAGES[*]}"
log_config "Production stage: ${PROD_STAGE} (system-managed)"
echo ""

log_info "Stages to be created:"
for stage_name in "${NON_PROD_STAGES[@]}"; do
    echo "   - ${PROJECT_KEY}-${stage_name}"
done

echo ""

count=0
for stage_name in "${NON_PROD_STAGES[@]}"; do
    echo ""
    log_info "[$(( ++count ))/${#NON_PROD_STAGES[@]}] Creating stage: $stage_name"
    process_stage "$stage_name"
done

echo ""

create_lifecycle_configuration

echo ""
log_step "Stages creation summary"
echo ""
log_config "📋 Created Stages:"
for stage_name in "${NON_PROD_STAGES[@]}"; do
    echo "   • ${PROJECT_KEY}-${stage_name} (promote)"
done

echo ""
log_config "🔄 Lifecycle Configuration:"
echo "   • Promote stages: ${NON_PROD_STAGES[*]}"
echo "   • Production stage: ${PROD_STAGE} (always last, system-managed)"

echo ""
log_success "🎯 All AppTrust stages and lifecycle configuration have been processed"
log_success "   Stages are now available for artifact promotion workflows"

finalize_script "$(basename "$0")"
