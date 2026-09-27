# Bridge service. Build context is the REPO ROOT (see docker-compose.yml):
# the composite Gradle build needs the root settings.gradle plus vendor/megamek
# and vendor/mm-data (see docs/decisions.md #1, #5 and bridge/README.md).
FROM eclipse-temurin:21-jdk AS build
# See docs/decisions.md #11: vendor/mm-data has a non-ASCII file name that
# needs a UTF-8 locale to even be enumerated correctly by the JVM/Gradle.
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
WORKDIR /workspace
COPY settings.gradle gradlew ./
COPY gradle ./gradle
COPY bridge ./bridge
COPY vendor/megamek ./vendor/megamek
COPY vendor/mm-data ./vendor/mm-data

RUN --mount=type=cache,target=/root/.gradle \
    ./gradlew --no-daemon :bridge:installDist

FROM eclipse-temurin:21-jre AS runtime
WORKDIR /opt/bridge
COPY --from=build /workspace/bridge/build/install/bridge ./

EXPOSE 8080
ENTRYPOINT ["./bin/bridge"]
