# Troubleshooting Guide

Common issues and solutions for both personal and multi-user modes.

## 🔍 Diagnosis Commands

### Check Lambda Function Status
```bash
# List functions
aws lambda list-functions --query 'Functions[?contains(FunctionName, `appointment`) || contains(FunctionName, `global`)]'

# Get function details
aws lambda get-function --function-name FUNCTION_NAME

# View recent logs
aws logs filter-log-events \
    --log-group-name /aws/lambda/FUNCTION_NAME \
    --start-time $(date -d '30 minutes ago' +%s)000
```

### Test Lambda Function Manually
```bash
# Trigger CloudWatch event (personal mode)
aws lambda invoke \
    --function-name PersonalAppointmentStack-personal-appointment-scanner \
    --payload '{"source":"aws.events"}' \
    response.json && cat response.json

# Test API endpoint (multi-user mode)
curl -X POST "https://YOUR_FUNCTION_URL/subscriptions" \
    -H "Content-Type: application/json" \
    -d '{"action":"subscribe","location":"5300","ntfyTopic":"test-topic"}'
```

## 🚨 Common Issues

### 1. No Notifications Received

**Symptoms:**
- Lambda runs successfully
- No notifications in Ntfy app
- CloudWatch logs show no errors

**Solutions:**

1. **Test Ntfy Topic Manually**:
```bash
curl -X POST "https://ntfy.sh" \
    -H "Content-Type: application/json" \
    -d '{
        "topic": "YOUR_TOPIC",
        "message": "Test message",
        "title": "Test"
    }'
```

2. **Check Ntfy App Subscription**:
   - Open Ntfy app
   - Verify you're subscribed to the correct topic
   - Check topic name for typos

3. **Verify Lambda Configuration**:
```bash
aws lambda get-function-configuration \
    --function-name FUNCTION_NAME \
    --query 'Environment.Variables'
```

4. **Check for Appointments**:
   - Manually visit the TTP website
   - Verify appointments are actually available
   - Scanner only sends notifications when appointments exist

### 2. Lambda Function Errors

**Symptoms:**
- Function execution fails
- CloudWatch logs show errors
- HTTP timeout errors

**Solutions:**

1. **Check Network Connectivity**:
   - TTP API might be temporarily down
   - Ntfy.sh might be unreachable
   - Lambda has automatic retry logic (3 attempts)

2. **Verify Environment Variables**:
```bash
# Personal mode required variables
PERSONAL_MODE=true
LOCATION_ID=XXXXX
NTFY_TOPIC=your-topic

# Multi-user mode required variables
MONGODB_PASSWORD=your-password
```

3. **Check Memory/Timeout Issues**:
   - Personal mode: 64MB memory, 30s timeout
   - Multi-user mode: 128MB memory, 60s timeout
   - Increase if needed via AWS Console

4. **API Rate Limiting**:
   - TTP API might be rate limiting requests
   - Lambda automatically retries with backoff
   - Consider increasing timeout if persistent

### 3. Deployment Issues

**Symptoms:**
- CDK deployment fails
- Stack creation errors
- Permission denied errors

**Solutions:**

1. **Check AWS Credentials**:
```bash
aws sts get-caller-identity
aws configure list
```

2. **Verify CDK Bootstrap**:
```bash
cdk bootstrap aws://ACCOUNT_ID/REGION
```

3. **Check IAM Permissions**:
   Required permissions:
   - `lambda:*`
   - `events:*`
   - `iam:CreateRole`
   - `iam:AttachRolePolicy`
   - `cloudformation:*`

4. **Environment Variables for Deployment**:
```bash
export AWS_ACCOUNT=your-account-id
export AWS_REGION=us-east-1
export PERSONAL_MODE=true  # for personal mode
export LOCATION_ID=5300
export NTFY_TOPIC=your-topic
```

### 4. Database Connection Issues (Multi-user Mode)

**Symptoms:**
- MongoDB connection timeouts
- Authentication errors
- Collection not found errors

**Solutions:**

1. **Check MongoDB Atlas Status**:
   - Verify cluster is running
   - Check network access whitelist
   - Verify database credentials

