plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 👇 1. Додаємо імпорти, щоб читати файл ключів
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

            // 👇 2. Завантажуємо дані з key.properties
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
            }

            // 👇 3. Створюємо конфігурацію підпису (Release)
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
                    // 👇 4. Підключаємо створений підпис
                    signingConfig = signingConfigs.getByName("release")
                    // Налаштування стиснення (для Flutter зазвичай false)
                    isMinifyEnabled = false
                    isShrinkResources = false
                }
            }

            dependencies {
                implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk7:1.8.22")
                coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
            }
        }

flutter {
    source = "../.."
}