---
title: 'golang で Google の Text-to-Speech を使う'
date: Sun, 19 Aug 2018 08:27:02 +0000
draft: false
tags: ['Go', 'google']
---

[Google Home mini](https://store.google.com/jp/product/google_home_mini) に任意の文章を読み上げさせるために [https://github.com/ikasamah/homecast](https://github.com/ikasamah/homecast) をいじって使ってましたが、これは [https://translate.google.com/translate\_tts?client=tw-ob&ie=UTF-8&q=テスト&tl=ja](https://translate.google.com/translate_tts?client=tw-ob&ie=UTF-8&q=テスト&tl=ja) といった Google 翻訳の非公式(?) API にアクセスしていました。その後、Google は [Cloud Text-to-Speech](https://cloud.google.com/text-to-speech/) サービスを[発表](https://cloudplatform-jp.googleblog.com/2018/03/introducing-Cloud-Text-to-Speech-powered-by-Deepmind-WaveNet-technology.html)したので Go でこの [API](https://cloud.google.com/text-to-speech/docs/reference/rest/v1beta1/text/synthesize) を使ってみます。

[cloud.google.com/go/texttospeech/apiv1](https://godoc.org/cloud.google.com/go/texttospeech/apiv1) を使えば良さそうです。[これを使った例](http://codegists.com/code/google-cloud-speech-example/)もあったので参考にさせていただきました。

[Google Cloud Developer Console](https://console.cloud.google.com/) でプロジェクトを作成し、[Cloud Text-to-Speech API](https://console.cloud.google.com/apis/api/texttospeech.googleapis.com/overview) を有効にし、サービスアカウントを作って JSON 形式の秘密鍵をダウンロードします。 `GOOGLE_APPLICATION_CREDENTIALS` という環境変数にこの JSON ファイルへの PATH を設定します。([アプリケーションに認証情報を提供する](https://cloud.google.com/docs/authentication/production#providing_credentials_to_your_application))

```
go get
go build
echo "テキストメッセージ" | ./tts
```

このようにすることで speech.mp3 というファイル(出力先ファイルは `-o` オプションで指定可能)が作成されます。`-v` で voice name を指定できます、日本語は `ja-JP-Wavenet-A` or `ja-JP-Standard-A` の2つが指定可能で、[Wavenet](https://cloud.google.com/text-to-speech/docs/wavenet) はより高品質らしいが料金も高い ([料金体系](https://cloud.google.com/text-to-speech/pricing))
