#!/bin/zsh
set -euo pipefail
PROJECT_DIR="${0:A:h:h}"
cd "$PROJECT_DIR"
mkdir -p tools/downloads tools/src tools/bin .build/tmp
SOURCE_FILE=tools/downloads/ffmpeg-8.0.1.tar.xz
if [[ ! -f "$SOURCE_FILE" ]]; then
  /usr/bin/curl -fL --retry 2 https://ffmpeg.org/releases/ffmpeg-8.0.1.tar.xz -o "$SOURCE_FILE"
fi
SOURCE_SHA=$(/usr/bin/shasum -a 256 "$SOURCE_FILE")
[[ "${SOURCE_SHA%% *}" == 05ee0b03119b45c0bdb4df654b96802e909e0a752f72e4fe3794f487229e5a41 ]] || { print 'SHA-256 inesperado'; exit 1; }
if [[ ! -d tools/src/ffmpeg-8.0.1 ]]; then /usr/bin/tar -xf "$SOURCE_FILE" -C tools/src; fi
cd tools/src/ffmpeg-8.0.1
# Relative temporary paths avoid FFmpeg configure's whitespace limitation.
export TMPDIR=../../../.build/tmp
if [[ -f ffbuild/config.mak ]]; then
  /usr/bin/make distclean > '../../../.build/ffmpeg-clean.log' 2>&1
fi
./configure --prefix=../../../tools --disable-everything --disable-autodetect --disable-network --disable-doc \
  --disable-debug --enable-small --enable-shared --disable-static --disable-avdevice \
  --enable-ffmpeg --enable-ffprobe --enable-videotoolbox --install-name-dir=@rpath \
  --enable-decoder=vp9,opus,vorbis,h264,aac --enable-parser=vp9,opus,vorbis,h264,aac \
  --enable-demuxer=matroska,mov --enable-protocol=file,pipe \
  --enable-encoder=h264_videotoolbox,aac,wrapped_avframe,pcm_s16le --enable-muxer=mp4,mov,null \
  --enable-filter=scale,format,aresample,aformat,vflip,null,anull --cc=/usr/bin/clang \
  --extra-cflags=-mmacosx-version-min=13.0 \
  --extra-ldflags='-mmacosx-version-min=13.0 -Wl,-dead_strip -Wl,-rpath,@executable_path/lib' \
  > '../../../.build/ffmpeg-configure.log' 2>&1
/usr/bin/make -j6 > '../../../.build/ffmpeg-build.log' 2>&1
# Keep one shared copy of the codec libraries for both commands. Stage and test
# the complete runtime before replacing the tools used by the app and fixtures.
RUNTIME_DIR=../../../.build/ffmpeg-runtime
rm -rf "$RUNTIME_DIR"
mkdir -p "$RUNTIME_DIR/lib"
cp ffmpeg ffprobe "$RUNTIME_DIR/"
for library in libavutil libavcodec libavformat libavfilter libswscale libswresample; do
  for dylib in "$library"/*.dylib; do
    # The real files have the full version in their name; install the major name
    # recorded in LC_ID_DYLIB without adding redundant copies or symlinks.
    [[ -L "$dylib" ]] && continue
    library_id=$(/usr/bin/otool -D "$dylib" | /usr/bin/tail -1)
    cp "$dylib" "$RUNTIME_DIR/lib/${library_id##*/}"
  done
done
for executable in "$RUNTIME_DIR"/lib/*.dylib "$RUNTIME_DIR/ffmpeg" "$RUNTIME_DIR/ffprobe"; do
  /usr/bin/strip -S -x "$executable"
  /usr/bin/codesign --force --sign - "$executable"
done
"$RUNTIME_DIR/ffmpeg" -version > /dev/null
"$RUNTIME_DIR/ffprobe" -version > /dev/null
mkdir -p ../../bin/lib
cp "$RUNTIME_DIR"/lib/*.dylib ../../bin/lib/
cp "$RUNTIME_DIR/ffmpeg" "$RUNTIME_DIR/ffprobe" ../../bin/
rm -rf "$RUNTIME_DIR"
/usr/bin/make clean > '../../../.build/ffmpeg-clean.log' 2>&1
print 'FFmpeg y FFprobe compactos, con bibliotecas compartidas locales.'
