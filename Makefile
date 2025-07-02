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
	if [ "$$SERVICE_TYPE" = "Global Entry" ]; then \
		echo "   Visit: https://ttp.cbp.dhs.gov/schedulerui/schedule-interview/location?lang=en&vo=true&returnUrl=ttp-external&service=GP"; \
	else \
		echo "   Visit: https://ttp.cbp.dhs.gov/schedulerui/schedule-interview/location?lang=en&vo=true&returnUrl=ttp-external&service=NH"; \
	fi; \
	echo "   Look at browser network tab for locationId parameter"; \
	echo ""; \
	read -p "Enter your location ID (e.g., 5300): " LOCATION_ID; \
	echo ""; \
	echo "📱 Setup Ntfy notifications:"; \
	echo "   1. Install Ntfy app: https://ntfy.sh/"; \
	echo "   2. Create a unique topic name (e.g., myname-appointments-$(shell date +%s))"; \
	echo ""; \
	read -p "Enter your Ntfy topic: " NTFY_TOPIC; \
	echo ""; \
	echo "🔧 Deploying with:"; \
	echo "   Service: $$SERVICE_TYPE"; \
	echo "   Location: $$LOCATION_ID"; \
	echo "   Topic: $$NTFY_TOPIC"; \
	echo ""; \
	read -p "Proceed with deployment? (y/N): " confirm; \
	if [ "$$confirm" != "y" ] && [ "$$confirm" != "Y" ]; then \
		echo "Deployment cancelled."; exit 1; \
	fi; \
	PERSONAL_MODE=true SERVICE_TYPE="$$SERVICE_TYPE" LOCATION_ID=$$LOCATION_ID NTFY_TOPIC=$$NTFY_TOPIC cdk deploy PersonalAppointmentStack

destroy-personal:
	@echo "🗑️  Destroying personal appointment scanner..."
	@read -p "Are you sure? (y/N): " confirm; \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		cdk destroy PersonalAppointmentStack; \
	else \
		echo "Destruction cancelled."; \
	fi

# Helper target to show location lookup instructions  
location-help:
	@echo "📍 How to find your location ID:"
	@echo ""
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
	@echo "  location-help   - Show how to find location IDs"
	@echo ""
	@echo "AWS:"
	@echo "  aws-login      - Login via AWS SSO"
	@echo "  update-creds   - Update AWS credentials"
	@echo ""
	@echo "Help:"
	@echo "  help           - Show this help message"

.PHONY: clean develop-clean develop invoke aws-login update-creds deploy destroy deploy-personal destroy-personal location-help help