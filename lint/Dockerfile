FROM node:lts

WORKDIR /app

RUN npm install textlint-rule-preset-ja-technical-writing

COPY textlintrc /app/.textlintrc

ENV PATH /app/node_modules/.bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
