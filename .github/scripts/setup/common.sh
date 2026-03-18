#!/usr/bin/env bash

# FUNCTIONS PROVIDED:
#     [Error Handling]
#     error_handler()           : Global error handler with detailed context reporting
#     setup_error_handling()    : Initialize error handling for calling scripts
#     
#     [Logging Functions]
#     log_info(), log_success(), log_warning(), log_error(), log_step(), log_config()
#     
#     [HTTP API Functions]
#     jfrog_api_call()          : Standardized HTTP API communication with JFrog Platform
#     handle_api_response()     : Process and categorize HTTP response codes
#     
#     
#     [Script Management]
#     init_script()            : Initialize script with error handling and validation
#     finalize_script()        : Finalize script execution with success/failure reporting
#     process_batch()          : Process arrays of items with consistent error handling
#     
#     [Environment Management]
#     validate_environment()   : Validate required environment variables are present
#     show_config()           : Display current configuration for debugging

# ENVIRONMENT VARIABLES:
#     [Required Variables]
#     JFROG_URL              : JFrog Platform URL (e.g., https://company.jfrog.io)
#     JFROG_ADMIN_TOKEN      : JFrog admin token for API access
#     PROJECT_KEY            : BookVerse project identifier
#     
#     [Optional Variables]
#     LOG_LEVEL              : Logging verbosity [default: INFO]
#     DEBUG                  : Enable debug output [default: false]
#     CI_ENVIRONMENT         : CI/CD environment identifier for debugging

# Exit on any error and treat unset variables as errors for safety
set -euo pipefail

# HTTP Status Code Constants
[[ -z ${HTTP_OK+x} ]] && readonly HTTP_OK=200
[[ -z ${HTTP_CREATED+x} ]] && readonly HTTP_CREATED=201
[[ -z ${HTTP_ACCEPTED+x} ]] && readonly HTTP_ACCEPTED=202
[[ -z ${HTTP_NO_CONTENT+x} ]] && readonly HTTP_NO_CONTENT=204
[[ -z ${HTTP_BAD_REQUEST+x} ]] && readonly HTTP_BAD_REQUEST=400
[[ -z ${HTTP_UNAUTHORIZED+x} ]] && readonly HTTP_UNAUTHORIZED=401
[[ -z ${HTTP_NOT_FOUND+x} ]] && readonly HTTP_NOT_FOUND=404
[[ -z ${HTTP_CONFLICT+x} ]] && readonly HTTP_CONFLICT=409
[[ -z ${HTTP_INTERNAL_ERROR+x} ]] && readonly HTTP_INTERNAL_ERROR=500

# ANSI Color Code Constants
[[ -z ${RED+x} ]] && readonly RED='\033[0;31m'      # Error messages and failures
[[ -z ${GREEN+x} ]] && readonly GREEN='\033[0;32m'   # Success messages and confirmations
[[ -z ${YELLOW+x} ]] && readonly YELLOW='\033[1;33m' # Warning messages and important notices
[[ -z ${BLUE+x} ]] && readonly BLUE='\033[0;34m'     # Informational messages and updates
[[ -z ${PURPLE+x} ]] && readonly PURPLE='\033[0;35m' # Step headers and major operations
[[ -z ${CYAN+x} ]] && readonly CYAN='\033[0;36m'     # Configuration details and debugging
[[ -z ${NC+x} ]] && readonly NC='\033[0m'            # No Color - reset to default

# Global Script State Management
FAILED=false  # Global flag tracking if any operation has failed

# Comprehensive Error Handler
# Arguments:
#   $1 - line_no: Line number where the error occurred
#   $2 - error_code: Exit code from the failed command
#   $3 - script_name: Name of the script where error occurred [optional, auto-detected]
# 
# Outputs:
#   Writes comprehensive error report to stderr with:
#   - Error location and context information
#   - Failed command details and exit code
#   - Environment state and configuration details
#   - Debugging hints and troubleshooting information
error_handler() {
    local line_no=$1
    local error_code=$2
    local script_name=${3:-$(basename "$0")}
    
    echo ""
    echo -e "${RED}❌ SCRIPT ERROR DETECTED!${NC}"
    echo "   Script: $script_name"
    echo "   Line: $line_no"
    echo "   Exit Code: $error_code"
    echo "   Command: ${BASH_COMMAND}"
    echo ""
    echo -e "${CYAN}🔍 DEBUGGING INFORMATION:${NC}"
    echo "   Environment: CI=${CI_ENVIRONMENT:-'Not set'}"
    echo "   Working Directory: $(pwd)"
    echo "   Project: ${PROJECT_KEY:-'Not set'}"
    echo "   JFrog URL: ${JFROG_URL:-'Not set'}"
    echo ""
    exit $error_code
}

setup_error_handling() {
    local script_name=${1:-$(basename "$0")}
    trap "error_handler \${LINENO} \$? \"$script_name\"" ERR
    set -e
}

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
    FAILED=true
}

log_step() {
    echo -e "${PURPLE}🚀 $1${NC}"
}

log_config() {
    echo -e "${CYAN}🔧 $1${NC}"
}

