---
title: 'FortiGateでVPC'
date: 
draft: true
tags: ['AWS', 'VPC']
---

FortiGate 310B で VPC 接続 Amazon で VPC 設定を進めると設定情報がもらえる```
VPN Connection Configuration
================================================================================
AWS utilizes unique identifiers to manipulate the configuration of
a VPN Connection. Each VPN Connection is assigned a VPN Connection Identifier
and is associated with two other identifiers, namely the
Customer Gateway Identifier and the Virtual Private Gateway Identifier.

Your VPN Connection ID                   : vpn-AAAAAAAA
Your Virtual Private Gateway ID          : vgw-BBBBBBBB
Your Customer Gateway ID                 : cgw-CCCCCCCC

A VPN Connection consists of a pair of IPSec tunnel security associations (SAs).
It is important that both tunnel security associations be configured.

```IPSec項目 (2つ設定する)```
IPSec Tunnel #1
  #1: Internet Key Exchange Configuration

     Configure the IKE SA as follows
       - Authentication Method    : Pre-Shared Key
       - Pre-Shared Key           : XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
       - Authentication Algorithm : sha1
       - Encryption Algorithm     : aes-128-cbc
       - Lifetime                 : 28800 seconds
       - Phase 1 Negotiation Mode : main
       - Perfect Forward Secrecy  : Diffie-Hellman Group 2

  #2: IPSec Configuration

     Configure the IPSec SA as follows:
       - Protocol                 : esp
       - Authentication Algorithm : hmac-sha1-96
       - Encryption Algorithm     : aes-128-cbc
       - Lifetime                 : 3600 seconds
       - Mode                     : tunnel
       - Perfect Forward Secrecy  : Diffie-Hellman Group 2

     IPSec Dead Peer Detection (DPD) will be enabled on the AWS Endpoint. We
     recommend configuring DPD on your endpoint as follows:
       - DPD Interval             : 10
       - DPD Retries              : 3

     IPSec ESP (Encapsulating Security Payload) inserts additional
     headers to transmit packets. These headers require additional space,
     which reduces the amount of space available to transmit application data.
     To limit the impact of this behavior, we recommend the following
     configuration on your Customer Gateway:
       - TCP MSS Adjustment       : 1387 bytes
       - Clear Don't Fragment Bit : enabled
       - Fragmentation            : Before encryption

  #3: Tunnel Interface Configuration

     Outside IP Addresses:
       - Customer Gateway                    : 202.213.201.225
       - Virtual Private Gateway             : 27.0.1.16

     Inside IP Addresses
       - Customer Gateway                    : 169.254.252.2/30
       - Virtual Private Gateway             : 169.254.252.1/30

     Configure your tunnel to fragment at the optimal size:
       - Tunnel interface MTU     : 1436 bytes

  #4: Border Gateway Protocol (BGP) Configuration:

    BGP Configuration Options:
      - Customer Gateway ASN                  : 65000
      - Virtual Private  Gateway ASN          : 10124
      - Neighbor IP Address                   : 169.254.252.1
      - Neighbor Hold Time                    : 30

```