# Testing the OLM CI Workflow (OKD Compatible)

This document describes how to test the ToolHive Operator OLM CI workflow both locally and in GitHub Actions. The workflow is designed for OKD (the community distribution of Kubernetes) compatibility.

## Prerequisites

### For Local Testing

- [KIND](https://kind.sigs.k8s.io/) v0.29.0 or later
- [OpenShift CLI (oc)](https://docs.okd.io/latest/cli_reference/openshift_cli/getting-started-cli.html) - For OKD compatibility (includes kubectl)
- [Helm](https://helm.sh/) v3.0+
- [Chainsaw](https://kyverno.github.io/chainsaw/) v0.2.12+
- [Go](https://go.dev/) 1.22+ (for Chainsaw installation if needed)

**Note:** For a true OKD experience, consider using [CodeReady Containers (CRC)](https://developers.redhat.com/products/codeready-containers/overview) which provides a local OKD cluster with OLM pre-installed.

### For GitHub Actions

The workflow automatically installs all dependencies, so no prerequisites are needed.

## Local Testing

### Step 1: Create KIND Cluster

```bash
kind create cluster --name toolhive-olm-test --config - <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
EOF
```

### Step 2: Install OLM

```bash
# Install OLM CRDs
oc apply -f https://github.com/operator-framework/operator-lifecycle-manager/releases/download/v0.28.0/crds.yaml

# Install OLM
oc apply -f https://github.com/operator-framework/operator-lifecycle-manager/releases/download/v0.28.0/olm.yaml

# Wait for OLM to be ready
oc wait --for=condition=available --timeout=5m deployment/olm-operator -n olm
oc wait --for=condition=available --timeout=5m deployment/catalog-operator -n olm
oc wait --for=condition=available --timeout=5m deployment/packageserver -n olm

# Create openshift-marketplace namespace
oc create namespace openshift-marketplace
```

### Step 3: Deploy OLM Resources

```bash
# Set environment variables
export OPERATOR_NS=toolhive-test-ns
export CATALOG_IMAGE=quay.io/kpais/toolhive-test-catalog:latest

# Render and apply Helm chart
mkdir -p temp-manifests
helm template toolhive-olm ./toolhive-olm-chart \
  --set catalogSource.image=${CATALOG_IMAGE} \
  --set namespace.name=${OPERATOR_NS} \
  --set operatorGroup.targetNamespaces[0]=${OPERATOR_NS} \
  --set subscription.channel=stable \
  --set subscription.source=toolhive-test-catalog \
  --set subscription.sourceNamespace=openshift-marketplace \
  > temp-manifests/olm-resources.yaml

oc apply -f temp-manifests/olm-resources.yaml
```

### Step 4: Wait for Operator Installation

```bash
# Wait for CatalogSource to be READY
oc wait --for=jsonpath='{.status.connectionState.lastObservedState}'=READY \
  catalogsource/toolhive-test-catalog -n openshift-marketplace \
  --timeout=10m

# Wait for InstallPlan to complete
timeout 300 bash -c 'until oc get installplan -n ${OPERATOR_NS} -l "operators.coreos.com/toolhive-operator.${OPERATOR_NS}" 2>/dev/null | grep -q Complete; do sleep 5; done'

# Wait for CSV to be Succeeded
oc wait --for=jsonpath='{.status.phase}'=Succeeded \
  csv -n ${OPERATOR_NS} \
  -l "operators.coreos.com/toolhive-operator.${OPERATOR_NS}" \
  --timeout=10m

# Wait for operator deployment
oc wait --for=condition=available \
  deployment/toolhive-operator -n ${OPERATOR_NS} \
  --timeout=10m
```

### Step 5: Run Chainsaw Tests

```bash
# Set KUBECONFIG
export KUBECONFIG=$(kind get kubeconfig --name toolhive-olm-test)

# Run tests
chainsaw test --test-dir ./test-suites --namespace ${OPERATOR_NS}
```

### Step 6: Cleanup

```bash
# Delete OLM resources
oc delete subscription toolhive-operator -n ${OPERATOR_NS} --ignore-not-found=true
oc delete operatorgroup toolhive-operator-group -n ${OPERATOR_NS} --ignore-not-found=true
oc delete catalogsource toolhive-test-catalog -n openshift-marketplace --ignore-not-found=true
oc delete namespace ${OPERATOR_NS} --ignore-not-found=true

# Delete KIND cluster
kind delete cluster --name toolhive-olm-test
```

## GitHub Actions Testing

### Manual Workflow Dispatch

1. Go to the repository on GitHub
2. Navigate to **Actions** tab
3. Select **OLM Test** workflow
4. Click **Run workflow**
5. Optionally specify a different catalog image
6. Click **Run workflow** button

### Trigger via Push

The workflow automatically runs on:
- Push to `main` or `master` branches
- Pull requests to `main` or `master` branches

### Monitoring Workflow Execution

1. Go to **Actions** tab in GitHub
2. Click on the workflow run
3. Click on the **olm-test** job to see detailed logs
4. Each step shows its output and any errors

## Troubleshooting

### CatalogSource Not Becoming READY

**Symptoms:**
- CatalogSource status shows `CONNECTION_FAILED` or stays in `CONNECTING`

**Solutions:**
1. Check catalog pod logs:
   ```bash
   oc logs -n openshift-marketplace -l olm.catalogSource=toolhive-test-catalog
   ```
2. Verify catalog image is accessible:
   ```bash
   docker pull quay.io/kpais/toolhive-test-catalog:latest
   ```
3. For KIND, ensure image is loaded:
   ```bash
   kind load docker-image quay.io/kpais/toolhive-test-catalog:latest --name toolhive-olm-test
   ```

### CSV Not Reaching Succeeded Phase

**Symptoms:**
- CSV stays in `Installing` or `Failed` phase

**Solutions:**
1. Check CSV conditions:
   ```bash
   oc describe csv -n ${OPERATOR_NS} -l "operators.coreos.com/toolhive-operator.${OPERATOR_NS}"
   ```
2. Check operator deployment:
   ```bash
   oc get deployment toolhive-operator -n ${OPERATOR_NS}
   oc describe deployment toolhive-operator -n ${OPERATOR_NS}
   ```
3. Check operator pod logs:
   ```bash
   oc logs -n ${OPERATOR_NS} -l name=toolhive-operator
   ```

### Chainsaw Tests Failing

**Symptoms:**
- Tests fail with assertion errors

**Solutions:**
1. Check test output for specific failures
2. Verify operator is running:
   ```bash
   oc get pods -n ${OPERATOR_NS}
   ```
3. Check MCPServer CR status:
   ```bash
   oc get mcpserver -n ${OPERATOR_NS} -o yaml
   ```
4. Review operator logs for reconciliation errors

### KIND Cluster Issues

**Symptoms:**
- Cluster creation fails or nodes not ready

**Solutions:**
1. Check KIND version:
   ```bash
   kind version
   ```
2. Ensure Docker is running
3. Check available resources:
   ```bash
   docker system df
   ```
4. Try recreating cluster:
   ```bash
   kind delete cluster --name toolhive-olm-test
   kind create cluster --name toolhive-olm-test
   ```

## Validation Checklist

Before pushing to GitHub, verify:

- [ ] All files are committed
- [ ] `.gitignore` is configured correctly
- [ ] Workflow YAML syntax is valid
- [ ] Helm chart templates render correctly
- [ ] Test files use correct namespace
- [ ] No hardcoded credentials or secrets
- [ ] README.md is up to date
- [ ] All emojis removed from workflow and test files

## Next Steps

1. **Commit and push to GitHub:**
   ```bash
   git add .
   git commit -m "Add CI workflow for ToolHive Operator OLM testing"
   git push -u origin master
   ```

2. **Monitor first workflow run:**
   - Check Actions tab for workflow execution
   - Review logs for any issues
   - Fix any problems and push updates

3. **Iterate and improve:**
   - Add more test scenarios as needed
   - Enhance error messages
   - Add matrix testing for multiple Kubernetes versions

