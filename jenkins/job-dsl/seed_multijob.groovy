#!groovy

job('demo2-build') {
    jdk('oracle-jdk8u144-linux-x64')
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
        shell('javac -version')
        maven {
            goals('clean package')
            properties(skipTests: true)
            mavenInstallation('maven-3.5.0')
        }
        shell(readFileFromWorkspace('jenkins/job-dsl/postbuild-step.sh'))
    }
    publishers {
        archiveArtifacts {
            pattern('target/*.jar')
            onlyIfSuccessful()
        }
    }
    wrappers {
        colorizeOutput()
        timestamps()
    }
}

job('demo2-infra-preparation') {
    scm {
        git {
            remote {
                url('https://github.com/lerkasan/DevOps028.git')
                name('origin')
            }
            branch('jenkins')
            browser {
                gitWeb('https://github.com/lerkasan/DevOps028.git')
            }
            extensions {
                cleanBeforeCheckout()
            }
        }
    }
    steps {
        shell(readFileFromWorkspace('jenkins/job-dsl/prepare-infra.sh'))
        shell(readFileFromWorkspace('jenkins/job-dsl/check-webapp-response.sh'))
    }
    publishers {
        extendedEmail {
            recipientList('lerkasan@gmail.com')
            contentType('text/html')
            triggers {
                success {
                    subject('Web application Samsara was deployed')
                //  content('${BUILD_LOG_REGEX, regex="Webapp endpoint", showTruncatedLines=false}')
                    content('Webapp endpoint: ${env.ELB_HOST}:${env.ELB_PORT}')
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

multiJob('demo2-MULTIJOB') {
    jdk('oracle-jdk8u144-linux-x64')
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
        maven {
            goals('clean test')
            mavenInstallation('maven-3.5.0')
        }
        phase('Build') {
            continuationCondition('SUCCESSFUL')
            phaseJob('demo2-build')
        }
        phase('Prepare infrastructure and deploy') {
            continuationCondition('SUCCESSFUL')
            phaseJob('demo2-infra-preparation')
        }
    }
    publishers {
        extendedEmail {
            recipientList('lerkasan@gmail.com')
            contentType('text/html')
            triggers {
                failure {
                    subject('Failure during building Web application Samsara')
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
