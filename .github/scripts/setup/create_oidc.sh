#!/usr/bin/env bash

set -e

source "$(dirname "$0")/config.sh"

# =============================================================================
# JPD INTEGRATION WORKAROUND CONFIGURATION
# =============================================================================
# Due to a JPD bug that prevents OIDC integrations from working correctly 
# with project-specific roles, we implement a temporary workaround using
# a platform admin user instead of service-specific users.
USE_PLATFORM_ADMIN_WORKAROUND="${USE_PLATFORM_ADMIN_WORKAROUND:-true}"
CICD_TEMP_USERNAME="cicd"
CICD_TEMP_PASSWORD="CicdTemp2024!"

echo ""
echo "🚀 Creating OIDC integrations and identity mappings"
echo "🔧 Project: $PROJECT_KEY"
echo "🔧 JFrog URL: $JFROG_URL"
if [[ "$USE_PLATFORM_ADMIN_WORKAROUND" == "true" ]]; then
    echo "🐛 JPD Workaround: Using platform admin user (temporary)"
else
    echo "✅ Standard Mode: Using project-specific roles"
fi
echo ""

OIDC_CONFIGS=(
    "inventory|frank.inventory@bookverse.com|BookVerse Inventory"
    "recommendations|grace.ai@bookverse.com|BookVerse Recommendations" 
    "checkout|pipeline.checkout@bookverse.com|BookVerse Checkout"
    "platform|diana.architect@bookverse.com|BookVerse Platform"
    "web|pipeline.web@bookverse.com|BookVerse Web"
    "infra|pipeline.infra@bookverse.com|BookVerse Infrastructure"
    "helm|pipeline.helm@bookverse.com|BookVerse Helm Charts"
)

integration_exists() {
    local name="$1"
    local tmp=$(mktemp)
    local code=$(curl -s \
        --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
        --header "Accept: application/json" \
        -w "%{http_code}" -o "$tmp" \
        "${JFROG_URL}/access/api/v1/oidc")
    if [[ "$code" -ge 200 && "$code" -lt 300 ]]; then
        if grep -q '"name"\s*:\s*"'"$name"'"' "$tmp" 2>/dev/null; then
            rm -f "$tmp"
            return 0
        fi
    fi
    rm -f "$tmp"
    return 1
}

mapping_exists() {
    local integration_name="$1"
    local tmp=$(mktemp)
    local code=$(curl -s \
        --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
        --header "Accept: application/json" \
        -w "%{http_code}" -o "$tmp" \
        "${JFROG_URL}/access/api/v1/oidc/${integration_name}/identity_mappings")
    if [[ "$code" -ge 200 && "$code" -lt 300 ]]; then
        if grep -q '"name"\s*:\s*"'"$integration_name"'"' "$tmp" 2>/dev/null; then
            rm -f "$tmp"
            return 0
        fi
    fi
    rm -f "$tmp"
    return 1
}

create_cicd_temp_user() {
    if [[ "$USE_PLATFORM_ADMIN_WORKAROUND" != "true" ]]; then
        return 0
    fi
    
    echo "🔧 Creating temporary platform admin user: $CICD_TEMP_USERNAME"
    
    # Check if user already exists
    local user_check_response=$(mktemp)
    local user_check_code=$(curl -s \
        --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
        --header "Accept: application/json" \
        -w "%{http_code}" -o "$user_check_response" \
        "${JFROG_URL}/access/api/v2/users/${CICD_TEMP_USERNAME}")
    
    if [[ "$user_check_code" -eq 200 ]]; then
        echo "ℹ️  Temporary user '$CICD_TEMP_USERNAME' already exists"
        rm -f "$user_check_response"
        return 0
    fi
    
    # Create the temporary platform admin user
    local user_payload=$(jq -n \
        --arg username "$CICD_TEMP_USERNAME" \
        --arg password "$CICD_TEMP_PASSWORD" \
        --arg email "cicd-temp@bookverse.com" \
        '{
            "username": $username,
            "password": $password,
            "email": $email,
            "admin": true,
            "profile_updatable": false,
            "disable_ui_access": true,
            "internal_password_disabled": false
        }')
    
    local create_response=$(mktemp)
    local create_code=$(curl -s \
        --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
        --header "Content-Type: application/json" \
        -X POST \
        -d "$user_payload" \
        -w "%{http_code}" -o "$create_response" \
        "${JFROG_URL}/access/api/v2/users")
    
    case "$create_code" in
        200|201)
            echo "✅ Temporary platform admin user '$CICD_TEMP_USERNAME' created successfully"
            ;;
        409)
            echo "ℹ️  User '$CICD_TEMP_USERNAME' already exists (conflict)"
            ;;
        *)
            echo "⚠️  Warning: Could not create temporary user (HTTP $create_code)"
            echo "Response: $(cat "$create_response")"
            echo "💡 Continuing anyway - user might already exist or be managed externally"
            ;;
    esac
    
    rm -f "$user_check_response" "$create_response"
    echo ""
}

