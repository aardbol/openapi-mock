#!/usr/bin/env bash

set -e

# Configuration - Set your LocalStack Auth Token here
LOCALSTACK_AUTH_TOKEN="${LOCALSTACK_AUTH_TOKEN:-}"

# LocalStack directory - you can override this by setting LOCALSTACK_DIR environment variable
LOCALSTACK_DIR="${LOCALSTACK_DIR:-$HOME/.localstack}"

# AWS Profile - you can override this by setting AWS_PROFILE environment variable
AWS_PROFILE="${AWS_PROFILE:-default}"

LOCALSTACK_DNS="${LOCALSTACK_DNS:-1.1.1.1}"

echo "🚀 LocalStack Setup Script"
echo "========================="

if [ -z "$LOCALSTACK_AUTH_TOKEN" ]; then
    echo "❌ ERROR: LOCALSTACK_AUTH_TOKEN is not set!"
    echo ""
    echo "Please set your LocalStack auth token in one of these ways:"
    echo "1. Edit this script and set LOCALSTACK_AUTH_TOKEN variable"
    echo "2. Export it as environment variable: export LOCALSTACK_AUTH_TOKEN=your-token"
    echo "3. Pass it when running: LOCALSTACK_AUTH_TOKEN=your-token ./localstack_setup.sh start"
    echo ""
    echo "Get your token from: https://app.localstack.cloud/workspace/auth-token"
    exit 1
fi

echo "✅ LocalStack auth token is configured"

# Check if Docker service is running using systemctl
check_docker_service() {
    if command -v systemctl &> /dev/null; then
        if systemctl is-active --quiet docker.service || systemctl is-active --quiet docker.socket; then
            echo "✅ Docker service is running"
            return 0
        else
            echo "❌ Docker service is not running"
            echo "Start it with: sudo systemctl start docker"
            exit 1
        fi
    else
        # Fallback to docker command check
        if ! command -v docker &> /dev/null; then
            echo "❌ Docker is not installed. Please install Docker first."
            exit 1
        fi

        if ! docker info &> /dev/null; then
            echo "❌ Docker is not running. Please start Docker first."
            exit 1
        fi
        echo "✅ Docker is installed and running"
    fi
}

# Create LocalStack directory and virtual environment
setup_environment() {
    echo "📁 Setting up LocalStack environment in: $LOCALSTACK_DIR"

    mkdir -p "$LOCALSTACK_DIR"
    cd "$LOCALSTACK_DIR"

    if [ ! -d "venv" ]; then
        echo "🐍 Creating Python virtual environment..."
        python3 -m venv venv
    fi

    echo "🔧 Activating virtual environment..."
    source venv/bin/activate

    echo "⬆️  Upgrading pip..."
    pip install --upgrade pip

    echo "📦 Installing LocalStack and tools..."
    pip install localstack awscli awscli-local terraform-local

    echo "✅ Environment setup complete"
}

start_localstack() {
    cd "$LOCALSTACK_DIR"
    source venv/bin/activate

    echo "🚀 Starting LocalStack..."

    export LOCALSTACK_AUTH_TOKEN="$LOCALSTACK_AUTH_TOKEN"

    localstack start -d

    echo "⏳ Waiting for LocalStack to be ready..."
    timeout=60
    counter=0

    while [ $counter -lt $timeout ]; do
        if curl -s http://localhost:4566/_localstack/health >/dev/null 2>&1; then
            echo "✅ LocalStack is ready!"
            echo "🌐 LocalStack Gateway: http://localhost:4566"
            echo "📊 Health endpoint: http://localhost:4566/_localstack/health"
            echo "🗂️  Data directory: $LOCALSTACK_DIR/volume"
            break
        fi
        sleep 2
        counter=$((counter + 2))
    done

    if [ $counter -ge $timeout ]; then
        echo "⚠️  LocalStack might still be starting up. Check with: localstack logs"
    fi
}

stop_localstack() {
    cd "$LOCALSTACK_DIR"
    source venv/bin/activate

    echo "🛑 Stopping LocalStack..."
    localstack stop
}

