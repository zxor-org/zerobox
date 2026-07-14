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
    if (name == "file_picker") {
        pluginManager.apply("org.jetbrains.kotlin.android")
    }
    if (name == "wasm_run_flutter") {
        pluginManager.withPlugin("com.android.library") {
            extensions.configure<com.android.build.api.dsl.LibraryExtension> {
                namespace = "com.example.wasm_run_flutter"
            }
        }
        afterEvaluate {
            extensions.findByType<com.android.build.api.dsl.LibraryExtension>()?.apply {
                compileSdk = 34
                defaultConfig {
                    minSdk = 21
                }
            }
        }
    }
    if (name == "quickjs_engine") {
        pluginManager.withPlugin("com.android.library") {
            extensions.configure<com.android.build.api.dsl.LibraryExtension> {
                compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_17
                    targetCompatibility = JavaVersion.VERSION_17
                }
                defaultConfig {
                    externalNativeBuild {
                        cmake {
                            arguments += "-DCMAKE_SHARED_LINKER_FLAGS=-llog"
                        }
                    }
                }
            }
        }
    }
    if (name == "mp_audio_stream") {
        afterEvaluate {
            extensions.findByType<com.android.build.api.dsl.LibraryExtension>()?.apply {
                // These published plugins still target API 31/33, but their
                // current AndroidX dependencies require compileSdk 34+.
                compileSdk = 34
                defaultConfig {
                    minSdk = 21
                }
            }
        }
    }
    if (name == "app" || name == "file_picker" || name == "quickjs_engine") {
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
