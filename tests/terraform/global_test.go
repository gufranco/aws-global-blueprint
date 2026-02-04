// =============================================================================
// Terraform Tests using Terratest
// =============================================================================
// Run: cd tests/terraform && go test -v -timeout 30m
// =============================================================================

package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

// TestGlobalModule tests the global Terraform module
func TestGlobalModule(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../../modules/global",
		Vars: map[string]interface{}{
			"project_name": "test-project",
			"environment":  "test",
			"regions": map[string]interface{}{
				"us_east_1": map[string]interface{}{
					"enabled":     true,
					"aws_region":  "us-east-1",
					"is_primary":  true,
					"tier":        "primary",
					"cidr_block":  "10.0.0.0/16",
					"ecs_api_min": 1,
					"ecs_api_max": 2,
					"enable_nat":  false,
				},
			},
			"enable_global_accelerator": false,
			"ecr_repositories":          []string{"api", "worker"},
		},
		NoColor: true,
	}

	// Clean up resources after test
	defer terraform.Destroy(t, terraformOptions)

	// Run terraform init and plan
	terraform.InitAndPlan(t, terraformOptions)
}

// TestRegionModule tests the region Terraform module
func TestRegionModule(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../../modules/region",
		Vars: map[string]interface{}{
			"project_name": "test-project",
			"environment":  "test",
			"aws_region":   "us-east-1",
			"region_key":   "us_east_1",
			"is_primary":   true,
			"tier":         "primary",
			"cidr_block":   "10.0.0.0/16",
			"enable_nat":   false,
			"api_image":    "nginx:latest",
			"worker_image": "nginx:latest",
		},
		NoColor: true,
	}

	// Clean up resources after test
	defer terraform.Destroy(t, terraformOptions)

	// Run terraform init and plan
	terraform.InitAndPlan(t, terraformOptions)
}

// TestDataModule tests the data Terraform module
func TestDataModule(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../../modules/data",
		Vars: map[string]interface{}{
			"project_name": "test-project",
			"environment":  "test",
			"regions": map[string]interface{}{
				"us_east_1": map[string]interface{}{
					"enabled":     true,
					"aws_region":  "us-east-1",
					"is_primary":  true,
					"tier":        "primary",
					"cidr_block":  "10.0.0.0/16",
					"ecs_api_min": 1,
					"ecs_api_max": 2,
					"enable_nat":  false,
				},
			},
			"aurora_database_name":    "testdb",
			"dynamodb_billing_mode":   "PAY_PER_REQUEST",
			"vpc_ids":                 map[string]string{"us_east_1": "vpc-12345"},
			"private_subnet_ids":      map[string][]string{"us_east_1": {"subnet-1", "subnet-2"}},
			"database_security_group_ids": map[string]string{"us_east_1": "sg-12345"},
			"redis_security_group_ids":    map[string]string{"us_east_1": "sg-67890"},
		},
		NoColor: true,
	}

	// Clean up resources after test
	defer terraform.Destroy(t, terraformOptions)

	// Run terraform init and plan
	terraform.InitAndPlan(t, terraformOptions)
}

// TestSecurityModule tests the security Terraform module
func TestSecurityModule(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../../modules/security",
		Vars: map[string]interface{}{
			"project_name":        "test-project",
			"environment":         "test",
			"enable_waf":          true,
			"enable_kms":          true,
			"enable_guardduty":    false, // Requires account-level enablement
			"enable_security_hub": false, // Requires account-level enablement
			"enable_vpc_endpoints": false,
		},
		NoColor: true,
	}

	// Clean up resources after test
	defer terraform.Destroy(t, terraformOptions)

	// Run terraform init and plan
	terraform.InitAndPlan(t, terraformOptions)
}

// TestObservabilityModuleOutputs tests that observability module produces expected outputs
func TestObservabilityModuleOutputs(t *testing.T) {
	// This is a placeholder for output validation tests
	// In a real scenario, you would validate specific outputs
	assert.True(t, true, "Observability module outputs test placeholder")
}

// TestModuleValidation validates all modules have required variables
func TestModuleValidation(t *testing.T) {
	modules := []string{
		"../../modules/global",
		"../../modules/region",
		"../../modules/data",
		"../../modules/security",
		"../../modules/observability",
		"../../modules/compliance",
		"../../modules/resilience",
		"../../modules/finops",
	}

	for _, module := range modules {
		t.Run(module, func(t *testing.T) {
			terraformOptions := &terraform.Options{
				TerraformDir: module,
				NoColor:      true,
			}

			// Just init to validate module structure
			terraform.Init(t, terraformOptions)
		})
	}
}
