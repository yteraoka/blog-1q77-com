---
title: 'DigitalOcean のメタデータ API'
date: Sat, 20 Aug 2016 05:30:35 +0000
draft: false
tags: ['DigitalOcean', 'DigitalOcean']
---

[https://developers.digitalocean.com/documentation/metadata/](https://developers.digitalocean.com/documentation/metadata/) にドキュメントがあります。 （AWS EC2 での [インスタンスメタデータ](http://docs.aws.amazon.com/ja_jp/AWSEC2/latest/UserGuide/ec2-instance-metadata.html) です）```
curl -s http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address

```とすればパブリックIPアドレスが取得できます。```
curl -s http://169.254.169.254/metadata/v1.json

```とすれば JSON ですべて取れます。```
{
  "droplet\_id":2756294,
  "hostname":"sample-droplet",
  "vendor\_data":"#cloud-config\\ndisable\_root: false\\nmanage\_etc\_hosts: true\\n\\ncloud\_config\_modules:\\n - ssh\\n - set\_hostname\\n - \[ update\_etc\_hosts, once-per-instance \]\\n\\ncloud\_final\_modules:\\n - scripts-vendor\\n - scripts-per-once\\n - scripts-per-boot\\n - scripts-per-instance\\n - scripts-user\\n",
  "public\_keys":\["ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCcbi6cygCUmuNlB0KqzBpHXf7CFYb3VE4pDOf/RLJ8OFDjOM+fjF83a24QktSVIpQnHYpJJT2pQMBxD+ZmnhTbKv+OjwHSHwAfkBullAojgZKzz+oN35P4Ea4J78AvMrHw0zp5MknS+WKEDCA2c6iDRCq6/hZ13Mn64f6c372JK99X29lj/B4VQpKCQyG8PUSTFkb5DXTETGbzuiVft+vM6SF+0XZH9J6dQ7b4yD3sOder+M0Q7I7CJD4VpdVD/JFa2ycOS4A4dZhjKXzabLQXdkWHvYGgNPGA5lI73TcLUAueUYqdq3RrDRfaQ5Z0PEw0mDllCzhk5dQpkmmqNi0F sammy@digitalocean.com"\],
  "region":"nyc3",
  "interfaces":{
    "private":\[
      {
        "ipv4":{
          "ip\_address":"10.132.255.113",
          "netmask":"255.255.0.0",
          "gateway":"10.132.0.1"
        },
        "mac":"04:01:2a:0f:2a:02",
        "type":"private"
      }
    \],
    "public":\[
      {
        "ipv4":{
          "ip\_address":"104.131.20.105",
          "netmask":"255.255.192.0",
          "gateway":"104.131.0.1"
        },
        "ipv6":{
          "ip\_address":"2604:A880:0800:0010:0000:0000:017D:2001",
          "cidr":64,
          "gateway":"2604:A880:0800:0010:0000:0000:0000:0001"
        },
        "mac":"04:01:2a:0f:2a:01",
        "type":"public"}
    \]
  },
  "floating\_ip": {
    "ipv4": {
      "active": false
    }
  },
  "dns":{
    "nameservers":\[
      "2001:4860:4860::8844",
      "2001:4860:4860::8888",
      "8.8.8.8"
    \]
  }
}

```169.254.169.254 という IP アドレスは DigitalOcean も EC2 も同じですが、path は全く異なります。 169.254.0.0/16 は IPv4 Link Local Addresses で [RFC 3927](https://tools.ietf.org/html/rfc3927) に規定があるみたい。