# Regles de reduction pour la compilation de production (EXI-SEC09).

# Flutter / plugins
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# drift / sqlite3 : chargement natif par reflexion
-keep class com.google.android.gms.** { *; }
-dontwarn org.sqlite.**

# flutter_secure_storage : Keystore (EXI-SEC03)
-keep class androidx.security.crypto.** { *; }

# Ne jamais conserver les numeros de ligne d'origine sans le fichier source
# associe : les symboles partent au service de diagnostic (§16.3), pas dans l'APK.
-renamesourcefileattribute SourceFile
-keepattributes SourceFile,LineNumberTable

# --- Play Core : composants differes ---------------------------------------
#
# L'embarqueur Flutter reference `SplitCompatApplication` et le gestionnaire de
# composants differes, mais MajiChrono n'utilise pas les « deferred components »
# et ne depend donc pas de Play Core. R8 refusait de compiler faute de trouver
# ces classes — la compilation de production echouait entierement.
#
# Ajouter la dependance Play Core aurait alourdi l'APK pour du code jamais
# execute (EXI-P03 : moins de 25 Mo). On indique donc a R8 que ces absences
# sont attendues.
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.android.FlutterPlayStoreSplitApplication
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
