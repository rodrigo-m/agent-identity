#!/bin/bash
# ==============================================================================
# Google Cloud Vertex AI Agent Engine - ADK Agent Deployment Script
# Deploys or updates an ADK agent codebase to a pre-defined Agent Engine ID.
# ==============================================================================

set -euo pipefail

# Color Codes for elegant output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# --- Configurations ---
REGION="us-central1"
AGENT_DIR="secret_agent"

# --- Arguments and Defaults ---
AGENT_ENGINE_ID="${1:-}"

# Automatically discover current project ID
PROJECT_ID="${GOOGLE_CLOUD_PROJECT:-}"
if [ -z "${PROJECT_ID}" ] || [ "${PROJECT_ID}" = "(unset)" ]; then
    PROJECT_ID=$(gcloud config get-value project 2>/dev/null || true)
fi

if [ -z "${PROJECT_ID}" ] || [ "${PROJECT_ID}" = "(unset)" ]; then
    log_error "Could not detect your active Google Cloud Project ID."
    echo "Please set it with: export GOOGLE_CLOUD_PROJECT=your-project-id"
    exit 1
fi

echo -e "${BLUE}======================================================================${NC}"
echo -e "${BLUE}Vertex AI Agent Engine - Pre-defined Agent ID Deployment${NC}"
echo -e "${BLUE}======================================================================${NC}"
log_info "Target Project ID:  ${PROJECT_ID}"
log_info "Target Region:      ${REGION}"
log_info "Agent Directory:    ${AGENT_DIR}"

# --- Prompt for Agent Engine ID if not provided ---
if [ -z "${AGENT_ENGINE_ID}" ]; then
    echo -e "\n${YELLOW}No Agent Engine ID was provided as an argument.${NC}"
    log_info "Searching for existing reasoning engine deployments in project '${PROJECT_ID}'..."
    
    # Try listing existing reasoning engines to help the user choose
    EXISTING_ENGINES=$(gcloud ai reasoning-engines list --project="${PROJECT_ID}" --region="${REGION}" --format="value(name, displayName)" 2>/dev/null || true)
    
    if [ -n "${EXISTING_ENGINES}" ]; then
        echo -e "\n${GREEN}Found existing Reasoning Engine resources in '${REGION}':${NC}"
        echo "--------------------------------------------------------"
        echo "${EXISTING_ENGINES}" | while read -r line; do
            RE_NAME=$(echo "$line" | awk '{print $1}')
            DISPLAY_NAME=$(echo "$line" | cut -f2-)
            RE_ID=$(basename "${RE_NAME}")
            echo -e "  • ID: ${GREEN}${RE_ID}${NC} \t(Display Name: '${DISPLAY_NAME}')"
        done
        echo "--------------------------------------------------------"
    else
        log_warning "No active Reasoning Engines found in '${REGION}' region."
    fi
    
    echo -ne "\n${YELLOW}Please enter the target Pre-defined Agent ID to deploy to: ${NC}"
    read -r AGENT_ENGINE_ID
fi

if [ -z "${AGENT_ENGINE_ID}" ]; then
    log_error "An Agent Engine ID is required for deployment."
    exit 1
fi

log_info "Deploying code to Pre-defined Agent Engine ID: ${AGENT_ENGINE_ID}"

# --- Detect ADK Executable ---
ADK_EXEC=""
if [ -f ".venv/bin/adk" ]; then
    ADK_EXEC=".venv/bin/adk"
elif [ -f "venv/bin/adk" ]; then
    ADK_EXEC="venv/bin/adk"
elif command -v adk &>/dev/null; then
    ADK_EXEC="adk"
fi

if [ -z "${ADK_EXEC}" ]; then
    log_error "Google Agent Development Kit (ADK) command-line interface was not found."
    echo "Please ensure you have initialized your Python virtual environment and installed google-adk:"
    echo "  source .venv/bin/activate && pip install google-adk"
    exit 1
fi

log_info "Using ADK executable: ${ADK_EXEC}"

# --- Execute Deployment ---
echo -e "\n${BLUE}Executing ADK Deployment Command...${NC}"
DEPLOY_CMD="${ADK_EXEC} deploy agent_engine \
  --project=${PROJECT_ID} \
  --region=${REGION} \
  --display_name=\"Secret Agent\" \
  --description=\"Retrieves a secret from Google Cloud Secret Manager.\" \
  --agent_engine_id=${AGENT_ENGINE_ID} \
  ${AGENT_DIR}"

log_info "Running: ${DEPLOY_CMD}"
echo "--------------------------------------------------------"

# Run command
eval "${DEPLOY_CMD}"

echo "--------------------------------------------------------"
log_success "Deployment completed successfully to Agent ID: ${AGENT_ENGINE_ID}!"
echo -e "${BLUE}======================================================================${NC}"
