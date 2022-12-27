# textlint の実行

https://github.com/textlint-ja/textlint-rule-preset-ja-technical-writing

```bash
docker run -it --rm \
  -v $(pwd)/lint/textlintrc:/app/.textlintrc \
  -v $(pwd):/app/src textlint:latest /app/node_modules/.bin/textlint \
  src/content/posts/\*.md \
  src/content/posts/\*/index.md
```
