#!/bin/bash

# Setup script for LocalStack development environment

set -e

echo "🚀 Setting up LocalStack environment..."

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker and try again."
    exit 1
fi

# Start LocalStack
echo "📦 Starting LocalStack..."
docker-compose up -d localstack

# Wait for LocalStack to be ready
echo "⏳ Waiting for LocalStack to be ready..."
timeout=60
counter=0
while ! curl -s http://localhost:4566/_localstack/health > /dev/null; do
    if [ $counter -ge $timeout ]; then
        echo "❌ LocalStack failed to start within $timeout seconds"
        exit 1
    fi
    sleep 2
    counter=$((counter + 2))
    echo "   Still waiting... ($counter/$timeout seconds)"
done

echo "✅ LocalStack is ready!"

# Set environment variables
export AWS_ENDPOINT=http://localhost:4566
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1

echo ""
echo "📝 Environment variables set:"
echo "   AWS_ENDPOINT=$AWS_ENDPOINT"
echo "   AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID"
echo "   AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY"
echo "   AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION"
echo ""
echo "✅ Setup complete! You can now run Terraform commands."
echo ""
echo "Example:"
echo "  cd networking"
echo "  terraform init"
echo "  terraform plan"
echo "  terraform apply"

