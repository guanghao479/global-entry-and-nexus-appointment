package main

import (
	"encoding/json"
	"io"
	"os"

	awscdk "github.com/aws/aws-cdk-go/awscdk/v2"
	"github.com/aws/aws-cdk-go/awscdk/v2/awsevents"
	"github.com/aws/aws-cdk-go/awscdk/v2/awseventstargets"
	"github.com/aws/aws-cdk-go/awscdk/v2/awsiam"
	"github.com/aws/aws-cdk-go/awscdk/v2/awslambda"
	constructs "github.com/aws/constructs-go/constructs/v10"
	jsii "github.com/aws/jsii-runtime-go"
)

const (
	// Multi-user mode constants
	StackName    = "GlobalEntryStack"
	FunctionName = "globalentry"
	MemorySize   = 128
	MaxDuration  = 60

	// Personal mode constants
	PersonalStackName    = "PersonalAppointmentStack"
	PersonalFunctionName = "personal-appointment-scanner"
	PersonalMemorySize   = 64 // Reduced memory for personal mode
	PersonalMaxDuration  = 30 // Reduced timeout for personal mode

	// Shared constants
	CodePath     = ".bin/"
	Handler      = "main.Handler"
	ScheduleRate = 1
	EnvFilePath  = "env.json"
)

type LambdaCdkStackProps struct {
	awscdk.StackProps
}

type Environment struct {
	Parameters map[string]*string `json:"Parameters"`
	AWS        map[string]*string `json:'"AWS"`
}

func LoadEnvironmentVariables(filePath string) (map[string]*string, error) {
	file, err := os.Open(filePath)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	data, err := io.ReadAll(file)
	if err != nil {
		return nil, err
	}

	var env Environment

	err = json.Unmarshal(data, &env)
	if err != nil {
		return nil, err
	}

	return env.Parameters, nil
}

// Personal mode deployment configuration
type PersonalConfig struct {
	ServiceType string
	LocationID  string
	NtfyTopic   string
	NtfyServer  string
}

// NewPersonalLambdaStack creates a personal mode stack
func NewPersonalLambdaStack(scope constructs.Construct, id string, config PersonalConfig, props *LambdaCdkStackProps) awscdk.Stack {
	stack := awscdk.NewStack(scope, &id, &props.StackProps)

	// Personal mode environment variables
	envVars := map[string]*string{
		"PERSONAL_MODE": jsii.String("true"),
		"SERVICE_TYPE":  jsii.String(config.ServiceType),
		"LOCATION_ID":   jsii.String(config.LocationID),
		"NTFY_TOPIC":    jsii.String(config.NtfyTopic),
	}

	if config.NtfyServer != "" {
		envVars["NTFY_SERVER"] = jsii.String(config.NtfyServer)
	}

	// Define Lambda function for personal mode (optimized settings)
	personalFn := awslambda.NewFunction(stack, jsii.String(PersonalFunctionName), &awslambda.FunctionProps{
		FunctionName: jsii.String(*stack.StackName() + "-" + PersonalFunctionName),
		Runtime:      awslambda.Runtime_PROVIDED_AL2023(),
		MemorySize:   jsii.Number(PersonalMemorySize),                           // Reduced memory
		Timeout:      awscdk.Duration_Seconds(jsii.Number(PersonalMaxDuration)), // Reduced timeout
		Code:         awslambda.AssetCode_FromAsset(jsii.String(CodePath), nil),
		Handler:      jsii.String(Handler),
		Environment:  &envVars,
		// No Function URL - personal mode doesn't need public access
	})

	// Define CloudWatch event rule (1-minute schedule same as multi-user)
	rule := awsevents.NewRule(stack, jsii.String("PersonalScheduledRule"), &awsevents.RuleProps{
		Schedule: awsevents.Schedule_Rate(awscdk.Duration_Minutes(jsii.Number(ScheduleRate))),
	})

	// Add permission for the event rule to invoke the Lambda function
	personalFn.AddPermission(jsii.String("AllowEventRule"),
		&awslambda.Permission{
			Action:    jsii.String("lambda:InvokeFunction"),
			Principal: awsiam.NewServicePrincipal(jsii.String("events.amazonaws.com"), &awsiam.ServicePrincipalOpts{}),
			SourceArn: rule.RuleArn(),
		},
	)

	// Add Lambda function as a target for the rule
	rule.AddTarget(awseventstargets.NewLambdaFunction(personalFn, &awseventstargets.LambdaFunctionProps{}))

	// Output the function name for reference
	awscdk.NewCfnOutput(stack, jsii.String("PersonalFunctionName"), &awscdk.CfnOutputProps{
		Value: personalFn.FunctionName(),
	})

	return stack
}

