BUILD_TO_DIR := .bin
GO_LINUX := GOOS=linux GOARCH=amd64 CGO_ENABLED=0

export AWS_ACCOUNT=889453232531
export AWS_REGION=us-east-1
export JSII_SILENCE_WARNING_UNTESTED_NODE_VERSION=1

clean:
	rm -rf .aws-sam

develop-clean:
	rm -rf $(BUILD_TO_DIR)
	mkdir -p $(BUILD_TO_DIR)

develop: develop-clean
	go fmt ./...
	$(GO_LINUX) go build -o $(BUILD_TO_DIR)/bootstrap ./lambda/main.go;

invoke: develop
	sam local start-api --env-vars env.json --template globalentry.yaml --region ${AWS_REGION} --port 9070 --docker-network host --invoke-image amazon/aws-sam-cli-emulation-image-go1.x --skip-pull-image --log-file /dev/stdout

aws-login:
	aws sso login --profile ${AWS_ACCOUNT}_AdministratorAccess

#run output of this command so environment variables are set.
update-creds:	
	export $(shell printf "AWS_ACCESS_KEY_ID=%s AWS_SECRET_ACCESS_KEY=%s AWS_SESSION_TOKEN=%s" \
	$(shell aws sts assume-role \
	--profile ${AWS_ACCOUNT}_AdministratorAccess \
	--role-arn arn:aws:iam::${AWS_ACCOUNT}:role/AdminRole \
	--role-session-name AWSCLI-Session \
	--query "Credentials.[AccessKeyId,SecretAccessKey,SessionToken]" \
	--output text))

deploy:
	cdk deploy

destroy:
	cdk destroy

# Personal mode targets
deploy-personal:
	@echo "🚀 Personal Appointment Scanner Setup"
	@echo "======================================"
	@echo ""
	@echo "Select service type:"
	@echo "1) Global Entry"
	@echo "2) NEXUS"
	@read -p "Enter choice (1 or 2): " choice; \
	case $$choice in \
		1) SERVICE_TYPE="Global Entry" ;; \
		2) SERVICE_TYPE="NEXUS" ;; \
		*) echo "Invalid choice. Exiting."; exit 1 ;; \
	esac; \
	echo ""; \
	echo "📍 Find your location ID:"; \
	echo "   Option 1: Run 'make select-location' for interactive selection"; \
	echo "   Option 2: Manual lookup:"; \
	if [ "$$SERVICE_TYPE" = "Global Entry" ]; then \
		echo "     Visit: https://ttp.cbp.dhs.gov/schedulerui/schedule-interview/location?lang=en&vo=true&returnUrl=ttp-external&service=GP"; \
	else \
		echo "     Visit: https://ttp.cbp.dhs.gov/schedulerui/schedule-interview/location?lang=en&vo=true&returnUrl=ttp-external&service=NH"; \
	fi; \
	echo "     Look at browser network tab for locationId parameter"; \
	echo ""; \
	read -p "Enter your location ID (e.g., 5300): " LOCATION_ID; \
	echo ""; \
	echo "📱 Setup Ntfy notifications:"; \
	echo "   1. Install Ntfy app: https://ntfy.sh/"; \
	echo "   2. Create a unique topic name (e.g., myname-appointments-$(shell date +%s))"; \
	echo ""; \
	read -p "Enter your Ntfy topic: " NTFY_TOPIC; \
	echo ""; \
	echo "🔢 Minimum slot configuration:"; \
	echo "   Enter minimum slots to check (comma-separated)"; \
	echo "   Examples: '1' (default), '1,2', '1,2,3'"; \
	echo "   This checks for 1 OR 2 OR 3 minimum available slots"; \
	echo ""; \
	read -p "Enter minimum slots [1]: " MINIMUM_SLOTS; \
	if [ -z "$$MINIMUM_SLOTS" ]; then \
		MINIMUM_SLOTS="1"; \
	fi; \
	echo ""; \
	echo "🔧 Deploying with:"; \
	echo "   Service: $$SERVICE_TYPE"; \
	echo "   Location: $$LOCATION_ID"; \
	echo "   Topic: $$NTFY_TOPIC"; \
	echo "   Minimum Slots: $$MINIMUM_SLOTS"; \
	echo ""; \
	read -p "Proceed with deployment? (y/N): " confirm; \
	if [ "$$confirm" != "y" ] && [ "$$confirm" != "Y" ]; then \
		echo "Deployment cancelled."; exit 1; \
	fi; \
	PERSONAL_MODE=true SERVICE_TYPE="$$SERVICE_TYPE" LOCATION_ID=$$LOCATION_ID NTFY_TOPIC=$$NTFY_TOPIC MINIMUM_SLOTS=$$MINIMUM_SLOTS cdk deploy PersonalAppointmentStack

destroy-personal:
	@echo "🗑️  Destroying personal appointment scanner..."
	@read -p "Are you sure? (y/N): " confirm; \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		cdk destroy PersonalAppointmentStack; \
	else \
		echo "Destruction cancelled."; \
	fi

