# =====================================================================
# R8 / ProGuard keep kuralları
# ---------------------------------------------------------------------
# Release derlemesinde R8 sınıf isimlerini karartıyor. Yansıma (reflection)
# ile isimden bulunan sınıflar karartılınca çalışma zamanında bulunamıyor.
#
# Yaşanan somut çökme:
#   java.lang.RuntimeException: Unable to get provider
#       androidx.startup.InitializationProvider
#   Caused by: Failed to create an instance of androidx.work.impl.WorkDatabase
#
# Sebep: Room, üretilmiş `*_Impl` sınıfını Class.forName ile arıyor;
# R8 onu yeniden adlandırınca WorkManager veritabanını kuramıyor ve
# uygulama daha main() çalışmadan, süreç başlarken ölüyor.
# =====================================================================

# --- Room ------------------------------------------------------------
# Üretilmiş WorkDatabase_Impl gibi sınıfların adı korunmalı.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.room.** { *; }
-dontwarn androidx.room.paging.**

# --- WorkManager (google_mobile_ads üzerinden geliyor) ----------------
-keep class androidx.work.** { *; }
-keep class * extends androidx.work.ListenableWorker { <init>(...); }
-dontwarn androidx.work.**

# --- App Startup -----------------------------------------------------
# InitializationProvider, Initializer sınıflarını manifest meta-data'daki
# isimlerinden bulur.
-keep class androidx.startup.** { *; }
-keep class * implements androidx.startup.Initializer { *; }

# --- Google Play Services / Sign-In ----------------------------------
# İstemci kütüphaneleri model sınıflarını yansımayla kuruyor.
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# --- Google Mobile Ads -----------------------------------------------
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.ads.** { *; }

# --- Flutter ---------------------------------------------------------
# Flutter eklenti kaydı yansıma kullanıyor.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**
