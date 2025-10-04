#!/bin/bash
# Wrapper functions for deployment with verbose error handling

# Override the default error handler to show more information
verbose_error_handler() {
    local exit_code=$1
    local line_number=$2
    local bash_lineno=$3
    local last_command=$4

    echo "=============== ERROR DETECTED ==============="
    echo "Exit Code: $exit_code"
    echo "Line Number: $line_number"
    echo "Command: $last_command"
    echo "Script: ${BASH_SOURCE[1]}"
    echo "Function Stack: ${FUNCNAME[*]}"
    echo "=============================================="

    # Don't exit, just log the error
    return 0
}

# Function to safely execute commands with full debugging
safe_execute() {
    local cmd="$*"
    echo "[EXECUTE] Running: $cmd"

    # Execute with full output
    set +e  # Temporarily disable exit on error
    eval "$cmd"
    local result=$?
    set -e  # Re-enable exit on error

    if [ $result -ne 0 ]; then
        echo "[ERROR] Command failed with exit code $result: $cmd"
        return $result
    else
        echo "[SUCCESS] Command completed successfully"
        return 0
    fi
}

export -f verbose_error_handler
export -f safe_execute
