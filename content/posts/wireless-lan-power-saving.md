---
title: 'Battey駆動時の無線LANが遅い'
date: Sun, 09 Dec 2012 12:35:02 +0000
draft: false
tags: ['linux']
---

※ 2014/03/29 on と off が逆だったので訂正 Linux でバッテリー駆動時の無線LANが異常に遅いなあと思って調べてみた。 省電力のためにバッテリー駆動時には省エネモードに切り替えられていた。 iwconfig で確認すると Bit Rate=65 Mb/s → 1 Mb/s ACアダプターを挿したり抜いたりすると /var/log/pm-powersave.log に何をやってるかが出力される。(Linux Mint 14.1 で確認) あまりに遅いので、バッテリー駆動時に一時的に速度を上げたい場合には

```
sudo iwconfig wlan0 power off
```

を実行し、Power Management を無効にすることで速くできる。用が終わったら

```
sudo iwconfig wlan0 power on
```

で元に戻すことを忘れずに。 ACアダプター接続時

```
mypc log # iwconfig wlan0
wlan0     IEEE 802.11bgn  ESSID:"********"  
          Mode:Managed  Frequency:2.442 GHz  Access Point: XX:XX:XX:XX:XX:XX   
          Bit Rate=65 Mb/s   Tx-Power=16 dBm   
          Retry  long limit:7   RTS thr:off   Fragment thr:off
          Encryption key:off
          Power Management:off
          Link Quality=70/70  Signal level=-33 dBm  
          Rx invalid nwid:0  Rx invalid crypt:0  Rx invalid frag:0
          Tx excessive retries:29  Invalid misc:7578   Missed beacon:0
```

バッテリー駆動時

```
mypc log # iwconfig wlan0
wlan0     IEEE 802.11bgn  ESSID:"********"  
          Mode:Managed  Frequency:2.442 GHz  Access Point: XX:XX:XX:XX:XX:XX   
          Bit Rate=1 Mb/s   Tx-Power=16 dBm   
          Retry  long limit:7   RTS thr:off   Fragment thr:off
          Encryption key:off
          Power Management:on
          Link Quality=69/70  Signal level=-41 dBm  
          Rx invalid nwid:0  Rx invalid crypt:0  Rx invalid frag:0
          Tx excessive retries:29  Invalid misc:7584   Missed beacon:0
```
