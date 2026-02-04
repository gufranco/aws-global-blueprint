#!/bin/bash

# Validate all Terraform modules

set -e

echo "🔍 Validating all Terraform modules..."
echo "======================================"

MODULES=("networking" "serverless" "server" "lambda" "edge" "cognito" "dynamodb" "s3" "sa-east-1")
FAILED=0

for module in "${MODULES[@]}"; do
    echo ""
    echo "📦 Validating $module module..."
    
    if [ -d "$module" ]; then
        cd "$module"
        
        if terraform init -backend=false > /dev/null 2>&1; then
            if terraform validate > /dev/null 2>&1; then
                if terraform fmt -check > /dev/null 2>&1; then
                    echo "✅ $module: OK (init, validate, fmt)"
                else
                    echo "⚠️  $module: Format issues found (run: terraform fmt)"
                    FAILED=$((FAILED + 1))
                fi
            else
                echo "❌ $module: Validation failed"
                terraform validate
                FAILED=$((FAILED + 1))
            fi
        else
            echo "❌ $module: Initialization failed"
            FAILED=$((FAILED + 1))
        fi
        
        cd ..
    else
        echo "⚠️  $module: Directory not found, skipping"
    fi
done

echo ""
echo "======================================"
if [ $FAILED -eq 0 ]; then
    echo "✅ All modules validated successfully!"
    exit 0
else
    echo "❌ $FAILED module(s) failed validation"
    exit 1
fi

