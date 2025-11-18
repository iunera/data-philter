#!/bin/sh

echo "

 ▄▄▄▄▄                                             ▄▄▄▄▄▄    ▄▄           ██     ▄▄▄▄
 ██▀▀▀██               ██                          ██▀▀▀▀█▄  ██           ▀▀     ▀▀██        ██
 ██    ██   ▄█████▄  ███████    ▄█████▄            ██    ██  ██▄████▄   ████       ██      ███████    ▄████▄    ██▄████
 ██    ██   ▀ ▄▄▄██    ██       ▀ ▄▄▄██            ██████▀   ██▀   ██     ██       ██        ██      ██▄▄▄▄██   ██▀
 ██    ██  ▄██▀▀▀██    ██      ▄██▀▀▀██            ██        ██    ██     ██       ██        ██      ██▀▀▀▀▀▀   ██
 ██▄▄▄██   ██▄▄▄███    ██▄▄▄   ██▄▄▄███            ██        ██    ██  ▄▄▄██▄▄▄    ██▄▄▄     ██▄▄▄   ▀██▄▄▄▄█   ██
 ▀▀▀▀▀      ▀▀▀▀ ▀▀     ▀▀▀▀    ▀▀▀▀ ▀▀            ▀▀        ▀▀    ▀▀  ▀▀▀▀▀▀▀▀     ▀▀▀▀      ▀▀▀▀     ▀▀▀▀▀    ▀▀


"

GREEN='\033[0;32m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m' # No Color

set -eu

# Defaults
DATA_PHILTER_DIR="$HOME/.data-philter"
# TODO change the URLs to main branch when ready
BASE_URL="https://raw.githubusercontent.com/iunera/data-philter/refs/heads/main"
URL="$BASE_URL/docker-compose.yml"
APP_ENV_TEMPLATE_URL="$BASE_URL/app.env_template"
DRUID_ENV_TEMPLATE_URL="$BASE_URL/druid.env_template"
TMP_FILES=""
CREATED_ENV_FILES=""
INSTALL_OK=0
EXISTING_ENV_FILES=""

log() { printf "%b\n" "${GREEN}$*${NC}"; }
info() { printf "%b\n" "$*"; }
err() { printf "%b\n" "${RED}$*${NC}" 1>&2; }
die() { err "$*"; exit 1; }

# Cleanup temporary files on exit and remove created env files on cancellation
cleanup() {
    # remove temp files
    for f in $TMP_FILES; do
        [ -n "$f" ] && [ -f "$f" ] && rm -f "$f" || true
    done

    # if installation didn't complete successfully, remove any env files we created
    if [ "$INSTALL_OK" -ne 1 ]; then
        for ef in $CREATED_ENV_FILES; do
            if [ -n "$ef" ] && [ -f "$ef" ]; then
                # only remove if it did NOT exist before the script started
                found=0
                for ex in $EXISTING_ENV_FILES; do
                    if [ "$ex" = "$ef" ]; then
                        found=1
                        break
                    fi
                done
                if [ "$found" -eq 0 ]; then
                    info "Installation canceled — removing $ef"
                    rm -f "$ef" || true
                else
                    info "Installation canceled — leaving pre-existing $ef"
                fi
            fi
        done
    fi
}

cleanup_and_exit() {
    # accept optional exit code
    code=${1:-1}
    # disable EXIT trap to avoid double-running cleanup
    trap - EXIT
    cleanup
    exit $code
}

# Traps: on INT/TERM do cleanup_and_exit with appropriate codes; on EXIT do cleanup
trap 'cleanup_and_exit 130' INT
trap 'cleanup_and_exit 143' TERM
trap cleanup EXIT

# Parse args
while [ "$#" -gt 0 ]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        *)
            err "Unknown option: $1"
            usage
            exit 2
            ;;
    esac
done

log "🚀 Welcome to the Data Philter Installer! 🚀"
info "This script will guide you through the setup process."

