---
status: complete
priority: p3
issue_id: "048"
tags: [android, ci, cd, local-dev, java, gradle]
dependencies: []
---

# Add Java runtime support for local Android CI/CD verification

Completed: 2026-05-26

## Resolution

Documented the current local-agent limitation instead of installing Java in this
environment. `JASONETTE-Android/JasonetteApp/README.md` now states that Android
verification requires Java 17, lists the local Gradle commands, records that the
current agent environment lacks a Java runtime, and points to the GitHub Actions
`android` job as the source of truth until Java 17 is provisioned locally.

## Completion Evidence

Local environment check on 2026-05-26:

```bash
java -version
/usr/libexec/java_home -V
```

Both commands failed with `Unable to locate a Java Runtime`.

CI equivalent for the JSON conversion changes that motivated this todo:

- Workflow run: <https://github.com/Bande-a-Bonnot/JASONETTE-Reborn/actions/runs/26445029969>
- Android job: <https://github.com/Bande-a-Bonnot/JASONETTE-Reborn/actions/runs/26445029969/job/77849058307>
- Event/SHA: `push` on `main`, `4588389c0aaf0064cde27a666440338543ce0373`
- Result: success on 2026-05-26
- Scope: CI provisioned Java 17 and ran `./gradlew assembleDebug` plus
  `./gradlew test`. The targeted local `JsonValueConverterTest` command remains
  blocked locally until Java 17 is installed, but its test class is included in
  the successful CI `./gradlew test` run.

## Problem Statement

Android Gradle verification cannot currently be run in this local agent
environment because no Java runtime is installed. This blocks pre-push local
validation of Android CI/CD changes and forces reliance on GitHub Actions for
feedback.

## Evidence

During `todos/033` verification on 2026-05-26, the targeted Android unit test
command failed before Gradle could run:

```bash
cd JASONETTE-Android/JasonetteApp \
  && ./gradlew :app:testDebugUnitTest --tests 'com.jasonette.JsonValueConverterTest'
```

Result:

```text
The operation couldn’t be completed. Unable to locate a Java Runtime.
Please visit http://www.java.com for information on installing Java.
```

## Recommended Action

1. Install or provision a Java 17 runtime for local Android verification in the
   development/agent environment.
2. Document the expected Java runtime setup in the Android or CI/CD developer
   notes.
3. Re-run the Android verification commands that were blocked during
   `todos/033`:

   ```bash
   cd JASONETTE-Android/JasonetteApp
   ./gradlew :app:testDebugUnitTest --tests 'com.jasonette.JsonValueConverterTest'
   ./gradlew test
   ```

4. If local Java installation is intentionally out of scope for agents,
   document that Android changes rely on GitHub Actions as the source of truth
   and include the exact CI checks to monitor.

## Acceptance Criteria

- [x] A Java 17 runtime is available for local Android Gradle verification, or
      the lack of local Java is documented as an intentional limitation
- [x] Android CI/CD developer docs state the required Java/Gradle verification
      commands
- [x] The `JsonValueConverterTest` command from `todos/033` has been re-run
      successfully locally or verified in CI
- [x] Full Android tests (`./gradlew test`) have been run locally or their CI
      equivalent is linked as evidence

## Notes

This is related to CI/CD and developer-environment reliability, not app runtime
behavior. It matters because Android changes otherwise cannot be validated before
push from this environment.
