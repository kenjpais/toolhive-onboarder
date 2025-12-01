# ToolHive Operator OLM CI Testing (OKD Compatible)

This repository contains a GitHub Actions CI workflow for testing the ToolHive Operator installation via OLM (Operator Lifecycle Manager) on OKD-compatible environments using KIND, Helm, and Chainsaw.

## Overview

The CI workflow tests ToolHive Operator installation in an OKD-compatible environment. OKD (the community distribution of Kubernetes that powers OpenShift) includes OLM by default. This workflow:

1. Provisions a KIND cluster with OLM installed (simulating OKD environment)
2. Uses OpenShift CLI (`oc`) for OKD-compatible operations
3. Deploys the ToolHive Operator via OLM using a Helm chart
4. Validates the installation using Chainsaw declarative tests
5. Tests operator functionality by reconciling MCPServer Custom Resources

**Note:** In a real OKD cluster, OLM is pre-installed. This workflow installs OLM on KIND to simulate the OKD environment for CI testing purposes.

## Repository Structure

```
toolhive-operator-test/
├── .github/
│   └── workflows/
│       └── olm-test.yaml          # Main CI workflow
├── test-suites/                    # Chainsaw test files
│   ├── validate-olm-success.yaml  # OLM installation validation
│   ├── mcp-reconciliation.yaml    # Operator functionality tests
│   └── assert-*.yaml              # Assertion files
├── toolhive-olm-chart/            # Helm chart for OLM deployment
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
│       ├── catalogsource.yaml
│       ├── operatorgroup.yaml
│       ├── subscription.yaml
│       └── namespace.yaml
└── README.md                       # This file
```

## CI Workflow

### Workflow File

The main workflow is located at `.github/workflows/olm-test.yaml`.

### Triggers

The workflow runs on:
- Push to `main` or `master` branches
- Pull requests to `main` or `master` branches
- Manual dispatch (with optional catalog image input)

### Workflow Steps

1. **Environment Setup**
   - Checkout code
   - Install Go, Helm, Chainsaw, kubectl, and OpenShift CLI (oc) for OKD compatibility

2. **Cluster Provisioning**
   - Install OpenShift CLI (`oc`) for OKD compatibility
   - Create KIND cluster
   - Install OLM components (simulating OKD where OLM is pre-installed)
   - Wait for OLM to be ready

3. **Catalog Preparation**
   - Use pre-built catalog image from registry
   - Default: `quay.io/kpais/toolhive-test-catalog:latest`

4. **OLM Deployment**
   - Render Helm chart with catalog image
   - Apply OLM resources (CatalogSource, OperatorGroup, Subscription)
   - Wait for operator installation

5. **Testing**
   - Run Chainsaw tests to validate OLM installation
   - Test MCPServer CR reconciliation

6. **Cleanup**
   - Remove OLM resources
   - Delete KIND cluster

### Environment Variables

- `OPERATOR_NS`: `toolhive-test-ns` (namespace for operator)
- `CATALOG_IMAGE`: Catalog index image (default: `quay.io/kpais/toolhive-test-catalog:latest`)
- `TEST_TIMEOUT`: `10m` (timeout for waiting operations)
- `CLUSTER_NAME`: `toolhive-olm-test` (KIND cluster name)

## Test Suites

The `test-suites/` directory contains Chainsaw declarative tests:

### Main Tests

- **validate-olm-success.yaml**: Validates OLM successfully installed the operator
  - Verifies CatalogSource is READY
  - Verifies CRDs are installed
  - Verifies CSV is Succeeded
  - Verifies operator deployment is ready

- **mcp-reconciliation.yaml**: Tests operator functionality
  - Deploys a test MCPServer CR
  - Verifies MCPServer reconciliation
  - Verifies Deployment and Service creation
  - Cleans up test resources

### Assertion Files

- `assert-catalogsource-ready.yaml` - CatalogSource status
- `assert-crds-installed.yaml` - CRD installation
- `assert-csv-succeeded.yaml` - CSV phase
- `assert-operator-ready.yaml` - Operator deployment
- `assert-mcpserver-ready.yaml` - MCPServer status
- `assert-mcpserver-deployment.yaml` - MCPServer deployment
- `assert-mcpserver-service.yaml` - MCPServer service

## Helm Chart

The `toolhive-olm-chart/` directory contains a Helm chart for deploying OLM resources:

- **CatalogSource**: Registers the operator catalog
- **OperatorGroup**: Defines operator scope
- **Subscription**: Subscribes to the operator
- **Namespace**: Creates the target namespace

### Chart Values

Key values can be overridden:
- `catalogSource.image`: Catalog index image
- `namespace.name`: Target namespace
- `operatorGroup.targetNamespaces`: Namespaces for operator
- `subscription.channel`: Operator channel (default: `stable`)

