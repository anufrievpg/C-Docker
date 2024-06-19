ARG BASE_IMAGE=eclipse-temurin:17
ARG AGENT_VERSION=1.3.3
FROM $BASE_IMAGE


LABEL maintainer="dc-deployments@atlassian.com"
LABEL securitytxt="https://www.atlassian.com/.well-known/security.txt"


ENV APP_NAME                                        confluence
ENV RUN_USER                                        confluence
ENV RUN_GROUP                                       confluence
ENV RUN_UID                                         2002
ENV RUN_GID                                         2002

# https://confluence.atlassian.com/doc/confluence-home-and-other-important-directories-590259707.html
ENV CONFLUENCE_HOME                                 /var/atlassian/application-data/confluence
ENV CONFLUENCE_INSTALL_DIR                          /opt/atlassian/confluence
ENV JAVA_OPTS="-javaagent:/opt/atlassian//confluence/atlassian-agent.jar ${JAVA_OPTS}"


ENV CONFLUENCE_LOG_STDOUT                           false


WORKDIR $CONFLUENCE_HOME


# Expose HTTP and Synchrony ports
EXPOSE 8090
EXPOSE 8091


CMD ["/usr/bin/python3", "/entrypoint.py"]
ENTRYPOINT ["/usr/bin/tini", "--"]


COPY entrypoint.py \
     shutdown-wait.sh \
     shared-components/image/entrypoint_helpers.py  /
COPY shared-components/support /opt/atlassian/support
COPY config/*                 /opt/atlassian/etc/


RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends fontconfig fonts-noto python3 python3-jinja2 tini \
    && apt-get clean autoclean && apt-get autoremove -y && rm -rf /var/lib/apt/lists/*




ARG CONFLUENCE_VERSION=8.5.4
ENV CONFLUENCE_VERSION                              ${CONFLUENCE_VERSION}
ARG DOWNLOAD_URL=https://product-downloads.atlassian.com/software/confluence/downloads/atlassian-confluence-${CONFLUENCE_VERSION}.tar.gz


COPY atlassian-agent.jar  /opt/atlassian/confluence/atlassian-agent.jar






RUN groupadd --gid ${RUN_GID} ${RUN_GROUP} \
    && useradd --uid ${RUN_UID} --gid ${RUN_GID} --home-dir ${CONFLUENCE_HOME} --shell /bin/bash ${RUN_USER} \
    && echo PATH=$PATH > /etc/environment \
    \
    && mkdir -p                                     ${CONFLUENCE_INSTALL_DIR} \
    && curl -L --silent                             ${DOWNLOAD_URL} | tar -xz --strip-components=1 -C "${CONFLUENCE_INSTALL_DIR}" \
    && chmod -R "u=rwX,g=rX,o=rX"                   ${CONFLUENCE_INSTALL_DIR}/ \
    && chown -R root.                               ${CONFLUENCE_INSTALL_DIR}/ \
    && chown -R ${RUN_USER}:${RUN_GROUP}            ${CONFLUENCE_INSTALL_DIR}/logs \
    && chown -R ${RUN_USER}:${RUN_GROUP}            ${CONFLUENCE_INSTALL_DIR}/temp \
    && chown -R ${RUN_USER}:${RUN_GROUP}            ${CONFLUENCE_INSTALL_DIR}/work \
    && chown -R ${RUN_USER}:${RUN_GROUP}            ${CONFLUENCE_HOME} \
    && for file in "/opt/atlassian/support /entrypoint.py /entrypoint_helpers.py /shutdown-wait.sh"; do \
       chmod -R "u=rwX,g=rX,o=rX" ${file} && \
       chown -R root ${file}; done \
    && sed -i -e 's/-Xms\([0-9]\+[kmg]\) -Xmx\([0-9]\+[kmg]\)/-Xms\${JVM_MINIMUM_MEMORY:=\1} -Xmx\${JVM_MAXIMUM_MEMORY:=\2} -Dconfluence.home=\${CONFLUENCE_HOME}/g' ${CONFLUENCE_INSTALL_DIR}/bin/setenv.sh \
    && sed -i -e 's/-XX:ReservedCodeCacheSize=\([0-9]\+[kmg]\)/-XX:ReservedCodeCacheSize=${JVM_RESERVED_CODE_CACHE_SIZE:=\1}/g' ${CONFLUENCE_INSTALL_DIR}/bin/setenv.sh \
    && sed -i -e 's/export CATALINA_OPTS/CATALINA_OPTS="\${CATALINA_OPTS} \${JVM_SUPPORT_RECOMMENDED_ARGS} -DConfluenceHomeLogAppender.disabled=${CONFLUENCE_LOG_STDOUT}"\n\nexport CATALINA_OPTS/g' ${CONFLUENCE_INSTALL_DIR}/bin/setenv.sh \
    \
    && mkdir -p /opt/java/openjdk/lib/fonts/fallback/ \
    && ln -sf /usr/share/fonts/truetype/noto/* /opt/java/openjdk/lib/fonts/fallback/


VOLUME ["${CONFLUENCE_HOME}"]





