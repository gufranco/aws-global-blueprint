#!/bin/bash

# Test script for LocalStack infrastructure

set -e

echo "🧪 Testing LocalStack Infrastructure"
echo "=================================="

# Check if LocalStack is running
if ! curl -s http://localhost:4566/_localstack/health > /dev/null 2>&1; then
    echo "❌ LocalStack is not running. Please start it first:"
    echo "   docker-compose up -d localstack"
    exit 1
fi

echo "✅ LocalStack is running"

# Set environment variables
export AWS_ENDPOINT=http://localhost:4566
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1

# Test networking module
echo ""
echo "📦 Testing Networking Module..."
cd networking

if terraform init -backend=false > /dev/null 2>&1; then
    echo "✅ Networking module initialized"
    
    if terraform validate > /dev/null 2>&1; then
        echo "✅ Networking module validated"
    else
        echo "❌ Networking module validation failed"
        terraform validate
        exit 1
    fi
else
    echo "❌ Networking module initialization failed"
    exit 1
fi

cd ..

# Test serverless module
echo ""
echo "📦 Testing Serverless Module..."
cd serverless

if terraform init -backend=false > /dev/null 2>&1; then
    echo "✅ Serverless module initialized"
    
    if terraform validate > /dev/null 2>&1; then
        echo "✅ Serverless module validated"
    else
        echo "❌ Serverless module validation failed"
        terraform validate
        exit 1
    fi
else
    echo "❌ Serverless module initialization failed"
    exit 1
fi

cd ..

# Test server module
echo ""
echo "📦 Testing Server Module..."
cd server

if terraform init -backend=false > /dev/null 2>&1; then
    echo "✅ Server module initialized"
    
    if terraform validate > /dev/null 2>&1; then
        echo "✅ Server module validated"
    else
        echo "❌ Server module validation failed"
        terraform validate
        exit 1
    fi
else
    echo "❌ Server module initialization failed"
    exit 1
fi

cd ..

echo ""
echo "✅ All modules validated successfully!"
echo ""
echo "To apply infrastructure to LocalStack:"
echo "  cd networking && terraform apply"
echo "  cd ../serverless && terraform apply"
echo "  cd ../server && terraform apply"

