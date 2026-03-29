#!/bin/bash -eu
# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
################################################################################

TLATOOLS_DIR="$SRC/tlaplus/tlatools/org.lamport.tlatools"
FUZZER_SRC_DIR="$SRC/tlaplus/tlatools/org.lamport.tlatools/src/fuzz_targets"

cd "$TLATOOLS_DIR"
ant -f customBuild.xml compile compile-test dist
rm -rf "TLA+ Tools/"

# find "$TLATOOLS_DIR/class" -type f -name '*.tla' -exec cp {} "$OUT/" \;
cp "$TLATOOLS_DIR/dist/tla2tools.jar" "$OUT/tla2tools.jar"

PROJECT_JARS="tla2tools.jar"
RUNTIME_CLASSPATH=$(echo $PROJECT_JARS | xargs printf -- "\$this_dir/%s:"):\$this_dir
BUILD_CLASSPATH=$(echo $PROJECT_JARS | xargs printf -- "$OUT/%s:"):$JAZZER_API_PATH

# seed corpuses
CORPUS_DIR="$FUZZER_SRC_DIR/tla2sany_corpus"
if [[ ! -d "$CORPUS_DIR" ]]; then
  echo "Expected corpus directory not found: $CORPUS_DIR" >&2
  exit 1
fi
(cd "$CORPUS_DIR" && zip -r "$OUT/FuzzSanyParse_seed_corpus.zip" .)

CORPUS_DIR="$FUZZER_SRC_DIR/pcal_corpus"
if [[ ! -d "$CORPUS_DIR" ]]; then
  echo "Expected corpus directory not found: $CORPUS_DIR" >&2
  exit 1
fi
(cd "$CORPUS_DIR" && zip -r "$OUT/FuzzPcalTranslate_seed_corpus.zip" .)

CORPUS_DIR="$FUZZER_SRC_DIR/tlc_corpus"
if [[ ! -d "$CORPUS_DIR" ]]; then
  echo "Expected corpus directory not found: $CORPUS_DIR" >&2
  exit 1
fi
(cd "$CORPUS_DIR" && zip -r "$OUT/FuzzTLCSimulate_seed_corpus.zip" .)

# dictionaries
cp "$FUZZER_SRC_DIR/tlaplus.dict" "$OUT/FuzzSanyParse.dict"
cp "$FUZZER_SRC_DIR/tlaplus.dict" "$OUT/FuzzTLCSimulate.dict"
cp "$FUZZER_SRC_DIR/pluscal.dict" "$OUT/FuzzPcalTranslate.dict"

# fuzz target binaries
for fuzzer in $(find $FUZZER_SRC_DIR -name 'Fuzz*.java'); do
  fuzzer_basename=$(basename -s .java $fuzzer)
  # javac -cp $BUILD_CLASSPATH $fuzzer
  # cp $TLATOOLS_DIR/class/fuzz_targets/$fuzzer_basename.class $OUT/

  echo "#!/bin/bash
# LLVMFuzzerTestOneInput for fuzzer detection.
this_dir=\$(dirname \"\$0\")
if [[ \"\$@\" =~ (^| )-runs=[0-9]+($| ) ]]; then
  mem_settings='-Xmx1900m:-Xss900k'
else
  mem_settings='-Xmx2048m:-Xss1024k'
fi
LD_LIBRARY_PATH=\"$JVM_LD_LIBRARY_PATH\":\$this_dir \
\$this_dir/jazzer_driver --agent_path=\$this_dir/jazzer_agent_deploy.jar \
--cp=$RUNTIME_CLASSPATH \
--target_class=fuzz_targets.$fuzzer_basename \
--jvm_args=\"\$mem_settings:-Djava.awt.headless=true\" \
\$@" > $OUT/$fuzzer_basename
  chmod +x $OUT/$fuzzer_basename
done

