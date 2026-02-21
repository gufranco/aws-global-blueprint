#!/bin/bash

# Validate all Terraform modules

set -euo pipefail

echo "Validating all Terraform modules..."
echo "======================================"

MODULES=("modules/global" "modules/region" "modules/data" "modules/security" "modules/compliance" "modules/observability" "modules/resilience" "modules/finops")
FAILED=0

for module in "${MODULES[@]}"; do
    echo ""
    echo "Validating $module..."

    if [ -d "$module" ]; then
        pushd "$module" > /dev/null

        if terraform init -backend=false > /dev/null 2>&1; then
            if terraform validate > /dev/null 2>&1; then
                if terraform fmt -check > /dev/null 2>&1; then
                    echo "  OK (init, validate, fmt)"
                else
                    echo "  Format issues found (run: terraform fmt)"
                    FAILED=$((FAILED + 1))
                fi
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
echo "======================================"
if [ $FAILED -eq 0 ]; then
    echo "All modules validated successfully!"
    exit 0
else
    echo "$FAILED module(s) failed validation"
    exit 1
fi
