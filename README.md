# Docker Multi-stage Build Example

Docker-multistage-example demonstrates how a Dockerfile can be converted into a multi-stage build.

Multi-stage builds are useful to anyone who needs to optimise Dockerfiles while keeping them easy to read and maintain.

This example will:
* convert `Dockerfile-orig` to a multi-stage Dockerfile
* optimise the Dockerfile for caching benefits
* import a cacert
* show that the Java truststore is in the final image

## Initial Dockerfile

The initial Dockerfile looks like this:

```Dockerfile
FROM openjdk:9-jdk-slim
COPY certificates /usr/local/share/ca-certificates/certificates
RUN apt-get update && apt-get install --no-install-recommends -y -qq ca-certificates-java && \
         update-ca-certificates
RUN groupadd --gid 1000 java &&\
    useradd --uid 1000 --gid java --shell /bin/bash --create-home java && \
    chmod -R a+w /home/java
WORKDIR /home/java
```

## Multi-stage Build Dockerfile

The production image is `java-multistage:latest` and can be built with the script `auto/package`.

The multi-stage build Dockerfile looks like this:

```Dockerfile
FROM openjdk:9-jdk-slim AS build
COPY certificates /usr/local/share/ca-certificates/certificates
RUN apt-get update && apt-get install --no-install-recommends -y -qq ca-certificates-java && \
  update-ca-certificates --verbose

FROM openjdk:9-jre-slim
COPY --from=build /etc/ssl/certs/java/cacerts /etc/ssl/certs/java/cacerts
RUN groupadd --gid 1000 java && \
  useradd --uid 1000 --gid java --shell /bin/bash --create-home java && \
  chmod -R a+w /home/java
WORKDIR /home/java
USER java
```

The certificate was copied to the folder `certificates` for the
`update-ca-certificates` command to add it to the truststore.

## Dockerfile Optimising

There are now multiple `FROM` statements in the Dockerfile. Each uses a different base.
The first uses `openjdk:9-jdk-slim` and the second `FROM` instruction starts with `openjdk:9-jre-slim` as its base.

Instead of building the final image with the JDK, we're using the JRE image because we don't need the JDK in the production image. If this example included an application it would have been built using the JDK base image.
The JRE image is sufficient to run the application with a significant reduction in image size.
In terms of size `openjdk:9-jdk-slim` is 374MB and `openjdk:9-jre-slim` is 286MB.

The original Dockerfile already has some optimisations, i.e., combining commands into one `RUN` instruction.
By not using separate `RUN` instructions for each command minimises the number of image layers created.
We've optimised by moving the `java` user creation to the production image.
The updated `cacerts` file from the build image is copied from the build image to the production image.
An additional certificate - `ca.crt` - was added to the truststore in the build image as this file is not needed in the production image.

The size and complexity of the production image could be reduced by choosing a smaller base image, like one based
on Alpine Linux.
Having less unneeded or unused files and binaries in the production image can mitigate security risks
when vulnerabilities are found.

## Testing the Java Truststore

To test that the Java truststore is in the production image and it contains the added `ca.crt`, a test script was written. Run `auto/test` to execute the test script.

For the purpose of this example the added certificate has an alias name of `debian:ca.pem`.
Using the alias the `keytool` command will output the SHA-256 fingerprint of the certificate.
The script then prints the SHA-256 fingerprint of the `cacert` used in the build image for manual verification.
This step could be improved by modifying the script to compare the SHA-256 fingerprints.

Output:

```BASH
$ auto/test

***** Press Enter at the password prompt *****
Enter keystore password:  

*****************  WARNING WARNING WARNING  *****************
* The integrity of the information stored in your keystore  *
* has NOT been verified!  In order to verify its integrity, *
* you must provide your keystore password.                  *
*****************  WARNING WARNING WARNING  *****************

debian:ca.pem, Apr 28, 2019, trustedCertEntry, 
Certificate fingerprint (SHA-256): 0C:25:8A:12:A5:67:4A:EF:25:F2:8B:A7:DC:FA:EC:EE:A3:48:E5:41:E6:F5:CC:4E:E6:3B:71:B3:61:60:6A:C3

***** It must match this fingerprint for the alias "debian:ca.pem" *****
Certificate fingerprint (SHA-256): 0C:25:8A:12:A5:67:4A:EF:25:F2:8B:A7:DC:FA:EC:EE:A3:48:E5:41:E6:F5:CC:4E:E6:3B:71:B3:61:60:6A:C3
```
