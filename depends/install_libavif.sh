#!/usr/bin/env bash
set -eo pipefail

if [ $(uname) != "Darwin" ]; then
    TRAVIS_OS_NAME="manylinux$MB_ML_VER"
fi

SVT_AV1_VERSION=0.8.6
LIBAVIF_CMAKE_FLAGS=()

if uname -s | grep -q Darwin; then
    PREFIX=/usr/local
else
    PREFIX=/usr
fi

PKGCONFIG=${PKGCONFIG:-pkg-config}

export CFLAGS="-fPIC -O3 $CFLAGS"
export CXXFLAGS="-fPIC -O3 $CXXFLAGS"

echo "::group::Fetching libavif"
mkdir -p libavif-$LIBAVIF_VERSION
curl -sLo - \
    https://github.com/AOMediaCodec/libavif/archive/v$LIBAVIF_VERSION.tar.gz \
    | tar --strip-components=1 -C libavif-$LIBAVIF_VERSION -zxf -
pushd libavif-$LIBAVIF_VERSION
echo "::endgroup::"

if $PKGCONFIG --exists aom; then
    LIBAVIF_CMAKE_FLAGS+=(-DAVIF_CODEC_AOM=ON)
else
    echo "::group::Building aom"
    pushd ext > /dev/null
    bash aom.cmd
    popd > /dev/null
    LIBAVIF_CMAKE_FLAGS+=(-DAVIF_CODEC_AOM=ON -DAVIF_LOCAL_AOM=ON)
    echo "::endgroup::"
fi

if $PKGCONFIG --exists dav1d; then
    LIBAVIF_CMAKE_FLAGS+=(-DAVIF_CODEC_DAV1D=ON)
fi

if $PKGCONFIG --exists rav1e; then
    LIBAVIF_CMAKE_FLAGS+=(-DAVIF_CODEC_RAV1E=ON)
fi

if $PKGCONFIG --exists SvtAv1Enc; then
    LIBAVIF_CMAKE_FLAGS+=(-DAVIF_CODEC_SVT=ON)
fi

if $PKGCONFIG --exists libgav1; then
    LIBAVIF_CMAKE_FLAGS+=(-DAVIF_CODEC_LIBGAV1=ON)
fi