# portable download helper: curl preferred, fallback to wget
download_file() {
    url=$1
    dest=$2
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$url" -o "$dest"
        return $?
    elif command -v wget >/dev/null 2>&1; then
        wget -q -O "$dest" "$url"
        return $?
    else
        return 2
    fi
}

ensure_dir() {
    dir=$1
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir" || die "Failed to create directory: $dir"
    fi
}

install_ollama() {
    if command -v ollama >/dev/null 2>&1; then
        return 0
    fi

    printf "Ollama is not installed. Do you want to install Ollama now? (y/n) [y]: "
    # read input (fall back to empty if read fails), trim and apply default 'n' when empty
    read -r consent < /dev/tty || consent=""
    consent=$(printf "%s" "$consent" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    consent=${consent:-y}
    if [ "$consent" != "y" ]; then
        die "Ollama installation skipped. Please install it manually to proceed."
    fi

    OS=$(uname -s)
    case "$OS" in
        Linux)
            info "Installing Ollama for Linux..."
            if command -v curl >/dev/null 2>&1; then
                curl -fsSL https://ollama.com/install.sh | sh || die "Ollama install failed on Linux"
            else
                die "curl required to install Ollama on Linux. Please install Ollama manually."
            fi
            ;;
        Darwin)
            info "Installing Ollama for macOS..."
            if command -v brew >/dev/null 2>&1; then
                brew install ollama || die "Homebrew reported failure installing Ollama"
            else
                die "Homebrew not found. Install Homebrew (https://brew.sh) or install Ollama manually from https://ollama.com/download"
            fi
            ;;
        *)
            die "Unsupported OS for automatic Ollama installation: $OS — install manually from https://ollama.com/download"
            ;;
    esac

    if ! command -v ollama >/dev/null 2>&1; then
        die "Ollama installation failed or ollama command not found."
    fi
    log "Ollama installed successfully."
}

remove_key_from_template() {
    template_file=$1
    key=$2
    if [ -f $template_file ]; then
        # Use inline sed with cross-platform handling (macOS requires a zero-length backup suffix)
        if [ "$(uname -s)" = "Darwin" ]; then
            sed -i '' "/^${key}=/d" $template_file || true
        else
            sed -i "/^${key}=/d" $template_file || true
        fi
        log "Removed ${key} from ${template_file}"
    fi
}

