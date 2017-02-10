# Jenkins-With-Docker

This is a Jenkins docker image with Docker tools pre-installed. It is based on the official Jenkins images
at https://hub.docker.com/_/jenkins/, in particular the ```alpine``` based images. This image allows to run docker commands on the Jenkins host, which is essential if you want to use the [docker-workflow-plugin](https://github.com/jenkinsci/docker-workflow-plugin).

## Building the Image

Simply type ```docker build . -t <yourtag>``` to build the image.

## Using the (Prebuilt-)Images

The image uses the same configuration mechanism and options as described in the [official documentation](https://hub.docker.com/_/jenkins/).

To be able to use Docker from inside of this image, make sure that you also bind ```/var/run/docker.sock``` inside the image:

```
docker run -p 8080:8080 -v /home/jenkins:/var/jenkins_home -v /var/run/docker.sock:/var/run/docker.sock m00re/jenkins-with-docker:2.32.2-alpine
```

I am providing pre-built images using the tags of ```m00re/jenkins-with-docker```, see https://hub.docker.com/r/m00re/jenkins-with-docker/ for the list of available image versions.
