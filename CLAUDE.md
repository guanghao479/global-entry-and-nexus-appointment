# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Local Development
- `make develop` - Build the Lambda function binary for Linux
- `make invoke` - Start local API server on port 9070 using SAM
- `make clean` - Clean SAM artifacts
- `make develop-clean` - Clean build artifacts

### Testing
- `go test ./lambda/` - Run unit tests with testcontainers
- Tests use MongoDB testcontainers for integration testing

### AWS Deployment
- `make deploy` - Deploy stack using AWS CDK
- `make destroy` - Destroy the CDK stack
- `make aws-login` - Login via AWS SSO
- `make update-creds` - Assume AdminRole for deployment

### Required Environment Setup
Create `env.json` file with:
```json
{
  "Parameters": {
    "MONGODB_PASSWORD": "<your-password>"
  }
}
```

## Architecture Overview

### Core Components
1. **Lambda Handler** (`lambda/main.go`) - Single AWS Lambda function handling:
   - API Gateway requests for subscription management
   - CloudWatch Events for scheduled appointment scanning
   - MongoDB operations for subscription storage
   - Ntfy.sh notifications when appointments are found

2. **CDK Infrastructure** (`cdk.go`) - Defines:
   - Lambda function with 1-minute CloudWatch trigger
   - Public Function URL for API access
   - IAM permissions and environment variables

3. **Frontend** (`docs/`) - Static GitHub Pages site for subscription interface

### Data Flow
- Users subscribe via web interface → Lambda stores in MongoDB
- CloudWatch triggers Lambda every minute → checks Global Entry API
- If appointments found → sends notifications via Ntfy.sh
- Auto-cleanup removes subscriptions after 30 days

### Key Data Structures
- `Subscription` - MongoDB document with location, ntfyTopic, createdAt
- `LocationTopics` - Aggregated view grouping topics by location
- `Appointment` - Global Entry API response structure

### Configuration
- AWS region: us-east-1 (hardcoded)
- MongoDB connection via MONGODB_PASSWORD env var
- Ntfy server: https://ntfy.sh (configurable via NTFY_SERVER)
- CORS enabled for https://arun0009.github.io domain

### Testing Strategy
Uses testcontainers-go with MongoDB for integration tests. Tests cover subscription management, appointment checking, and notification sending with mock HTTP servers.