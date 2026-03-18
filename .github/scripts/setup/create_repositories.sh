#!/usr/bin/env bash

set -e

source "$(dirname "$0")/config.sh"

# 🏢 BookVerse Service Architecture Definition
# Complete list of all BookVerse microservices requiring dedicated artifact repositories
# Each service has specialized package type requirements based on technology stack
SERVICES=(
    "inventory"      # Core business inventory and stock management service
    "recommendations" # AI-powered personalization and recommendation engine
    "checkout"       # Secure payment processing and transaction management service
    "platform"      # Unified platform coordination and API gateway service
    "web"           # Customer-facing frontend and static asset delivery service
    "helm"          # Kubernetes deployment manifests and infrastructure-as-code
    "infra"         # Infrastructure libraries and shared DevOps automation components
)

get_packages_for_service() {
    local service="$1"
    case "$service" in
        inventory)
            echo "docker pypi"
            ;;
        recommendations)
            echo "docker generic"
            ;;
        checkout)
            echo "docker generic"
            ;;
        platform)
            echo "docker"
            ;;
        web)
            echo "generic"
            ;;
        helm)
            echo "helm"
            ;;
        infra)
            echo "pypi generic"
            ;;
        *)
            echo "docker"
            ;;
    esac
}

echo ""
echo "🚀 Creating repositories for BookVerse microservices platform"
echo "🔧 Project: $PROJECT_KEY"
echo "🔧 JFrog URL: $JFROG_URL"
echo ""

get_visibility_for_service() {
    local service_name="$1"
    case "$service_name" in
        platform)
            echo "public"
            ;;
        *)
            echo "internal"
            ;;
    esac
}

create_repository() {
    local service="$1"
    local package_type="$2"
    local stage="$3"
    
    local visibility
    visibility=$(get_visibility_for_service "$service")
    # Use lowercase stage in repo key for Docker compatibility (Docker requires lowercase in image paths)
    local stage_lower
    stage_lower=$(echo "$stage" | tr '[:upper:]' '[:lower:]')
    local repo_key="${PROJECT_KEY}-${service}-${visibility}-${package_type}-${stage_lower}-local"
    
    if [[ "$stage" == "release" ]]; then
        local environments='["PROD"]'
        local repo_config=$(jq -n \
            --arg key "$repo_key" \
            --arg rclass "local" \
            --arg packageType "$package_type" \
            --arg description "Repository for $service $package_type packages (release)" \
            --arg projectKey "$PROJECT_KEY" \
            --argjson environments "$environments" \
            '{
                "key": $key,
                "rclass": $rclass,
                "packageType": $packageType,
                "description": $description,
                "projectKey": $projectKey,
                "environments": $environments
            }')
    else
        local stage_env="${PROJECT_KEY}-${stage}"
        local environments="[\"${stage_env}\"]"
        local repo_config=$(jq -n \
            --arg key "$repo_key" \
            --arg rclass "local" \
            --arg packageType "$package_type" \
            --arg description "Repository for $service $package_type packages ($stage)" \
            --arg projectKey "$PROJECT_KEY" \
            --argjson environments "$environments" \
            '{
                "key": $key,
                "rclass": $rclass,
                "packageType": $packageType,
                "description": $description,
                "projectKey": $projectKey,
                "environments": $environments
            }')
    fi
    
    echo "Creating repository: $repo_key"
    
    local temp_response=$(mktemp)
    local response_code=$(curl -s --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
        --header "Content-Type: application/json" \
        -X PUT \
        -d "$repo_config" \
        --write-out "%{http_code}" \
        --output "$temp_response" \
        "${JFROG_URL}/artifactory/api/repositories/${repo_key}")
    
    case "$response_code" in
        200|201)
            echo "✅ Repository '$repo_key' created successfully (HTTP $response_code)"
            ;;
        409)
            echo "✅ Repository '$repo_key' already exists and is configured"
            ;;
        400)
            if grep -q -i "already exists\|repository.*exists\|case insensitive.*already exists" "$temp_response"; then
                echo "✅ Repository '$repo_key' already exists (case-insensitive match)"
            else
                echo "⚠️  Repository '$repo_key' creation issue (HTTP $response_code)"
                if [[ "${VERBOSITY:-0}" -ge 1 ]]; then
                    echo "Response body: $(cat "$temp_response")"
                    echo "Repository config sent:"
                    echo "$repo_config" | jq .
                fi
                echo "💡 Repository may exist with different configuration or permissions issue"
                rm -f "$temp_response"
            fi
            ;;
        *)
            echo "❌ Failed to create repository '$repo_key' (HTTP $response_code)"
            if [[ "${VERBOSITY:-0}" -ge 1 ]]; then
                echo "Response body: $(cat "$temp_response")"
                echo "Repository config sent:"
                echo "$repo_config" | jq .
            fi
            echo "💡 This may be due to permissions, API changes, or network issues"
            rm -f "$temp_response"
            return 1
            ;;
    esac
    
    rm -f "$temp_response"

    local expected_envs_json
    if [[ "$stage" == "release" ]]; then
        expected_envs_json='["PROD"]'
    else
        expected_envs_json=$(jq -nc --arg p "$PROJECT_KEY" --arg s "$stage" '[($p+"-"+$s)]')
    fi

    local get_resp_file=$(mktemp)
    local get_code=$(curl -s --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
        --write-out "%{http_code}" --output "$get_resp_file" \
        "${JFROG_URL}/artifactory/api/repositories/${repo_key}")
    if [[ "$get_code" =~ ^2 ]]; then
        local envs_match
        envs_match=$(jq --argjson exp "$expected_envs_json" '(
            ( .environments // [] ) as $cur
            | ($cur | length) == ($exp | length)
            and ((($cur - $exp) | length) == 0)
            and ((($exp - $cur) | length) == 0)
        )' "$get_resp_file" 2>/dev/null || echo "false")
        if [[ "$envs_match" != "true" ]]; then
            echo "Updating environments for repository: $repo_key"
            local updated_config
            updated_config=$(jq --arg projectKey "$PROJECT_KEY" --argjson envs "$expected_envs_json" \
                '.projectKey = $projectKey | .environments = $envs' "$get_resp_file")
            local up_tmp=$(mktemp)
            local up_code=$(curl -s --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
                --header "Content-Type: application/json" -X POST \
                -d "$updated_config" --write-out "%{http_code}" --output "$up_tmp" \
                "${JFROG_URL}/artifactory/api/repositories/${repo_key}")
            case "$up_code" in
                200)
                    echo "✅ Repository '$repo_key' environments updated"
                    ;;
                *)
                    echo "⚠️  Failed to update environments for '$repo_key' (HTTP $up_code)"
                    if [[ "${VERBOSITY:-0}" -ge 1 ]]; then
                        echo "Response body: $(cat "$up_tmp")"
                    fi
                    ;;
            esac
            rm -f "$up_tmp"
        fi
    else
        echo "⚠️  Could not fetch repository '$repo_key' to verify environments (HTTP $get_code)"
    fi
    rm -f "$get_resp_file"
}

