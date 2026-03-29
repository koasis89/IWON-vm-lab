#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
RELEASE_DIR="$ROOT/release"

WAS_DIR="${WAS_SOURCE_DIR:-$ROOT/services/was}"
APP_DIR="${APP_SOURCE_DIR:-$ROOT/services/app}"
INT_DIR="${INTEGRATION_SOURCE_DIR:-$ROOT/services/integration}"
WEB_DIR="${WEB_SOURCE_DIR:-$ROOT/web}"

mkdir -p "$RELEASE_DIR/was" "$RELEASE_DIR/app" "$RELEASE_DIR/integration" "$RELEASE_DIR/web"

build_java_module() {
  local module_dir="$1"
  local out_file="$2"

  if [ ! -d "$module_dir" ]; then
    echo "ERROR: module directory not found: $module_dir"
    return 1
  fi

  pushd "$module_dir" >/dev/null

  if [ -f "./gradlew" ]; then
    chmod +x ./gradlew
    ./gradlew clean build -x test
  elif [ -f "./mvnw" ]; then
    chmod +x ./mvnw
    ./mvnw -B -DskipTests package
  elif [ -f "./pom.xml" ]; then
    mvn -B -DskipTests package
  else
    echo "ERROR: cannot detect Java build tool in $module_dir"
    popd >/dev/null
    return 1
  fi

  jar_path="$(ls build/libs/*.jar 2>/dev/null | head -n1 || true)"
  if [ -z "$jar_path" ]; then
    jar_path="$(ls target/*.jar 2>/dev/null | head -n1 || true)"
  fi

  if [ -z "$jar_path" ]; then
    echo "ERROR: jar not found in $module_dir (build/libs or target)"
    popd >/dev/null
    return 1
  fi

  cp "$jar_path" "$out_file"
  popd >/dev/null
}

build_java_module "$WAS_DIR" "$RELEASE_DIR/was/app.jar"
build_java_module "$APP_DIR" "$RELEASE_DIR/app/app.jar"
build_java_module "$INT_DIR" "$RELEASE_DIR/integration/app.jar"

if [ ! -d "$WEB_DIR" ]; then
  echo "ERROR: web source directory not found: $WEB_DIR"
  exit 1
fi

pushd "$WEB_DIR" >/dev/null
if [ -f "package-lock.json" ]; then
  npm ci
else
  npm install
fi
npm run build

if [ -d "dist" ]; then
  zip -rq "$RELEASE_DIR/web/html.zip" dist
elif [ -d "build" ]; then
  zip -rq "$RELEASE_DIR/web/html.zip" build
else
  echo "ERROR: web build output not found (dist or build)"
  popd >/dev/null
  exit 1
fi
popd >/dev/null

echo "Build complete"
ls -al "$RELEASE_DIR/was/app.jar" "$RELEASE_DIR/app/app.jar" "$RELEASE_DIR/integration/app.jar" "$RELEASE_DIR/web/html.zip"
