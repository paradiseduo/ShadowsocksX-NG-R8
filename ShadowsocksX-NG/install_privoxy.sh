#!/bin/sh

#  install_privoxy.sh
#  ShadowsocksX-NG
#
#  Created by 王晨 on 16/10/7.
#  Copyright © 2016年 zhfish. All rights reserved.


cd "$(dirname "${BASH_SOURCE[0]}")"
privoxyVersion=3.0.28.static
mkdir -p "$HOME/Library/Application Support/ShadowsocksX-NG-R8/privoxy-$privoxyVersion"
cp -f privoxy "$HOME/Library/Application Support/ShadowsocksX-NG-R8/privoxy-$privoxyVersion/"
cp -f libpcre.1.dylib "$HOME/Library/Application Support/ShadowsocksX-NG-R8/privoxy-$privoxyVersion/"
rm -f "$HOME/Library/Application Support/ShadowsocksX-NG-R8/privoxy"
ln -s "$HOME/Library/Application Support/ShadowsocksX-NG-R8/privoxy-$privoxyVersion/privoxy" "$HOME/Library/Application Support/ShadowsocksX-NG-R8/privoxy"
ln -sf "$HOME/Library/Application Support/ShadowsocksX-NG-R8/privoxy-$privoxyVersion/libpcre.1.dylib" "$HOME/Library/Application Support/ShadowsocksX-NG-R8/libpcre.1.dylib"
echo done
