# WorkManager and Room use reflection to instantiate their generated database.
# Without this, R8 removes WorkDatabase_Impl's no-arg constructor and the app
# crashes before Flutter starts.
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class * extends androidx.room.RoomDatabase { <init>(); }

# WorkManager instantiates workers by name at runtime.
-keep class * extends androidx.work.ListenableWorker {
    <init>(android.content.Context, androidx.work.WorkerParameters);
}
-keep class com.dw.scrobr.BackupWorker {
    <init>(android.content.Context, androidx.work.WorkerParameters);
}
