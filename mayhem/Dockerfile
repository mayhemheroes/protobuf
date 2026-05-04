# Copyright 2021 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
################################################################################

FROM gcr.io/oss-fuzz-base/base-builder-jvm

RUN apt-get -o Acquire::Retries=5 update && apt-get -o Acquire::Retries=5 install -y make autoconf automake libtool pkg-config cmake

RUN curl -L https://archive.apache.org/dist/maven/maven-3/3.9.9/binaries/apache-maven-3.9.9-bin.zip -o maven.zip && unzip maven.zip -d $SRC/maven && rm -rf maven.zip

ENV MVN $SRC/maven/apache-maven-3.9.9/bin/mvn

RUN curl -L -O https://raw.githubusercontent.com/protobuf-c/protobuf-c/39cd58f5ff06048574ed5ce17ee602dc84006162/t/test-full.proto

COPY . protobuf
RUN rm -rf protobuf/mayhem

COPY mayhem/build.sh $SRC
COPY mayhem/ProtobufFuzzer.java $SRC

WORKDIR $SRC

ENV FUZZING_LANGUAGE=jvm SANITIZER=address FUZZING_ENGINE=libfuzzer
RUN compile
RUN chmod +x /out/jazzer_driver
