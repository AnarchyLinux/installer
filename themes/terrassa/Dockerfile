FROM nginx
ARG EXPOSE=80
EXPOSE ${EXPOSE}/tcp
EXPOSE ${EXPOSE}/udp
ARG HUGO_SITE=exampleSite
COPY /${HUGO_SITE}/public/ /usr/share/nginx/html/