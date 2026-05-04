#!/bin/bash -eu
# Build protoc using CMake (autotools no longer available in modern protobuf)
unset CFLAGS CXXFLAGS
mkdir -p $SRC/protobuf-build
cd $SRC/protobuf-build
cmake $SRC/protobuf \
    -Dprotobuf_BUILD_TESTS=OFF \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=$SRC/protobuf-install
make -j$(nproc) protoc
make install

export PROTOC="$SRC/protobuf-install/bin/protoc"

# Get protobuf version from pom.xml
PROTOBUF_VERSION=$(grep -m1 "<version>" $SRC/protobuf/java/pom.xml | sed "s/.*<version>\(.*\)<\/version>.*/\1/")
echo "Protobuf version: $PROTOBUF_VERSION"

# Download protobuf-java jar from Maven Central (avoids building pom.xml from templates)
curl -L -o $OUT/protobuf-java.jar \
  "https://repo1.maven.org/maven2/com/google/protobuf/protobuf-java/${PROTOBUF_VERSION}/protobuf-java-${PROTOBUF_VERSION}.jar"

# Compile test protos with protoc.
cd $SRC/
$PROTOC --java_out=. --proto_path=. test-full.proto
jar --create --file $OUT/test-full.jar foo/*

ALL_JARS="protobuf-java.jar test-full.jar"

# The classpath at build-time includes the project jars in $OUT as well as the
# Jazzer API.
BUILD_CLASSPATH=$(echo $ALL_JARS | xargs printf -- "$OUT/%s:"):$JAZZER_API_PATH

# All .jar and .class files lie in the same directory as the fuzzer at runtime.
RUNTIME_CLASSPATH=$(echo $ALL_JARS | xargs printf -- "\$this_dir/%s:"):\$this_dir

for fuzzer in $(find $SRC -name '*Fuzzer.java'); do
  fuzzer_basename=$(basename -s .java $fuzzer)
  javac -cp $BUILD_CLASSPATH $fuzzer
  cp $SRC/$fuzzer_basename.class $OUT/

  # Create an execution wrapper that executes Jazzer with the correct arguments.
  echo "#!/bin/sh
# LLVMFuzzerTestOneInput for fuzzer detection.
this_dir=\$(dirname \"\$0\")
LD_LIBRARY_PATH=\"$JVM_LD_LIBRARY_PATH\" \\
\$this_dir/jazzer_driver --agent_path=\$this_dir/jazzer_agent_deploy.jar \\
--cp=$RUNTIME_CLASSPATH \\
--target_class=$fuzzer_basename \\
--jvm_args=\"-Xmx2048m\" \\
\$@" > $OUT/$fuzzer_basename
  chmod +x $OUT/$fuzzer_basename
done
