@echo off
set JAVA_HOME=C:\Program Files\Android\Android Studio\jbr
set ANDROID_HOME=C:\AndroidSDK
set PATH=%PATH%;C:\flutter\bin;C:\AndroidSDK\platform-tools;C:\AndroidSDK\cmdline-tools\latest\bin

echo Accepting all Android SDK licenses...
echo y | flutter doctor --android-licenses
echo.
echo Done. Running flutter doctor to verify...
flutter doctor
pause
