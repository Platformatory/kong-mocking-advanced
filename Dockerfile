FROM kong/kong:3.4.0-rhel
USER root
RUN yum install -y openssl-devel
USER kong
