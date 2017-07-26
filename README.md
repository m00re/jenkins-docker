# Jenkins-Docker

This is a Jenkins docker image based on Alpine Linux. It is an extension of the official Jenkins images
at https://hub.docker.com/_/jenkins/, and provides additional (security) configuration upon container start. 

## Configuration Features
- Creation of admin and normal users upon first boot
- Setting of slave port upon boot
- Setting the number of executors on master upon boot
- Installation of plugins upon boot
- Configuration of access permissions (on a per user basis using the matrix authorization plugin)
- Enabling of CSRF protection

Note: self-registration for new users is disabled by default.

## Building the Image

Simply type ```docker build . -t <yourtag>``` to build the image yourself.

## Using the (Prebuilt-)Images

I am providing pre-built images using the tags of ```m00re/jenkins-docker```, see https://hub.docker.com/r/m00re/jenkins-docker/ for a list of available image versions. The image uses the same configuration mechanism and options as described in the [official documentation](https://hub.docker.com/_/jenkins/).

In addition, the following configuration/environment variables are provided:
- ```JAVA_VM_PARAMETERS```: JVM startup parameters, e.g. ```-Xmx1024m -Xms512m```
- ```JENKINS_PARAMETERS```: additional Jenkins startup parameters
- ```JENKINS_MASTER_EXECUTORS```: the number of executors on this master node
- ```JENKINS_SLAVEPORT```: the listening port for slave connections
- ```JENKINS_PLUGINS```: a whitespace-separated list of Jenkins plugins to install upon boot. The image will always install the plugins ```matrix-auth build-timeout credentials-binding workflow-aggregator timestamper ws-cleanup swarm```.
- ```JENKINS_ADMIN_USER```: the login name of the initial admin user
- ```JENKINS_ADMIN_PASSWORD```: the password of the initial admin user
- ```JENKINS_KEYSTORE_PASSWORD```: optionally, you can set the password of the keystore file, if not specified, a random password is being generated and used.
- ```JENKINS_LOG_FILE```: optionally, you can define the destination of the Jenkins logs. If not set, the log will be written to standard/error output (which is the default).
- ```JENKINS_USER_NAMES```: a comma-separated list of users that shall be created upon first boot.
- ```JENKINS_USER_PASSWORDS```: a comma-separated list of passwords that shall be used for these users.
- ```JENKINS_USER_PERMISSIONS```: a comma-separated list of permissions that these users shall be granted. Each set of permissions is a double-point separated list of single permissions (e.g. ```hudson.model.Computer.CONNECT:hudson.model.Computer.DISCONNECT```)
- ```JENKINS_GROUP_NAMES```: a comma-separated list of groups that shall be created upon first boot (since 2.32.3).
- ```JENKINS_GROUP_PERMISSIONS```: a comma-separated list of permissions that these groups shall be granted. Each set of permissions is a double-point separated list of single permissions (since 2.32.3).

## Example ```docker-compose.yml```
```
version: '2'
services:
  jenkins:
    image: m00re/jenkins-docker:2.60.2-alpine
    container_name: jenkins
    hostname: jenkins
    ports:
     - "8080:8080"
    volumes:
      - jenkinsdata:/var/jenkins_home
    environment:
      - JAVA_VM_PARAMETERS=-Xmx1024m -Xms512m
      - JENKINS_PARAMETERS=
      - JENKINS_MASTER_EXECUTORS=0
      - JENKINS_SLAVEPORT=50000
      - JENKINS_PLUGINS=
      - JENKINS_ADMIN_USER=admin
      - JENKINS_ADMIN_PASSWORD=test
      - JENKINS_KEYSTORE_PASSWORD=
      - JENKINS_LOG_FILE=
      - JENKINS_USER_NAMES=slave
      - JENKINS_USER_PERMISSIONS=jenkins.model.Jenkins.READ:hudson.model.Computer.CONNECT:hudson.model.Computer.DISCONNECT:hudson.model.Computer.CREATE
      - JENKINS_USER_PASSWORDS=slave
```

## Acknowledgements

A huge thank you goes to [blacklabelops](https://github.com/blacklabelops/) for his Dockerfile recipes in https://github.com/blacklabelops/jenkins/. His scripts were a great starting point for the above image.
