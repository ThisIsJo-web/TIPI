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

subprojects {
    plugins.withId("com.android.library") {
        val androidExtension = project.extensions.findByName("android")
        if (androidExtension != null) {
            try {
                // Namespace injection
                val getNamespace = androidExtension.javaClass.getMethod("getNamespace")
                val setNamespace = androidExtension.javaClass.getMethod("setNamespace", String::class.java)
                if (getNamespace.invoke(androidExtension) == null) {
                    setNamespace.invoke(androidExtension, "com.example.tipi.${project.name.replace("-", "_")}")
                }
                
                // Align Java compile compatibility to 17
                val compileOptions = androidExtension.javaClass.getMethod("getCompileOptions").invoke(androidExtension)
                val setSource = compileOptions.javaClass.getMethod("setSourceCompatibility", org.gradle.api.JavaVersion::class.java)
                val setTarget = compileOptions.javaClass.getMethod("setTargetCompatibility", org.gradle.api.JavaVersion::class.java)
                setSource.invoke(compileOptions, org.gradle.api.JavaVersion.VERSION_17)
                setTarget.invoke(compileOptions, org.gradle.api.JavaVersion.VERSION_17)
            } catch (e: Exception) {
                // Ignore
            }
        }
    }
}

subprojects {
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
