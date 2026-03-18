#!/usr/bin/env bash

set -e

source "$(dirname "$0")/config.sh"

echo ""
echo "🚀 Creating BookVerse users and assigning project roles"
echo "🔧 Project: $PROJECT_KEY"
echo "🔧 JFrog URL: $JFROG_URL"
echo ""

BOOKVERSE_USERS=(
    "alice.developer@bookverse.com|alice.developer@bookverse.com|BookVerse2024!|Developer"
    "bob.release@bookverse.com|bob.release@bookverse.com|BookVerse2024!|Release Manager"
    "charlie.devops@bookverse.com|charlie.devops@bookverse.com|BookVerse2024!|Project Manager"
    "diana.architect@bookverse.com|diana.architect@bookverse.com|BookVerse2024!|AppTrust Admin"
    "edward.manager@bookverse.com|edward.manager@bookverse.com|BookVerse2024!|AppTrust Admin"
    "frank.inventory@bookverse.com|frank.inventory@bookverse.com|BookVerse2024!|Inventory Manager"
    "grace.ai@bookverse.com|grace.ai@bookverse.com|BookVerse2024!|AI/ML Manager"
    "henry.checkout@bookverse.com|henry.checkout@bookverse.com|BookVerse2024!|Checkout Manager"
    "ivan.devops@bookverse.com|ivan.devops@bookverse.com|BookVerse2024!|DevOps Manager"
    "pipeline.inventory@bookverse.com|pipeline.inventory@bookverse.com|Pipeline2024!|Pipeline User"
    "pipeline.recommendations@bookverse.com|pipeline.recommendations@bookverse.com|Pipeline2024!|Pipeline User"
    "pipeline.checkout@bookverse.com|pipeline.checkout@bookverse.com|Pipeline2024!|Pipeline User"
    "pipeline.web@bookverse.com|pipeline.web@bookverse.com|Pipeline2024!|Pipeline User"
    "pipeline.platform@bookverse.com|pipeline.platform@bookverse.com|Pipeline2024!|Pipeline User"
    "pipeline.helm@bookverse.com|pipeline.helm@bookverse.com|Pipeline2024!|Pipeline User"
    "k8s.pull@bookverse.com|k8s.pull@bookverse.com|K8sPull2024!|K8s Pull User"
)

PLATFORM_OWNERS=(
    "diana.architect@bookverse.com"
    "edward.manager@bookverse.com"
    "charlie.devops@bookverse.com"
    "bob.release@bookverse.com"
    "frank.inventory@bookverse.com"
    "grace.ai@bookverse.com"
    "henry.checkout@bookverse.com"
    "ivan.devops@bookverse.com"
)

is_platform_owner() {
    local username="$1"
    for owner in "${PLATFORM_OWNERS[@]}"; do
        [[ "$username" == "$owner" ]] && return 0
    done
    return 1
}

is_pipeline_user() {
    local username="$1"
    [[ "$username" == pipeline.*@* ]]
}

map_role_to_project_role() {
    local title="$1"
    case "$title" in
        "Developer") echo "Developer" ;;
        "Release Manager") echo "Release Manager" ;;
        "Project Manager") echo "Project Admin" ;;
        "AppTrust Admin") echo "Release Manager" ;;
        "Inventory Manager"|"AI/ML Manager"|"Checkout Manager"|"DevOps Manager") echo "Release Manager" ;;
        "Pipeline User") echo "Developer" ;;
        "K8s Pull User") echo "Viewer" ;;
        *) echo "Viewer" ;;
    esac
}

