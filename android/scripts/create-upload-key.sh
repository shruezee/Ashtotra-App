#!/bin/zsh
# Creates the Google Play *upload key* for Ashtotra and a local keystore.properties for Gradle.
# You type the password; it is stored only on this Mac. Back up the .jks file and password somewhere safe
# (e.g. a password manager). If lost, Google support can reset the upload key, but it takes days.
set -e
KEYDIR="$HOME/Keys"; KEYSTORE="$KEYDIR/shruezee-upload.jks"; ALIAS=upload
JAVA_HOME=$(ls -d ~/Library/Java/jdk-21*/Contents/Home 2>/dev/null | head -1); KEYTOOL="${JAVA_HOME:+$JAVA_HOME/bin/}keytool"
mkdir -p "$KEYDIR"; chmod 700 "$KEYDIR"
if [ -f "$KEYSTORE" ]; then echo "Upload key already exists at $KEYSTORE"; else
  echo "Choose a strong password (at least 8 characters). You'll type it twice."
  read -s "PASS?Password: "; echo; read -s "PASS2?Repeat password: "; echo
  [ "$PASS" = "$PASS2" ] || { echo "Passwords don't match."; exit 1; }
  "$KEYTOOL" -genkeypair -v -keystore "$KEYSTORE" -alias $ALIAS -keyalg RSA -keysize 4096 -validity 10000 \
    -storepass "$PASS" -keypass "$PASS" -dname "CN=Shruezee Studio, O=Shruezee Studio, L=Sydney, C=AU" >/dev/null
  chmod 600 "$KEYSTORE"
  printf "storeFile=%s\nstorePassword=%s\nkeyAlias=%s\nkeyPassword=%s\n" "$KEYSTORE" "$PASS" "$ALIAS" "$PASS" > "$(dirname "$0")/../keystore.properties"
  chmod 600 "$(dirname "$0")/../keystore.properties"
  echo "✅ Upload key created at $KEYSTORE"
fi
echo "Back up $KEYSTORE and your password now."
