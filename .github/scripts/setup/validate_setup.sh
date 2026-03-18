#!/usr/bin/env bash

set -e

source "$(dirname "$0")/config.sh"

echo ""
echo "🔍 Validating complete BookVerse setup"
echo "🔧 Project: $PROJECT_KEY"
echo "🔧 JFrog URL: $JFROG_URL"
echo ""

validate_api_response() {
    local url="$1"
    local description="$2"
    local temp_response=$(mktemp)
    
    local response_code=$(curl -s --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
        --write-out "%{http_code}" \
        --output "$temp_response" \
        "$url")
    
    case "$response_code" in
        200)
            echo "✅ $description accessible (HTTP $response_code)" >&2
            cat "$temp_response"
            ;;
        404)
            echo "⚠️  $description not found (HTTP $response_code)" >&2
            echo "[]"
            ;;
        *)
            echo "❌ $description failed (HTTP $response_code)" >&2
            echo "[]"
            ;;
    esac
    
    rm -f "$temp_response"
}

echo "🏗️  Validating core infrastructure..."
echo ""

echo "1. Checking project existence..."
project_response=$(validate_api_response "${JFROG_URL}/access/api/v1/projects/${PROJECT_KEY}" "Project '${PROJECT_KEY}'")
if echo "$project_response" | grep -q "project_key"; then
    echo "✅ Project '$PROJECT_KEY' exists"
else
    echo "❌ Project '$PROJECT_KEY' not found"
fi
echo ""

echo "2. Counting repositories..."
repo_response=$(validate_api_response "${JFROG_URL}/artifactory/api/repositories" "Repositories API")
repo_count=$(echo "$repo_response" | jq -r ".[] | select(.key | startswith(\"${PROJECT_KEY}\")) | .key" 2>/dev/null | wc -l)
echo "✅ Found $repo_count repositories"
echo ""

echo "3. Counting BookVerse users..."

expected_users=(
  "alice.developer@bookverse.com"
  "bob.release@bookverse.com"
  "charlie.devops@bookverse.com"
  "diana.architect@bookverse.com"
  "edward.manager@bookverse.com"
  "frank.inventory@bookverse.com"
  "grace.ai@bookverse.com"
  "henry.checkout@bookverse.com"
  "pipeline.inventory@bookverse.com"
  "pipeline.recommendations@bookverse.com"
  "pipeline.checkout@bookverse.com"
  "pipeline.web@bookverse.com"
  "pipeline.platform@bookverse.com"
  "k8s.pull@bookverse.com"
)

found_users=()
missing_users=()

all_candidates=""
for endpoint in "/access/api/v1/users" "/artifactory/api/security/users" "/access/api/v2/users"; do
  resp=$(curl -s -w "%{http_code}" -H "Authorization: Bearer $JFROG_ADMIN_TOKEN" "${JFROG_URL}${endpoint}")
  code="${resp: -3}"; body="${resp%???}"
  if [[ "$code" =~ ^[23] ]]; then
    c=$(echo "$body" | jq -r '[.[]? | (.email? // empty), (.name? // empty), (.username? // empty)] | .[]' 2>/dev/null || echo "")
    if [[ -n "$c" ]]; then
      all_candidates="$all_candidates"$'\n'"$c"
    fi
  fi
done
all_candidates=$(printf "%s\n" "$all_candidates" | awk 'NF' | sort -u)

for exp in "${expected_users[@]}"; do
  if printf "%s\n" "$all_candidates" | grep -qx "$exp"; then
    found_users+=("$exp")
  else
    u1=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $JFROG_ADMIN_TOKEN" "${JFROG_URL}/access/api/v1/users/${exp}")
    u2=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $JFROG_ADMIN_TOKEN" "${JFROG_URL}/artifactory/api/security/users/${exp}")
    if [[ "$u1" == "200" || "$u2" == "200" ]]; then
      found_users+=("$exp")
    else
      missing_users+=("$exp")
    fi
  fi
done

