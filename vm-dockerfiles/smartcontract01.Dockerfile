# Source priority: helm_bak_20260318(dev-smartcontract image ci-jdk17) -> dockerfiles/jdk-dockerfile
FROM eclipse-temurin:17-jdk-jammy

USER root
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      git \
      curl \
      ca-certificates \
      bash \
      ssh-client \
      unzip && \
    rm -rf /var/lib/apt/lists/*

ENV GRADLE_VERSION=8.6
RUN curl -fsSL https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip -o /tmp/gradle.zip && \
    unzip /tmp/gradle.zip -d /opt && \
    ln -s /opt/gradle-${GRADLE_VERSION}/bin/gradle /usr/bin/gradle && \
    rm -f /tmp/gradle.zip

ENV MAVEN_VERSION=3.9.9
RUN curl -fsSL https://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz \
      | tar -xz -C /opt && \
    ln -s /opt/apache-maven-${MAVEN_VERSION}/bin/mvn /usr/bin/mvn

WORKDIR /workspace
EXPOSE 8080
CMD ["bash"]