create_user() {
    local username="$1"
    local email="$2"
    local password="$3"
    local role="$4"
    
    echo "Creating user: $username ($role)"
    
    local user_payload=$(jq -n \
        --arg name "$username" \
        --arg email "$email" \
        --arg password "$password" \
        '{
            "name": $name,
            "email": $email,
            "password": $password,
            "admin": false,
            "profileUpdatable": true,
            "disableUIAccess": false,
            "groups": ["readers"]
        }')
    
    local temp_response=$(mktemp)
    local response_code=$(curl -s --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
        --header "Content-Type: application/json" \
        -X PUT \
        -d "$user_payload" \
        --write-out "%{http_code}" \
        --output "$temp_response" \
        "${JFROG_URL}/artifactory/api/security/users/${username}")
    
    case "$response_code" in
        200|201)
            echo "✅ User '$username' created successfully (HTTP $response_code)"
            ;;
        409)
            echo "⚠️  User '$username' already exists (HTTP $response_code)"
            ;;
        400)
            if grep -q -i "already exists\|user.*exists" "$temp_response"; then
                echo "⚠️  User '$username' already exists (HTTP $response_code)"
            else
                echo "❌ Failed to create user '$username' (HTTP $response_code)"
                echo "Response body: $(cat "$temp_response")"
                rm -f "$temp_response"
                return 1
            fi
            ;;
        *)
            echo "❌ Failed to create user '$username' (HTTP $response_code)"
            echo "Response body: $(cat "$temp_response")"
            rm -f "$temp_response"
            return 1
            ;;
    esac
    
    rm -f "$temp_response"
}

assign_project_roles() {
    local username="$1"; shift
    local roles=("$@")

    local joined
    joined=$(printf "%s:::" "${roles[@]}")
    joined="${joined%:::}"

    echo "Assigning project roles to $username for project $PROJECT_KEY: ${roles[*]}"

    local role_payload=$(jq -n \
        --arg roles_str "$joined" \
        '{
            "roles": ( $roles_str | split(":::") )
        }')

    local temp_response=$(mktemp)
    local response_code=$(curl -s --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
        --header "Content-Type: application/json" \
        -X PUT \
        -d "$role_payload" \
        --write-out "%{http_code}" \
        --output "$temp_response" \
        "${JFROG_URL}/access/api/v1/projects/${PROJECT_KEY}/users/${username}")

    case "$response_code" in
        200|201|204)
            echo "✅ Roles assigned to '$username' successfully (HTTP $response_code)"
            ;;
        409)
            echo "⚠️  Roles already assigned to '$username' (HTTP $response_code)"
            ;;
        400)
            if grep -q -i "already.*assign\|role.*exists" "$temp_response"; then
                echo "⚠️  Roles already assigned to '$username' (HTTP $response_code)"
            else
                echo "❌ Failed to assign roles to '$username' (HTTP $response_code)"
                echo "Response body: $(cat "$temp_response")"
                rm -f "$temp_response"
                return 1
            fi
            ;;
        *)
            echo "❌ Failed to assign roles to '$username' (HTTP $response_code)"
            echo "Response body: $(cat "$temp_response")"
            rm -f "$temp_response"
            return 1
            ;;
    esac

    rm -f "$temp_response"
}

echo "ℹ️  Users to be created:"
for user_data in "${BOOKVERSE_USERS[@]}"; do
    IFS='|' read -r username email password role <<< "$user_data"
    mapped=$(map_role_to_project_role "$role")
    if is_platform_owner "$username"; then
        echo "   - $username ($role → $mapped) + Project Admin"
    else
        echo "   - $username ($role → $mapped)"
    fi
done

echo ""
echo "🔧 Ensuring project role 'cicd_pipeline' exists..."

CICD_PIPELINE_ROLE_AVAILABLE=false