# New: encapsulate model provider selection + setup in its own function
configure_model_choice() {
    log "🔧 Step 3.5: Configuring AI Model Type..."
    MODEL_CHOICE=""
    while :; do
        printf "Choose your AI model provider (ollama/openai) [ollama]: "
        # read input (fall back to empty on failure), trim and lowercase, then apply default 'ollama' when empty
        read -r MODEL_CHOICE < /dev/tty || MODEL_CHOICE=""
        MODEL_CHOICE=$(printf "%s" "$MODEL_CHOICE" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr '[:upper:]' '[:lower:]')
        MODEL_CHOICE=${MODEL_CHOICE:-ollama}
        case "$MODEL_CHOICE" in
            ollama)
                # Ask for model size
                while :; do
                    printf "Choose Ollama model size (small/medium/large/xl) [small]:"
                    # read input (fall back to empty on failure), trim/lowercase, then default to 'small' if empty
                    read -r SIZE_CHOICE < /dev/tty || SIZE_CHOICE=""
                    SIZE_CHOICE=$(printf "%s" "$SIZE_CHOICE" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr '[:upper:]' '[:lower:]')
                    SIZE_CHOICE=${SIZE_CHOICE:-small}
                    case "$SIZE_CHOICE" in
                        small|s)
                            export IUNERA_MODEL_TYPE="ollama-s"
                            break
                            ;;
                        medium|m)
                            export IUNERA_MODEL_TYPE="ollama-m"
                            break
                            ;;
                        large|l)
                            export IUNERA_MODEL_TYPE="ollama-l"
                            break
                            ;;
                        xl|xlarge|extra-large|"extra large")
                            export IUNERA_MODEL_TYPE="ollama-xl"
                            break
                            ;;
                        *)
                            err "Invalid choice. Please enter 'small', 'medium', 'large', or 'xl'."
                            ;;
                    esac
                done

                remove_key_from_template "app.env_template" "SPRING_AI_OPENAI_API_KEY"
                break
                ;;
            openai)
                export IUNERA_MODEL_TYPE="openai"
                # Prompt for API key only if not already set in env
                if [ -z "$(eval "printf '%s' "\${SPRING_AI_OPENAI_API_KEY:-}"")" ]; then
                    printf "Enter your OpenAI API Key (SPRING_AI_OPENAI_API_KEY): "
                    read -r SPRING_AI_OPENAI_API_KEY < /dev/tty || SPRING_AI_OPENAI_API_KEY=""
                    # trim leading/trailing whitespace
                    SPRING_AI_OPENAI_API_KEY=$(printf "%s" "$SPRING_AI_OPENAI_API_KEY" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                    if [ -z "$SPRING_AI_OPENAI_API_KEY" ]; then
#                        die "OpenAI API Key cannot be empty if 'openai' is selected."
                        remove_key_from_template "app.env_template" "SPRING_AI_OPENAI_API_KEY"
                    fi
                    export SPRING_AI_OPENAI_API_KEY
                else
                    # Already set in environment, export to ensure it's available
                    export SPRING_AI_OPENAI_API_KEY
                fi
                break
                ;;
            *)
                err "Invalid choice. Please enter 'ollama' or 'openai'."
                ;;
        esac
    done

    case "$IUNERA_MODEL_TYPE" in
        ollama-*)
            if ! command -v ollama >/dev/null 2>&1; then
                install_ollama
            fi
            # Ensure Ollama server is running
            if ! ollama ps >/dev/null 2>&1; then
                info "Ollama is not running. Attempting to start Ollama server in the background..."
                ollama serve >/dev/null 2>&1 &
                sleep 5
                if ! ollama ps >/dev/null 2>&1; then
                    die "Failed to start Ollama server. Please check your Ollama installation."
                fi
                log "Ollama server started successfully in the background."
            fi
            ;;
    esac
}

