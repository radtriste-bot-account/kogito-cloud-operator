#!/bin/bash

QUAY_USERNAME=
QUAY_PASSWORD=

OPERATOR_DIR=build/_output/operatorhub/
APPLICATION_NAME=kogito-operator
QUAY_NAMESPACE={QUAY_USERNAME}
VERSION={CURRENT_VERSION}

prerequisites
	helm
	helm registry plugin
	operator-courier

############################# CREATE

1 - Update operator.yaml with built image

2 - make vet (to update csv file)

3 - make prepare-olm ${VERSION} (output folder => ${OPERATOR_DIR})

4 - Get token ?

	TOKEN=$(curl -sH "Content-Type: application/json" -XPOST https://quay.io/cnr/api/v1/users/login -d '
	{
		"user": {
			"username": "'"${QUAY_USERNAME}"'",
			"password": "'"${QUAY_PASSWORD}"'"
		}
	}' | jq -r '.token')

5 - push to quay.io via operator courier
	try to delete version before ?
		helm registry delete-package quay.io/${QUAY_NAMESPACE}/${APPLICATION_NAME}@${VERSION}
	
	operator-courier push "${OPERATOR_DIR}" "${QUAY_NAMESPACE}" "${APPLICATION_NAME}" "${VERSION}" "${TOKEN}"
	
6 - Set application as public ???
	Did not find how to do that ...

8 - Update and apply operator-source to cluster
	update deploy/olm-catalog/kogito-operator/kogito-operator-operatorsource.yaml
    	=> set registryNamespace to ${QUAY_NAMESPACE}
	oc apply -f deploy/olm-catalog/kogito-operator/kogito-operator-operatorsource.yaml

# In BDD tests, not in shell
9 - Wait for operator to be available via olm
10 - Install custom kogito-cloud-operator

############################# DELETE

1 - delete operator-source
	oc delete operatorsource kogito-operator

2 - delete quay.io application version
	helm registry delete-package quay.io/${QUAY_NAMESPACE}/${APPLICATION_NAME}@${VERSION}