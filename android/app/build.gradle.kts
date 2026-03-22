plugins {
    id("com.android.application")

    id("com.google.gms.google-services")

    id("kotlin-android")

    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
        import java.io.FileInputStream

        android {

            namespace = "com.pavlo.smart_fridge"

            compileSdk = flutter.compileSdkVersion

            ndkVersion = flutter.ndkVersion


            // 🔥 FIX JVM VERSION
            compileOptions {

                isCoreLibraryDesugaringEnabled = true

                sourceCompatibility = JavaVersion.VERSION_11
                targetCompatibility = JavaVersion.VERSION_11
            }

            kotlinOptions {

                jvmTarget = "11"
            }


            val keystoreProperties = Properties()

            val keystorePropertiesFile = rootProject.file("key.properties")

            if (keystorePropertiesFile.exists()) {

                keystoreProperties.load(
                    FileInputStream(keystorePropertiesFile)
                )
            }


            defaultConfig {

                applicationId = "com.pavlo.smart_fridge"

                minSdk = flutter.minSdkVersion

                targetSdk = flutter.targetSdkVersion

                versionCode = flutter.versionCode

                versionName = flutter.versionName


                multiDexEnabled = true
            }


            signingConfigs {

                create("release") {

                    keyAlias =
                        keystoreProperties["keyAlias"] as String

                    keyPassword =
                        keystoreProperties["keyPassword"] as String

                    storeFile =
                        if (keystoreProperties["storeFile"] != null)

                            file(
                                keystoreProperties["storeFile"] as String
                            )

                        else null

                    storePassword =
                        keystoreProperties["storePassword"] as String
                }
            }


            buildTypes {

                release {

                    signingConfig =
                        signingConfigs.getByName("release")

                    isMinifyEnabled = false

                    isShrinkResources = false
                }
            }
        }


dependencies {

    implementation(
        "org.jetbrains.kotlin:kotlin-stdlib:1.9.24"
    )

    coreLibraryDesugaring(
        "com.android.tools:desugar_jdk_libs:2.1.5"
    )

    implementation(
        "androidx.multidex:multidex:2.0.1"
    )
}


flutter {

    source = "../.."
}