configure_env_file() {
    TEMPLATE_FILE=$1
    ENV_FILE=$2

    if [ -f "$ENV_FILE" ]; then
        info "$ENV_FILE already exists, skipping configuration."
        return 0
    fi

    info "Configuring $ENV_FILE..."
    # We'll write to a temp file first
    TMP_ENV=$(mktemp)
    TMP_FILES="$TMP_FILES $TMP_ENV"

    comment_block=""
    while IFS= read -r line || [ -n "$line" ]; do
        # Preserve comment lines and accumulate contiguous comment lines to show before the next var prompt
        case "$line" in
            "" )
                # blank line
                printf "%s\n" "" >> "$TMP_ENV"
                comment_block=""
                ;;
            \#*)
                printf "%s\n" "$line" >> "$TMP_ENV"
                # append this comment line (strip trailing whitespace)
                clean=$(printf "%s" "$line" | sed 's/[[:space:]]*$//')
                comment_block="${comment_block}${clean}\n"
                ;;
            *"="*)
                # split on first '='
                key=$(printf "%s" "$line" | sed 's/=.*$//')
                value=$(printf "%s" "$line" | sed 's/^[^=]*=//')
                if [ -z "$value" ]; then
                    # If an environment variable with this key already exists, use it
                    # Use eval to expand the variable name stored in $key into a parameter expansion
                    # e.g. if key=SPRING_AI_OPENAI_API_KEY the eval becomes: printf '%s' "${SPRING_AI_OPENAI_API_KEY:-}"
                    env_value=""
                    # Read the value of the exported environment variable named by $key.
                    # Use printenv which returns empty/non-zero if the variable is not exported.
                    env_value=$(printenv "$key" 2>/dev/null || true)
                     if [ -n "$env_value" ]; then
                        printf "%s=%s\n" "$key" "$env_value" >> "$TMP_ENV"
                    elif [ "$key" = "DRUID_SSL_ENABLED" ]; then
                        # leave placeholder; we'll set later based on DRUID_ROUTER_URL
                        printf "%s=\n" "$key" >> "$TMP_ENV"
                    else
                        # interactive: show accumulated comment block (if any)
                        if [ -n "$comment_block" ]; then
                            printf "\n"
                            printf "%s" "$comment_block" | while IFS= read -r cline || [ -n "$cline" ]; do
                                # remove leading '# ' for rest part
                                rest=$(printf "%s" "$cline" | sed 's/^#[[:space:]]*//;s/[[:space:]]*$//')
                                printf "%b\n" "${BOLD}#${NC}${rest}"
                            done
                        fi

                        # prompt loop that trims input and confirms empty values
                        while :; do
                            printf "%s: " "$key"
                            read -r user_value < /dev/tty || user_value=""
                            # trim leading/trailing whitespace
                            user_value=$(printf "%s" "$user_value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                            if [ -n "$user_value" ]; then
                                printf "%s=%s\n" "$key" "$user_value" >> "$TMP_ENV"
                                break
                            fi
                            # empty after trim -> ask for confirmation
                            printf "Empty value — really save? (y/n): "
                            # read confirm, trim and default to 'n' if empty
                            read -r confirm < /dev/tty || confirm=""
                            confirm=$(printf "%s" "$confirm" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                            confirm=${confirm:-n}
                            if [ "$confirm" = "y" ]; then
                                printf "%s=\n" "$key" >> "$TMP_ENV"
                                break
                            fi
                            # otherwise, re-display comment block (if any) and prompt again
                            if [ -n "$comment_block" ]; then
                                printf "%s" "$comment_block" | while IFS= read -r cline || [ -n "$cline" ]; do
                                    rest=$(printf "%s" "$cline" | sed 's/^#[[:space:]]*//;s/[[:space:]]*$//')
                                    printf "%b\n" "${BOLD}#${NC}${rest}"
                                done
                            fi
                        done
                    fi
                else
                    # preserve the existing assignment line
                    printf "%s\n" "$line" >> "$TMP_ENV"
                fi
                comment_block=""
                ;;
            *)
                # unknown line, preserve
                printf "%s\n" "$line" >> "$TMP_ENV"
                ;;
        esac
    done < "$TEMPLATE_FILE"

    # If this is druid.env, determine DRUID_SSL_ENABLED based on DRUID_ROUTER_URL
    if [ "$(basename "$ENV_FILE")" = "druid.env" ]; then
        # extract DRUID_ROUTER_URL
        DRUID_ROUTER_URL=$(grep '^DRUID_ROUTER_URL=' "$TMP_ENV" 2>/dev/null | sed 's/^DRUID_ROUTER_URL=//') || DRUID_ROUTER_URL=""
        if printf "%s" "$DRUID_ROUTER_URL" | grep -q '^https://' 2>/dev/null; then
            DRUID_SSL_ENABLED_VALUE=true
        else
            DRUID_SSL_ENABLED_VALUE=false
        fi
        # replace or add DRUID_SSL_ENABLED line
        if grep -q '^DRUID_SSL_ENABLED=' "$TMP_ENV" 2>/dev/null; then
            # use portable sed with temp file
            TMP2=$(mktemp)
            TMP_FILES="$TMP_FILES $TMP2"
            sed "s|^DRUID_SSL_ENABLED=.*|DRUID_SSL_ENABLED=$DRUID_SSL_ENABLED_VALUE|" "$TMP_ENV" > "$TMP2"
            mv "$TMP2" "$TMP_ENV"
        else
            printf "DRUID_SSL_ENABLED=%s\n" "$DRUID_SSL_ENABLED_VALUE" >> "$TMP_ENV"
        fi
    fi

    mv "$TMP_ENV" "$ENV_FILE"
    # remove from TMP_FILES list since moved to final location
    TMP_FILES=$(printf "%s" "$TMP_FILES" | sed "s# $TMP_ENV##g")
    CREATED_ENV_FILES="$CREATED_ENV_FILES $ENV_FILE"
    log "$ENV_FILE configured."
}

