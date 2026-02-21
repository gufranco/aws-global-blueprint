#!/bin/bash

# Test script for LocalStack infrastructure

set -euo pipefail

echo "Testing LocalStack Infrastructure"
echo "=================================="

# Check if LocalStack is running
if ! curl -s http://localhost:4566/_localstack/health > /dev/null 2>&1; then
    echo "LocalStack is not running. Please start it first:"
    echo "  docker compose up -d localstack"
    exit 1
fi

echo "LocalStack is running"

# Set environment variables
export AWS_ENDPOINT=http://localhost:4566
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1

MODULES=("modules/global" "modules/region" "modules/data" "modules/security" "modules/compliance" "modules/observability" "modules/resilience" "modules/finops")
FAILED=0

for module in "${MODULES[@]}"; do
    echo ""
    echo "Testing $module..."

    if [ -d "$module" ]; then
        pushd "$module" > /dev/null

        if terraform init -backend=false > /dev/null 2>&1; then
            echo "  Initialized"

            if terraform validate > /dev/null 2>&1; then
                echo "  Validated"
            else
                echo "  Validation failed:"
                terraform validate
                FAILED=$((FAILED + 1))
            fi
        else
            echo "  Initialization failed"
            FAILED=$((FAILED + 1))
        fi

        popd > /dev/null
    else
        echo "  Directory not found, skipping"
    fi
done

echo ""
echo "=================================="
if [ $FAILED -eq 0 ]; then
    echo "All modules validated successfully!"
else
    echo "$FAILED module(s) failed validation"
    exit 1
fi
