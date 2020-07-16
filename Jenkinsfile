// Setup milestone to stop previous build from running when a new one is launched
// The result would be:
//  Build 1 runs and creates milestone 1
//  While build 1 is running, suppose build 2 fires. It has milestone 1 and milestone 2. It passes 1, which causes build #1 to abort

def buildNumber = env.BUILD_NUMBER as int
if (buildNumber > 1) milestone(buildNumber - 1)
milestone(buildNumber)

pipeline {
    agent { label 'operator-slave'}
    options {
        buildDiscarder logRotator(artifactDaysToKeepStr: '', artifactNumToKeepStr: '', daysToKeepStr: '', numToKeepStr: '10')
        timeout(time: 90, unit: 'MINUTES')
    }
    environment {
        WORKING_DIR = "/home/jenkins/go/src/github.com/kiegroup/kogito-cloud-operator/"
        GOPATH = "/home/jenkins/go"
        GOCACHE = "/home/jenkins/go/.cache/go-build"

        OPENSHIFT_INTERNAL_REGISTRY = "image-registry.openshift-image-registry.svc:5000"
    }
    stages {
        stage('Clean Workspace') {
            steps {
                dir ("${WORKING_DIR}") {
                    deleteDir()
                }
            }
        }
        stage('Initialize') {
            steps {
                sh "mkdir -p ${WORKING_DIR} && cd ${WORKSPACE} && cp -Rap * ${WORKING_DIR}"
                sh "set +x && oc login --token=\$(oc whoami -t) --server=${OPENSHIFT_API} --insecure-skip-tls-verify"
            }
        }
        stage('Build Kogito Operator') {
            steps {
                dir ("${WORKING_DIR}") {
                    sh """
                        export GOROOT=`go env GOROOT`
                        GO111MODULE=on 
                        go get -u golang.org/x/lint/golint
                        touch /etc/sub{u,g}id
                        usermod --add-subuids 10000-75535 \$(whoami)
                        usermod --add-subgids 10000-75535 \$(whoami)
                        cat /etc/subuid
                        cat /etc/subgid
                        make image_builder=buildah
                    """
                }
            }
            
        }
        stage('Build Kogito CLI') {
            steps {
                dir ("${WORKING_DIR}") {
                    sh "make build-cli"
                }
            }
        }
        stage('Push Operator Image to Openshift Registry') {
            steps {
                dir ("${WORKING_DIR}") {
                    sh """
                        set +x && buildah login -u jenkins -p \$(oc whoami -t) --tls-verify=false ${OPENSHIFT_REGISTRY}
                        cd version/ && TAG_OPERATOR=\$(grep -m 1 'Version =' version.go) && TAG_OPERATOR=\$(echo \${TAG_OPERATOR#*=} | tr -d '"')
                        buildah tag quay.io/kiegroup/kogito-cloud-operator:\${TAG_OPERATOR} ${OPENSHIFT_REGISTRY}/openshift/kogito-cloud-operator:pr-\$(echo \${GIT_COMMIT} | cut -c1-7)
                        buildah push --tls-verify=false docker://${OPENSHIFT_REGISTRY}/openshift/kogito-cloud-operator:pr-\$(echo \${GIT_COMMIT} | cut -c1-7)
                    """
                }
            }
        }
        stage("Build examples' images for testing"){
            steps {
                script {
                    dir ("${WORKING_DIR}") {
                        // Do not build native images for the PR checks
                        sh "make build-examples-images tags='~@native' concurrent=1 ${getBDDParameters('never', false)}"
                    }
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: 'test/logs/**/*.log', allowEmptyArchive: true
                    junit testResults: 'test/logs/**/junit.xml', allowEmptyResults: true
                }
            }
        }
        stage('Running Smoke Testing') {
            steps {
                dir ("${WORKING_DIR}") {
                    sh """
                        make run-smoke-tests concurrent=3 ${getBDDParameters('always', true)}
                    """
                }
            }
            post {
                always {
                    dir("${WORKING_DIR}") {
                        archiveArtifacts artifacts: 'test/logs/**/*.log', allowEmptyArchive: true
                        junit testResults: 'test/logs/**/junit.xml', allowEmptyResults: true
                        sh "cd test && go run scripts/prune_namespaces.go"
                    }
                }
            }
        }
    }
}

String getBDDParameters(String image_cache_mode, boolean runtime_app_registry_internal=false) {
    testParamsMap = [:]

    testParamsMap["load_default_config"] = true
    testParamsMap["ci"] = "jenkins"
    testParamsMap["load_factor"] = 3

    testParamsMap["operator_image"] = "${OPENSHIFT_REGISTRY}/openshift/kogito-cloud-operator"
    testParamsMap["operator_tag"] = "pr-\$(echo \${GIT_COMMIT} | cut -c1-7)"
    testParamsMap["maven_mirror"] = env.MAVEN_MIRROR_REPOSITORY
    
    // runtime_application_image are built in this pipeline so we can just use Openshift registry for them
    testParamsMap["image_cache_mode"] = image_cache_mode
    testParamsMap["runtime_application_image_registry"] = runtime_app_registry_internal ? env.OPENSHIFT_INTERNAL_REGISTRY : env.OPENSHIFT_REGISTRY
    testParamsMap["runtime_application_image_namespace"] = "openshift"
    testParamsMap["runtime_application_image_version"] = "pr-\$(echo \${GIT_COMMIT} | cut -c1-7)"
    
    // Use podman container engine in tests
    testParamsMap['container_engine'] = 'podman'

    String testParams = testParamsMap.collect{ entry -> "${entry.getKey()}=\"${entry.getValue()}\"" }.join(" ")
    echo "BDD parameters = ${testParams}"
    return testParams
}