# Jasonette Android App

## Local Verification

Android verification requires Java 17. CI provisions Temurin 17 with
`actions/setup-java@v4`, then runs the Gradle wrapper from this directory.

Recommended local checks:

```bash
java -version
cd JASONETTE-Android/JasonetteApp
./gradlew assembleDebug
./gradlew :app:testDebugUnitTest --tests 'com.jasonette.JsonValueConverterTest'
./gradlew test
```

The current local agent environment does not have a Java runtime installed as of
2026-05-26. In that environment, `java -version` and `/usr/libexec/java_home -V`
fail with:

```text
The operation couldn’t be completed. Unable to locate a Java Runtime.
Please visit http://www.java.com for information on installing Java.
```

Until Java 17 is provisioned locally, do not claim local Android Gradle
verification. Use the GitHub Actions `android` job as the source of truth and
record the exact run/job evidence in todos and handoff notes.

Recent CI evidence for the JSON conversion changes that motivated this note:

- Workflow: CI
- Run: <https://github.com/Bande-a-Bonnot/JASONETTE-Reborn/actions/runs/26445029969>
- Job: `android` / <https://github.com/Bande-a-Bonnot/JASONETTE-Reborn/actions/runs/26445029969/job/77849058307>
- Event/SHA: `push` on `main`, `4588389c0aaf0064cde27a666440338543ce0373`
- Result: success on 2026-05-26
- Scope: CI ran `./gradlew assembleDebug` and `./gradlew test` after provisioning
  Java 17; local Gradle verification remained blocked by the missing local Java
  runtime.