log_section() {
    echo ""
    echo -e "${YELLOW}📋 === $1 ===${NC}"
    echo ""
}
log_debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        echo -e "${CYAN}🔍 $1${NC}"
    fi
}


jfrog_api_call() {
    local method="$1"
    local url="$2"
    local data="${3:-}"
    local output_file="${4:-/dev/null}"
    local temp_file
    temp_file=$(mktemp)
    
    local curl_args=(
        -s
        -w "%{http_code}"
        -o "$temp_file"
        --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}"
        --header "Content-Type: application/json"
        -X "$method"
    )
    
    if [[ -n "$data" ]]; then
        curl_args+=(-d "$data")
    fi
    
    # Debug the curl command
    echo "🔍 DEBUG: jfrog_api_call called with url='$url'" >&2
    echo "🔍 DEBUG: curl_args=(${curl_args[*]})" >&2
    echo "🔍 DEBUG: About to run: curl ${curl_args[*]} '$url'" >&2
    
    local response_code
    response_code=$(curl "${curl_args[@]}" "$url")
    
    if [[ "$output_file" != "/dev/null" ]]; then
        # Debug: Check temp file content before copying
        echo "🔍 DEBUG: temp_file size: $(wc -c < "$temp_file" 2>/dev/null || echo "0") bytes" >&2
        echo "🔍 DEBUG: temp_file content: $(head -c 200 "$temp_file" 2>/dev/null || echo "empty")" >&2
        cp "$temp_file" "$output_file"
    fi
    
    rm -f "$temp_file"
    
    echo "$response_code"
}

handle_api_response() {
    local code="$1"
    local resource_name="$2"
    local operation="${3:-operation}"
    
    case "$code" in
        $HTTP_OK|$HTTP_CREATED)
            log_success "$resource_name $operation successful (HTTP $code)"
            return 0
            ;;
        $HTTP_CONFLICT)
            log_warning "$resource_name already exists (HTTP $code)"
            return 0
            ;;
        $HTTP_BAD_REQUEST)
            log_error "$resource_name $operation failed - bad request (HTTP $code)"
            return 1
            ;;
        $HTTP_UNAUTHORIZED)
            log_error "$resource_name $operation failed - unauthorized (HTTP $code)"
            return 1
            ;;
        $HTTP_NOT_FOUND)
            log_error "$resource_name $operation failed - not found (HTTP $code)"
            return 1
            ;;
        *)
            log_error "$resource_name $operation failed (HTTP $code)"
            return 1
            ;;
    esac
}


init_script() {
    local script_name="${1:-$(basename "$0")}"
    local description="$2"
    
    setup_error_handling "$script_name"
    
    if [[ -z "${PROJECT_KEY:-}" ]]; then
        local script_dir
        script_dir="$(dirname "${BASH_SOURCE[0]}")"
        source "$script_dir/config.sh"
    fi
    
    validate_environment
    
    echo ""
    log_step "$description"
    log_config "Project: ${PROJECT_KEY}"
    log_config "JFrog URL: ${JFROG_URL}"
    echo ""
}

process_batch() {
    local batch_name="$1"
    local items_array_name="$2"
    local processor_function="$3"
    
    local -n items_ref="$items_array_name"
    local total=${#items_ref[@]}
    local count=0
    
    log_step "Processing $total $batch_name..."
    
    for item in "${items_ref[@]}"; do
        ((count++))
        echo ""
        log_info "[$count/$total] Processing $batch_name..."
        
        if ! "$processor_function" "$item"; then
            log_error "Failed to process item $count of $total"
            FAILED=true
        fi
    done
    
    echo ""
    if [[ "$FAILED" != "true" ]]; then
        log_success "All $total $batch_name processed successfully"
    else
        log_error "Some $batch_name failed to process"
    fi
}


validate_environment() {
    local missing_vars=()
    
    if [[ -z "${JFROG_ADMIN_TOKEN}" ]]; then
        missing_vars+=("JFROG_ADMIN_TOKEN")
    fi
    
    if [[ -z "${JFROG_URL}" ]]; then
        missing_vars+=("JFROG_URL")
    fi
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_error "Missing required environment variables:"
        printf '   - %s\n' "${missing_vars[@]}"
        echo ""
        echo "Please set these variables and try again."
        exit 1
    fi
}

check_env_vars() {
    local missing_vars=()
    for var in "$@"; do
        if [[ -z "${!var:-}" ]]; then
            missing_vars+=("$var")
        fi
    done
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_error "Missing required environment variables:"
        printf '   - %s\n' "${missing_vars[@]}"
        echo ""
        echo "Please set these variables and try again."
        exit 1
    fi
}

show_config() {
    log_config "Current BookVerse Configuration:"
    log_config "Project Key: ${PROJECT_KEY}"
    log_config "Project Name: ${PROJECT_DISPLAY_NAME}"
    log_config "JFrog URL: ${JFROG_URL}"
    log_config "Non-Prod Stages: ${NON_PROD_STAGES[*]}"
    log_config "Production Stage: ${PROD_STAGE}"
}

export -f setup_error_handling error_handler
export -f log_info log_success log_warning log_error log_step log_config log_section log_debug
export -f jfrog_api_call handle_api_response


export -f init_script finalize_script process_batch 
export -f validate_environment check_env_vars show_config
