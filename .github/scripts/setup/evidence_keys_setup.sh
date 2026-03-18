#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "$0")/config.sh"

# 🔐 BookVerse Evidence Key Configuration
# Cryptographic key management and evidence collection configuration
ALIAS_DEFAULT="bookverse-signing-key"
KEY_ALIAS="${EVIDENCE_KEY_ALIAS:-$ALIAS_DEFAULT}"

# 📦 BookVerse Service Repository Configuration
# Complete list of all BookVerse service repositories requiring evidence keys
# GH_REPOSITORY_OWNER is validated by config.sh
SERVICE_REPOS=(
  "${GH_REPOSITORY_OWNER}/bookverse-inventory"      # Core business inventory and stock management
  "${GH_REPOSITORY_OWNER}/bookverse-recommendations" # AI-powered personalization engine
  "${GH_REPOSITORY_OWNER}/bookverse-checkout"      # Secure payment processing and transactions
  "${GH_REPOSITORY_OWNER}/bookverse-platform"      # Unified platform coordination and API gateway
  "${GH_REPOSITORY_OWNER}/bookverse-web"          # Customer-facing frontend and static assets
  "${GH_REPOSITORY_OWNER}/bookverse-helm"         # Kubernetes deployment and infrastructure
)

echo "🔐 Evidence Keys Setup"
echo "   🗝️  Alias: $KEY_ALIAS"
echo "   🐸 JFrog: ${JFROG_URL:-unset}"

if [[ -z "${JFROG_URL:-}" || -z "${JFROG_ADMIN_TOKEN:-}" ]]; then
  echo "❌ Missing JFROG_URL or JFROG_ADMIN_TOKEN in environment" >&2
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "❌ GitHub CLI (gh) not found" >&2
  exit 1
fi

check_repo_keys() {
  local repo="$1"
  echo "🔍 Checking for existing keys in $repo..."
  
  local public_key_exists=false
  local alias_exists=false
  
  if gh variable list --repo "$repo" | grep -q "EVIDENCE_PUBLIC_KEY"; then
    public_key_exists=true
  fi
  
  if gh variable list --repo "$repo" | grep -q "EVIDENCE_KEY_ALIAS"; then
    alias_exists=true
  fi
  
  if [[ "$public_key_exists" == true && "$alias_exists" == true ]]; then
    return 0
  else
    return 1
  fi
}

get_repo_keys() {
  local repo="$1"
  local temp_dir="$2"
  
  echo "📥 Retrieving keys from $repo..."
  
  local public_key_content
  local key_alias
  
  public_key_content=$(gh variable get EVIDENCE_PUBLIC_KEY --repo "$repo")
  key_alias=$(gh variable get EVIDENCE_KEY_ALIAS --repo "$repo")
  
  if [[ -z "$public_key_content" || -z "$key_alias" ]]; then
    echo "❌ Failed to retrieve keys from $repo" >&2
    return 1
  fi
  
  printf "%s" "$public_key_content" > "$temp_dir/evidence_public.pem"
  
  KEY_ALIAS="$key_alias"
  
  echo "✅ Retrieved keys from $repo (alias: $key_alias)"
  return 0
}

