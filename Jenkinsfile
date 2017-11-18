#!groovy

podTemplate(
        label: 'slave',
        cloud: 'kubernetes',
        name: 'jenkins-slave',
        namespace: 'default',
        containers: [
                containerTemplate(
                        name: 'jenkins-slave',
                        image: '370535134506.dkr.ecr.us-west-2.amazonaws.com/jenkins-slave',
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
            string(name: 'registry_url', defaultValue: 'a0c447b4ecc5111e7b35502cab5b7ee6-669942456.us-west-2.elb.amazonaws.com:5000', description: 'Docker Container Registry URL')
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
//                    sh 'docker_pass=`aws ecr get-login --no-include-email --region us-west-2 | awk \'{print \$6}\'` && docker login -u AWS -p "${docker_pass}" https://370535134506.dkr.ecr.us-west-2.amazonaws.com/demo3'
                    sh 'docker build -t jdk8:152 -f kubernetes/Dockerfile.jdk .'
                    sh "docker tag jdk8:152 ${params.registry_url}/jdk8:152"
                    sh "docker push ${params.registry_url}/jdk8:152"

                    sh 'docker build -t db:latest -f kubernetes/Dockerfile.db .'
                    sh "docker tag db:latest ${params.registry_url}/db:latest"
                    sh "docker push ${params.registry_url}/db:latest"
//                    jdkImage = docker.build("jdk8:152", "-f kubernetes/Dockerfile.jdk .")
//                    echo "DOCKER IMAGE WAS BUILT SUCCESSFULLY"
//                    dbImage = docker.build("db:latest", "-f kubernetes/Dockerfile.db .")
//                    docker.withRegistry("${params.aws_ecr_url}") {
//                        jdkImage.push("152")
//                        dbImage.push("latest")
//                    }
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
                    sh "docker tag samsara:latest 3${params.registry_url}/samsara:latest"
                    sh "docker push ${params.registry_url}/samsara:latest"
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
                    def CLUSTER_NAME = "${NAME}-cluster.k8s.local"
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