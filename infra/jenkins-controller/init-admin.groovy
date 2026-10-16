#!groovy
import jenkins.model.*
import hudson.security.*

def instance = Jenkins.getInstance()
def env = System.getenv()

String adminUser = env['JENKINS_ADMIN_USER'] ?: 'admin'
String adminPass = env['JENKINS_ADMIN_PASS'] ?: 'admin123'
String rootUrl = env['JENKINS_ROOT_URL'] ?: 'http://jenkins-controller:8080/'

// 1. Configure Jenkins Root URL
println "--> [Init] Configuring Jenkins Root URL: ${rootUrl}"
def locationConfig = JenkinsLocationConfiguration.get()
locationConfig.setUrl(rootUrl)
locationConfig.save()

// 2. Set Controller (Built-In Node) Executors to 0
println "--> [Init] Setting controller executors to 0 (Dedicated Agents Only)..."
instance.setNumExecutors(0)
instance.save()

// 3. Configure Admin User & Authorization
println "--> [Init] Configuring Jenkins Admin User: ${adminUser}"
def hudsonRealm = new HudsonPrivateSecurityRealm(false)
if (hudsonRealm.getUser(adminUser) == null) {
    hudsonRealm.createAccount(adminUser, adminPass)
    instance.setSecurityRealm(hudsonRealm)

    def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
    strategy.setAllowAnonymousRead(false)
    instance.setAuthorizationStrategy(strategy)
    instance.save()
    println "--> [Init] Admin user created successfully."
} else {
    println "--> [Init] Admin user already exists. Skipping creation."
}
