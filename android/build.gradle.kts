allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// NOTE: the `telephony` package (SMS read/listen — core to this app,
// but unmaintained upstream since ~2021) shipped with several settings
// too old for the current Android Gradle Plugin/AndroidX to accept as
// hard errors (not just warnings). Attempting to patch these from this
// root build file via afterEvaluate/compileOptions proved unreliable —
// AGP finalizes those properties before external config can land in
// time. Patched directly in the package's own build.gradle instead:
//   %LOCALAPPDATA%\Pub\Cache\hosted\pub.dev\telephony-0.2.0\android\build.gradle
// Changes made there (reapply all four if this ever regresses after a
// `flutter pub cache repair` or fresh package reinstall wipes them,
// since that file lives in the shared pub cache, not this repo):
//   1. `namespace 'com.shounakmulay.telephony'` — AGP requires an
//      explicit namespace; this package never declared one.
//   2. `compileOptions { source/targetCompatibility JavaVersion.VERSION_17 }`
//      — was unset, defaulted inconsistently with its own Kotlin target.
//   3. `kotlinOptions { jvmTarget = "17" }` — was "1.8", mismatched (1).
//   4. `compileSdkVersion 36` — was 31; modern AndroidX transitive deps
//      (androidx.activity, androidx.window, androidx.core, etc.) require
//      compiling against API 33/34+, which AGP's checkDebugAarMetadata
//      task enforces as a hard failure, not a warning, on newer AGP.
//
// flutter_contacts's incremental-Kotlin-cache crash is worked around
// separately via `kotlin.incremental=false` in gradle.properties.

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
