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

// إصلاح: بعض الحزم (مثل vosk_flutter_service) تُنشَر بـ compileSdk قديم (33) داخل ملف
// build.gradle الخاص بها هي نفسها. afterEvaluate هنا يُنفَّذ بعد اكتمال قراءة ملف تلك الحزمة
// بالكامل (بما فيه سطرها القديم compileSdkVersion 33)، فتُكتب قيمتنا 36 فوقها أخيرًا، لا العكس —
// بعكس المحاولة السابقة التي استخدمت plugins.withId ونُفِّذت قبل ذلك السطر فانمحت قيمتها.
//
// استبعاد ":app" صراحةً هو ما يمنع خطأ "Cannot run Project.afterEvaluate when the project is
// already evaluated" الذي ظهر سابقًا: evaluationDependsOn(":app") أدناه يُجبر كل حزمة فرعية أخرى
// على انتظار اكتمال تقييم ":app" أولًا، مما يجعل ":app" نفسه يُقيَّم بالكامل مبكرًا جدًا — فيصبح
// استدعاء afterEvaluate عليه لاحقًا غير قانوني. ":app" أصلًا لا يحتاج هذا الإصلاح، فاستبعاده آمن.
subprojects {
    if (project.name != "app") {
        afterEvaluate {
            extensions.findByType(com.android.build.gradle.BaseExtension::class.java)?.let { android ->
                android.compileSdkVersion(36)
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}