#!groovy
import jenkins.model.Jenkins
import org.jenkinsci.plugins.workflow.multibranch.WorkflowMultiBranchProject
import jenkins.branch.BranchSource
import jenkins.plugins.git.GitSCMSource
import jenkins.plugins.git.traits.BranchDiscoveryTrait
import com.cloudbees.hudson.plugins.folder.computed.PeriodicFolderTrigger
import com.cloudbees.hudson.plugins.folder.computed.DefaultOrphanedItemStrategy

def instance = Jenkins.getInstanceOrNull()
def jobName = "demo-app-pipeline"
def gitRepoUrl = "https://github.com/k-ngn/devops-k8s.git"

if (instance != null) {
    def existingItem = instance.getItem(jobName)
    // If it exists but is not a WorkflowMultiBranchProject, recreate as Multibranch
    if (existingItem != null && !(existingItem instanceof WorkflowMultiBranchProject)) {
        println "--> [Init] Existing item '${jobName}' is not a Multibranch Pipeline. Recreating..."
        existingItem.delete()
        existingItem = null
    }

    if (existingItem == null) {
        println "--> [Init] Creating automated Multibranch Pipeline: ${jobName}..."
        try {
            def job = instance.createProject(WorkflowMultiBranchProject.class, jobName)
            job.setDescription("Automated Multibranch CI/CD Pipeline for Demo Web Application on Kubernetes (K3s)")

            // Configure Git SCM Source
            def gitSource = new GitSCMSource(gitRepoUrl)
            gitSource.setCredentialsId(null)
            gitSource.setTraits([
                new BranchDiscoveryTrait()
            ])

            job.setSourcesList([new BranchSource(gitSource)])

            // Retain up to 10 orphaned branch items for 7 days
            job.setOrphanedItemStrategy(new DefaultOrphanedItemStrategy(true, "7", "10"))

            // Periodic branch scanning trigger (every 2 minutes)
            job.addTrigger(new PeriodicFolderTrigger("2m"))

            job.save()
            println "--> [Init] Scheduling initial repository scan for '${jobName}'..."
            job.scheduleBuild2(0)
            println "--> [Init] Multibranch Pipeline '${jobName}' successfully created with Git SCM Source!"
        } catch (Exception e) {
            println "--> [Init] ERROR: Failed to create multibranch pipeline '${jobName}': ${e.getMessage()}"
        }
    } else {
        println "--> [Init] Multibranch Pipeline '${jobName}' already exists. Skipping creation."
    }
}