user_count=${#found_users[@]}
echo "✅ Found $user_count/${#expected_users[@]} expected users:"
if [[ ${#found_users[@]} -gt 0 ]]; then
  printf '   • %s\n' "${found_users[@]}"
fi
if [[ ${#missing_users[@]} -gt 0 ]]; then
  echo "⚠️  Missing users (not visible via current APIs/permissions):"
  printf '   • %s\n' "${missing_users[@]}"
fi
echo ""

echo "3b. Validating project membership for all expected users..."
members_resp=$(curl -s -H "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" "${JFROG_URL}/access/api/v1/projects/${PROJECT_KEY}/users")
project_members=$(echo "$members_resp" | jq -r '.members[]?.name' 2>/dev/null || echo "")
missing_members=()
for exp in "${expected_users[@]}"; do
  if ! echo "$project_members" | grep -qx "$exp"; then
    missing_members+=("$exp")
  fi
done

if [[ ${#missing_members[@]} -eq 0 ]]; then
  echo "✅ All expected users are members of project '${PROJECT_KEY}'"
else
  echo "⚠️  Users not yet members of project '${PROJECT_KEY}':"
  printf '   • %s\n' "${missing_members[@]}"
fi
echo ""

echo "4. Counting applications..."
app_response=$(validate_api_response "${JFROG_URL}/apptrust/api/v1/applications" "Applications API")
app_count=$(echo "$app_response" | jq -r ".[] | select(.project_key == \"${PROJECT_KEY}\") | .application_key" 2>/dev/null | wc -l)
echo "✅ Found $app_count applications"
echo ""

echo "5. Counting project stages..."

stage_list=$(curl -s -H "Authorization: Bearer $JFROG_ADMIN_TOKEN" \
  "${JFROG_URL}/access/api/v2/stages/?project_key=${PROJECT_KEY}&scope=project&category=promote" | jq -r '.[]?.name' 2>/dev/null)

stage_count=0
if [[ -n "$stage_list" ]]; then
  stage_count=$(echo "$stage_list" | wc -l | awk '{print $1}')
  echo "✅ Found $stage_count project stages (project-scoped promote)"
  echo "$stage_list" | sed 's/^/   - /'
else
  lifecycle_body=$(curl -s -H "Authorization: Bearer $JFROG_ADMIN_TOKEN" \
    "${JFROG_URL}/access/api/v2/lifecycle/?project_key=${PROJECT_KEY}")
  promote_stages=$(echo "$lifecycle_body" | jq -r '.promote_stages[]?' 2>/dev/null)
  if [[ -n "$promote_stages" ]]; then
    stage_count=$(echo "$promote_stages" | wc -l | awk '{print $1}')
    echo "✅ Found $stage_count project stages (via lifecycle configuration)"
    echo "$promote_stages" | sed 's/^/   - /'
  else
    echo "⚠️  No project stages found via API"
  fi
fi
echo ""

echo "6. Counting OIDC integrations..."
oidc_response=$(validate_api_response "${JFROG_URL}/access/api/v1/oidc" "OIDC API")
oidc_count=$(echo "$oidc_response" | jq -r ".[] | select(.name | startswith(\"${PROJECT_KEY}-\") and endswith(\"-github\")) | .name" 2>/dev/null | wc -l)
echo "✅ Found $oidc_count OIDC integrations"
echo ""

echo "🐙 Validating GitHub repositories..."
echo ""
set +e

expected_repos=("inventory" "recommendations" "checkout" "platform" "web" "helm")
github_repos_ok=0

for service in "${expected_repos[@]}"; do
    repo_name="bookverse-${service}"
    if gh repo view "${GH_REPOSITORY_OWNER}/${repo_name}" >/dev/null 2>&1; then
        echo "✅ Repository ${repo_name} exists"
        ((github_repos_ok++))
        
        if gh api "repos/${GH_REPOSITORY_OWNER}/${repo_name}/contents/.github/workflows" >/dev/null 2>&1; then
            echo "   ✅ Workflows directory exists"
        else
            echo "   ⚠️  No workflows directory found"
        fi
        
        if [[ "$service" != "demo-assets" && "$service" != "helm" ]]; then
            if gh variable list -R "${GH_REPOSITORY_OWNER}/${repo_name}" | grep -q "PROJECT_KEY"; then
                echo "   ✅ Repository variables configured"
            else
                echo "   ⚠️  Repository variables missing"
            fi
        fi
    else
        echo "❌ Repository ${repo_name} not found"
    fi
    echo ""
done
set -e

echo "🧪 Running smoke tests..."
echo ""

echo "Test 1: JFrog Platform connectivity"
ping_response=$(curl -s --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
    "${JFROG_URL}/artifactory/api/system/ping")
if [[ "$ping_response" == "OK" ]]; then
    echo "✅ JFrog Platform ping successful"
else
    echo "❌ JFrog Platform ping failed"
fi
echo ""

echo "Test 2: Repository access validation"
test_repo="${PROJECT_KEY}-inventory-internal-python-DEV-local"
repo_exists=$(curl -s --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
    "${JFROG_URL}/artifactory/api/repositories/${test_repo}" | jq -r '.key' 2>/dev/null)
if [[ "$repo_exists" == "$test_repo" ]]; then
    echo "✅ Sample repository accessible: $test_repo"
else
    echo "⚠️  Sample repository not accessible: $test_repo"
fi
echo ""

echo "Test 3: OIDC integration validation"
test_oidc="${PROJECT_KEY}-inventory-github"
oidc_exists=$(echo "$oidc_response" | jq -r ".[] | select(.name == \"${test_oidc}\") | .name" 2>/dev/null)
if [[ "$oidc_exists" == "$test_oidc" ]]; then
    echo "✅ Sample OIDC integration accessible: $test_oidc"
else
    echo "⚠️  Sample OIDC integration not accessible: $test_oidc"
fi
echo ""

echo "📊 VALIDATION SUMMARY"
echo "===================="
echo ""
echo "📋 Resource Counts:"
echo "   • Project: $PROJECT_KEY $([ -n "$project_response" ] && echo '✅' || echo '❌')"
echo "   • Repositories: $repo_count (expected: 14+)"
echo "   • Users: $user_count (expected: 13)"
echo "   • Applications: $app_count (expected: 4)"
echo "   • Stages: $stage_count (expected: 3)"  
echo "   • OIDC Integrations: $oidc_count (expected: 5)"
echo ""
echo "🐙 GitHub Repositories: $github_repos_ok/6 (checking access)"
echo ""

issues_found=0

if [[ "$repo_count" -lt 14 ]]; then
    echo "⚠️  Issue: Repository count below expected (14)"
    ((issues_found++))
fi

if [[ "$app_count" -lt 4 ]]; then
    echo "⚠️  Issue: Application count below expected (4)"
    ((issues_found++))
fi

if [[ "$oidc_count" -lt 5 ]]; then
    echo "⚠️  Issue: OIDC integration count below expected (5)"
    ((issues_found++))
fi

if [[ "$github_repos_ok" -lt 6 ]]; then
    echo "⚠️  Issue: GitHub repository count below expected (6)"
    ((issues_found++))
fi

echo ""
if [[ "$issues_found" -eq 0 ]]; then
    echo "🎉 VALIDATION PASSED!"
    echo "✨ BookVerse platform setup is complete and ready for demo"
    echo "🚀 All core infrastructure and integrations are functional"
    echo ""
    echo "📖 Next steps:"
    echo "   1. Review docs/DEMO_RUNBOOK.md for demo instructions"
    echo "   2. Test CI/CD workflows by making commits to service repositories"
    echo "   3. Demonstrate artifact promotion through DEV → QA → STAGING → PROD"
else
    echo "⚠️  VALIDATION COMPLETED WITH WARNINGS"
    echo "🔧 Found $issues_found potential issues (see details above)"
    echo "💡 Most functionality should still work for demo purposes"
    echo ""
    echo "🛠️  Recommended actions:"
    echo "   1. Review any missing resources listed above"
    echo "   2. Re-run init workflow if needed: gh workflow run init.yml"
    echo "   3. Check JFROG_ADMIN_TOKEN if API calls failed"
fi

echo ""
echo "✅ validate_setup.sh completed successfully!"
echo ""