# Step 1: create directory
log "🔧 Step 1: Creating directory..."
info "We will create the $DATA_PHILTER_DIR directory to store environment files."
ensure_dir "$DATA_PHILTER_DIR"
cd "$DATA_PHILTER_DIR" || die "Failed to enter directory $DATA_PHILTER_DIR"

# Record which env files already existed before we start creating any
for f in app.env druid.env; do
    if [ -f "$f" ]; then
        EXISTING_ENV_FILES="$EXISTING_ENV_FILES $f"
        # Ask user whether to recreate (overwrite) or keep the existing file
        while :; do
            printf "Found existing %s. Do you want to recreate (overwrite) it? [y/N]: " "$f"
            # read resp, trim and default to 'n' when empty
            read -r resp < /dev/tty || resp=""
            # trim whitespace
            resp=$(printf "%s" "$resp" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            resp=${resp:-n}
            case "$resp" in
                y|Y)
                    info "User chose to recreate $f — it will be overwritten."
                    # remove the existing file so configure_env_file will create a fresh one
                    rm -f "$f" || true
                    break
                    ;;
                *)
                    info "Keeping existing $f — installer will skip configuring it."
                    break
                    ;;
            esac
        done
    fi
done

# Step 2: Download templates
log "🔧 Step 2: Downloading templates..."
info "Downloading app.env_template"
TMP_APP_TEMPLATE=$(mktemp)
TMP_FILES="$TMP_FILES $TMP_APP_TEMPLATE"
if ! download_file "$APP_ENV_TEMPLATE_URL" "$TMP_APP_TEMPLATE"; then
    die "Failed to download app.env_template from $APP_ENV_TEMPLATE_URL"
fi
info "Downloading druid.env_template"
TMP_DRUID_TEMPLATE=$(mktemp)
TMP_FILES="$TMP_FILES $TMP_DRUID_TEMPLATE"
if ! download_file "$DRUID_ENV_TEMPLATE_URL" "$TMP_DRUID_TEMPLATE"; then
    die "Failed to download druid.env_template from $DRUID_ENV_TEMPLATE_URL"
fi
# Move templates into place (will be removed after configuration)
mv "$TMP_APP_TEMPLATE" app.env_template
mv "$TMP_DRUID_TEMPLATE" druid.env_template
# remove them from TMP_FILES
TMP_FILES=$(printf "%s" "$TMP_FILES" | sed "s# $TMP_APP_TEMPLATE##g" | sed "s# $TMP_DRUID_TEMPLATE##g")

# Step 3: Check dependencies (Docker and Ollama)
log "🔧 Step 3: Checking dependencies..."
if ! command -v docker >/dev/null 2>&1; then
    die "docker could not be found, please install it first."
fi

DOCKER_CMD="docker"
if ! docker ps >/dev/null 2>&1; then
    info "Could not connect to Docker as current user. Attempting to use 'sudo' for Docker commands (you may be prompted)."
    if ! sudo docker ps >/dev/null 2>&1; then
        die "Failed to run docker (even with sudo). Please check your docker installation and permissions."
    fi
    DOCKER_CMD="sudo docker"
fi

if ! $DOCKER_CMD compose version >/dev/null 2>&1; then
    die "'docker compose' could not be found. It is required to run this script. Please ensure you have a recent Docker installation."
fi

