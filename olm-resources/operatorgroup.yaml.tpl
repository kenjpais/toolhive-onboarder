apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: toolhive-operator-group
  namespace: ${OPERATOR_NS}
spec:
  targetNamespaces:
    - ${OPERATOR_NS}

