#!/usr/bin/env bash
# This is used in a task in .vscode/tasks.json
# Start developing with:
# - Run Task -> Install Dependencies
# - Debug -> Extension

# Capture the initial directory
INITIAL_DIRECTORY=$(pwd)

# Define the log file name and path using the initial directory
LOG_FILE_NAME="install-dependencies.log"
LOG_FILE_PATH="$INITIAL_DIRECTORY/$LOG_FILE_NAME"

# Clear the log file if it exists, otherwise create a new empty file
if [ -f "$LOG_FILE_PATH" ]; then
    > "$LOG_FILE_PATH"
else
    touch "$LOG_FILE_PATH"
fi

# Function to log messages to a file
log_message() {
    local MESSAGE="$1"
    local HEADER_CHAR="$2"
    local HEADER_LENGTH=80

    # Get timestamp for the log entry
    local TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
    local LOG_ENTRY="[$TIMESTAMP] $MESSAGE"

    # Add header if specified
    if [ -n "$HEADER_CHAR" ]; then
        local HEADER_LINE=$(printf "%-${HEADER_LENGTH}s" | tr ' ' "$HEADER_CHAR")
        echo "[$TIMESTAMP] $HEADER_LINE" >> "$LOG_FILE_PATH"
    fi

    # Add the actual log entry
    echo "$LOG_ENTRY" >> "$LOG_FILE_PATH"
}

# Function to execute a command and log its output
execute_command() {
    local COMMAND="$1"
    log_message "Executing: $COMMAND"
    eval "$COMMAND" >> "$LOG_FILE_PATH" 2>&1
    if [ $? -ne 0 ]; then
        log_message "Command failed: $COMMAND" "!"
        echo "Check 'install-dependencies.log' for details."
        exit 1
    fi
}

# Ensure all required commands are available
check_dependency() {
    local DEP="$1"
    if ! command -v "$DEP" &> /dev/null; then
        echo "$DEP could not be found. Please install it before proceeding."
        log_message "$DEP could not be found."
        exit 1
    else
        echo "$DEP found."
        log_message "$DEP found."
    fi
}

# Check for required dependencies
echo "Checking for required dependencies..."
log_message "Checking for required dependencies..." "#"
check_dependency "npm"

# Install dependencies for different parts
sections=(
    "core"
    "gui"
    "extensions/vscode"
    "binary"
    "docs"
)

for section in "${sections[@]}"; do
    echo "Installing $section extension dependencies..."
    log_message "Installing $section extension dependencies..." "#"
    pushd "$section" > /dev/null
    execute_command "npm install"
    if [ "$section" == "core" ]: then
        execute_command "npm link"
    elif [ "$section" == "gui" ]; then
        execute_command "npm link @continuedev/core"
        execute_command "npm run build"
    elif [ "$section" == "extensions/vscode" ]; then
        execute_command "npm link @continuedev/core"
        execute_command "npm run prepackage"
        execute_command "npm run package"
    elif [ "$section" == "binary" ]; then
        execute_command "npm run build"
    fi
    popd > /dev/null
done

echo "All dependencies installed successfully."
log_message "All dependencies installed successfully."