create_oidc_integration() {
    local service_name="$1"
    local username="$2"
    local display_name="$3"
    local integration_name="${PROJECT_KEY}-${service_name}-github"
    
    echo "Creating OIDC integration: $integration_name"
    echo "  Service: $service_name"
    echo "  User: $username"
    echo "  Display: $display_name"
    echo "  Provider: GitHub"
    
    local org_name="${GH_REPOSITORY_OWNER}"
    local integration_payload_github=$(jq -n \
        --arg name "$integration_name" \
        --arg issuer_url "https://token.actions.githubusercontent.com" \
        --arg provider_type "GitHub" \
        --arg projectKey "$PROJECT_KEY" \
        --arg audience "$JFROG_URL" \
        --arg organization "$org_name" \
        --arg description "OIDC integration for GitHub Actions" \
        '{
            "name": $name,
            "provider_type": $provider_type,
            "issuer_url": $issuer_url,
            "projectKey": $projectKey,
            "audience": $audience,
            "organization": $organization,
            "description": $description
        }')
    local integration_payload_minimal=$(jq -n \
        --arg name "$integration_name" \
        --arg issuer_url "https://token.actions.githubusercontent.com" \
        '{
            "name": $name,
            "issuer_url": $issuer_url
        }')
    
    if integration_exists "$integration_name"; then
        echo "⚠️  OIDC integration '$integration_name' already exists (pre-check)"
    else
        local temp_response=$(mktemp)
        local response_code=$(curl -s --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
            --header "Content-Type: application/json" \
            -X POST \
            -d "$integration_payload_github" \
            --write-out "%{http_code}" \
            --output "$temp_response" \
            "${JFROG_URL}/access/api/v1/oidc")

        case "$response_code" in
            200|201)
                echo "✅ OIDC integration '$integration_name' created successfully (GitHub provider)"
                rm -f "$temp_response"
                ;;
            409)
                echo "⚠️  OIDC integration '$integration_name' already exists (HTTP $response_code)"
                rm -f "$temp_response"
                ;;
            400)
                echo "⚠️  GitHub provider not accepted by this JFrog version. Falling back to minimal payload."
                echo "Response body: $(cat "$temp_response")"
                rm -f "$temp_response"
                temp_response=$(mktemp)
                response_code=$(curl -s --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
                    --header "Content-Type: application/json" \
                    -X POST \
                    -d "$integration_payload_minimal" \
                    --write-out "%{http_code}" \
                    --output "$temp_response" \
                    "${JFROG_URL}/access/api/v1/oidc")
                case "$response_code" in
                    200|201)
                        echo "✅ OIDC integration '$integration_name' created successfully (generic provider)"
                        rm -f "$temp_response"
                        ;;
                    409)
                        echo "⚠️  OIDC integration '$integration_name' already exists (HTTP $response_code)"
                        rm -f "$temp_response"
                        ;;
                    500|502|503|504)
                        echo "⚠️  Transient error creating '$integration_name' (HTTP $response_code)"
                        echo "Response body: $(cat "$temp_response")"
                        rm -f "$temp_response"
                        local attempt
                        for attempt in 1 2 3; do
                            temp_response=$(mktemp)
                            response_code=$(curl -s --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
                                --header "Content-Type: application/json" \
                                -X POST \
                                -d "$integration_payload_minimal" \
                                --write-out "%{http_code}" \
                                --output "$temp_response" \
                                "${JFROG_URL}/access/api/v1/oidc")
                            if [[ "$response_code" =~ ^20|^409 ]]; then
                                echo "✅ OIDC integration '$integration_name' created (after retry)"
                                rm -f "$temp_response"
                                break
                            fi
                            rm -f "$temp_response"
                            sleep $((attempt * 3))
                        done
                        ;;
                    *)
                        echo "❌ Failed to create OIDC integration '$integration_name' (HTTP $response_code)"
                        echo "Response body: $(cat "$temp_response")"
                        rm -f "$temp_response"
                        return 1
                        ;;
                esac
                ;;
            500|502|503|504)
                echo "⚠️  Transient error creating '$integration_name' (HTTP $response_code)"
                echo "Response body: $(cat "$temp_response")"
                rm -f "$temp_response"
                local attempt
                for attempt in 1 2 3; do
                    temp_response=$(mktemp)
                    response_code=$(curl -s --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
                        --header "Content-Type: application/json" \
                        -X POST \
                        -d "$integration_payload_github" \
                        --write-out "%{http_code}" \
                        --output "$temp_response" \
                        "${JFROG_URL}/access/api/v1/oidc")
                    if [[ "$response_code" =~ ^20|^409 ]]; then
                        echo "✅ OIDC integration '$integration_name' created (GitHub provider after retry)"
                        rm -f "$temp_response"
                        break
                    fi
                    rm -f "$temp_response"
                    sleep $((attempt * 3))
                done
                if ! [[ "$response_code" =~ ^20|^409 ]]; then
                    echo "ℹ️  Falling back to minimal payload after GitHub retries"
                    temp_response=$(mktemp)
                    response_code=$(curl -s --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
                        --header "Content-Type: application/json" \
                        -X POST \
                        -d "$integration_payload_minimal" \
                        --write-out "%{http_code}" \
                        --output "$temp_response" \
                        "${JFROG_URL}/access/api/v1/oidc")
                    if [[ "$response_code" =~ ^20|^409 ]]; then
                        echo "✅ OIDC integration '$integration_name' created (generic provider after retry)"
                        rm -f "$temp_response"
                    else
                        echo "❌ Failed to create OIDC integration '$integration_name' (HTTP $response_code)"
                        echo "Response body: $(cat "$temp_response")"
                        rm -f "$temp_response"
                        return 1
                    fi
                fi
                ;;
            *)
                echo "❌ Failed to create OIDC integration '$integration_name' (HTTP $response_code)"
                echo "Response body: $(cat "$temp_response")"
                rm -f "$temp_response"
                return 1
                ;;
        esac
    fi
    
    local repo_claim
    local mapping_description
    local mapping_payload
    local token_username
    local token_scope
    
    if [[ "$service_name" == "platform" ]]; then
        repo_claim="${org_name}/bookverse-*"
        mapping_description="Platform identity mapping with cross-service access"
        echo "🔧 Platform service detected - granting cross-service repository access: $repo_claim"
    else
        repo_claim="${org_name}/bookverse-${service_name}"
        mapping_description="Identity mapping for $integration_name"
    fi
    
    # Conditional identity mapping based on workaround flag
    if [[ "$USE_PLATFORM_ADMIN_WORKAROUND" == "true" ]]; then
        echo "🐛 Creating identity mapping for: $integration_name → $CICD_TEMP_USERNAME (platform admin workaround)"
        token_username="$CICD_TEMP_USERNAME"
        token_scope="applied-permissions/admin"
        mapping_description="$mapping_description (temporary platform admin workaround)"
        
        mapping_payload=$(jq -n \
            --arg name "$integration_name" \
            --arg priority "1" \
            --arg repo "$repo_claim" \
            --arg username "$token_username" \
            --arg scope "$token_scope" \
            --arg description "$mapping_description" \
            '{
                "name": $name,
                "description": $description,
                "priority": ($priority | tonumber),
                "claims": {"repository": $repo},
                "token_spec": {
                    "username": $username,
                    "scope": $scope
                }
            }')
    else
        echo "✅ Creating identity mapping for: $integration_name → $username (project-specific role)"
        token_scope="applied-permissions/roles:${PROJECT_KEY}:cicd_pipeline"
        
        mapping_payload=$(jq -n \
            --arg name "$integration_name" \
            --arg priority "1" \
            --arg repo "$repo_claim" \
            --arg scope "$token_scope" \
            --arg description "$mapping_description" \
            '{
                "name": $name,
                "description": $description,
                "priority": ($priority | tonumber),
                "claims": {"repository": $repo},
                "token_spec": {"scope": $scope}
            }')
    fi

    echo "OIDC identity mapping payload:"; echo "$mapping_payload" | jq . || echo "$mapping_payload"
    
    if mapping_exists "$integration_name"; then
        echo "⚠️  Identity mapping for '$integration_name' already exists (pre-check)"
    else
        local attempt2
        for attempt2 in 1 2 3; do
            local temp_response2=$(mktemp)
            echo "Sending identity mapping, attempt ${attempt2}..."
            echo "$mapping_payload" | jq . || echo "$mapping_payload"
            local response_code2=$(curl -s --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
                --header "Content-Type: application/json" \
                -X POST \
                -d "$mapping_payload" \
                --write-out "%{http_code}" \
                --output "$temp_response2" \
                "${JFROG_URL}/access/api/v1/oidc/${integration_name}/identity_mappings")

            case "$response_code2" in
                200|201)
                    echo "✅ Identity mapping for '$integration_name' created successfully (HTTP $response_code2)"
                    rm -f "$temp_response2"
                    break
                    ;;
                409)
                    echo "⚠️  Identity mapping for '$integration_name' already exists (HTTP $response_code2)"
                    rm -f "$temp_response2"
                    break
                    ;;
                500|502|503|504|404)
                    echo "⚠️  Transient error creating identity mapping for '$integration_name' (HTTP $response_code2)"
                    echo "Response body: $(cat "$temp_response2")"
                    rm -f "$temp_response2"
                    if mapping_exists "$integration_name"; then
                        echo "ℹ️  Detected identity mapping present after error; continuing"
                        break
                    fi
                    if [[ "$attempt2" -lt 3 ]]; then
                        sleep $((attempt2 * 3))
                        continue
                    else
                        echo "❌ Failed to create identity mapping for '$integration_name' after retries"
                        return 1
                    fi
                    ;;
                400)
                    echo "❌ Identity mapping creation returned 400"
                    echo "Response body: $(cat "$temp_response2")"
                    rm -f "$temp_response2"
                    return 1
                    ;;
                *)
                    echo "❌ Failed to create identity mapping for '$integration_name' (HTTP $response_code2)"
                    echo "Response body: $(cat "$temp_response2")"
                    rm -f "$temp_response2"
                    return 1
                    ;;
            esac
        done
    fi
    echo ""
}

echo "ℹ️  OIDC configurations to create:"
for oidc_data in "${OIDC_CONFIGS[@]}"; do
    IFS='|' read -r service_name username display_name <<< "$oidc_data"
    echo "   - $display_name → $username"
done

echo ""

# Create temporary platform admin user if workaround is enabled
create_cicd_temp_user

echo "🚀 Processing ${#OIDC_CONFIGS[@]} OIDC integrations..."
echo ""

for oidc_data in "${OIDC_CONFIGS[@]}"; do
    IFS='|' read -r service_name username display_name <<< "$oidc_data"
    
    create_oidc_integration "$service_name" "$username" "$display_name"
done

echo "✅ OIDC integration process completed!"
echo ""
echo "🔐 OIDC Integrations Summary:"
for oidc_data in "${OIDC_CONFIGS[@]}"; do
    IFS='|' read -r service_name username display_name <<< "$oidc_data"
    echo "   - ${PROJECT_KEY}-${service_name}-github → $username"
done

echo ""
echo "🎯 OIDC integrations setup completed"
echo "   Successfully created integrations are ready for GitHub Actions"
echo "   Any integrations with validation issues may require manual setup"
echo ""