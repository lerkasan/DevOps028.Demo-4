import org.csanchez.jenkins.plugins.kubernetes.*
import jenkins.model.*

def j = Jenkins.getInstance()

def k = new KubernetesCloud(
        'jenkins',
        null,
        'https://api.jenkins.lerkasan.de',
        'jenkins',
        'http://jenkins.lerkasan.de:8080/',
        '10', 15, 15, 5
)

k.setSkipTlsVerify(true)
j.clouds.replace(k)
j.save()