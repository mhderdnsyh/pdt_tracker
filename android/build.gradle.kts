buildscript {
    repositories {
        google()
        mavenCentral()
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    plugins.withId("com.android.library") {
        val android = project.extensions.findByName("android")
        if (android != null) {
            try {
                val getNamespace = android.javaClass.getMethod("getNamespace")
                val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)
                if (getNamespace.invoke(android) == null) {
                    val manifestFile = project.file("src/main/AndroidManifest.xml")
                    if (manifestFile.exists()) {
                        val manifestText = manifestFile.readText()
                        val match = Regex("package=\"([^\"]+)\"").find(manifestText)
                        if (match != null) {
                            setNamespace.invoke(android, match.groupValues[1])
                        } else {
                            setNamespace.invoke(android, "com.example.${project.name.replace('-', '_')}")
                        }
                    } else {
                        setNamespace.invoke(android, "com.example.${project.name.replace('-', '_')}")
                    }
                }
            } catch (_: Exception) {}
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