SERVICES=("core" "inventory" "recommendations" "checkout" "platform" "web" "helm" "infra")

get_packages_for_service() {
    case "$1" in
        core)
            echo "python docker pypi"
            ;;
        inventory|recommendations|checkout)
            echo "python docker generic"
            ;;
        platform)
            echo "python docker generic"
            ;;
        web)
            echo "npm docker generic"
            ;;
        helm)
            echo "helm generic"
            ;;
        infra)
            echo "pypi generic"
            ;;
        *)
            echo ""
            ;;
    esac
}

echo "Creating repositories for services..."
echo ""

for service in "${SERVICES[@]}"; do
    package_types="$(get_packages_for_service "$service")"
    echo "Processing service: $service (creating: $package_types)"

    for package_type in $package_types; do
        for stage in "${NON_PROD_STAGES[@]}"; do
            create_repository "$service" "$package_type" "$stage"
        done
        create_repository "$service" "$package_type" "release"
    done
    
    echo ""
done

echo "✅ Service repositories creation completed successfully!"
echo ""
echo "ℹ️ Dependency repositories and prepopulation are now run by workflow steps."


prune_old_repositories() {
    echo ""; echo "🧹 Pruning old/misnamed local repositories (project=${PROJECT_KEY})"

    local expected_file
    expected_file=$(mktemp)
    for service in "${SERVICES[@]}"; do
        package_types="$(get_packages_for_service "$service")"
        visibility="$(get_visibility_for_service "$service")"
        for package_type in $package_types; do
            for stage in "${NON_PROD_STAGES[@]}"; do
                stage_lower=$(echo "$stage" | tr '[:upper:]' '[:lower:]')
                key="${PROJECT_KEY}-${service}-${visibility}-${package_type}-${stage_lower}-local"
                echo "$key" >> "$expected_file"
            done
            key="${PROJECT_KEY}-${service}-${visibility}-${package_type}-release-local"
            echo "$key" >> "$expected_file"
        done
    done

    local list_file candidates_file
    list_file=$(mktemp)
    candidates_file=$(mktemp)
    local code=$(curl -s --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
        --header "Accept: application/json" \
        --write-out "%{http_code}" --output "$list_file" \
        "${JFROG_URL}/artifactory/api/repositories?type=local")
    if [[ "$code" -lt 200 || "$code" -ge 300 ]]; then
        echo "⚠️  Failed to list repositories (HTTP $code); skipping prune"
        rm -f "$list_file" "$candidates_file"
        return 0
    fi

    jq -r --arg p "${PROJECT_KEY}-" '[ .[] | select(.key|startswith($p)) | .key ] | .[]' "$list_file" 2>/dev/null > "$candidates_file" || printf '' > "$candidates_file"
    rm -f "$list_file"

    CANDIDATES=()
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        CANDIDATES+=("$line")
    done < "$candidates_file"
    rm -f "$candidates_file"

    local pruned=0
    for key in "${CANDIDATES[@]}"; do
        if [[ "$key" != *"-internal-"* && "$key" != *"-public-"* ]]; then continue; fi
        if [[ "$key" != *"-local" ]]; then continue; fi
        if grep -Fxq "$key" "$expected_file"; then continue; fi
        echo "🗑️  Deleting outdated repo: $key"
        local del_code=$(curl -s -X DELETE \
            --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
            --write-out "%{http_code}" --output /dev/null \
            "${JFROG_URL}/artifactory/api/repositories/${key}" || echo 000)
        if [[ "$del_code" =~ ^2 ]]; then
            echo "✅ Deleted $key"
            pruned=$((pruned+1))
        else
            echo "⚠️  Failed to delete $key (HTTP $del_code)"
        fi
    done

    if [[ "$pruned" -gt 0 ]]; then
        echo "🧹 Prune complete. Removed $pruned repos."
    else
        echo "🧹 No outdated repos found to prune."
    fi

    rm -f "$expected_file"
}

prune_old_repositories