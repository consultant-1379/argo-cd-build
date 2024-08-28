#!/usr/bin/env groovy

def bob = "./bob/bob"

def LOCKABLE_RESOURCE_LABEL = "bob-ci-patch-lcm"

def SLAVE_NODE = null
def SERVICE_OWNERS="sachin.p@ericsson.com, raman.n@ericsson.com"
def MAIL_TO='d386f28a.ericsson.onmicrosoft.com@emea.teams.ms, PDLMMECIMM@pdl.internal.ericsson.com'

node(label: 'docker') {
    stage('Nominating build node') {
        SLAVE_NODE = "${NODE_NAME}"
        echo "Executing build on ${SLAVE_NODE}"
    }
}

pipeline {
    agent {
        node {
            label "${SLAVE_NODE}"
        }
    }

    options {
        timestamps()
        buildDiscarder(logRotator(numToKeepStr: '50', artifactNumToKeepStr: '50'))
    }

    environment {
        TEAM_NAME = "${teamName}"
        KUBECONFIG = "${WORKSPACE}/.kube/config"
        DOCKER_CONFIG_FILE = "${WORKSPACE}"
        MAVEN_CLI_OPTS = "-Duser.home=${env.HOME} -B -s ${env.SETTINGS_CONFIG_FILE_NAME}"
        GIT_AUTHOR_NAME = "mxecifunc"
        GIT_AUTHOR_EMAIL = "PDLMMECIMM@pdl.internal.ericsson.com"
        GIT_COMMITTER_NAME = "${USER}"
        GIT_COMMITTER_EMAIL = "${GIT_AUTHOR_EMAIL}"
        GIT_SSH_COMMAND = "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o GSSAPIAuthentication=no -o PubKeyAuthentication=yes"
        GERRIT_CREDENTIALS_ID = 'gerrit-http-password-mxecifunc'
        DOCKER_CONFIG = "${WORKSPACE}"
        FOSSA_ENABLED = "true"
        MIMER_CHECK_ENABLED = "false"
        FOSSA_DEPENDENCY_VALIDATE = "false"   
    }

    // Stage names (with descriptions) taken from ADP Microservice CI Pipeline Step Naming Guideline: https://confluence.lmera.ericsson.se/pages/viewpage.action?pageId=122564754
    stages {
        stage('Commit Message Check') {
            steps {
                script {
                    def final commitMessage = new String(env.GERRIT_CHANGE_COMMIT_MESSAGE.decodeBase64())
                    if (commitMessage ==~ /(?ms)((Revert)|(\[MEE\-[0-9]+\])|(\[MXE\-[0-9]+\])|(\[MXESUP\-[0-9]+\])|(\[NoJira\]))+\s\S.*/) {
                        gerritReview labels: ['Commit-Message': 1]
                    } else {
                        def final message = 'Commit message check has failed'
                        def final link = 'https://confluence.lmera.ericsson.se/display/MXE/Code+review+WoW'
                        addWarningBadge text: message, link: link
                        addShortText text: 'malformed commit-msg', link: link, border: 0
                        gerritReview labels: ['Commit-Message': -1], message: message + ', see ' + link
                    }
                }
            }
        }

        stage('Submodule Init'){
            steps{
                sshagent(credentials: ['ssh-key-mxecifunc']) {
                    sh 'git clean -xdff'
                    sh 'git submodule sync'
                    sh 'git submodule update --init --recursive'
                }
            }
        }

        stage('Clean') {
            steps {
                script{
                    sh "${bob} clean"
                }
            }
        }

        stage('Init') {
            steps {
                sh "${bob} init-precodereview"
                script {
                    env.AUTHOR_NAME = sh(returnStdout: true, script: 'git show -s --pretty=%an')
                    currentBuild.displayName = currentBuild.displayName + ' / ' + env.AUTHOR_NAME
                    withCredentials([file(credentialsId: 'ARM_DOCKER_CONFIG', variable: 'DOCKER_CONFIG_FILE')]) {
                        writeFile file: 'config.json', text: readFile(DOCKER_CONFIG_FILE)
                    }
                }
            }
        }

        stage('Lint') {
            steps {
                sh "${bob} lint-license-check"
            }
            post {
                success {
                    gerritReview labels: ['Code-Format': 1]
                }
                unsuccessful {
                    gerritReview labels: ['Code-Format': -1]
                }
            }
        }

        stage('Images') {
            environment{
                ARM_API_TOKEN = credentials('arm-api-token-mxecifunc')
                SERO_ARM_TOKEN = credentials ('SERO_ARM_TOKEN')
            }
            steps {
                    sshagent(credentials: ['ssh-key-mxecifunc']) {
                        sh "${bob} image"
                    }
            }
            post {
                always {
                    archiveArtifacts allowEmptyArchive: true, artifacts: '**/image-design-rule-check-report*'
                    script{
                        if(fileExists('.bob/var.stdout-redirect-version-mismatch')){
                            fileContents = readFile('.bob/var.stdout-redirect-version-mismatch')
                            mail to : SERVICE_OWNERS,
                            subject : "[argo-cd-build] Warning: Newer version of stdout-redirect exists",
                            body : fileContents + "<br><br>" + "Changeset Author: ${env.AUTHOR_NAME} should consider upgrading stdout-redirect version <br>" +
                                    "<b>Gerrit Change Url:</b> ${env.GERRIT_CHANGE_URL} <br>" +
                                    "<b>Refer:</b> ${env.BUILD_URL} <br><br>" +
                                    "<b>Note:</b> This mail was automatically sent as part of ${env.JOB_NAME} jenkins job.",
                            mimeType: 'text/html'
                        }
                        sh "${bob} delete-images"
                    }
                }
            }
        }
        
        stage('FOSSA Scan'){
            when {
                expression {  env.FOSSA_ENABLED == "true" }
            }
            environment{
                FOSSA_API_KEY = credentials('FOSSA_API_KEY_PROD')
            }
            stages{                    
                stage('FOSSA Server Status Check') {
                    steps {
                        sh "${bob} fossa-server-check"
                    }
                }

                stage('FOSSA Analyze') {
                   when {
                        expression { readFile('.bob/var.fossa-available').trim() == "true" }
                   }
                    steps {
                        parallel (
                            "Analyze Argo CD": {
                                script {
                                    sh "${bob} fossa-argo-cd-analyze"  
                                }
                            },
                            "Analyze Argo UI" : {
                                script {
                                    sh "${bob} fossa-argo-cd-ui-analyze" 
                                }
                            },
                        )
                    }
                }
                stage('Fossa Scan Status Check'){
                    when {
                        expression { readFile('.bob/var.fossa-available').trim() == "true" }
                    }
                    steps {
                        parallel(
                            "Argo CD Scan Status Check": {
                                script {
                                    sh "${bob} fossa-argo-cd-scan-status-check"
                                }
                            },
                            "Argo CD UI Scan Status Check": {
                                script {
                                    sh "${bob} fossa-argo-cd-ui-scan-status-check"
                                }
                            },
                        )
                    }
                }
                stage('FOSSA Fetch Report') {
                   when {
                        expression {  readFile('.bob/var.fossa-available').trim() == "true" }
                   }
                    steps {
                        parallel(
                            "Argo CD Fetch Report": {
                                retry(5) {
                                    sh "${bob} fetch-argo-cd-fossa-report-attribution"
                                    archiveArtifacts '*fossa-argo-cd-report.json'
                                }
                            },
                            "Argo CD UI Fetch Report": {
                                retry(5) {
                                    sh "${bob} fetch-argo-cd-ui-fossa-report-attribution" 
                                    archiveArtifacts '*fossa-argo-cd-ui-report.json'
                                }
                            },
                        )
                    }
                }
            }
        }

        // Disabled for now..
        stage('FOSSA Dependency Validate') {
            when {
                expression {  env.FOSSA_DEPENDENCY_VALIDATE == "true" }                
            }

            steps {
                parallel(
                    "Argo CD Dependency Validate": {
                        script {
                            sh "${bob} dependency-validate-argo-cd"
                        }
                    },
                    "Argo CD UI Dependency Validate": {
                        script {
                            sh "${bob} dependency-validate-argo-cd-ui"
                        }
                    },
                    "Dependency Validate 2pps":{
                        script {
                            sh "${bob} dependency-validate-2pps"
                        }
                    },
                    "Dependency Validate 3pps":{
                        script {
                            sh "${bob} dependency-validate-3pps"
                        }
                    }
                )
            }
        }

        // Disabled for now..
        stage('Generate Input Files') {
            when {
                expression {  env.MIMER_CHECK_ENABLED == "true" }    
            }
            environment{
                MUNIN_TOKEN = credentials('MUNIN_TOKEN')
            }
            steps {
                parallel(
                    "argo cd Dependency File for Registration": {
                        script {
                            sh "${bob} check-foss-in-mimer-argo-cd"
                        }
                    },
                    "argo cd ui Dependency File for Registration": {
                        script {
                            sh "${bob} check-foss-in-mimer-argo-cd-ui"
                        }
                    },
                    "3pps Dependency File for Registration": {
                        script {
                            sh "${bob} check-foss-in-mimer-3pps"
                        }
                    }
                )
            }
            post {
                always {
                    archiveArtifacts allowEmptyArchive: true, artifacts: 'config/fossa/dependencies.argo-cd.yaml'
                }
            }
        }
    }
    post {
        success {
            script {
                modifyBuildDescription()
                cleanWs()
            }
        }
    }
}

def modifyBuildDescription() {

    def DOCKER_IMAGE_PREFIX="eric-aiml-declarative-deployer"
    def IMAGE_SUFFIXES=["argo-cd"]
    def VERSION = readFile('.bob/var.version').trim()

    def desc = "Docker Images: <br>"
    for (suffix in IMAGE_SUFFIXES) {
       def DOCKER_IMAGE_NAME="${DOCKER_IMAGE_PREFIX}-${suffix}"
       def DOCKER_IMAGE_DOWNLOAD_LINK = "https://armdocker.rnd.ericsson.se/artifactory/proj-mlops-ci-internal-docker-global/proj-mlops-ci-internal/${DOCKER_IMAGE_NAME}/${VERSION}/"
       desc+= "<a href='${DOCKER_IMAGE_DOWNLOAD_LINK}'>${DOCKER_IMAGE_NAME}:${VERSION}</a><br>"
    }
    desc+="Gerrit: <a href=${env.GERRIT_CHANGE_URL}>${env.GERRIT_CHANGE_URL}</a> <br>"
    currentBuild.description = desc
}

