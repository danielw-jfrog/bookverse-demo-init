#!/bin/bash

upload_evidence_key_to_jfrog() {
    local public_key_file="$1"
    local alias="$2"

    local payload
    payload=$(jq -n --arg alias "$alias" --arg public_key "$(cat $public_key_file)" \
        '{
            "alias": $alias,
            "public_key": $public_key
        }' 2>/dev/null)

    if [[ -z "$payload" ]]; then
        echo "ERROR: Command 'jq' not available"
        return 2
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
        echo "Public key uploaded to JFrog Platform"
        return 0
    elif [[ "$http_code" == "409" ]]; then
        echo "ERROR: Key alias '$alias' already exists in JFrog Platform"
        return 1
    else
        echo "ERROR: Failed to upload public key (HTTP $http_code)"
        return 1
    fi
}
export -f upload_evidence_key_to_jfrog
