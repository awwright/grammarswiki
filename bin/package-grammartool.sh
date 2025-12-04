#!/bin/zsh
# A simple script to create packages of the CLI tool for a few platforms

PATH=/opt/homebrew/opt/swift/bin/swift:$PATH
RELEASE=debug

arch=arm64
( cd grammartool && swift build -c $RELEASE )
tar -czf grammartool-macos.tar.gz -C grammartool/.build/$arch-apple-macosx/$RELEASE grammartool

arch=aarch64
( cd grammartool && swift build -c $RELEASE --swift-sdk $arch-swift-6.2.1-RELEASE_static-linux-0.0.1 )
tar -czf grammartool-$arch-linux-musl.tar.gz -C grammartool/.build/$arch-swift-linux-musl/$RELEASE grammartool

arch=x86_64
( cd grammartool && swift build -c $RELEASE --swift-sdk $arch-swift-6.2.1-RELEASE_static-linux-0.0.1 )
tar -czf grammartool-$arch-linux-musl.tar.gz -C grammartool/.build/$arch-swift-linux-musl/$RELEASE grammartool
