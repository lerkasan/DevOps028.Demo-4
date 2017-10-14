pipelineJob('demo2-PIPELINE') {
    properties {
        githubProjectUrl('https://github.com/lerkasan/DevOps028.git')
    }
    scm {
        git {
            remote {
                url('https://github.com/lerkasan/DevOps028.git')
                name('origin')
                credentials('github_lerkasan')
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
//          script(readFileFromWorkspace('jenkins/pipeline/Jenkinsfile'))
//          sandbox()
//      }
        cpsScm {
            scm {
                git {
                    remote {
                        url('https://github.com/lerkasan/DevOps028.git')
                        name('origin')
                        credentials('github_lerkasan')
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
            scriptPath('jenkins/pipeline/Jenkinsfile')
        }
    }
}