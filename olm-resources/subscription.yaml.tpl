apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: toolhive-operator
  namespace: ${OPERATOR_NS}
spec:
  channel: stable
  name: toolhive-operator
  source: toolhive-test-catalog
  sourceNamespace: openshift-marketplace
  installPlanApproval: Automatic

