#!groovy

//job('demo2-start-and-connect-slave-nodes') {
//    scm {
//        git {
//            remote {
//                url('https://github.com/lerkasan/DevOps028.git')
//                name('origin')
//            }
//            branch('jenkins')
//            browser {
//                gitWeb('https://bitbucket.org/lerkasan/jenkins-jobdsl')
//            }
//            extensions {
//                cleanBeforeCheckout()
//            }
//        }
//    }
//    steps {
//        shell(readFileFromWorkspace('jenkins/job-dsl/start-slave-nodes.sh'))
//        groovyScriptFile('connect_slave_nodes.groovy')
//    }
//    wrappers {
//        colorizeOutput()
//        timestamps()
//    }
//}
//
//job('demo2-stop-slave-nodes') {
//    scm {
//        git {
//            remote {
//                url('https://github.com/lerkasan/DevOps028.git')
//                name('origin')
//            }
//            branch('jenkins')
//            browser {
//                gitWeb('https://bitbucket.org/lerkasan/jenkins-jobdsl')
//            }
//            extensions {
//                cleanBeforeCheckout()
//            }
//        }
//    }
//    steps {
//        shell(readFileFromWorkspace('jenkins/job-dsl/stop-slave-nodes.sh'))
//    }
//    wrappers {
//        colorizeOutput()
//        timestamps()
//    }
//}

job('demo2-test') {
    properties {
        githubProjectUrl('https://github.com/lerkasan/DevOps028.git')
    }
    scm {
        git {
            remote {
                url('https://github.com/lerkasan/DevOps028.git')
                name('origin')
            }
            branch('master')
            browser {
                gitWeb('https://github.com/lerkasan/DevOps028.git')
            }
            extensions {
                cleanBeforeCheckout()
            }
        }
    }
    steps {
        // shell(readFileFromWorkspace('jenkins/job-dsl/jobdsl-test-step.sh'))
        maven {
            goals('clean test')
            mavenInstallation('Maven 3.5.0')
        }
    }
    wrappers {
        colorizeOutput()
        timestamps()
    }
}

job('demo2-build') {
    properties {
        githubProjectUrl('https://github.com/lerkasan/DevOps028.git')
    }
    scm {
        git {
            remote {
                url('https://github.com/lerkasan/DevOps028.git')
                name('origin')
            }
            branch('master')
            browser {
                gitWeb('https://github.com/lerkasan/DevOps028.git')
            }
            extensions {
                cleanBeforeCheckout()
            }
        }
    }
    steps {
        shell(readFileFromWorkspace('jenkins/job-dsl/jobdsl-prebuild-step.sh'))
        maven {
            goals('clean package')
            properties(skipTests: true)
            mavenInstallation('Maven 3.5.0')
        }
        shell(readFileFromWorkspace('jenkins/job-dsl/jobdsl-postbuild-step.sh'))
    }

    publishers {
        archiveArtifacts {
            pattern('target/ROOT.war')
            pattern('target/*.jar')
            onlyIfSuccessful()
        }
    }
    wrappers {
        colorizeOutput()
        timestamps()
    }
}

job('demo2-create-prod-rds') {
    scm {
        git {
            remote {
                url('https://github.com/lerkasan/DevOps028.git')
                name('origin')
            }
            branch('jenkins')
            browser {
                gitWeb('https://bitbucket.org/lerkasan/jenkins-jobdsl')
            }
            extensions {
                cleanBeforeCheckout()
            }
        }
    }
    steps {
        shell(readFileFromWorkspace('jenkins/job-dsl/jobdsl-create-rds-step.sh'))
    }
    wrappers {
        colorizeOutput()
        timestamps()
    }
}

job('demo2-install-tomcat') {
    scm {
        git {
            remote {
                url('https://github.com/lerkasan/DevOps028.git')
                name('origin')
            }
            branch('jenkins')
            browser {
                gitWeb('https://bitbucket.org/lerkasan/jenkins-jobdsl')
            }
            extensions {
                cleanBeforeCheckout()
            }
        }
    }
    steps {
        shell(readFileFromWorkspace('jenkins/job-dsl/jobdsl-install-tomcat-step.sh'))
    }
    wrappers {
        colorizeOutput()
        timestamps()
    }
}

job('demo2-deploy') {
    properties {
        githubProjectUrl('https://github.com/lerkasan/DevOps028.git')
    }
    scm {
        git {
            remote {
                url('https://github.com/lerkasan/DevOps028.git')
                name('origin')
            }
            branch('master')
            browser {
                gitWeb('https://github.com/lerkasan/DevOps028.git')
            }
            extensions {
                cleanBeforeCheckout()
            }
        }
    }
    steps {
        copyArtifacts('demo2-build') {
            targetDirectory('target')
            flatten()
            buildSelector {
                latestSuccessful(true)
            }
        }
        shell(readFileFromWorkspace('jenkins/job-dsl/jobdsl-deploy-step.sh'))
    }
    publishers {
        extendedEmail {
            recipientList('lerkasan@gmail.com')
            contentType('text/html')
            triggers {
                success {
                    subject('Web application Samsara was deployed to Tomcat')
                    content('${BUILD_LOG_REGEX, regex="Tomcat endpoint", showTruncatedLines=false}')
                    sendTo {
                        recipientList()
                    }
                }
            }
        }
    }
    wrappers {
        colorizeOutput()
        timestamps()
    }
}

multiJob('demo2') {
    properties {
        githubProjectUrl('https://github.com/lerkasan/DevOps028.git')
    }
    scm {
        git {
            remote {
                url('https://github.com/lerkasan/DevOps028.git')
                name('origin')
            }
            branch('master')
            browser {
                gitWeb('https://github.com/lerkasan/DevOps028.git')
            }
            extensions {
                cleanBeforeCheckout()
            }
        }
    }
    triggers {
        githubPush()
    }
    steps {
//        phase('Start and connect ec2 slave nodes') {
//            continuationCondition('SUCCESSFUL')
//            phaseJob('demo2-start-and-connect-slave-nodes')
//        }
        phase('Test') {
            continuationCondition('SUCCESSFUL')
            phaseJob('demo2-test')
        }
        phase('Create RDS, install Tomcat and build war') {
            continuationCondition('SUCCESSFUL')
            phaseJob('demo2-create-prod-rds')
            phaseJob('demo2-install-tomcat')
            phaseJob('demo2-build')
        }
        phase('Deploy') {
            phaseJob('demo2-deploy')
        }
//        phase('Stop ec2 slave nodes') {
//            phaseJob('demo2-stop-slave-nodes')
//        }
    }
    publishers {
        extendedEmail {
            recipientList('lerkasan@gmail.com')
            contentType('text/html')
            triggers {
                failure {
                    subject('Failure during building web application Samsara')
                    content('${BUILD_LOG, maxLines=1500}')
                    sendTo {
                        recipientList()
                    }
                }
            }
        }
    }
    wrappers {
        colorizeOutput()
        timestamps()
    }
}