# Step 3.5: Configure AI Model Type
# If app.env already exists and IUNERA_MODEL_TYPE is set (in env or inside app.env),
# skip the interactive model configuration step.
SKIP_MODEL_CONFIG=0
if [ -f "app.env" ]; then
    if [ -n "${IUNERA_MODEL_TYPE:-}" ] || grep -q '^IUNERA_MODEL_TYPE=' app.env 2>/dev/null; then
        info "app.env exists and IUNERA_MODEL_TYPE is set — skipping model configuration."
        SKIP_MODEL_CONFIG=1
        # Ensure IUNERA_MODEL_TYPE is exported if it's only present in app.env
        if [ -z "${IUNERA_MODEL_TYPE:-}" ]; then
            IUNERA_MODEL_TYPE=$(grep '^IUNERA_MODEL_TYPE=' app.env | sed 's/^IUNERA_MODEL_TYPE=//')
            export IUNERA_MODEL_TYPE
        fi
        # If using an Ollama model, ensure Ollama is installed and running (same behavior as in configure_model_choice)
        case "$IUNERA_MODEL_TYPE" in
            ollama-*)
                if ! command -v ollama >/dev/null 2>&1; then
                    install_ollama
                fi
                if ! ollama ps >/dev/null 2>&1; then
                    info "Ollama is not running. Attempting to start Ollama server in the background..."
                    ollama serve >/dev/null 2>&1 &
                    sleep 5
                    if ! ollama ps >/dev/null 2>&1; then
                        die "Failed to start Ollama server. Please check your Ollama installation."
                    fi
                    log "Ollama server started successfully in the background."
                fi
                ;;
        esac
    fi
fi

if [ "${SKIP_MODEL_CONFIG}" -ne 1 ]; then
    configure_model_choice
fi

# Step 4: Configure environment files
log "🔧 Step 4: Configuring environment files..."
configure_env_file app.env_template app.env
configure_env_file druid.env_template druid.env

# remove templates
rm -f app.env_template druid.env_template

# Step 5: Download docker-compose.yml
log "🔧 Step 5: Downloading docker-compose.yml..."
if ! download_file "$URL" docker-compose.yml; then
    die "Failed to download docker-compose.yml from $URL"
fi

# Step 6: Start services
log "🔧 Step 6: Starting services..."
$DOCKER_CMD compose up -d

log "Services started in the background."
info "You can check the status with '$DOCKER_CMD ps'."

log "✅ Installation complete!"
info "You can now access the application at http://localhost:4000"

open_browser() {
    URL=$1

    # Wait for backend to be ready before opening the browser
    # Try for up to 120 seconds
    WAIT_TIMEOUT=120
    WAIT_INTERVAL=2
    waited=0

    info "Waiting for backend to become available at $URL (timeout: ${WAIT_TIMEOUT}s)..."
    while [ $waited -lt $WAIT_TIMEOUT ]; do
        if command -v curl >/dev/null 2>&1; then
            if curl -fsS -o /dev/null "$URL/actuator/health" >/dev/null 2>&1; then
                log "Backend is up!"
                break
            fi
        elif command -v wget >/dev/null 2>&1; then
            if wget -q --spider "$URL" >/dev/null 2>&1; then
                log "Backend is up!"
                break
            fi
        else
            # Neither curl nor wget available; do a simple grace wait once
            if [ $waited -eq 0 ]; then
                info "curl/wget not found — waiting 10s before opening the browser..."
            fi
            sleep 10 || true
            waited=$((waited + 10))
            break
        fi
        sleep $WAIT_INTERVAL || true
        waited=$((waited + WAIT_INTERVAL))
    done

    if [ $waited -ge $WAIT_TIMEOUT ]; then
        err "Backend did not become ready within ${WAIT_TIMEOUT}s. You may need to wait a bit longer."
    fi

    OS=$(uname -s)
    case "$OS" in
        Linux)
            if command -v xdg-open >/dev/null 2>&1; then
                xdg-open "$URL" >/dev/null 2>&1 &
                log "Opening $URL in your default browser..."
            else
                info "Could not find xdg-open. Please open $URL manually."
            fi
            ;;
        Darwin)
            open "$URL" >/dev/null 2>&1 &
            log "Opening $URL in your default browser..."
            ;;
        *)
            info "Unsupported OS for automatic browser opening. Please open $URL manually."
            ;;
    esac
}

open_browser "http://localhost:4000"

INSTALL_OK=1
