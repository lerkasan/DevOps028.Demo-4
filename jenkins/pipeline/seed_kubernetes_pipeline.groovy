package pipeline

pipelineJob('demo3-kubernetes') {
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
//          script(readFileFromWorkspace('Jenkinsfile'))
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
                    branch('master')
                    browser {
                        gitWeb('https://github.com/lerkasan/DevOps028.git')
                    }
                    extensions {
                        cleanBeforeCheckout()
                    }
                }
            }
            scriptPath('Jenkinsfile.kubernetes')
        }
    }
}