ensure_cicd_pipeline_role() {
    local role_name="cicd_pipeline"
    local tmp=$(mktemp)

    local list_code=$(curl -s \
        --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
        --header "Accept: application/json" \
        -w "%{http_code}" -o "$tmp" \
        "${JFROG_URL}/access/api/v1/projects/${PROJECT_KEY}/roles")
    if [[ "$list_code" -ge 200 && "$list_code" -lt 300 ]] && grep -q '"name"\s*:\s*"'"$role_name"'"' "$tmp" 2>/dev/null; then
        echo "✅ Project role '$role_name' already exists"
        CICD_PIPELINE_ROLE_AVAILABLE=true
        rm -f "$tmp"
        return 0
    fi
    rm -f "$tmp"

    echo "🛠️  Creating project role '$role_name' with validated CUSTOM schema"

    local payload=$(jq -n \
        --arg name "$role_name" \
        --arg desc "Role for QA and testing activities, allowing read access to dev repositories." \
        --arg proj "$PROJECT_KEY" \
        '{
            name: $name,
            description: $desc,
            type: "CUSTOM",
            actions: [
                "ANNOTATE_BUILD",
                "ANNOTATE_RELEASE_BUNDLE",
                "ANNOTATE_REPOSITORY",
                "MANAGE_XRAY_MD_BUILD",
                "MANAGE_XRAY_MD_RELEASE_BUNDLE",
                "MANAGE_XRAY_MD_REPOSITORY",
                "BIND_APPLICATION",
                "CREATE_APPLICATION",
                "CREATE_RELEASE_BUNDLE",
                "DELETE_APPLICATION",
                "DELETE_BUILD",
                "DELETE_OVERWRITE_REPOSITORY",
                "DELETE_RELEASE_BUNDLE",
                "DEPLOY_BUILD",
                "DEPLOY_CACHE_REPOSITORY",
                "PROMOTE_APPLICATION",
                "READ_APPLICATION",
                "READ_BUILD",
                "READ_RELEASE_BUNDLE",
                "READ_REPOSITORY"
            ],
            environments: [
                ($proj + "-DEV"),
                ($proj + "-QA"),
                ($proj + "-STAGING"),
                "PROD",
                "DEV"
            ]
        }')

    local resp=$(mktemp)
    local code=$(curl -s \
        --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
        --header "Content-Type: application/json" \
        --write-out "%{http_code}" -o "$resp" \
        -X POST \
        -d "$payload" \
        "${JFROG_URL}/access/api/v1/projects/${PROJECT_KEY}/roles")
    if [[ "$code" == "409" || "$code" =~ ^20 ]]; then
        echo "✅ Project role '$role_name' ensured (HTTP $code)"
        CICD_PIPELINE_ROLE_AVAILABLE=true
    else
        echo "⚠️  Role creation returned HTTP $code; response: $(cat "$resp")"
    fi
    rm -f "$resp"
}

ensure_cicd_pipeline_role

if [[ "$CICD_PIPELINE_ROLE_AVAILABLE" != true ]]; then
    echo "⚠️  Proceeding without custom role 'cicd_pipeline' (fallback will assign 'Project Admin' to pipeline users)"
fi

ensure_k8s_image_pull_role() {
    local role_name="k8s_image_pull"
    local tmp=$(mktemp)

    local list_code=$(curl -s \
        --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
        --header "Accept: application/json" \
        -w "%{http_code}" -o "$tmp" \
        "${JFROG_URL}/access/api/v1/projects/${PROJECT_KEY}/roles")
    if [[ "$list_code" -ge 200 && "$list_code" -lt 300 ]] && grep -q '"name"\s*:\s*"'"$role_name"'"' "$tmp" 2>/dev/null; then
        echo "✅ Project role '$role_name' already exists"
        K8S_IMAGE_PULL_ROLE_AVAILABLE=true
        rm -f "$tmp"
        return 0
    fi
    rm -f "$tmp"

    echo "🛠️  Creating project role '$role_name' with minimal read permissions for K8s image pulling"

    local payload=$(jq -n \
        --arg name "$role_name" \
        --arg desc "Kubernetes Image Pull - Minimal read access to PROD repositories for container deployment" \
        --arg proj "$PROJECT_KEY" \
        '{
            name: $name,
            description: $desc,
            type: "CUSTOM",
            actions: [
                "READ_REPOSITORY",
                "READ_RELEASE_BUNDLE",
                "READ_APPLICATION"
            ],
            environments: [
                "PROD"
            ]
        }')

    local resp=$(mktemp)
    local code=$(curl -s \
        --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
        --header "Content-Type: application/json" \
        --write-out "%{http_code}" -o "$resp" \
        -X POST \
        -d "$payload" \
        "${JFROG_URL}/access/api/v1/projects/${PROJECT_KEY}/roles")
    if [[ "$code" == "409" || "$code" =~ ^20 ]]; then
        echo "✅ Project role '$role_name' ensured (HTTP $code)"
        K8S_IMAGE_PULL_ROLE_AVAILABLE=true
    else
        echo "⚠️  K8s role creation returned HTTP $code; response: $(cat "$resp")"
        # Record error for job summary detection
        echo "K8s role creation failed: k8s_image_pull (HTTP $code)" >> /tmp/setup_errors.log 2>/dev/null || true
    fi
    rm -f "$resp"
}

