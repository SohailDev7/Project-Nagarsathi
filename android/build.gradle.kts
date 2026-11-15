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

// Some plugins (e.g. open_filex) declare compileSdk 34, which is not installed
// on this machine and Gradle's auto-install cannot fetch it. Compile them
// against the SDK the app itself uses instead. Newer SDKs are backwards
// compatible for compilation, so this is safe. This has to run before the
// Android plugin finalizes its DSL, so it is registered before the
// evaluationDependsOn block below forces project evaluation.
subprojects {
    afterEvaluate {
        val android = extensions.findByName("android") ?: return@afterEvaluate
        val declared = runCatching {
            android.javaClass.getMethod("getCompileSdkVersion").invoke(android) as? String
        }.getOrNull()
        val level = declared?.substringAfterLast('-')?.toIntOrNull()
        if (level == null || level >= 36) return@afterEvaluate

        val setter = android.javaClass.methods.firstOrNull {
            it.name == "setCompileSdkVersion" && it.parameterCount == 1
        } ?: return@afterEvaluate
        val argument: Any = when (setter.parameterTypes[0]) {
            Int::class.javaPrimitiveType, Integer::class.java -> 36
            else -> "android-36"
        }
        runCatching { setter.invoke(android, argument) }
            .onSuccess {
                logger.lifecycle("Bumped $name compileSdk from $declared to 36")
            }
            .onFailure {
                logger.warn("Could not bump $name compileSdk: ${it.cause ?: it}")
            }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
