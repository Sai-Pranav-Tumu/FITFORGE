plugins {
  // ...

  // Add the dependency for the Google services Gradle plugin
  id("com.google.gms.google-services") version "4.4.2" apply false
  // Firebase Crashlytics Gradle plugin (uploads mapping files on release builds)
  id("com.google.firebase.crashlytics") version "3.0.2" apply false

}

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

// Pin every module's Kotlin JVM target to 17. Some plugins (e.g. tflite_flutter)
// leave Java at the AGP default (1.8) while Kotlin compiles to the JDK's version
// (21), which trips the "Inconsistent JVM-target" check and also risks dexing
// Java-21 class files. Forcing Kotlin to 17 keeps bytecode dex-safe; the
// `kotlin.jvm.target.validation.mode=warning` flag in gradle.properties downgrades
// any residual Java/Kotlin target gap from a build failure to a warning.
subprojects {
    tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile::class.java)
        .configureEach {
            compilerOptions {
                jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
            }
        }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
