# MegaMek dedicated server, built from source (see docs/decisions.md #5 for why:
# in short, the only release tag available at the time this repo was written
# predates megamek.client.HeadlessClient, so the bridge's vendor/megamek pin and
# this server image must be the exact same commit or SERVER_VERSION_CHECK
# rejects the bridge's connection). Build context is the REPO ROOT, not this
# directory, because it needs both vendor/megamek and vendor/mm-data
# (see docker-compose.yml).
FROM eclipse-temurin:21-jdk AS build
WORKDIR /workspace

# mm-data must be a sibling of megamek-repo: vendor/megamek/settings.gradle
# does includeBuild('../mm-data').
COPY vendor/megamek ./megamek-repo
COPY vendor/mm-data ./mm-data

# mm-data ships at least one non-ASCII (UTF-8) file name
# (data/images/units/meks/Götterdämmerung.png). Without a UTF-8 locale, the
# JVM's sun.jnu.encoding falls back to ASCII and Gradle can't even hash the
# file ("No such file or directory") - hit and confirmed during development
# in a POSIX-locale container; see docs/decisions.md.
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

WORKDIR /workspace/megamek-repo
# installDist (from the Gradle 'application' plugin) only packages bin/+lib/;
# it does NOT stage data/ (that only happens for MegaMek's own custom
# distZip/distTar/createExe tasks or `gradle run`). We need the real data
# (maps, unit definitions, from mm-data) for a playable server, so stage it
# explicitly - see docs/decisions.md #5/#10.
RUN --mount=type=cache,target=/root/.gradle \
    ./gradlew --no-daemon :megamek:stageDataFiles :megamek:installDist

FROM eclipse-temurin:21-jre AS runtime
WORKDIR /opt/megamek
# Gradle's 'application' plugin names the dist dir after applicationName
# ('MegaMek'), but the launch script inside it is lowercase ('bin/megamek').
COPY --from=build /workspace/megamek-repo/megamek/build/install/MegaMek ./
COPY --from=build /workspace/megamek-repo/megamek/data ./data
COPY --from=build /workspace/megamek-repo/megamek/mmconf ./mmconf

# -Djava.awt.headless: no display in the container, and MegaMek's own main()
#   touches a couple of Swing utility classes before it even looks at -dedicated.
# -Dsentry.dsn=: disables the crash-telemetry SDK MegaMek initializes
#   unconditionally in MegaMek.main(); we don't want a home-server's dedicated
#   server phoning home by default.
ENV JAVA_TOOL_OPTIONS="-Djava.awt.headless=true -Dsentry.dsn="

EXPOSE 2346
ENTRYPOINT ["./bin/megamek"]
CMD ["-dedicated", "-port", "2346"]