show_logs() {
    cd "$LOCALSTACK_DIR"
    source venv/bin/activate

    localstack logs
}

show_status() {
    cd "$LOCALSTACK_DIR"
    source venv/bin/activate

    echo "📊 LocalStack Status:"
    localstack status
    echo ""
    echo "🏥 Health Check:"
    curl -s http://localhost:4566/_localstack/health 2>/dev/null | python3 -m json.tool || echo "LocalStack not accessible"
}

configure_aws() {
    cd "$LOCALSTACK_DIR"
    source venv/bin/activate

    echo "🔧 Configuring AWS CLI for LocalStack (profile: $AWS_PROFILE)..."

    # Configure specified profile for LocalStack
    aws configure set aws_access_key_id test --profile "$AWS_PROFILE"
    aws configure set aws_secret_access_key test --profile "$AWS_PROFILE"
    aws configure set region us-east-1 --profile "$AWS_PROFILE"
    aws configure set output json --profile "$AWS_PROFILE"

    echo "✅ AWS CLI configured for LocalStack (profile: $AWS_PROFILE)"
    echo "💡 Use 'awslocal' command instead of 'aws' for LocalStack operations"
    if [ "$AWS_PROFILE" != "default" ]; then
        echo "   Example: awslocal s3 ls --profile $AWS_PROFILE"
    else
        echo "   Example: awslocal s3 ls"
    fi
}

# Check Docker first
check_docker_service

case "${1:-}" in
    "setup"|"install")
        setup_environment
        echo ""
        echo "🎉 Setup complete! Next steps:"
        echo "1. ./localstack_setup.sh start"
        echo "2. ./localstack_setup.sh configure-aws"
        ;;
    "start")
        if [ ! -d "$LOCALSTACK_DIR/venv" ]; then
            echo "🔧 Virtual environment not found. Running setup first..."
            setup_environment
        fi
        start_localstack
        ;;
    "stop")
        stop_localstack
        ;;
    "restart")
        stop_localstack
        sleep 2
        start_localstack
        ;;
    "logs")
        show_logs
        ;;
    "status")
        show_status
        ;;
    "configure-aws")
        configure_aws
        ;;
    "full")
        echo "🚀 Running full LocalStack setup..."
        setup_environment
        configure_aws
        start_localstack
        echo ""
        echo "🎉 Full setup complete! LocalStack is running and AWS CLI is configured."
        ;;
    *)
        echo "📋 Usage: $0 {setup|start|stop|restart|logs|status|configure-aws|full}"
        echo ""
        echo "Commands:"
        echo "  setup         - Install LocalStack and create virtual environment"
        echo "  start         - Start LocalStack (auto-setup if needed)"
        echo "  stop          - Stop LocalStack"
        echo "  restart       - Restart LocalStack"
        echo "  logs          - Show LocalStack logs"
        echo "  status        - Show LocalStack status"
        echo "  configure-aws - Configure AWS CLI for LocalStack"
        echo "  full          - Complete setup (setup + configure-aws + start)"
        echo ""
        echo "Configuration:"
        echo "  LOCALSTACK_AUTH_TOKEN - Your LocalStack auth token (required)"
        echo "  LOCALSTACK_DIR        - Installation directory (default: ~/.localstack)"
        echo "  AWS_PROFILE           - AWS CLI profile name (default: default)"
        echo ""
        echo "⚠️  Don't forget to set LOCALSTACK_AUTH_TOKEN!"
        echo ""
        echo "Quick start (one command):"
        echo "  export LOCALSTACK_AUTH_TOKEN=your-token"
        echo "  ./localstack_setup.sh full"
        echo ""
        echo "Step by step:"
        echo "  1. Get auth token from: https://app.localstack.cloud/workspace/auth-token"
        echo "  2. export LOCALSTACK_AUTH_TOKEN=your-token"
        echo "  3. ./localstack_setup.sh setup"
        echo "  4. ./localstack_setup.sh start"
        echo ""
        echo "Custom AWS profile:"
        echo "  AWS_PROFILE=localstack ./localstack_setup.sh configure-aws"
        echo ""
        echo "📚 Documentation: https://docs.localstack.cloud/"
        ;;
esac
