set -euo pipefail
mkdir -p evidence
sudo mkdir -p /var/jenkins_home/init.groovy.d
sudo chown -R "$(id -u):$(id -g)" /var/jenkins_home
git clone "$GITHUB_WORKSPACE" /var/jenkins_home/lab-scm
git -C /var/jenkins_home/lab-scm config user.name 'Assignment 3 verification'
git -C /var/jenkins_home/lab-scm config user.email 'assignment-verification@example.invalid'
cat > /var/jenkins_home/init.groovy.d/lab.groovy <<'GROOVY'
import hudson.model.*
import hudson.plugins.git.GitSCM
import jenkins.model.Jenkins
import org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition
import org.jenkinsci.plugins.workflow.job.WorkflowJob

def job = Jenkins.get().createProject(WorkflowJob, 'cicd-assignment-FA23-BCT-021')
def definition = new CpsScmFlowDefinition(new GitSCM('file:///var/jenkins_home/lab-scm'), 'Jenkinsfile')
definition.setLightweight(false)
job.setDefinition(definition)
job.save()
GROOVY
docker build -t assignment-jenkins -f - . <<'DOCKER'
FROM docker:cli AS cli
FROM jenkins/jenkins:lts-jdk21
COPY --from=cli /usr/local/bin/docker /usr/local/bin/docker
COPY --from=cli /usr/local/libexec/docker/cli-plugins /usr/local/libexec/docker/cli-plugins
RUN jenkins-plugin-cli --plugins workflow-aggregator workflow-stage-view git github junit timestamper
DOCKER
docker run -d --name assignment-jenkins --network host --user root \
  -e 'JAVA_OPTS=-Djenkins.install.runSetupWizard=false -Dhudson.plugins.git.GitSCM.ALLOW_LOCAL_CHECKOUT=true' \
  -v /var/jenkins_home:/var/jenkins_home -v /var/run/docker.sock:/var/run/docker.sock assignment-jenkins --httpListenAddress=127.0.0.1
job=http://127.0.0.1:8080/job/cicd-assignment-FA23-BCT-021
for attempt in {1..90}; do
  if curl -fsS "$job/api/json" >/dev/null 2>&1; then break; fi
  sleep 2
done
crumb=$(curl -fsS -c /tmp/assignment-jenkins-cookie http://127.0.0.1:8080/crumbIssuer/api/json | jq -r '.crumbRequestField + ": " + .crumb')
capture() {
  google-chrome --headless --no-sandbox --disable-dev-shm-usage --hide-scrollbars --window-size=1500,1000 \
    --user-data-dir="$(mktemp -d)" --virtual-time-budget=10000 --screenshot="$PWD/evidence/$1.png" "$2" > /dev/null 2>&1
}
build() {
  local number=$1 expected=$2 result=
  curl -fsS -b /tmp/assignment-jenkins-cookie -H "$crumb" -X POST "$job/build" >/dev/null
  for attempt in {1..150}; do
    result=$(curl -fsS "$job/$number/api/json" 2>/dev/null | jq -r '.result // empty') || true
    if [[ -n "$result" ]]; then break; fi
    sleep 2
  done
  curl -fsS "$job/$number/consoleText" > "evidence/jenkins-build-$number.log"
  curl -fsS "$job/$number/wfapi/describe" > "evidence/jenkins-build-$number.json"
  curl -fsS "$job/$number/testReport/api/json" > "evidence/jenkins-tests-$number.json" || true
  printf 'Jenkins build %s result: %s\n' "$number" "$result"
  [[ "$result" == "$expected" ]]
}
cd "$GITHUB_WORKSPACE"
build 1 SUCCESS
curl -fsS http://127.0.0.1:8081 > /tmp/assignment-live-before.html
capture 02-jenkins-first-green "$job/"
sed -i 's/The cloud lab page is running./Intentional quality gate failure./' /var/jenkins_home/lab-scm/index.html
git -C /var/jenkins_home/lab-scm commit -am 'Demonstrate the deployment quality gate'
build 2 FAILURE
grep -F 'skipped due to earlier failure' evidence/jenkins-build-2.log
curl -fsS http://127.0.0.1:8081 > /tmp/assignment-live-after.html
cmp /tmp/assignment-live-before.html /tmp/assignment-live-after.html
sha256sum /tmp/assignment-live-before.html /tmp/assignment-live-after.html > evidence/live-site-integrity.txt
capture 03-jenkins-failed-deploy-skipped "$job/"
git -C /var/jenkins_home/lab-scm revert --no-edit HEAD
sed -i 's/· Lab Assignment 3/· Lab Assignment 3 · CI\/CD Demo/' /var/jenkins_home/lab-scm/index.html
git -C /var/jenkins_home/lab-scm commit -am 'Update the assignment page subtitle'
build 3 SUCCESS
capture 04-jenkins-three-builds "$job/"
capture 05-jenkins-test-result "$job/3/testReport/"
capture 06-jenkins-deployed-site http://127.0.0.1:8081
capture 07-jenkinsfile 'https://github.com/AhmadShabaan/cicd-assignment-FA23-BCT-021/blob/main/Jenkinsfile'
