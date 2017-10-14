#!groovy

pipeline {
    agent {
        label 'slave-node'
    }
    tools {
        jdk 'oracle-jdk8u144-linux-x64'
        maven "maven-3.5.0"
    }
    options {
        timestamps()
    }
    stages {
        stage('Checkout') {
            steps {
                echo "Cleaning workspace ..."
                cleanWs()
                echo "Checkout master branch to workspace folder and checkout jenkins branch to subfolder 'jenkins'"
                checkout(
                        [$class: 'GitSCM',
                         branches: [[name: '*/master']], doGenerateSubmoduleConfigurations: false,
                         browser: [$class: 'GithubWeb', repoUrl: 'https://github.com/lerkasan/DevOps028.git'],
                         // extensions: [[$class: 'CleanBeforeCheckout']],
                         extensions: [[$class: 'CleanBeforeCheckout'], [$class: 'PathRestriction', excludedRegions: 'Jenkinsfile.*']],
                         gitTool: 'git-slave',
                         submoduleCfg: [],
                         userRemoteConfigs: [[url: 'https://github.com/lerkasan/DevOps028.git', credentialsId: 'github_lerkasan']]
                        ])
                checkout(
                        [$class: 'GitSCM',
                         branches: [[name: '*jenkins']], doGenerateSubmoduleConfigurations: false,
                         // extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: 'jenkins']],
                         // extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: 'jenkins'], [$class: 'PathRestriction', excludedRegions: 'jenkins/.*']],
                         extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: 'jenkins'], [$class: 'IgnoreNotifyCommit'], [$class: 'PathRestriction', excludedRegions: 'jenkins/.*']],
                         gitTool: 'git-slave',
                         submoduleCfg: [],
                         userRemoteConfigs: [[url: 'https://github.com/lerkasan/DevOps028.git', credentialsId: 'github_lerkasan']]
                        ])
            }
        }
        // Let's create here AWS infrastructure and assume that it is our production environment that has already existed before running this pipeline
        // This stage should be ommited in real situation when we already have existing production environment
        stage("Prepare AWS infrastructure, test and build ") {
            parallel  {
                stage("Prepare AWS infrastructure") {
                    steps {
                        echo "Preparing AWS infrastructure ..."
                        sh "chmod +x jenkins/jenkins/pipeline/*.sh"
                        sh "jenkins/jenkins/pipeline/prepare-infra.sh"
                    }
                }
                stage("Test and build")  {
                    steps {
                        sh "javac -version"
                        echo "Testing project"
                        sh "mvn clean test"
                        echo "Building jar ..."
                        sh "mvn clean package"
                    }
                    post {
                        success {
                            archiveArtifacts artifacts: 'target/*.jar', onlyIfSuccessful: true
                            sh "jenkins/jenkins/pipeline/postbuild-step.sh"
                        }
                    }
                }
            }
        }
        stage("Deploy") {
            steps {
                echo "Deploying ..."
                sh "jenkins/jenkins/pipeline/rolling-update-instances.sh"
            }
            post {
                success {
                    sh "jenkins/jenkins/pipeline/check-webapp-response.sh"
                }
            }
        }
    }
    post {
        success {
            emailext body: '${BUILD_LOG_REGEX, regex="Webapp endpoint", showTruncatedLines=false}',
                    subject: 'Web application Samsara was deployed',
                    to: 'lerkasan@gmail.com'
        }
        failure {
            emailext body: '${BUILD_LOG}',
                    subject: 'Web application Samsara deploy failed',
                    to: 'lerkasan@gmail.com'
        }
    }
}
