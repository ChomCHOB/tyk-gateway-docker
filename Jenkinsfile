def gitUrl = 'https://github.com/ChomCHOB/tyk-pump-docker'
def appName = 'ccif-one-repo-rule-infra'

build(
  job: '../bitbucket-infra/ccif-build-docker/master', 
  parameters: [
    // booleanParam(name: 'PUBLISH_TO_DOCKER_HUB', value: false), 
    // booleanParam(name: 'PUBLISH_LATEST', value: false), 
    string(name: 'GIT_URL', value: gitUrl), 
    string(name: 'GIT_BRANCH', value: gitBranch), 
    string(name: 'DOCKERFILE', value: 'Dockerfile'), 
  ]
)
