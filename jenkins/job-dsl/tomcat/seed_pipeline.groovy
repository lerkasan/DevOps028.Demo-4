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
}