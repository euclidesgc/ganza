plugins {
    id("com.android.application")
    // Faltava no módulo `:app`, embora o `settings.gradle.kts` já declarasse a
    // versão com `apply false` e a linha 63 usasse o `kotlin { }` que só este
    // plugin registra. Sem ele, `android.builtInKotlin=false` deixa a extensão
    // sem dono e o Gradle aborta na configuração — nenhum build Android saía.
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "br.com.ganza.ganza"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "br.com.ganza.ganza"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        testInstrumentationRunner = "pl.leancode.patrol.PatrolJUnitRunner"
        testInstrumentationRunnerArguments["clearPackageData"] = "true"
    }

    // O template do Flutter desliga resValues por padrão; os flavors usam
    // resValue para o app_name aparecer diferente na gaveta.
    buildFeatures {
        resValues = true
    }

    // Dois flavors com applicationId distinto para dev e prod conviverem no
    // mesmo aparelho — sem isso, instalar o build de teste desinstala o que
    // está em uso de verdade.
    flavorDimensions += "ambiente"

    productFlavors {
        create("dev") {
            dimension = "ambiente"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
            resValue("string", "app_name", "Ganzá dev")
        }
        create("prod") {
            dimension = "ambiente"
            resValue("string", "app_name", "Ganzá")
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    testOptions {
        execution = "ANDROIDX_TEST_ORCHESTRATOR"
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    androidTestUtil("androidx.test:orchestrator:1.5.1")
}
