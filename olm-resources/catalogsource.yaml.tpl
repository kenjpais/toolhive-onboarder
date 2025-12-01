apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: toolhive-test-catalog
  namespace: openshift-marketplace
spec:
  displayName: ToolHive Test Catalog
  image: ${CATALOG_IMAGE}
  publisher: ToolHive Test
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 10m

