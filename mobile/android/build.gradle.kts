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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// receive_sharing_intent 1.9.0 asks for compileSdk 37, but the SDK package for it is named "android-37.0", which
// the Android Gradle plugin does not find. The plugin builds fine against 36.
subprojects {
    if (name == "receive_sharing_intent") {
        afterEvaluate {
            extensions.configure<com.android.build.api.dsl.LibraryExtension> { compileSdk = 36 }
        }
    }
}