# pushd ext > /dev/null
#
# echo "::group::Building aom"
# if [ "$TRAVIS_OS_NAME" == "manylinux1" ]; then
#     # Patch for old perl and gcc on manylinux1
#     if [ ! -e aom ]; then
#         git clone -b v2.0.2 --depth 1 https://aomedia.googlesource.com/aom
#     fi
#     (cd aom && patch -p1 < ../../../aom-fixes-for-building-on-manylinux1.patch)
# fi
# bash aom.cmd
# LIBAVIF_CMAKE_FLAGS+=(-DAVIF_CODEC_AOM=ON -DAVIF_LOCAL_AOM=ON)
# echo "::endgroup::"
#
# if which cargo 1>/dev/null 2>/dev/null; then
#     echo "::group::Installing rav1e"
#
#     PATH="$HOME/.cargo/bin:$PATH"
#
#     if ! which cargo-cbuild 1>/dev/null 2>/dev/null; then
#         if [ $(uname) == "Darwin" ]; then
#             CARGO_C_TGZ=https://github.com/lu-zero/cargo-c/releases/download/v0.8.0/cargo-c-macos.zip
#             TAR=bsdtar
#         else
#             CARGO_C_TGZ=https://github.com/lu-zero/cargo-c/releases/download/v0.8.0/cargo-c-linux.tar.gz
#             TAR=tar
#         fi
#         curl -sLo - $CARGO_C_TGZ  | $TAR -C $HOME/.cargo/bin -zxf -
#     fi
#
#     if [ ! -d rav1e ]; then
#         mkdir rav1e
#         curl -sLo - \
#             https://github.com/xiph/rav1e/archive/refs/tags/v0.4.0.tar.gz \
#             | tar --strip-components=1 -C rav1e -zxf -
#     fi
#
#     (cd rav1e && patch -t -N -p0 -i ../../../rav1e-0.4.0-fix-build.patch ||:)
#
#     perl -pi -e 's/^(cargo install cargo-c)$/\# $1/g' rav1e.cmd
#     bash rav1e.cmd
#
#     # Check if cargo-c saved build files to a host-specific target directory,
#     # and if so copy the files to the location where libavif expects them to be
#     RUST_HOST=$(rustc -vV | perl -ne 'print "$1\n" if /^host: (.+)$/')
#     if [ -n "$RUST_HOST" ]; then
#         if [ -e rav1e/target/$RUST_HOST/release/rav1e.h ]; then
#             cp -a rav1e/target/$RUST_HOST/release rav1e/target
#         fi
#     fi
#
#     LIBAVIF_CMAKE_FLAGS+=(-DAVIF_CODEC_RAV1E=ON -DAVIF_LOCAL_RAV1E=ON)
#     echo "::endgroup::"
# fi
#
# if [ "$TRAVIS_OS_NAME" != "manylinux1" ]; then
#     echo "::group::Building libgav1"
#     bash libgav1.cmd
#     LIBAVIF_CMAKE_FLAGS+=(-DAVIF_CODEC_LIBGAV1=ON -DAVIF_LOCAL_LIBGAV1=ON)
#     echo "::endgroup::"
# fi
#
# echo "::group::Building dav1d"
# bash dav1d.cmd
# LIBAVIF_CMAKE_FLAGS+=(-DAVIF_CODEC_DAV1D=ON -DAVIF_LOCAL_DAV1D=ON)
# echo "::endgroup::"
#
# if [ "$TRAVIS_OS_NAME" != "manylinux1" ] && [ "$PLAT" != "i686" ]; then
#     echo "::group::Building SVT-AV1"
#     if [ ! -e SVT-AV1 ]; then
#         curl -sLo - \
#             https://github.com/AOMediaCodec/SVT-AV1/archive/v$SVT_AV1_VERSION.tar.gz \
#             | tar Czxf . -
#         mv SVT-AV1-$SVT_AV1_VERSION SVT-AV1
#     fi
#
#     pushd SVT-AV1
#     pushd Build/linux
#
#     sed -i.backup 's/check_executable \-p sudo/check_executable \-p sudo || true/' build.sh
#
#     echo "Applying patch for older bash versions"
#     perl -p0i -e 's/(?<=\n)(\s*?)toolchain=\*\)\n.*?\n\1    ;;\n//sm' build.sh
#
#     if [ "$TRAVIS_OS_NAME" == "manylinux2010" ]; then
#         LDFLAGS=-lrt ./build.sh release static
#         LIBAVIF_CMAKE_FLAGS+=(-DCMAKE_EXE_LINKER_FLAGS=-lrt)
#     else
#         ./build.sh release static
#     fi
#     popd  # SVT-AV1
#     mkdir -p include/svt-av1
#     cp Source/API/*.h include/svt-av1
#     LIBAVIF_CMAKE_FLAGS+=(-DAVIF_CODEC_SVT=ON -DAVIF_LOCAL_SVT=ON)
#     popd  # ext
#     echo "::endgroup::"
# fi
#
# popd > /dev/null # root

if [ "$TRAVIS_OS_NAME" == "osx" ]; then
    # Prevent cmake from using @rpath in install id, so that delocate can
    # find and bundle the libavif dylib
    LIBAVIF_CMAKE_FLAGS+=("-DCMAKE_INSTALL_NAME_DIR=$PREFIX/lib" -DCMAKE_MACOSX_RPATH=OFF)
fi

echo "::group::Building libavif"
mkdir build
pushd build
cmake .. \
    -DCMAKE_INSTALL_PREFIX=$PREFIX \
    -DCMAKE_BUILD_TYPE=Release \
    "${LIBAVIF_CMAKE_FLAGS[@]}"
make
popd

popd
echo "::endgroup::"