upload_key_to_jfrog() {
  local public_key_file="$1"
  local alias="$2"
  
  echo "📤 Uploading public key to JFrog trusted keys (alias: $alias)"
  
  local public_key_content
  public_key_content=$(cat "$public_key_file")
  
  local payload
  payload=$(jq -n \
    --arg alias "$alias" \
    --arg public_key "$public_key_content" \
    '{
      "alias": $alias,
      "public_key": $public_key
    }')
  
  local response
  local http_code
  response=$(curl -s -w "%{http_code}" \
    -X POST \
    -H "Authorization: Bearer $JFROG_ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$payload" \
    "$JFROG_URL/artifactory/api/security/keys/trusted")
  
  http_code="${response: -3}"
  
  if [[ "$http_code" == "200" ]] || [[ "$http_code" == "201" ]]; then
    echo "✅ Public key uploaded to JFrog Platform successfully"
    return 0
  
  elif [[ "$http_code" == "409" ]]; then
    echo "🔍 Key '$alias' already exists. Checking if content is identical..."
    
    local existing_key_data
    existing_key_data=$(curl -s -X GET "$JFROG_URL/artifactory/api/security/keys/trusted" \
      -H "Authorization: Bearer $JFROG_ADMIN_TOKEN" | \
      jq --arg alias "$alias" '.keys[] | select(.alias == $alias)')
    
    if [[ -z "$existing_key_data" ]]; then
      echo "❌ Could not fetch existing key data for alias '$alias'"
      return 1
    fi
    
    local existing_public_key
    existing_public_key=$(echo "$existing_key_data" | jq -r '.key')
    
    local normalized_new_key
    local normalized_existing_key
    normalized_new_key=$(echo "$public_key_content" | tr -d '[:space:]')
    normalized_existing_key=$(echo "$existing_public_key" | tr -d '[:space:]')
    
    if [[ "$normalized_new_key" == "$normalized_existing_key" ]]; then
      echo "✅ Existing key is identical. No action needed."
      return 0
    else
      echo "🔄 Existing key is different. Replacing it..."
      
      local kid
      kid=$(echo "$existing_key_data" | jq -r '.kid')
      
      if [[ -z "$kid" || "$kid" == "null" ]]; then
        echo "❌ Could not extract kid from existing key data"
        return 1
      fi
      
      echo "🗑️  Deleting old key (kid: $kid)..."
      local delete_response
      delete_response=$(curl -s -w "%{http_code}" \
        -X DELETE \
        -H "Authorization: Bearer $JFROG_ADMIN_TOKEN" \
        "$JFROG_URL/artifactory/api/security/keys/trusted/$kid")
      
      local delete_http_code="${delete_response: -3}"
      
      if [[ "$delete_http_code" == "200" ]] || [[ "$delete_http_code" == "204" ]]; then
        echo "✅ Old key deleted successfully"
      else
        echo "❌ Failed to delete old key (HTTP $delete_http_code)"
        return 1
      fi
      
      echo "📤 Uploading new key..."
      local upload_response
      upload_response=$(curl -s -w "%{http_code}" \
        -X POST \
        -H "Authorization: Bearer $JFROG_ADMIN_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$JFROG_URL/artifactory/api/security/keys/trusted")
      
      local upload_http_code="${upload_response: -3}"
      
      if [[ "$upload_http_code" == "200" ]] || [[ "$upload_http_code" == "201" ]]; then
        echo "✅ Key '$alias' was replaced successfully"
        return 0
      else
        echo "❌ Failed to upload new key after deletion (HTTP $upload_http_code)"
        echo "Response: ${upload_response%???}"
        return 1
      fi
    fi
  
  else
    echo "❌ Failed to upload public key to JFrog Platform (HTTP $http_code)"
    echo "Response: ${response%???}"
    return 1
  fi
}

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

echo ""
echo "🔍 Checking for existing evidence keys in repositories..."

FIRST_REPO="${SERVICE_REPOS[0]}"
if check_repo_keys "$FIRST_REPO"; then
  echo "✅ Found existing evidence keys in $FIRST_REPO"
  echo "📥 Using existing keys instead of generating new ones"
  
  if get_repo_keys "$FIRST_REPO" "$WORKDIR"; then
    PUBLIC_KEY_CONTENT=$(cat "$WORKDIR/evidence_public.pem")
    
    echo "🧪 Using existing key with alias: $KEY_ALIAS"
    
    if upload_key_to_jfrog "$WORKDIR/evidence_public.pem" "$KEY_ALIAS"; then
      echo "✅ Evidence keys setup complete using existing keys"
    else
      echo "⚠️  Evidence keys setup completed, but JFrog Platform update failed"
    fi
  else
    echo "❌ Failed to retrieve keys from $FIRST_REPO" >&2
    exit 1
  fi
else
  echo "⚠️  No evidence keys found in repositories"
  echo "⚠️  Please run the key replacement script to generate and deploy evidence keys:"
  echo "     ./scripts/update_evidence_keys.sh --generate"
  echo ""
  echo "🚫 Skipping evidence key setup until keys are deployed"
fi

echo "🎉 Evidence keys setup completed"