## Running Locally

To run the tests locally (requires KIND, kubectl, Helm, and Chainsaw):

```bash
# Create KIND cluster
kind create cluster --name toolhive-olm-test

# Install OLM
kubectl apply -f https://github.com/operator-framework/operator-lifecycle-manager/releases/download/v0.28.0/crds.yaml
kubectl apply -f https://github.com/operator-framework/operator-lifecycle-manager/releases/download/v0.28.0/olm.yaml

# Create openshift-marketplace namespace
kubectl create namespace openshift-marketplace

# Render and apply Helm chart
helm template toolhive-olm ./toolhive-olm-chart \
  --set catalogSource.image=quay.io/kpais/toolhive-test-catalog:latest \
  --set namespace.name=toolhive-test-ns \
  --set operatorGroup.targetNamespaces[0]=toolhive-test-ns \
  | kubectl apply -f -

# Wait for operator installation
kubectl wait --for=jsonpath='{.status.connectionState.lastObservedState}'=READY \
  catalogsource/toolhive-test-catalog -n openshift-marketplace --timeout=10m

# Run Chainsaw tests
export KUBECONFIG=$(kind get kubeconfig --name toolhive-olm-test)
chainsaw test --test-dir ./test-suites --namespace toolhive-test-ns

# Cleanup
kind delete cluster --name toolhive-olm-test
```

## Customization

### Using a Different Catalog Image

You can specify a different catalog image when manually triggering the workflow:

1. Go to Actions → OLM Test → Run workflow
2. Enter your catalog image in the input field
3. Click "Run workflow"

Or modify the `CATALOG_IMAGE` environment variable in the workflow file.

### Adding More Tests

Add new Chainsaw test files to the `test-suites/` directory. Follow the existing patterns:
- Use `apiVersion: chainsaw.kyverno.io/v1alpha1`
- Define appropriate timeouts
- Use `assert` blocks for validation
- Use `apply`/`delete` blocks for resource management

## Troubleshooting

### Workflow Failures

If the workflow fails, check:

1. **CatalogSource not READY**
   - Verify the catalog image is accessible
   - Check catalog pod logs in `openshift-marketplace` namespace

2. **CSV not Succeeded**
   - Check CSV conditions and events
   - Verify operator image is accessible
   - Check operator deployment status

3. **Chainsaw tests failing**
   - Review test output for specific assertion failures
   - Check operator logs for reconciliation errors
   - Verify MCPServer CR status

### Diagnostic Information

The workflow includes diagnostic collection on failure:
- Cluster state
- OLM resource status
- Operator logs
- Recent events

## Validation

Before pushing to GitHub, run the validation script:

```bash
./validate.sh
```

This will check:
- Required files exist
- No emojis in workflow/test files
- YAML syntax is valid
- Helm chart passes lint
- No obvious secrets
- Namespace consistency

## Testing

See [TESTING.md](TESTING.md) for detailed instructions on:
- Local testing with KIND
- GitHub Actions testing
- Troubleshooting common issues
- Validation checklist

## OKD Compatibility

This workflow is designed to test ToolHive Operator compatibility with [OKD](https://github.com/okd-project/okd) (the community distribution of Kubernetes that powers OpenShift). 

### OKD Features Tested

- **OLM Integration**: OKD includes OLM by default (simulated in CI by installing OLM on KIND)
- **OpenShift CLI**: Uses `oc` command for OKD-compatible operations
- **openshift-marketplace**: Uses OKD's standard namespace for CatalogSources
- **Operator Lifecycle**: Tests operator installation and management via OLM

### CI Environment Note

**Important:** This CI workflow uses KIND (Kubernetes in Docker) with OLM installed to simulate an OKD environment. KIND does not support full OKD distribution directly. 

- **What we test**: OKD-compatible operator installation via OLM using OpenShift CLI (`oc`)
- **What's simulated**: OLM installation (in real OKD, OLM is pre-installed)
- **For full OKD testing**: A cloud-based OKD cluster would be required (e.g., AWS, GCP, Azure)

In a production OKD environment, OLM is pre-installed and operators are managed through the OperatorHub. This workflow validates that the operator works correctly with OLM, which is the core component for operator management in OKD.

## Related Resources

- [OKD Project](https://github.com/okd-project/okd) - Community distribution of Kubernetes
- [ToolHive Operator](https://github.com/stacklok/toolhive)
- [OLM Documentation](https://olm.operatorframework.io/)
- [Chainsaw Testing](https://kyverno.github.io/chainsaw/)
- [KIND Documentation](https://kind.sigs.k8s.io/)

## License

This repository is part of the ToolHive project. See the ToolHive repository for license information.
