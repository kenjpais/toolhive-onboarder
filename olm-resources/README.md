# OLM Resources

Simple YAML templates for deploying ToolHive Operator via OLM.

## Files

- `namespace.yaml.tpl` - Creates the operator namespace
- `catalogsource.yaml.tpl` - Registers the operator catalog
- `operatorgroup.yaml.tpl` - Defines operator scope
- `subscription.yaml.tpl` - Subscribes to the operator

## Usage

Templates use environment variable substitution via `envsubst`:

```bash
export OPERATOR_NS=toolhive-test-ns
export CATALOG_IMAGE=quay.io/kpais/toolhive-test-catalog:latest

envsubst < namespace.yaml.tpl | oc apply -f -
envsubst < catalogsource.yaml.tpl | oc apply -f -
envsubst < operatorgroup.yaml.tpl | oc apply -f -
envsubst < subscription.yaml.tpl | oc apply -f -
```

Or use the Makefile:

```bash
make deploy-olm
```

## Variables

- `OPERATOR_NS` - Namespace for the operator (default: `toolhive-test-ns`)
- `CATALOG_IMAGE` - Catalog index image (default: `quay.io/kpais/toolhive-test-catalog:latest`)

