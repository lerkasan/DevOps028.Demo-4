//from https://github.com/Accenture/adop-jenkins/blob/59997d59b04f520d13d0b9c2adfd74d1fe6fd88b/resources/init.groovy.d/smtp.groovy
import hudson.model.*
import jenkins.model.*
import hudson.tools.*
import hudson.util.Secret

// Variables
def SystemAdminMailAddress = "jenkmailer@gmail.com"
def SMTPUser = "jenkmailer@gmail.com"
def SMTPPassword = ""
def SMTPPort = 465
def SMTPHost = "smtp.gmail.com"

// Constants
def instance = Jenkins.getInstance()
def mailServer = instance.getDescriptor("hudson.tasks.Mailer")
def jenkinsLocationConfiguration = JenkinsLocationConfiguration.get()
def extmailServer = instance.getDescriptor("hudson.plugins.emailext.ExtendedEmailPublisher")

Thread.start {
    sleep 10000

    //Jenkins Location
    println "--> Configuring JenkinsLocation"
    jenkinsLocationConfiguration.setAdminAddress(SystemAdminMailAddress)
    jenkinsLocationConfiguration.save()

    //E-mail Server
    mailServer.setSmtpAuth(SMTPUser, SMTPPassword)
    mailServer.setSmtpHost(SMTPHost)
    mailServer.setSmtpPort(SMTPPort)
    mailServer.setCharset("UTF-8")

    //Extended-Email
    extmailServer.smtpAuthUsername=SMTPUser
    extmailServer.smtpAuthPassword=Secret.fromString(SMTPPassword)
    extmailServer.smtpHost=SMTPHost
    extmailServer.smtpPort=SMTPPort
    extmailServer.charset="UTF-8"
    extmailServer.defaultSubject="\$PROJECT_NAME - Build # \$BUILD_NUMBER - \$BUILD_STATUS!"
    extmailServer.defaultBody="\$PROJECT_NAME - Build # \$BUILD_NUMBER - \$BUILD_STATUS:\n\nCheck console output at \$BUILD_URL to view the results."

    // Save the state
    instance.save()
}