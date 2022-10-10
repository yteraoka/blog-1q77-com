---
title: 'Apache で Response Header を消しつつその値をログに書き出す'
date: Fri, 01 Feb 2013 15:14:45 +0000
draft: false
tags: ['Apache']
---

Apache のログにアプリから返された Response Header の情報を書きたいが、クライアントには送りたくないというものがあった場合、mod\_headers で unset してしまうと %{HeaderName}o では書き出せなくなってしまいます。そこで、Apache 2.4 むけに patch を書きました。 ログにユーザーを特定する内部IDを書き出したいがクライアントには返したくないという場合に便利ではないでしょうか。

```
Header toenv {HeaderName} {EnvName}
```

で、HeaderName というヘッダーの値を subprocess\_env の EnvName にセットし、ヘッダーを消します。これで %{EnvName}e でログに書き出せます。

```diff
diff -uNr httpd-2.4.3.orig/modules/metadata/mod_headers.c httpd-2.4.3/modules/metadata/mod_headers.c
--- httpd-2.4.3.orig/modules/metadata/mod_headers.c	2011-12-05 09:08:01.000000000 +0900
+++ httpd-2.4.3/modules/metadata/mod_headers.c	2013-02-01 16:25:33.279766574 +0900
@@ -96,7 +96,8 @@
     hdr_unset = 'u',            /* unset header */
     hdr_echo = 'e',             /* echo headers from request to response */
     hdr_edit = 'r',             /* change value by regexp, match once */
-    hdr_edit_r = 'R'            /* change value by regexp, everymatch */
+    hdr_edit_r = 'R',           /* change value by regexp, everymatch */
+    hdr_toenv = 'E'             /* copy to subprocess_env and unset */
 } hdr_actions;
 
 /*
@@ -417,6 +418,8 @@
         new->action = hdr_merge;
     else if (!strcasecmp(action, "unset"))
         new->action = hdr_unset;
+    else if (!strcasecmp(action, "toenv"))
+        new->action = hdr_toenv;
     else if (!strcasecmp(action, "echo"))
         new->action = hdr_echo;
     else if (!strcasecmp(action, "edit"))
@@ -425,7 +428,7 @@
         new->action = hdr_edit_r;
     else
         return "first argument must be 'add', 'set', 'append', 'merge', "
-               "'unset', 'echo', 'edit', or 'edit*'.";
+               "'unset', 'toenv', 'echo', 'edit', or 'edit*'.";
 
     if (new->action == hdr_edit || new->action == hdr_edit_r) {
         if (subs == NULL) {
@@ -736,6 +739,11 @@
         case hdr_unset:
             apr_table_unset(headers, hdr->header);
             break;
+        case hdr_toenv:
+            apr_table_add(r->subprocess_env, process_tags(hdr, r),
+                          apr_table_get(headers, hdr->header));
+            apr_table_unset(headers, hdr->header);
+            break;
         case hdr_echo:
             v.r = r;
             v.hdr = hdr;
```

誰かの役に立つかな？