# Interactive location selection
select-location:
	@echo "🏢 Location Selection"
	@echo "===================="
	@echo ""
	@echo "Select service type:"
	@echo "1) Global Entry"
	@echo "2) NEXUS"
	@read -p "Enter choice (1 or 2): " choice; \
	case $$choice in \
		1) SERVICE_NAME="GlobalEntry" ;; \
		2) SERVICE_NAME="NEXUS" ;; \
		*) echo "Invalid choice. Exiting."; exit 1 ;; \
	esac; \
	echo ""; \
	echo "📡 Fetching $$SERVICE_NAME locations..."; \
	LOCATIONS=$$(curl -s "https://ttp.cbp.dhs.gov/schedulerapi/locations/?temporary=false&inviteOnly=false&operational=true&serviceName=$$SERVICE_NAME" \
		-H 'accept: application/json, text/plain, */*' \
		-H 'user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'); \
	if [ $$? -ne 0 ] || [ -z "$$LOCATIONS" ]; then \
		echo "❌ Failed to fetch locations. Please check your internet connection."; \
		echo ""; \
		echo "📍 Manual lookup instructions:"; \
		if [ "$$SERVICE_NAME" = "GlobalEntry" ]; then \
			echo "   Visit: https://ttp.cbp.dhs.gov/schedulerui/schedule-interview/location?lang=en&vo=true&returnUrl=ttp-external&service=GP"; \
		else \
			echo "   Visit: https://ttp.cbp.dhs.gov/schedulerui/schedule-interview/location?lang=en&vo=true&returnUrl=ttp-external&service=NH"; \
		fi; \
		echo "   Look at browser network tab for locationId parameter"; \
		exit 1; \
	fi; \
	echo "$$LOCATIONS" | jq -r 'to_entries | map("\(.key + 1)) \(.value.shortName) - \(.value.name) (ID: \(.value.id))") | .[]' > /tmp/locations.txt; \
	if [ $$? -ne 0 ]; then \
		echo "❌ Failed to parse locations. jq is required for this feature."; \
		echo "   Install jq: brew install jq (macOS) or apt-get install jq (Ubuntu)"; \
		exit 1; \
	fi; \
	echo ""; \
	echo "📍 Available locations:"; \
	cat /tmp/locations.txt; \
	echo ""; \
	LOCATION_COUNT=$$(cat /tmp/locations.txt | wc -l | tr -d ' '); \
	read -p "Enter location number (1-$$LOCATION_COUNT): " LOCATION_NUM; \
	if ! [[ "$$LOCATION_NUM" =~ ^[0-9]+$$ ]] || [ "$$LOCATION_NUM" -lt 1 ] || [ "$$LOCATION_NUM" -gt "$$LOCATION_COUNT" ]; then \
		echo "Invalid location number. Exiting."; exit 1; \
	fi; \
	SELECTED_LOCATION=$$(echo "$$LOCATIONS" | jq -r ".[$$((LOCATION_NUM - 1))]"); \
	LOCATION_ID=$$(echo "$$SELECTED_LOCATION" | jq -r '.id'); \
	LOCATION_NAME=$$(echo "$$SELECTED_LOCATION" | jq -r '.name'); \
	echo ""; \
	echo "✅ Selected: $$LOCATION_NAME (ID: $$LOCATION_ID)"; \
	echo ""; \
	echo "📋 Your location ID is: $$LOCATION_ID"; \
	echo "   You can use this ID in your deployment configuration."; \
	rm -f /tmp/locations.txt

# Helper target to show location lookup instructions  
location-help:
	@echo "📍 How to find your location ID:"
	@echo ""
	@echo "Option 1 - Use interactive selection:"
	@echo "   make select-location"
	@echo ""
	@echo "Option 2 - Manual lookup:"
	@echo "Global Entry locations:"
	@echo "   https://ttp.cbp.dhs.gov/schedulerui/schedule-interview/location?lang=en&vo=true&returnUrl=ttp-external&service=GP"
	@echo ""
	@echo "NEXUS locations:"
	@echo "   https://ttp.cbp.dhs.gov/schedulerui/schedule-interview/location?lang=en&vo=true&returnUrl=ttp-external&service=NH"
	@echo ""
	@echo "Instructions:"
	@echo "1. Open the URL in your browser"
	@echo "2. Open Developer Tools (F12)"
	@echo "3. Go to Network tab"
	@echo "4. Click on a location"
	@echo "5. Look for locationId parameter in the network requests"

# Show all available targets
help:
	@echo "Available targets:"
	@echo ""
	@echo "Development:"
	@echo "  develop        - Build Lambda function for local testing"
	@echo "  invoke         - Start local API server for testing"
	@echo "  clean          - Clean build artifacts"
	@echo ""
	@echo "Multi-user deployment:"
	@echo "  deploy         - Deploy multi-user stack (requires env.json)"
	@echo "  destroy        - Destroy multi-user stack"
	@echo ""
	@echo "Personal deployment:"
	@echo "  deploy-personal - Interactive personal deployment setup"
	@echo "  destroy-personal - Destroy personal stack"
	@echo "  select-location - Interactive location selection from API"
	@echo "  location-help   - Show how to find location IDs"
	@echo ""
	@echo "AWS:"
	@echo "  aws-login      - Login via AWS SSO"
	@echo "  update-creds   - Update AWS credentials"
	@echo ""
	@echo "Help:"
	@echo "  help           - Show this help message"

.PHONY: clean develop-clean develop invoke aws-login update-creds deploy destroy deploy-personal destroy-personal select-location location-help help