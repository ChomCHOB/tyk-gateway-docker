def gitUrl = 'https://github.com/ChomCHOB/tyk-gateway-docker'
def gitBranch = 'master'

def label = "pod.${env.JOB_NAME}".replace('-', '_').replace('/', '_').take(55) + ".${env.BUILD_NUMBER}"

podTemplate(
  label: label,
) {
node(label) {
  stage('build docker image') {
    def buildParameters = [
      booleanParam(name: 'PUBLISH_TO_DOCKER_HUB', value: true), 
      // booleanParam(name: 'PUBLISH_LATEST', value: true), 
      string(name: 'GIT_URL', value: gitUrl), 
      string(name: 'GIT_BRANCH', value: gitBranch), 
      string(name: 'DOCKERFILE', value: 'Dockerfile')
    ]

    // build
    build(
      job: '../../bitbucket-infra/ccinfra-build-docker/master', 
      parameters: buildParameters
    )
  }
}
}