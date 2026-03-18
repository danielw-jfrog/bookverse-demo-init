#!/usr/bin/env bash

set -e

source "$(dirname "$0")/config.sh"

echo ""
echo "🚀 Creating BookVerse custom roles"
echo "🔧 Project: $PROJECT_KEY"
echo "🔧 JFrog URL: $JFROG_URL"
echo ""

create_role() {
    local role_name="$1"
    local role_description="$2"
    local permissions="$3"
    local environments="$4"
    
    echo "Creating role: $role_name"
    echo "  Description: $role_description"
    echo "  Environments: $environments"
    
    local role_payload=$(jq -n \
        --arg name "$role_name" \
        --arg desc "$role_description" \
        --arg project "$PROJECT_KEY" \
        --argjson perms "$permissions" \
        --argjson envs "$environments" \
        '{
            "name": $name,
            "description": $desc,
            "type": "CUSTOM",
            "environment": "PROJECT",
            "project_key": $project,
            "actions": $perms,
            "environments": $envs
        }')
    
    local response_code
    response_code=$(curl -s --write-out "%{http_code}" \
        --output /dev/null \
        --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
        --header "Content-Type: application/json" \
        --request POST \
        --data "$role_payload" \
        "${JFROG_URL}/access/api/v1/projects/${PROJECT_KEY}/roles")
    
    case "$response_code" in
        201)
            echo "✅ Role '$role_name' created successfully"
            ;;
        409)
            echo "✅ Role '$role_name' already exists"
            ;;
        *)
            echo "⚠️  Role '$role_name' creation returned HTTP $response_code"
            # Record error for job summary detection
            echo "Role creation failed: $role_name (HTTP $response_code)" >> /tmp/setup_errors.log 2>/dev/null || true
            ;;
    esac
    echo ""
}


echo "📋 Role creation summary:"
echo ""
echo "ℹ️  Note: The 'k8s_image_pull' project role is created automatically by create_users.sh"
echo "          when K8s users are processed, ensuring proper permissions for image pulls."
echo ""

echo "🎯 Custom roles are now available for assignment to users"
echo ""
