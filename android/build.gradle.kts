import com.android.build.gradle.BaseExtension
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

// 👇 Підключення Google Services / Firebase
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.4.1")
    }
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

// 🔥 КРОК 1: РОЗДАЄМО ПРАВИЛА ДО СТАРТУ
subprojects {
    project.afterEvaluate {
        val androidExt = project.extensions.findByName("android") as? BaseExtension
        if (androidExt != null) {
            // Лікуємо старий image_gallery_saver
            if (androidExt.namespace == null) {
                androidExt.namespace = "com.example." + project.name.replace("-", "_")
            }
            // Лікуємо конфлікт Java (ставимо всім 11 версію)
            androidExt.compileOptions {
                sourceCompatibility = JavaVersion.VERSION_11
                targetCompatibility = JavaVersion.VERSION_11
            }
        }
    }

    // Лікуємо конфлікт Kotlin (ставимо всім 11 версію)
    tasks.withType<KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(JvmTarget.JVM_11)
        }
    }
}

// 🔥 КРОК 2: ТІЛЬКИ ТЕПЕР ДАЄМО КОМАНДУ ЗБИРАТИ
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}