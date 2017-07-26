FROM jenkins:2.60.2-alpine
MAINTAINER kontakt@jensmittag.de

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
ENTRYPOINT ["/bin/tini", "--", "/usr/local/bin/docker-entrypoint.sh"]
CMD ["jenkins"]
