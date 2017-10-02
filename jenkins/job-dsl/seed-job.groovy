#!groovy

job('demo2-test-and-build') {
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
        shell(readFileFromWorkspace('jenkins/job-dsl/jobdsl-test-step.sh'))
        maven {
            goals('clean test')
            mavenInstallation('Maven 3.5.0')
        }

        shell(readFileFromWorkspace('jenkins/job-dsl/jobdsl-build-step.sh'))
        maven {
            goals('clean package')
            properties(skipTests: true)
            mavenInstallation('Maven 3.5.0')
        }
    }
    publishers {
        archiveArtifacts {
            pattern('target/*.war')
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
    properties {
        githubProjectUrl('https://github.com/lerkasan/DevOps028.git')
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
        copyArtifacts('demo2-test-and-build') {
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
    steps {
        phase('Test and build') {
            continuationCondition('SUCCESSFUL')
            phaseJob('demo2-test-and-build')
        }
        phase('Create RDS and install Tomcat') {
            continuationCondition('SUCCESSFUL')
            phaseJob('demo2-create-prod-rds')
            phaseJob('demo2-install-tomcat')
        }
        phase('Deploy') {
            phaseJob('demo2-deploy')
        }
    }
}