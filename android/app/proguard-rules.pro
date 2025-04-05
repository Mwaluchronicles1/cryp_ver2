# Keep annotations that R8 needs
-keep class com.google.errorprone.annotations.** { *; }
-keep class javax.annotation.** { *; }
-keep class javax.annotation.concurrent.** { *; }

# Keep crypto classes
-keep class com.google.crypto.tink.** { *; }

# Keep file_picker implementation
-keep class com.mr.flutter.plugin.filepicker.** { *; }

# For more detailed configuration, you can use the missing_rules.txt that R8 generates
# but these rules should handle the current errors 