import hudson.model.*
import jenkins.model.*
import hudson.slaves.*
import hudson.plugins.sshslaves.SSHLauncher
import hudson.plugins.sshslaves.verifiers.*

def connectNode(String privateIp, String nodeName) {
    ManuallyTrustedKeyVerificationStrategy manuallyTrustedKeyVerificationStrategy = new ManuallyTrustedKeyVerificationStrategy(false)
    ComputerLauncher launcher = new SSHLauncher(
            privateIp, //"172.31.27.202", // Host
            22, // Port
            "18ce16e0-2700-42d5-b9b0-8d7d8ec5f143", // Credentials ID
            (String) null, // JVM Options
            (String) null, // JavaPath
            (String) null, // Prefix Start Slave Command
            (String) null, // Suffix Start Slave Command
            (Integer) null, // Connection Timeout in Seconds
            (Integer) null, // Maximum Number of Retries
            (Integer) null, // The number of seconds to wait between retries
            manuallyTrustedKeyVerificationStrategy // Manually trusted Key Verification Strategy
    )
    Slave agent = new DumbSlave(
            nodeName, // "node3",
            "/home/ec2-user",
            launcher)
    agent.nodeDescription = nodeName //"node3"
    agent.numExecutors = 3
    agent.labelString = "slave-node"
    agent.mode = Node.Mode.NORMAL
    agent.retentionStrategy = new RetentionStrategy.Always()
    print("Inside function. Connecting slave node" + nodeName + " with ip " + privateIp)
    Jenkins.instance.addNode(agent)
}

String[] slavesIpAddresses = "${env.SLAVE_IP_ADDRESSES}".split(' ')
int counter = 10
for (ipAddress in slavesIpAddresses) {
    print("Before function. Connecting slave node" + counter + " with ip " + ipAddress)
    connectNode(ipAddress, "node"+counter)
    counter++
}
