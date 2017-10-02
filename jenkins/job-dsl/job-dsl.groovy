#!groovy

job('demo2-test-and-build') {
    properties {
        githubProjectUrl('https://github.com/lerkasan/DevOps028.git')
    }
    scm {
        git {
            remote {
                github('lerkasan/DevOps028', 'https')
                name('origin')
            }
            branch('master')
            browser {
                gitWeb('https://github.com/lekrasan/DevOps028.git')
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
}