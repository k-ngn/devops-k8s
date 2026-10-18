#!groovy
import jenkins.model.Jenkins
import org.jenkinsci.plugins.workflow.job.WorkflowJob
import org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition
import hudson.plugins.git.GitSCM
import hudson.plugins.git.BranchSpec
import hudson.plugins.git.UserRemoteConfig
import java.util.Collections

def instance = Jenkins.getInstance()
def jobName = "demo-app-pipeline"
def repoUrl = "https://github.com/k-ngn/devops-k8s.git"
def branchSpec = "*/main"
def scriptPath = "Jenkinsfile"

if (instance.getItem(jobName) == null) {
    println "--> [Init] Creating automated Pipeline Job: ${jobName}..."
    try {
        def job = instance.createProject(WorkflowJob, jobName)
        def remoteConfigs = [new UserRemoteConfig(repoUrl, null, null, null)]
        def branches = [new BranchSpec(branchSpec)]
        def scm = new GitSCM(remoteConfigs, branches, false, Collections.emptyList(), null, null, Collections.emptyList())
        
        def definition = new CpsScmFlowDefinition(scm, scriptPath)
        definition.setLightweight(true)
        
        job.setDefinition(definition)
        job.setDescription("Automated CI/CD Pipeline for Demo Web Application on Kubernetes (K3s)")
        job.save()
        println "--> [Init] Pipeline Job '${jobName}' successfully created!"
    } catch (Exception e) {
        println "--> [Init] ERROR: Failed to create pipeline job '${jobName}': ${e.getMessage()}"
    }
} else {
    println "--> [Init] Pipeline Job '${jobName}' already exists. Skipping creation."
}