2. **Update Connection String**:
   - Check for special characters in password
   - URL encode password if contains special chars
   - Verify cluster hostname

3. **Check env.json File**:
```json
{
  "Parameters": {
    "MONGODB_PASSWORD": "your-actual-password"
  }
}
```

### 5. Invalid Location ID

**Symptoms:**
- API returns empty results
- No appointments found for valid locations
- HTTP 400/404 errors

**Solutions:**

1. **Verify Location ID**:
   - Use browser developer tools
   - Check Network tab when clicking locations
   - Ensure location supports your service (Global Entry/NEXUS)

2. **Common Location IDs**:
```bash
# Use location-help command
make location-help

# Or manually check these popular locations:
JFK Airport: 5300
LAX Airport: 5140
Seattle: 5440
Rainbow Bridge: 5020
```

3. **Service-Specific Locations**:
   - Some locations only offer Global Entry
   - Some locations only offer NEXUS
   - Verify location supports your selected service

### 6. Ntfy App Not Receiving Notifications

**Symptoms:**
- Manual curl test works
- Lambda sends notifications successfully
- App doesn't show notifications

**Solutions:**

1. **Check App Settings**:
   - Enable notifications in phone settings
   - Check Do Not Disturb mode
   - Verify app has notification permissions

2. **Topic Name Issues**:
   - Topic names are case-sensitive
   - No spaces or special characters allowed
   - Use only letters, numbers, hyphens, underscores

3. **Server Issues**:
   - Default: ntfy.sh
   - Try custom server if default fails
   - Check ntfy.sh status page

### 7. High AWS Costs

**Symptoms:**
- Unexpected Lambda charges
- High CloudWatch costs
- Function running too frequently

**Solutions:**

1. **Check Function Invocations**:
```bash
aws cloudwatch get-metric-statistics \
    --namespace AWS/Lambda \
    --metric-name Invocations \
    --dimensions Name=FunctionName,Value=FUNCTION_NAME \
    --start-time $(date -d '24 hours ago' --iso-8601) \
    --end-time $(date --iso-8601) \
    --period 3600 \
    --statistics Sum
```

2. **Optimize Settings**:
   - Use personal mode for single user
   - Reduce memory allocation if possible
   - Check for infinite loops in code

3. **Monitor CloudWatch Events**:
   - Verify schedule is 1 minute (not seconds)
   - Check for duplicate event rules
   - Disable function temporarily if needed

## 🔧 Advanced Debugging

### Enable Debug Logging

**Personal Mode:**
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

**Multi-user Mode:**
Update env.json:
```json
{
  "Parameters": {
    "MONGODB_PASSWORD": "your-password",
    "LOG_LEVEL": "DEBUG"
  }
}
```

### Manual API Testing

**Test TTP API:**
```bash
curl "https://ttp.cbp.dhs.gov/schedulerapi/slots?orderBy=soonest&limit=1&locationId=5300&minimum=1"
```

**Test Ntfy API:**
```bash
curl -X POST "https://ntfy.sh" \
    -H "Content-Type: application/json" \
    -d '{
        "topic": "test-topic",
        "message": "Debug test",
        "title": "Debug"
    }'
```

### Lambda Environment Inspection

**View Current Configuration:**
```bash
aws lambda get-function-configuration \
    --function-name FUNCTION_NAME \
    --query '{
        Environment: Environment.Variables,
        Runtime: Runtime,
        MemorySize: MemorySize,
        Timeout: Timeout
    }'
```

## 📞 Getting Help

1. **Check CloudWatch Logs**: Most issues show up in logs
2. **Review Environment Variables**: Ensure all required vars are set
3. **Test Components Individually**: API, Ntfy, Lambda separately
4. **Create GitHub Issue**: Include logs and configuration (remove sensitive data)

## 🔄 Recovery Procedures

### Reset Personal Mode Deployment
```bash
make destroy-personal
# Wait for completion
make deploy-personal
```

### Reset Multi-user Mode Deployment
```bash
make destroy
# Update env.json with correct values
make deploy
```

### Emergency Stop
```bash
# Disable CloudWatch rule
aws events disable-rule --name RULE_NAME

# Or delete function entirely
aws lambda delete-function --function-name FUNCTION_NAME
```