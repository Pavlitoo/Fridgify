plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Імпорти для читання файлу ключів
import java.util.Properties
        import java.io.FileInputStream

        android {
            namespace = "com.pavlo.smart_fridge"
            compileSdk = flutter.compileSdkVersion
            ndkVersion = flutter.ndkVersion

            compileOptions {
                isCoreLibraryDesugaringEnabled = true
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }

            kotlinOptions {
                jvmTarget = JavaVersion.VERSION_17.toString()
            }

            // Завантажуємо дані з key.properties
            val keystoreProperties = Properties()
            val keystorePropertiesFile = rootProject.file("key.properties")
            if (keystorePropertiesFile.exists()) {
                keystoreProperties.load(FileInputStream(keystorePropertiesFile))
            }

            defaultConfig {
                // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
                applicationId = "com.pavlo.smart_fridge"
                // You can update the following values to match your application needs.
                // For more information, see: https://flutter.dev/to/review-gradle-config.
                minSdk = flutter.minSdkVersion
                targetSdk = flutter.targetSdkVersion
                versionCode = flutter.versionCode
                versionName = flutter.versionName

                // 🔥 ВАЖЛИВО: Вмикаємо Multidex (щоб не було помилок збірки)
                multiDexEnabled = true
            }

            signingConfigs {
                create("release") {
                    keyAlias = keystoreProperties["keyAlias"] as String
                    keyPassword = keystoreProperties["keyPassword"] as String
                    storeFile = if (keystoreProperties["storeFile"] != null) file(keystoreProperties["storeFile"] as String) else null
                    storePassword = keystoreProperties["storePassword"] as String
                }
            }

            buildTypes {
                release {
                    signingConfig = signingConfigs.getByName("release")
                    // Налаштування стиснення (для Flutter зазвичай false)
                    isMinifyEnabled = false
                    isShrinkResources = false
                }
            }

            dependencies {
                implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk7:1.8.22")
                coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")

                // 🔥 ВАЖЛИВО: Бібліотека Multidex
                implementation("androidx.multidex:multidex:2.0.1")
            }
        }

flutter {
    source = "../.."
}