#!groovy

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
        shell(readFileFromWorkspace('jenkins/job-dsl/tomcat/jobdsl-prebuild-step.sh'))
        maven {
            goals('clean package')
            properties(skipTests: true)
            mavenInstallation('Maven 3.5.0')
        }
        shell(readFileFromWorkspace('jenkins/job-dsl/tomcat/jobdsl-postbuild-step.sh'))
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

job('demo2-prepare-rds') {
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
        shell(readFileFromWorkspace('jenkins/job-dsl/tomcat/jobdsl-prepare-rds-step.sh'))
    }
    wrappers {
        colorizeOutput()
        timestamps()
    }
}

job('demo2-prepare-tomcat') {
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
        shell(readFileFromWorkspace('jenkins/job-dsl/tomcat/jobdsl-prepare-tomcat-step.sh'))
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
        shell(readFileFromWorkspace('jenkins/job-dsl/tomcat/jobdsl-deploy-step.sh'))
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

multiJob('demo2-multijob') {
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
            mavenInstallation('Maven 3.5.0')
        }
        phase('Prepare RDS, Tomcat') {
            continuationCondition('SUCCESSFUL')
            phaseJob('demo2-prepare-rds')
            phaseJob('demo2-prepare-tomcat')
        }
        phase('Package war') {
            continuationCondition('SUCCESSFUL')
            phaseJob('demo2-build')
        }
        phase('Deploy') {
            phaseJob('demo2-deploy')
        }
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