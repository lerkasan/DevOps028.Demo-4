pipelineJob('demo2-pipeline') {
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
    definition {
//      cps {
//          script(readFileFromWorkspace('jenkins/job-dsl/tomcat/Jenkinsfile'))
//          sandbox()
//      }
        cpsScm {
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
            scriptPath('jenkins/job-dsl/tomcat/Jenkinsfile')
        }
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