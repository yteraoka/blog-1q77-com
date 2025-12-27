# blog-1q77-com

Hugo で生成する静的コンテンツでブログを GitHub Pages でホストする

## hugo の version 管理

- 作業用のコマンドは `mise.toml` で管理
- GitHub Actions の中で使用する version は workflow ファイルの中の `HUGO_VERSION` の値で管理

## Theme

https://github.com/CaiJimmy/hugo-theme-stack を Git Submodule で利用している

Document: https://stack.jimmycai.com/

### Submodule 更新

`themes/hugo-theme-stack` ディレクトリに移動して git fetch, git checkout で tag を切り替えて
`themes/hugo-theme-stack` ディレクトリを git add する

### Amazon Affiliate

Amazon の Affiliate リンクを挿入するために `layouts/partials/article/components/content.html`
を theme 側からコピーしてカスタマイズしている

Amazon の Affilicate 用コードはこちらのサイトを参考にさせてもらった

- [HugoでAmazonのアフェリエイトリンクをいい感じに表示する](https://kenpos.dev/hugo%E3%81%A7amazon%E3%81%AE%E3%82%A2%E3%83%95%E3%82%A7%E3%83%AA%E3%82%A8%E3%82%A4%E3%83%88%E3%83%AA%E3%83%B3%E3%82%AF%E3%82%92%E3%81%84%E3%81%84%E6%84%9F%E3%81%98%E3%81%AB%E8%A1%A8%E7%A4%BA%E3%81%99%E3%82%8B/)
- [AmazonアフェリエイトリンクをHugoブログに追加するShortCodeを書いた](https://kenpos.dev/amazon%E3%82%A2%E3%83%95%E3%82%A7%E3%83%AA%E3%82%A8%E3%82%A4%E3%83%88%E3%83%AA%E3%83%B3%E3%82%AF%E3%82%92hugo%E3%83%96%E3%83%AD%E3%82%B0%E3%81%AB%E8%BF%BD%E5%8A%A0%E3%81%99%E3%82%8Bshortcode%E3%82%92%E6%9B%B8%E3%81%84%E3%81%9F/)

`static/css/amazon.css` はそのまま拝借させていただいた
