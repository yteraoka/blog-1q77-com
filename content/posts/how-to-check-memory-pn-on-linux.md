---
title: 'Linux でメモリの型番を調べる'
date: Fri, 07 Dec 2012 11:53:51 +0000
draft: false
tags: ['Linux']
---

dmidecode コマンドを使ってハードウエアの情報が取得できます。 "-t memory" と指定すればメモリの情報だけを取得できます。

```
$ sudo dmidecode -t memory
# dmidecode 2.11
# SMBIOS entry point at 0xaaebdf18
SMBIOS 2.7 present.

Handle 0x000B, DMI type 16, 23 bytes
Physical Memory Array
	Location: System Board Or Motherboard
	Use: System Memory
	Error Correction Type: None
	Maximum Capacity: 2 GB
	Error Information Handle: Not Provided
	Number Of Devices: 2

Handle 0x000C, DMI type 17, 34 bytes
Memory Device
	Array Handle: 0x000B
	Error Information Handle: Not Provided
	Total Width: 64 bits
	Data Width: 64 bits
	Size: 4096 MB
	Form Factor: SODIMM
	Set: None
	Locator: SODIMM1
	Bank Locator: Bank 0
	Type: DDR3
	Type Detail: Unknown
	Speed: 1333 MHz
	Manufacturer: Unknown
	Serial Number: 00000000
	Asset Tag: Unknown
	Part Number: Not Specified
	Rank: 1
	Configured Clock Speed: 1333 MHz

Handle 0x000D, DMI type 17, 34 bytes
Memory Device
	Array Handle: 0x000B
	Error Information Handle: Not Provided
	Total Width: 64 bits
	Data Width: 64 bits
	Size: 4096 MB
	Form Factor: SODIMM
	Set: None
	Locator: SODIMM2
	Bank Locator: Bank 1
	Type: DDR3
	Type Detail: Unknown
	Speed: 1333 MHz
	Manufacturer: Samsung
	Serial Number: 00ACDF4C
	Asset Tag: Unknown
	Part Number: M471B5273DH0-YH9  
	Rank: 2
	Configured Clock Speed: 1333 MHz
```
