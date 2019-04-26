FROM openjdk:9-jdk-slim AS build
COPY certificates /usr/local/share/ca-certificates/certificates
RUN apt-get update && apt-get install --no-install-recommends -y -qq ca-certificates-java && \
  update-ca-certificates --verbose && \
  keytool -noprompt -cacerts -storepass changeit -importcert -alias multistage -file /usr/local/share/ca-certificates/certificates

FROM openjdk:9-jre-slim
COPY --from=build /etc/ssl/certs/java/cacerts /etc/ssl/certs/java/cacerts
RUN groupadd --gid 1000 java && \
  useradd --uid 1000 --gid java --shell /bin/bash --create-home java && \
  chmod -R a+w /home/java
WORKDIR /home/java
