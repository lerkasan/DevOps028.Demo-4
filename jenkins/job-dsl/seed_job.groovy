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
        shell(readFileFromWorkspace('jenkins/job-dsl/jobdsl-build-step.sh'))
        maven {
            goals('clean package')
            properties(skipTests: true)
            mavenInstallation('Maven 3.5.0')
        }
        shell('ARTIFACT_FILENAME=`ls ${WORKSPACE}/target | grep war | grep -v original` && mv ${WORKSPACE}/target/${ARTIFACT_FILENAME} ${WORKSPACE}/target/ROOT.war')
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
            includePatterns('*.war', '*.jar')
            targetDirectory('target')
            flatten()
            optional()
            buildSelector {
                latestSuccessful(true)
            }
        }
        shell(readFileFromWorkspace('jenkins/job-dsl/jobdsl-deploy-step.sh'))
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
    wrappers {
        colorizeOutput()
        timestamps()
    }
}