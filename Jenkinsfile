#!groovy

podTemplate(
        label: 'slave',
        cloud: 'kubernetes',
        name: 'jenkins-slave',
        namespace: 'default',
        containers: [
                containerTemplate(
                        name: 'jenkins-slave',
                        image: 'registry.lerkasan.de:5000/jenkins-slave',
                        ttyEnabled: true,
                        privileged: true,
                        alwaysPullImage: true,
                        workingDir: '/home/jenkins',
                        command: 'cat'
                )
        ],
        volumes: [
                hostPathVolume(mountPath: '/var/run/docker.sock', hostPath: '/var/run/docker.sock')
        ]
) {

    node('slave') {
        parameters {
            string(name: 'registry_url', defaultValue: 'registry.lerkasan.de:5000', description: 'Docker Container Registry URL')
        }
        timestamps {
//            stage('Checkout') {
//                echo "Checkout master branch to workspace folder and checkout jenkins branch to subfolder 'jenkins'"
//                checkout(
//                        [$class           : 'GitSCM',
//                         branches         : [[name: '*/master']], doGenerateSubmoduleConfigurations: false,
//                         browser          : [$class: 'GithubWeb', repoUrl: 'https://github.com/lerkasan/DevOps028.git'],
//                         extensions       : [[$class: 'CleanBeforeCheckout']],
//                         gitTool          : 'git',
//                         submoduleCfg     : [],
//                         userRemoteConfigs: [[url: 'https://github.com/lerkasan/DevOps028.git', credentialsId: 'github_lerkasan']]
//                        ])
//            }
            stage("Test and build jar") {
                git url: 'https://github.com/lerkasan/DevOps028.git'
                container('jenkins-slave') {
                    echo "Testing project ..."
                    sh "mvn clean test"
                    echo "Building jar ..."
                    sh "mvn clean package"
                    archiveArtifacts artifacts: 'target/*.jar', onlyIfSuccessful: true
                }
            }
            stage("Build docker dependency and database images") { // TODO this stage to be deleted from final pipeline
                container('jenkins-slave') {
                    echo "Building docker images for dependecy and database..."
                    sh 'docker build -t jdk8:152 -f kubernetes/Dockerfile.jdk kubernetes'
                    sh 'docker build -t db:latest -f kubernetes/Dockerfile.db kubernetes'
                    withEnv(["REGISTRY_URL=registry.lerkasan.de:5000"]) {
                        echo "Registry URL is: ${REGISTRY_URL}"
//                    sh 'docker_pass=`aws ecr get-login --no-include-email --region us-west-2 | awk \'{print \$6}\'` && docker login -u AWS -p "${docker_pass}" https://370535134506.dkr.ecr.us-west-2.amazonaws.com/demo3'
                        sh "docker tag jdk8:152 ${REGISTRY_URL}/jdk8:152"
                        sh "docker push ${REGISTRY_URL}/jdk8:152"
                        sh "docker tag db:latest ${REGISTRY_URL}/db:latest"
                        sh "docker push ${REGISTRY_URL}/db:latest"
//                    jdkImage = docker.build("jdk8:152", "-f kubernetes/Dockerfile.jdk .")
//                    echo "DOCKER IMAGE WAS BUILT SUCCESSFULLY"
//                    dbImage = docker.build("db:latest", "-f kubernetes/Dockerfile.db .")
//                    docker.withRegistry("${params.aws_ecr_url}") {
//                        jdkImage.push("152")
//                        dbImage.push("latest")
//                    }
                    }
                }
            }
            stage("Build and push samsara webapp image") {
                container('jenkins-slave') {
                    echo "Building and pushing samsara webapp image ..."
                    def ARTIFACT_FILENAME = sh(
                            script: "ls ${WORKSPACE}/target | grep jar | grep -v original",
                            returnStdout: true
                    ).trim()
                    sh "cp ${WORKSPACE}/target/${ARTIFACT_FILENAME} ."
//                    sh 'docker_pass=`aws ecr get-login --no-include-email --region us-west-2 | awk \'{print \$6}\'` && docker login -u AWS -p "${docker_pass}" https://370535134506.dkr.ecr.us-west-2.amazonaws.com/demo3'
                    sh "docker build -t samsara:latest --build-arg ARTIFACT_FILENAME=${ARTIFACT_FILENAME} ."
                    withEnv(["REGISTRY_URL=registry.lerkasan.de:5000"]) {
                        sh "docker tag samsara:latest ${REGISTRY_URL}/samsara:latest"
                        sh "docker push ${REGISTRY_URL}/samsara:latest"
                    }
//                    samsaraImage = docker.build("samsara:latest", "--build-arg ARTIFACT_FILENAME=${ARTIFACT_FILENAME} .")
//                    docker.withRegistry("${params.aws_ecr_url}") {
//                        samsaraImage.push("latest")
//                    }
                    sh "docker rmi -f `docker images -q` | true"
                }
            }
            stage("Deploy webapp") {
                container('jenkins-slave') {
//                    sh "kops update cluster ${CLUSTER_NAME} --yes"
                    def NAME = "samsara"
                    def CLUSTER_NAME = "${NAME}.lerkasan.de"
                    def KOPS_STATE_STORE = "s3://${NAME}-cluster-state"
                    sh "aws s3 cp ${KOPS_STATE_STORE}/kube-config ~/.kube/config"
                    sh "kops rolling-update cluster ${CLUSTER_NAME} --state ${KOPS_STATE_STORE} --yes"
                    sleep time: 20, unit: 'SECONDS'

                    echo "Checking connectivity to webapp load balancer ..."
                    def ELB_HOST = sh(script: "kubectl describe svc samsara | grep Ingress | awk '{print \$3}'",
                            returnStdout: true
                    ).trim()
                    echo "URL is ${ELB_HOST}:9000/login"
                    def response = httpRequest url: "http://${ELB_HOST}:9000/login", httpMode: 'GET', timeout: 60, consoleLogResponseBody: true
                    println("Webapp HTTP_RESPONSE_CODE = " + response.getStatus())
                    println("Webapp endpoint: ${ELB_HOST}:9000")
                }
            }
//    post {
//        success {
//            emailext body: '${BUILD_LOG_REGEX, regex="Webapp endpoint", showTruncatedLines=false}',
//                    subject: 'Web application Samsara was deployed',
//                    to: 'lerkasan@gmail.com'
//        }
//        failure {
//            emailext attachLog: true,
//                    body: 'Build log is attached.',
//                    subject: 'Web application Samsara deploy failed',
//                    to: 'lerkasan@gmail.com'
//        }
//    }
        }
    }
}