// NewLambdaCdkStack creates a multi-user mode stack (original functionality)
func NewLambdaCdkStack(scope constructs.Construct, id string, props *LambdaCdkStackProps) awscdk.Stack {
	stack := awscdk.NewStack(scope, &id, &props.StackProps)

	// Load environment variables from JSON file for multi-user mode
	envVars, err := LoadEnvironmentVariables(EnvFilePath)
	if err != nil {
		panic(err)
	}

	// Define Lambda function
	globalEntryFn := awslambda.NewFunction(stack, jsii.String(FunctionName), &awslambda.FunctionProps{
		FunctionName: jsii.String(*stack.StackName() + "-" + FunctionName),
		Runtime:      awslambda.Runtime_PROVIDED_AL2023(),
		MemorySize:   jsii.Number(MemorySize),
		Timeout:      awscdk.Duration_Seconds(jsii.Number(MaxDuration)),
		Code:         awslambda.AssetCode_FromAsset(jsii.String(CodePath), nil),
		Handler:      jsii.String(Handler),
		Environment:  &envVars,
	})

	// Define CloudWatch event rule
	rule := awsevents.NewRule(stack, jsii.String("GlobalEntryScheduledRule"), &awsevents.RuleProps{
		Schedule: awsevents.Schedule_Rate(awscdk.Duration_Minutes(jsii.Number(ScheduleRate))),
	})

	// Get the ARN of the CloudWatch Events rule
	ruleArn := rule.RuleArn()

	// Add permission for the event rule to invoke the Lambda function
	globalEntryFn.AddPermission(jsii.String("AllowEventRule"),
		&awslambda.Permission{
			Action:    jsii.String("lambda:InvokeFunction"),
			Principal: awsiam.NewServicePrincipal(jsii.String("events.amazonaws.com"), &awsiam.ServicePrincipalOpts{}),
			SourceArn: ruleArn,
		},
	)

	// Add Lambda function as a target for the rule
	rule.AddTarget(awseventstargets.NewLambdaFunction(globalEntryFn, &awseventstargets.LambdaFunctionProps{}))

	// Add a public Lambda Function URL
	functionUrl := globalEntryFn.AddFunctionUrl(&awslambda.FunctionUrlOptions{
		AuthType: awslambda.FunctionUrlAuthType_NONE,
	})

	// Output the public function URL
	awscdk.NewCfnOutput(stack, jsii.String("LambdaFunctionURL"), &awscdk.CfnOutputProps{
		Value: functionUrl.Url(),
	})

	return stack
}

func main() {
	app := awscdk.NewApp(nil)

	// Check if we're deploying in personal mode
	if os.Getenv("PERSONAL_MODE") == "true" {
		// Personal mode deployment
		config := PersonalConfig{
			ServiceType: os.Getenv("SERVICE_TYPE"),
			LocationID:  os.Getenv("LOCATION_ID"),
			NtfyTopic:   os.Getenv("NTFY_TOPIC"),
			NtfyServer:  os.Getenv("NTFY_SERVER"),
		}

		if config.ServiceType == "" {
			config.ServiceType = "Global Entry" // Default
		}

		NewPersonalLambdaStack(app, PersonalStackName, config, &LambdaCdkStackProps{
			awscdk.StackProps{
				Env: &awscdk.Environment{
					Account: jsii.String(os.Getenv("AWS_ACCOUNT")),
					Region:  jsii.String(os.Getenv("AWS_REGION")),
				},
			},
		})
	} else {
		// Multi-user mode deployment (original)
		NewLambdaCdkStack(app, StackName, &LambdaCdkStackProps{
			awscdk.StackProps{
				Env: &awscdk.Environment{
					Account: jsii.String(os.Getenv("AWS_ACCOUNT")),
					Region:  jsii.String(os.Getenv("AWS_REGION")),
				},
			},
		})
	}

	app.Synth(nil)
}
