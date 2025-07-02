# Personal Appointment Scanner Setup Guide

This guide helps you deploy your own personal appointment scanner for Global Entry or NEXUS programs.

## 🚀 Quick Start

The personal mode is designed for individual use with minimal AWS costs and simplified setup.

### Prerequisites

1. [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) installed and configured
2. [AWS CDK](https://docs.aws.amazon.com/cdk/latest/guide/work-with-cdk-typescript.html) installed: `npm install -g aws-cdk`
3. [Docker](https://www.docker.com/get-started/) for building the Lambda function
4. AWS account with appropriate permissions

### One-Command Deployment

```bash
make deploy-personal
```

This interactive command will guide you through:
1. **Service Selection**: Choose Global Entry or NEXUS
2. **Location ID**: Find and enter your preferred enrollment center
3. **Notification Setup**: Configure your Ntfy topic for alerts

## 📋 Step-by-Step Setup

### 1. Set AWS Credentials

```bash
export AWS_ACCESS_KEY_ID=YOUR_ACCESS_KEY
export AWS_SECRET_ACCESS_KEY=YOUR_SECRET_KEY
export AWS_REGION=us-east-1
export AWS_ACCOUNT=YOUR_ACCOUNT_ID
```

### 2. Find Your Location ID

#### For Global Entry:
1. Visit: https://ttp.cbp.dhs.gov/schedulerui/schedule-interview/location?lang=en&vo=true&returnUrl=ttp-external&service=GP
2. Open Developer Tools (F12) → Network tab
3. Click on your preferred enrollment center
4. Look for `locationId` parameter in network requests
5. Note down the numeric ID (e.g., `5300`)

#### For NEXUS:
1. Visit: https://ttp.cbp.dhs.gov/schedulerui/schedule-interview/location?lang=en&vo=true&returnUrl=ttp-external&service=NH
2. Follow same steps as Global Entry

**Quick Reference for Common Locations:**
```
JFK Airport (Terminal 4): 5300
LAX Airport: 5140
Seattle Enrollment Center: 5440
Rainbow Bridge: 5020
Peace Bridge: 5000
```

### 3. Setup Notifications

1. **Install Ntfy App**:
   - iOS: https://apps.apple.com/app/ntfy/id1625396347
   - Android: https://play.google.com/store/apps/details?id=io.heckel.ntfy

2. **Create Unique Topic**:
   - Use format: `yourname-appointments-YYYYMMDD`
   - Example: `john-appointments-20250102`
   - Must be unique and contain no spaces

### 4. Deploy

Run the interactive deployment:

```bash
make deploy-personal
```

Example session:
```
🚀 Personal Appointment Scanner Setup
======================================

Select service type:
1) Global Entry
2) NEXUS
Enter choice (1 or 2): 1

📍 Find your location ID:
   Visit: https://ttp.cbp.dhs.gov/schedulerui/schedule-interview/location?lang=en&vo=true&returnUrl=ttp-external&service=GP
   Look at browser network tab for locationId parameter

Enter your location ID (e.g., 5300): 5300

📱 Setup Ntfy notifications:
   1. Install Ntfy app: https://ntfy.sh/
   2. Create a unique topic name (e.g., myname-appointments-1672704123)

Enter your Ntfy topic: john-appointments-20250102

🔧 Deploying with:
   Service: Global Entry
   Location: 5300
   Topic: john-appointments-20250102

Proceed with deployment? (y/N): y
```

## 💰 Cost Optimization

Personal mode is optimized for minimal AWS costs:

- **Lambda Memory**: 64 MB (vs 128 MB multi-user)
- **Lambda Timeout**: 30 seconds (vs 60 seconds multi-user)
- **No Database**: Uses environment variables instead of MongoDB
- **No Public URL**: No Function URL endpoint
- **Single Location**: Only monitors your chosen location

**Estimated Monthly Cost**: < $1 USD

## 🔧 Configuration

### Environment Variables (automatically set during deployment):

```bash
PERSONAL_MODE=true
SERVICE_TYPE=Global Entry    # or "NEXUS"
LOCATION_ID=5300            # Your location ID
NTFY_TOPIC=your-topic       # Your notification topic
NTFY_SERVER=https://ntfy.sh # Optional: custom ntfy server
```

### Schedule

- Checks appointments every **1 minute** (same as multi-user mode)
- No automatic subscription expiration (runs indefinitely)
- Sends notifications only when appointments are available

## 🛠️ Management Commands

### Check Status
```bash
# View CloudWatch logs
aws logs describe-log-groups --log-group-name-prefix /aws/lambda/PersonalAppointmentStack

# View function details
aws lambda get-function --function-name PersonalAppointmentStack-personal-appointment-scanner
```

### Update Configuration
```bash
# Update location or service type
aws lambda update-function-configuration \
    --function-name PersonalAppointmentStack-personal-appointment-scanner \
    --environment Variables='{
        "PERSONAL_MODE":"true",
        "SERVICE_TYPE":"NEXUS",
        "LOCATION_ID":"5020",
        "NTFY_TOPIC":"your-topic"
    }'
```

### Destroy Stack
```bash
make destroy-personal
```

## 📱 Testing Notifications

### Test Your Ntfy Setup
```bash
# Send test notification
curl -X POST "https://ntfy.sh" \
    -H "Content-Type: application/json" \
    -d '{
        "topic": "your-topic-name",
        "message": "Test notification from appointment scanner",
        "title": "Test Alert"
    }'
```

### Monitor Lambda Execution
```bash
# View recent logs
aws logs filter-log-events \
    --log-group-name /aws/lambda/PersonalAppointmentStack-personal-appointment-scanner \
    --start-time $(date -d '1 hour ago' +%s)000
```

## 🐛 Troubleshooting

### Common Issues

**1. "Location ID not found"**
- Double-check the location ID in browser network tab
- Ensure the location offers your selected service (Global Entry/NEXUS)

**2. "No notifications received"**
- Test ntfy topic with manual curl command above
- Check Lambda CloudWatch logs for errors
- Verify Ntfy app is subscribed to correct topic

**3. "Deployment failed"**
- Ensure AWS credentials are set correctly
- Check AWS account permissions for Lambda and CloudWatch
- Verify region is set to us-east-1

**4. "Function timeout errors"**
- Check internet connectivity from Lambda
- API might be slow - this is normal, Lambda will retry

### Debug Mode

Enable verbose logging:
```bash
aws lambda update-function-configuration \
    --function-name PersonalAppointmentStack-personal-appointment-scanner \
    --environment Variables='{
        "PERSONAL_MODE":"true",
        "SERVICE_TYPE":"Global Entry",
        "LOCATION_ID":"5300",
        "NTFY_TOPIC":"your-topic",
        "LOG_LEVEL":"DEBUG"
    }'
```

## 🔄 Switching Between Services

To switch from Global Entry to NEXUS (or vice versa):

1. Find the new location ID for your desired service
2. Update the Lambda configuration:
```bash
aws lambda update-function-configuration \
    --function-name PersonalAppointmentStack-personal-appointment-scanner \
    --environment Variables='{
        "PERSONAL_MODE":"true",
        "SERVICE_TYPE":"NEXUS",
        "LOCATION_ID":"NEW_LOCATION_ID",
        "NTFY_TOPIC":"your-topic"
    }'
```

Or redeploy with new settings:
```bash
make destroy-personal
make deploy-personal
```

## 📚 Next Steps

- Subscribe to your Ntfy topic in the mobile app
- Test the setup by manually triggering the Lambda function
- Monitor CloudWatch logs to ensure everything works correctly
- Consider setting up CloudWatch alarms for function failures

For advanced configuration or troubleshooting, see the main [README.md](../README.md) or [TROUBLESHOOTING.md](./TROUBLESHOOTING.md).