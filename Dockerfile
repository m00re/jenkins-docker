FROM jenkins:2.32.2-alpine
MAINTAINER kontakt@jensmittag.de

USER root
RUN apk add --no-cache docker
USER ${user}
