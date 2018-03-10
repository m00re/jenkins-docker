FROM jenkins/jenkins:2.89.4-alpine
MAINTAINER kontakt@jensmittag.de

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["jenkins"]
