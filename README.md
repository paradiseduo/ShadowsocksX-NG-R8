# Remove due to regulation

## Software removal method
First put the .app from the application file to the trash (any way)
Then open the Terminal.app and enter:

```bash
rm -rf /Library/Application\ Support/ShadowsocksX-NG-R8
rm -rf ~/Library/Application\ Support/ShadowsocksX-NG-R8
rm -rf ~/Library/LaunchAgents/com.qiuyuzhou.shadowsocksX-NG.http.plist
rm -rf ~/Library/LaunchAgents/com.qiuyuzhou.shadowsocksX-NG.local.plist
rm -rf ~/.ShadowsocksX-NG
rm -rf ~/Library/Preferences/com.qiuyuzhou.ShadowsocksX-NG.plist
rm -rf ~/Library/Caches/com.qiuyuzhou.ShadowsocksX-NG
```

If the prompt is insufficient, please execute after using sudo
