# OLM Test Suites

This directory contains Chainsaw test files for validating ToolHive Operator installation via OLM (Operator Lifecycle Manager).

## Test Files

### Main Tests

- **validate-olm-success.yaml** - Validates that OLM successfully installed the ToolHive Operator
  - Verifies CatalogSource is READY
  - Verifies CRDs are installed
  - Verifies CSV is Succeeded
  - Verifies operator deployment is ready

- **mcp-reconciliation.yaml** - Tests operator functionality by reconciling an MCPServer CR
  - Deploys a test MCPServer CR
  - Verifies MCPServer status becomes ready
  - Verifies Deployment is created
  - Verifies Service is created
  - Cleans up the MCPServer CR

### Test Resources

- **test-mcp-server-cr.yaml** - MCPServer Custom Resource definition used for testing

### Assertion Files

- **assert-catalogsource-ready.yaml** - Asserts CatalogSource is in READY state
- **assert-crds-installed.yaml** - Asserts CRDs are installed
- **assert-csv-succeeded.yaml** - Asserts CSV is in Succeeded phase (used via script)
- **assert-operator-ready.yaml** - Asserts operator deployment is available
- **assert-mcpserver-ready.yaml** - Asserts MCPServer CR is in Running phase
- **assert-mcpserver-deployment.yaml** - Asserts MCPServer deployment is available
- **assert-mcpserver-service.yaml** - Asserts MCPServer service exists

## Usage

These tests are executed automatically by the GitHub Actions workflow (`.github/workflows/olm-test.yaml`).

To run manually:

```bash
export KUBECONFIG=<path-to-kubeconfig>
chainsaw test --test-dir ./test-suites --namespace toolhive-test-ns
```

## Test Structure

Tests use the Chainsaw Test CRD format (`apiVersion: chainsaw.kyverno.io/v1alpha1`) and follow declarative testing patterns:

- **apply**: Creates resources
- **assert**: Validates resource state
- **delete**: Cleans up resources
- **script**: Executes custom validation logic

## Namespace

All tests use the `toolhive-test-ns` namespace, which matches the `OPERATOR_NS` environment variable in the CI workflow.