ensure_k8s_image_pull_role

if [[ "$K8S_IMAGE_PULL_ROLE_AVAILABLE" != true ]]; then
    echo "⚠️  Proceeding without custom role 'k8s_image_pull' (fallback will assign 'Viewer' to K8s users)"
fi

echo "🚀 Processing ${#BOOKVERSE_USERS[@]} users..."

for user_data in "${BOOKVERSE_USERS[@]}"; do
    IFS='|' read -r username email password role <<< "$user_data"

    echo ""
    echo "Processing user: $username ($role)"

    create_user "$username" "$email" "$password" "$role"

    project_roles=("$(map_role_to_project_role "$role")")
    if is_platform_owner "$username"; then
        needs_admin=true
        for r in "${project_roles[@]}"; do
            if [[ "$r" == "Project Admin" ]]; then
                needs_admin=false
                break
            fi
        done
        if [[ "$needs_admin" == true ]]; then
            project_roles+=("Project Admin")
        fi
    fi

    if is_pipeline_user "$username"; then
        cleaned_roles=()
        for r in "${project_roles[@]}"; do
            if [[ "$r" != "Developer" && -n "$r" ]]; then
                cleaned_roles+=("$r")
            fi
        done
        project_roles=("${cleaned_roles[@]}")

        if [[ "$CICD_PIPELINE_ROLE_AVAILABLE" == true ]]; then
            already=false
            for r in "${project_roles[@]}"; do
                if [[ "$r" == "cicd_pipeline" ]]; then already=true; break; fi
            done
            if [[ "$already" == false ]]; then
                project_roles+=("cicd_pipeline")
            fi
        else
            has_admin=false
            for r in "${project_roles[@]}"; do
                if [[ "$r" == "Project Admin" ]]; then has_admin=true; break; fi
            done
            if [[ "$has_admin" == false ]]; then
                project_roles+=("Project Admin")
            fi
        fi
    fi

    if [[ "$username" == k8s.*@* ]]; then
        cleaned_roles=()
        for r in "${project_roles[@]}"; do
            if [[ "$r" != "Viewer" && -n "$r" ]]; then
                cleaned_roles+=("$r")
            fi
        done
        project_roles=("${cleaned_roles[@]}")

        if [[ "$K8S_IMAGE_PULL_ROLE_AVAILABLE" == true ]]; then
            already=false
            for r in "${project_roles[@]}"; do
                if [[ "$r" == "k8s_image_pull" ]]; then already=true; break; fi
            done
            if [[ "$already" == false ]]; then
                project_roles+=("k8s_image_pull")
            fi
        else
            has_viewer=false
            for r in "${project_roles[@]}"; do
                if [[ "$r" == "Viewer" ]]; then has_viewer=true; break; fi
            done
            if [[ "$has_viewer" == false ]]; then
                project_roles+=("Viewer")
            fi
        fi
    fi

    assign_project_roles "$username" "${project_roles[@]}"
done

echo ""
echo "✅ User creation completed successfully!"
echo ""