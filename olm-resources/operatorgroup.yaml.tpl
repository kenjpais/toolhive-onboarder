apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: toolhive-operator-group
  namespace: ${OPERATOR_NS}
spec:
  # Empty targetNamespaces means cluster-scoped (all namespaces)
  # Required because the operator installs CRDs which are cluster-scoped resources
  targetNamespaces: []

