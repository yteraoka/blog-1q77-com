---
title: 'Ansible AWX を試す その1 #ansible'
date: Fri, 09 Aug 2013 16:09:43 +0000
draft: false
tags: ['Ansible', 'ansible', 'awx', 'python']
---

このところ [Ansible Tutorial](http://yteraoka.github.io/ansible-tutorial/) を書いたりして Ansible ブームなので一昨日見つけた Ansible の WebUI ツール AWX を試してみました。www.ansibleworks.com/ansibleworks-awx/ （もう存在しない）から awx-setup-1.2.2.tar.gz をダウンロードします。 まずは中身の確認。```
\[vagrant@localhost ~\]$ tar ztf awx-setup-1.2.2.tar.gz 
awx-setup-1.2.2/
awx-setup-1.2.2/README.md
awx-setup-1.2.2/group\_vars/
awx-setup-1.2.2/group\_vars/all
awx-setup-1.2.2/site.yml
awx-setup-1.2.2/myhosts
awx-setup-1.2.2/setup.sh
awx-setup-1.2.2/roles/
awx-setup-1.2.2/roles/packages\_fedora/
awx-setup-1.2.2/roles/packages\_fedora/templates/
awx-setup-1.2.2/roles/packages\_fedora/templates/yum\_repo.j2
awx-setup-1.2.2/roles/packages\_fedora/tasks/
awx-setup-1.2.2/roles/packages\_fedora/tasks/main.yml
awx-setup-1.2.2/roles/packages\_ubuntu/
awx-setup-1.2.2/roles/packages\_ubuntu/templates/
awx-setup-1.2.2/roles/packages\_ubuntu/templates/awx\_repo.j2
awx-setup-1.2.2/roles/packages\_ubuntu/tasks/
awx-setup-1.2.2/roles/packages\_ubuntu/tasks/main.yml
awx-setup-1.2.2/roles/iptables/
awx-setup-1.2.2/roles/iptables/tasks/
awx-setup-1.2.2/roles/iptables/tasks/main.yml
awx-setup-1.2.2/roles/iptables/handlers/
awx-setup-1.2.2/roles/iptables/handlers/main.yml
awx-setup-1.2.2/roles/misc/
awx-setup-1.2.2/roles/misc/files/
awx-setup-1.2.2/roles/misc/files/51-awx.conf
awx-setup-1.2.2/roles/misc/tasks/
awx-setup-1.2.2/roles/misc/tasks/main.yml
awx-setup-1.2.2/roles/misc/handlers/
awx-setup-1.2.2/roles/misc/handlers/main.yml
awx-setup-1.2.2/roles/httpd/
awx-setup-1.2.2/roles/httpd/tasks/
awx-setup-1.2.2/roles/httpd/tasks/main.yml
awx-setup-1.2.2/roles/httpd/handlers/
awx-setup-1.2.2/roles/httpd/handlers/main.yml
awx-setup-1.2.2/roles/supervisor/
awx-setup-1.2.2/roles/supervisor/tasks/
awx-setup-1.2.2/roles/supervisor/tasks/main.yml
awx-setup-1.2.2/roles/supervisor/handlers/
awx-setup-1.2.2/roles/supervisor/handlers/main.yml
awx-setup-1.2.2/roles/postgres/
awx-setup-1.2.2/roles/postgres/templates/
awx-setup-1.2.2/roles/postgres/templates/pg\_hba.conf.j2
awx-setup-1.2.2/roles/postgres/tasks/
awx-setup-1.2.2/roles/postgres/tasks/main.yml
awx-setup-1.2.2/roles/postgres/handlers/
awx-setup-1.2.2/roles/postgres/handlers/main.yml
awx-setup-1.2.2/roles/awx\_install/
awx-setup-1.2.2/roles/awx\_install/templates/
awx-setup-1.2.2/roles/awx\_install/templates/settings.py.j2
awx-setup-1.2.2/roles/awx\_install/tasks/
awx-setup-1.2.2/roles/awx\_install/tasks/main.yml
awx-setup-1.2.2/roles/packages\_el6/
awx-setup-1.2.2/roles/packages\_el6/templates/
awx-setup-1.2.2/roles/packages\_el6/templates/yum\_repo.j2
awx-setup-1.2.2/roles/packages\_el6/tasks/
awx-setup-1.2.2/roles/packages\_el6/tasks/main.yml

```おや？これは！ Playbook ですね。Best Practice なディレクトリ構成です。Playbook の勉強にもなりますね。 [AnsibleWorks AWX User Guide](http://www.ansibleworks.com/releases/awx/docs/awx_user_guide.pdf) という PDF ドキュメントがあります。これに沿ってインストールしてみます。 まず DB (PostgreSQL) のパスワードを `group_vars/all` の `pg_password` 変数で設定します。 この他にもこのファイルには DB 名や DB のユーザー名、アプリのユーザー名、パスワードの定義もありますね。Django + PostgreSQL という構成みたいです。Ansible が Python だからやっぱりこのツールも Python 製ですね。 変数を設定したら後は setup.sh を実行するだけです。Ansible の威力ですね。```
\[vagrant@localhost awx-setup-1.2.2\]$ ./setup.sh 

PLAY \[all\] \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\* 

GATHERING FACTS \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\* 
ok: \[127.0.0.1\]

TASK: \[group hosts by distribution\] \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\* 
changed: \[127.0.0.1\] => {"changed": true, "groups": {"CentOS-6.4": \["127.0.0.1"\]}}

PLAY \[RedHat-6\*:CentOS-6\*:SL-6\*\] \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\* 

TASK: \[install epel6 repository\] \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\* 
changed: \[127.0.0.1\] => {"changed": true, "cmd": "rpm -q epel-release || rpm -Uvh http://download.fedoraproject.org/pub/epel/6/i386/epel-release-6-8.noarch.rpm ", "delta": "0:00:00.045414", "end": "2013-08-09 14:09:31.568672", "item": "", "rc": 0, "start": "2013-08-09 14:09:31.523258", "stderr": "", "stdout": "epel-release-6-8.noarch"}

TASK: \[install EL6 awx yum repository\] \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\* 
changed: \[127.0.0.1\] => {"changed": true, "dest": "/etc/yum.repos.d/awx.repo", "gid": 0, "group": "root", "item": "", "md5sum": "98239f7b2f42100e29efde40377f15e1", "mode": "0644", "owner": "root", "size": 163, "src": "/root/.ansible/tmp/ansible-1376057371.64-145330162957648/source", "state": "file", "uid": 0}

TASK: \[yum clean cached awx repository information\] \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\* 
changed: \[127.0.0.1\] => {"changed": true, "cmd": \["yum", "clean", "all", "--disablerepo=\*", "--enablerepo=ansibleworks-awx"\], "delta": "0:00:00.441243", "end": "2013-08-09 14:09:32.364621", "item": "", "rc": 0, "start": "2013-08-09 14:09:31.923378", "stderr": "", "stdout": "Loaded plugins: fastestmirror\\nCleaning repos: ansibleworks-awx\\nCleaning up Everything\\nCleaning up list of fastest mirrors"}

TASK: \[install required packages for EL6\] \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\* 
changed: \[127.0.0.1\] => (item=Django14,httpd,mod\_wsgi,libselinux-python,policycoreutils-python,postgresql-server,python-psycopg2,python-setuptools,setools-libs-python,supervisor) => {"changed": true, "item": "Django14,httpd,mod\_wsgi,libselinux-python,policycoreutils-python,postgresql-server,python-psycopg2,python-setuptools,setools-libs-python,supervisor", "msg": "", "rc": 0, "results": \["\\n================================================================================\\n Package                  Arch          Version               Repository   Size\\n================================================================================\\nInstalling:\\n Django14                 noarch        1.4.5-1.el6           epel        4.1 M\\nInstalling for dependencies:\\n python-simplejson        x86\_64        2.0.9-3.1.el6         base        126 k\\n\\nTransaction Summary\\n================================================================================\\nInstall       2 Package(s)\\n\\nTotal download size: 4.2 M\\nInstalled size: 17 M\\n\\nInstalled:\\n  Django14.noarch 0:1.4.5-1.el6                                                 \\n\\nDependency Installed:\\n  python-simplejson.x86\_64 0:2.0.9-3.1.el6                                      \\n\\n", "\\n================================================================================\\n Package            Arch        Version                      Repository    Size\\n================================================================================\\nInstalling:\\n httpd              x86\_64      2.2.15-28.el6.centos         updates      821 k\\nInstalling for dependencies:\\n apr                x86\_64      1.3.9-5.el6\_2                base         123 k\\n apr-util           x86\_64      1.3.9-3.el6\_0.1              base          87 k\\n apr-util-ldap      x86\_64      1.3.9-3.el6\_0.1              base          15 k\\n httpd-tools        x86\_64      2.2.15-28.el6.centos         updates       73 k\\n mailcap            noarch      2.1.31-2.el6                 base          27 k\\n\\nTransaction Summary\\n================================================================================\\nInstall       6 Package(s)\\n\\nTotal download size: 1.1 M\\nInstalled size: 3.6 M\\n\\nInstalled:\\n  httpd.x86\_64 0:2.2.15-28.el6.centos                                           \\n\\nDependency Installed:\\n  apr.x86\_64 0:1.3.9-5.el6\_2                                                    \\n  apr-util.x86\_64 0:1.3.9-3.el6\_0.1                                             \\n  apr-util-ldap.x86\_64 0:1.3.9-3.el6\_0.1                                        \\n  httpd-tools.x86\_64 0:2.2.15-28.el6.centos                                     \\n  mailcap.noarch 0:2.1.31-2.el6                                                 \\n\\n", "\\n================================================================================\\n Package            Arch             Version               Repository      Size\\n================================================================================\\nInstalling:\\n mod\_wsgi           x86\_64           3.2-3.el6             base            66 k\\n\\nTransaction Summary\\n================================================================================\\nInstall       1 Package(s)\\n\\nTotal download size: 66 k\\nInstalled size: 177 k\\n\\nInstalled:\\n  mod\_wsgi.x86\_64 0:3.2-3.el6                                                   \\n\\n", "\\n================================================================================\\n Package                Arch        Version                  Repository    Size\\n================================================================================\\nInstalling:\\n libselinux-python      x86\_64      2.0.94-5.3.el6\_4.1       updates      202 k\\nUpdating for dependencies:\\n libselinux             x86\_64      2.0.94-5.3.el6\_4.1       updates      108 k\\n libselinux-devel       x86\_64      2.0.94-5.3.el6\_4.1       updates      136 k\\n libselinux-ruby        x86\_64      2.0.94-5.3.el6\_4.1       updates       99 k\\n libselinux-utils       x86\_64      2.0.94-5.3.el6\_4.1       updates       81 k\\n\\nTransaction Summary\\n================================================================================\\nInstall       1 Package(s)\\nUpgrade       4 Package(s)\\n\\nTotal download size: 625 k\\n\\nInstalled:\\n  libselinux-python.x86\_64 0:2.0.94-5.3.el6\_4.1                                 \\n\\nDependency Updated:\\n  libselinux.x86\_64 0:2.0.94-5.3.el6\_4.1                                        \\n  libselinux-devel.x86\_64 0:2.0.94-5.3.el6\_4.1                                  \\n  libselinux-ruby.x86\_64 0:2.0.94-5.3.el6\_4.1                                   \\n  libselinux-utils.x86\_64 0:2.0.94-5.3.el6\_4.1                                  \\n\\n", "\\n================================================================================\\n Package                    Arch       Version                Repository   Size\\n================================================================================\\nInstalling:\\n policycoreutils-python     x86\_64     2.0.83-19.30.el6       base        342 k\\nInstalling for dependencies:\\n audit-libs-python          x86\_64     2.2-2.el6              base         59 k\\n libcgroup                  x86\_64     0.37-7.2.el6\_4         updates     111 k\\n libsemanage-python         x86\_64     2.0.43-4.2.el6         base         81 k\\n setools-libs               x86\_64     3.3.7-4.el6            base        400 k\\n setools-libs-python        x86\_64     3.3.7-4.el6            base        222 k\\n\\nTransaction Summary\\n================================================================================\\nInstall       6 Package(s)\\n\\nTotal download size: 1.2 M\\nInstalled size: 4.4 M\\n\\nInstalled:\\n  policycoreutils-python.x86\_64 0:2.0.83-19.30.el6                              \\n\\nDependency Installed:\\n  audit-libs-python.x86\_64 0:2.2-2.el6        libcgroup.x86\_64 0:0.37-7.2.el6\_4 \\n  libsemanage-python.x86\_64 0:2.0.43-4.2.el6  setools-libs.x86\_64 0:3.3.7-4.el6 \\n  setools-libs-python.x86\_64 0:3.3.7-4.el6   \\n\\n", "\\n================================================================================\\n Package                  Arch          Version               Repository   Size\\n================================================================================\\nInstalling:\\n postgresql-server        x86\_64        8.4.13-1.el6\_3        base        3.4 M\\nInstalling for dependencies:\\n postgresql               x86\_64        8.4.13-1.el6\_3        base        2.8 M\\n postgresql-libs          x86\_64        8.4.13-1.el6\_3        base        200 k\\n\\nTransaction Summary\\n================================================================================\\nInstall       3 Package(s)\\n\\nTotal download size: 6.4 M\\nInstalled size: 29 M\\n\\nInstalled:\\n  postgresql-server.x86\_64 0:8.4.13-1.el6\_3                                     \\n\\nDependency Installed:\\n  postgresql.x86\_64 0:8.4.13-1.el6\_3   postgresql-libs.x86\_64 0:8.4.13-1.el6\_3  \\n\\n", "\\n================================================================================\\n Package                 Arch           Version              Repository    Size\\n================================================================================\\nInstalling:\\n python-psycopg2         x86\_64         2.0.14-2.el6         base         100 k\\n\\nTransaction Summary\\n================================================================================\\nInstall       1 Package(s)\\n\\nTotal download size: 100 k\\nInstalled size: 318 k\\n\\nInstalled:\\n  python-psycopg2.x86\_64 0:2.0.14-2.el6                                         \\n\\n", "\\n================================================================================\\n Package                  Arch          Version               Repository   Size\\n================================================================================\\nInstalling:\\n python-setuptools        noarch        0.6.10-3.el6          base        336 k\\n\\nTransaction Summary\\n================================================================================\\nInstall       1 Package(s)\\n\\nTotal download size: 336 k\\nInstalled size: 1.5 M\\n\\nInstalled:\\n  python-setuptools.noarch 0:0.6.10-3.el6                                       \\n\\n", "setools-libs-python-3.3.7-4.el6.x86\_64 providing setools-libs-python is already installed", "\\n================================================================================\\n Package               Arch            Version              Repository     Size\\n================================================================================\\nInstalling:\\n supervisor            noarch          2.1-8.el6            epel          292 k\\nInstalling for dependencies:\\n python-meld3          x86\_64          0.6.7-1.el6          epel           71 k\\n\\nTransaction Summary\\n================================================================================\\nInstall       2 Package(s)\\n\\nTotal download size: 363 k\\nInstalled size: 1.4 M\\n\\nInstalled:\\n  supervisor.noarch 0:2.1-8.el6                                                 \\n\\nDependency Installed:\\n  python-meld3.x86\_64 0:0.6.7-1.el6                                             \\n\\n"\]}

TASK: \[install awx RPM for EL6\] \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\* 
changed: \[127.0.0.1\] => {"changed": true, "item": "", "msg": "", "rc": 0, "results": \["\\n================================================================================\\n Package     Arch           Version              Repository                Size\\n================================================================================\\nInstalling:\\n awx         noarch         1.2.2-0.el6          ansibleworks-awx         4.7 M\\n\\nTransaction Summary\\n================================================================================\\nInstall       1 Package(s)\\n\\nTotal download size: 4.7 M\\nInstalled size: 19 M\\n\\nInstalled:\\n  awx.noarch 0:1.2.2-0.el6                                                      \\n\\n"\]}

TASK: \[init postgresql\] \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\* 
changed: \[127.0.0.1\] => {"changed": true, "cmd": \["service", "postgresql", "initdb"\], "delta": "0:00:10.226856", "end": "2013-08-09 14:10:51.195623", "item": "", "rc": 0, "start": "2013-08-09 14:10:40.968767", "stderr": "", "stdout": "Initializing database: \[  OK  \]"}

TASK: \[update postgresql authentication settings\] \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\* 
changed: \[127.0.0.1\] => {"changed": true, "dest": "/var/lib/pgsql/data/pg\_hba.conf", "gid": 26, "group": "postgres", "item": "", "md5sum": "20c708b0d8e275e6b3163c02ee82aaab", "mode": "0600", "owner": "postgres", "size": 620, "src": "/root/.ansible/tmp/ansible-1376057451.29-79460499167534/source", "state": "file", "uid": 26}

TASK: \[restart postgresql and configure to startup automatically\] \*\*\*\*\*\*\*\*\*\*\*\*\* 
changed: \[127.0.0.1\] => {"changed": true, "enabled": true, "item": "", "name": "postgresql", "state": "started"}

TASK: \[wait for postgresql restart\] \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\* 
changed: \[127.0.0.1\] => {"changed": true, "cmd": \["sleep", "10"\], "delta": "0:00:10.003686", "end": "2013-08-09 14:11:04.001508", "item": "", "rc": 0, "start": "2013-08-09 14:10:53.997822", "stderr": "", "stdout": ""}

TASK: \[create the postgresql user for awx\] \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\* 
changed: \[127.0.0.1\] => {"changed": true, "item": "", "user": "awx"}

TASK: \[create the postgresql database for awx\] \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\* 
changed: \[127.0.0.1\] => {"changed": true, "db": "awx", "item": ""}

TASK: \[install awx package and dependencies via pip\] \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\* 
skipping: \[127.0.0.1\]

TASK: \[configure awx user\] \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\* 
skipping: \[127.0.0.1\]

TASK: \[configure awx user home directory\] \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\* 
ok: \[127.0.0.1\] => {"changed": false, "gid": 497, "group": "awx", "item": "", "mode": "0755", "owner": "awx", "path": "/var/lib/awx", "size": 4096, "state": "directory", "uid": 497}

TASK: \[configure awx projects directory\] \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\* 
changed: \[127.0.0.1\] => {"changed": true, "gid": 497, "group": "awx", "item": "", "mode": "0750", "owner": "awx", "path": "/var/lib/awx/projects", "size": 4096, "state": "directory", "uid": 497}

TASK: \[configure awx settings directory\] \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\* 
skipping: \[127.0.0.1\]

TASK: \[setup secret key for settings\] \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\* 
skipping: \[127.0.0.1\]

TASK: \[configure awx settings\] \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\* 
changed: \[127.0.0.1\] => {"changed": true, "dest": "/etc/awx/settings.py", "gid": 497, "group": "awx", "item": "", "md5sum": "c08fb3b628837d8670cb64980537bee6", "mode": "0644", "owner": "awx", "size": 1615, "src": "/root/.ansible/tmp/ansible-1376057465.74-151147353765701/source", "state": "file", "uid": 497}

TASK: \[create awx database schema\] \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\* 
changed: \[127.0.0.1\] => {"changed": true, "cmd": \["awx-manage", "syncdb", "--noinput"\], "delta": "0:00:01.131647", "end": "2013-08-09 14:11:07.184323", "item": "", "rc": 0, "start": "2013-08-09 14:11:06.052676", "stderr": "", "stdout": "Syncing...\\nCreating tables ...\\nCreating table django\_admin\_log\\nCreating table auth\_permission\\nCreating table auth\_group\_permissions\\nCreating table auth\_group\\nCreating table auth\_user\_user\_permissions\\nCreating table auth\_user\_groups\\nCreating table auth\_user\\nCreating table django\_content\_type\\nCreating table django\_session\\nCreating table django\_site\\nCreating table south\_migrationhistory\\nInstalling custom SQL ...\\nInstalling indexes ...\\nInstalled 0 object(s) from 0 fixture(s)\\n\\nSynced:\\n > django.contrib.admin\\n > django.contrib.auth\\n > django.contrib.contenttypes\\n > django.contrib.messages\\n > django.contrib.sessions\\n > django.contrib.sites\\n > django.contrib.staticfiles\\n > south\\n > rest\_framework\\n > awx.ui\\n\\nNot synced (use migrations):\\n - rest\_framework.authtoken\\n - django\_extensions\\n - djcelery\\n - kombu.transport.django\\n - taggit\\n - awx.main\\n(use ./manage.py migrate to migrate these)"}

TASK: \[migrate awx database schema\] \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\* 
changed: \[127.0.0.1\] => {"changed": true, "cmd": \["awx-manage", "migrate", "--noinput"\], "delta": "0:00:05.480693", "end": "2013-08-09 14:11:12.849291", "item": "", "rc": 0, "start": "2013-08-09 14:11:07.368598", "stderr": "", "stdout": "Running migrations for authtoken:\\n - Migrating forwards to 0001\_initial.\\n > authtoken:0001\_initial\\n - Loading initial data for authtoken.\\nInstalled 0 object(s) from 0 fixture(s)\\nRunning migrations for django\_extensions:\\n - Migrating forwards to 0001\_empty.\\n > django\_extensions:0001\_empty\\n - Loading initial data for django\_extensions.\\nInstalled 0 object(s) from 0 fixture(s)\\nRunning migrations for djcelery:\\n - Migrating forwards to 0004\_v30\_changes.\\n > djcelery:0001\_initial\\n > djcelery:0002\_v25\_changes\\n > djcelery:0003\_v26\_changes\\n > djcelery:0004\_v30\_changes\\n - Loading initial data for djcelery.\\nInstalled 0 object(s) from 0 fixture(s)\\nRunning migrations for django:\\n - Migrating forwards to 0001\_initial.\\n > django:0001\_initial\\n - Loading initial data for django.\\nInstalled 0 object(s) from 0 fixture(s)\\nRunning migrations for taggit:\\n - Migrating forwards to 0002\_unique\_tagnames.\\n > taggit:0001\_initial\\n > taggit:0002\_unique\_tagnames\\n - Loading initial data for taggit.\\nInstalled 0 object(s) from 0 fixture(s)\\nRunning migrations for main:\\n - Migrating forwards to 0008\_v12changes.\\n > main:0001\_v12b1\_initial\\n > main:0002\_v12b2\_changes\\n > main:0003\_v12b2\_changes\\n > main:0004\_v12b2\_changes\\n > main:0005\_v12b2\_changes\\n > main:0006\_v12b2\_changes\\n > main:0007\_v12b2\_changes\\n > main:0008\_v12changes\\n - Loading initial data for main.\\nInstalled 0 object(s) from 0 fixture(s)"}

TASK: \[collect awx static files\] \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\* 
changed: \[127.0.0.1\] => {"changed": true, "cmd": \["awx-manage", "collectstatic", "--noinput"\], "delta": "0:00:00.632565", "end": "2013-08-09 14:11:13.677810", "item": "", "rc": 0, "start": "2013-08-09 14:11:13.045245", "stderr": "", "stdout": "\\n0 static files copied, 213 unmodified."}

TASK: \[create django super user\] \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\* 
changed: \[127.0.0.1\] => {"changed": true, "cmd": "echo \\"from django.contrib.auth.models import User; User.objects.filter(username='admin').count() or User.objects.create\_superuser('admin', 'admin@example.com', 'password')\\" | awx-manage shell ", "delta": "0:00:00.985082", "end": "2013-08-09 14:11:14.887458", "item": "", "rc": 0, "start": "2013-08-09 14:11:13.902376", "stderr": "Python 2.6.6 (r266:84292, Feb 22 2013, 00:00:18) \\n\[GCC 4.4.7 20120313 (Red Hat 4.4.7-3)\] on linux2\\nType \\"help\\", \\"copyright\\", \\"credits\\" or \\"license\\" for more information.\\n(InteractiveConsole)", "stdout": "\\u001b\[?1034h>>> \\n>>> "}

TASK: \[update supervisor config\] \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\* 
ok: \[127.0.0.1\] => (item={'option': 'command', 'value': '/usr/bin/awx-manage celeryd -B -l info --autoscale=20,2'}) => {"changed": false, "dest": "/etc/supervisord.conf", "gid": 0, "group": "root", "item": {"option": "command", "value": "/usr/bin/awx-manage celeryd -B -l info --autoscale=20,2"}, "mode": "0644", "msg": "OK", "owner": "root", "size": 3662, "state": "file", "uid": 0}
ok: \[127.0.0.1\] => (item={'option': 'directory', 'value': u'/var/lib/awx'}) => {"changed": false, "dest": "/etc/supervisord.conf", "gid": 0, "group": "root", "item": {"option": "directory", "value": "/var/lib/awx"}, "mode": "0644", "msg": "OK", "owner": "root", "size": 3662, "state": "file", "uid": 0}
ok: \[127.0.0.1\] => (item={'option': 'user', 'value': u'awx'}) => {"changed": false, "dest": "/etc/supervisord.conf", "gid": 0, "group": "root", "item": {"option": "user", "value": "awx"}, "mode": "0644", "msg": "OK", "owner": "root", "size": 3662, "state": "file", "uid": 0}
ok: \[127.0.0.1\] => (item={'option': 'autostart', 'value': 'true'}) => {"changed": false, "dest": "/etc/supervisord.conf", "gid": 0, "group": "root", "item": {"option": "autostart", "value": "true"}, "mode": "0644", "msg": "OK", "owner": "root", "size": 3662, "state": "file", "uid": 0}
ok: \[127.0.0.1\] => (item={'option': 'autorestart', 'value': 'true'}) => {"changed": false, "dest": "/etc/supervisord.conf", "gid": 0, "group": "root", "item": {"option": "autorestart", "value": "true"}, "mode": "0644", "msg": "OK", "owner": "root", "size": 3662, "state": "file", "uid": 0}
ok: \[127.0.0.1\] => (item={'option': 'stopwaitsecs', 'value': 600}) => {"changed": false, "dest": "/etc/supervisord.conf", "gid": 0, "group": "root", "item": {"option": "stopwaitsecs", "value": 600}, "mode": "0644", "msg": "OK", "owner": "root", "size": 3662, "state": "file", "uid": 0}
ok: \[127.0.0.1\] => (item={'option': 'log\_stdout', 'value': 'true'}) => {"changed": false, "dest": "/etc/supervisord.conf", "gid": 0, "group": "root", "item": {"option": "log\_stdout", "value": "true"}, "mode": "0644", "msg": "OK", "owner": "root", "size": 3662, "state": "file", "uid": 0}
ok: \[127.0.0.1\] => (item={'option': 'log\_stderr', 'value': 'true'}) => {"changed": false, "dest": "/etc/supervisord.conf", "gid": 0, "group": "root", "item": {"option": "log\_stderr", "value": "true"}, "mode": "0644", "msg": "OK", "owner": "root", "size": 3662, "state": "file", "uid": 0}
ok: \[127.0.0.1\] => (item={'option': 'logfile', 'value': '/var/log/supervisor/awx-celeryd.log'}) => {"changed": false, "dest": "/etc/supervisord.conf", "gid": 0, "group": "root", "item": {"option": "logfile", "value": "/var/log/supervisor/awx-celeryd.log"}, "mode": "0644", "msg": "OK", "owner": "root", "size": 3662, "state": "file", "uid": 0}
ok: \[127.0.0.1\] => (item={'option': 'logfile\_maxbytes', 'value': '50MB'}) => {"changed": false, "dest": "/etc/supervisord.conf", "gid": 0, "group": "root", "item": {"option": "logfile\_maxbytes", "value": "50MB"}, "mode": "0644", "msg": "OK", "owner": "root", "size": 3662, "state": "file", "uid": 0}
ok: \[127.0.0.1\] => (item={'option': 'logfile\_backups', 'value': 999}) => {"changed": false, "dest": "/etc/supervisord.conf", "gid": 0, "group": "root", "item": {"option": "logfile\_backups", "value": 999}, "mode": "0644", "msg": "OK", "owner": "root", "size": 3662, "state": "file", "uid": 0}

TASK: \[stop supervisor\] \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\* 
ok: \[127.0.0.1\] => {"changed": false, "item": "", "name": "supervisord", "state": "stopped"}

TASK: \[start supervisor\] \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\* 
changed: \[127.0.0.1\] => {"changed": true, "enabled": true, "item": "", "name": "supervisord", "state": "started"}

TASK: \[determine if selinux is installed\] \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\* 
changed: \[127.0.0.1\] => {"changed": true, "cmd": "which getenforce || exit 0 ", "delta": "0:00:00.016455", "end": "2013-08-09 14:11:17.251571", "item": "", "rc": 0, "start": "2013-08-09 14:11:17.235116", "stderr": "", "stdout": "/usr/sbin/getenforce"}

TASK: \[determine if selinux is enabled\] \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\* 
changed: \[127.0.0.1\] => {"changed": true, "cmd": "getenforce | grep -q Disabled || echo yes && echo no ", "delta": "0:00:00.010524", "end": "2013-08-09 14:11:17.579428", "item": "", "rc": 0, "start": "2013-08-09 14:11:17.568904", "stderr": "", "stdout": "no"}

TASK: \[allow Apache network connections\] \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\* 
skipping: \[127.0.0.1\]

TASK: \[create awx wsgi application\] \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\* 
skipping: \[127.0.0.1\]

TASK: \[create httpd virtualhost for awx\] \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\* 
skipping: \[127.0.0.1\]

TASK: \[start httpd and configure to startup automatically\] \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\* 
changed: \[127.0.0.1\] => {"changed": true, "enabled": true, "item": "", "name": "httpd", "state": "started"}

TASK: \[determine if iptables is installed\] \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\* 
changed: \[127.0.0.1\] => {"changed": true, "cmd": \["iptables", "--version"\], "delta": "0:00:00.011655", "end": "2013-08-09 14:11:19.375786", "item": "", "rc": 0, "start": "2013-08-09 14:11:19.364131", "stderr": "", "stdout": "iptables v1.4.7"}

TASK: \[insert iptables rule for httpd\] \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\* 
changed: \[127.0.0.1\] => {"changed": true, "item": "", "msg": "line added"}

TASK: \[deploy config file for rsyslogd\] \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\* 
changed: \[127.0.0.1\] => {"changed": true, "dest": "/etc/rsyslog.d/51-awx.conf", "gid": 0, "group": "root", "item": "", "md5sum": "f732a302fd0c57e322fccc081ccf5407", "mode": "0644", "owner": "root", "size": 20, "src": "/root/.ansible/tmp/ansible-1376057479.67-227872901679182/source", "state": "file", "uid": 0}

NOTIFIED: \[restart postgresql\] \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\* 
changed: \[127.0.0.1\] => {"changed": true, "item": "", "name": "postgresql", "state": "started"}

NOTIFIED: \[restart supervisor\] \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\* 
changed: \[127.0.0.1\] => {"changed": true, "item": "", "name": "supervisord", "state": "started"}

NOTIFIED: \[restart httpd\] \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\* 
changed: \[127.0.0.1\] => {"changed": true, "item": "", "name": "httpd", "state": "started"}

NOTIFIED: \[restart apache2\] \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\* 
skipping: \[127.0.0.1\]

NOTIFIED: \[restart iptables\] \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\* 
changed: \[127.0.0.1\] => {"changed": true, "item": "", "name": "iptables", "state": "started"}

NOTIFIED: \[restart rsyslogd\] \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\* 
changed: \[127.0.0.1\] => {"changed": true, "item": "", "name": "rsyslog", "state": "started"}

PLAY \[Fedora-\*\] \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\* 
skipping: no hosts matched

PLAY \[Ubuntu-12\*:Ubuntu-13\*\] \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\* 
skipping: no hosts matched

PLAY RECAP \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\* 
127.0.0.1                  : ok=34   changed=30   unreachable=0    failed=0 
```インストール完了。`group_vars/all` の `admin_username` と `admin_password` の値でログインします。 ログインすると次のように表示されます。Webサイトに書いてあったことですね。無料で使えるのは管理対象サーバー10台までだよ。それ以上はライセンス買ってねと。

> Thank you for trying AnsibleWorks AWX. You can use this edition to manage up to 10 hosts free. Should you wish to acquire a license for additional servers, please visit the AnsibleWorks online store, or contact info@ansibleworks.com for assistance.

AWX ヒエラルキー

*   Organizations
    *   Inventories
        *   Groups
            *   Hosts
    *   Teams
        *   Credentials
        *   Permissions
        *   Users
            *   Credentials
            *   Permissions
*   Projects
    *   Playbooks
    *   Job Templates
*   Jobs

1.  まずは Organization を任意の組織名で作成する
2.  その組織にユーザーを作成する
3.  任意の名前でインベントリを作る ansible の inventory ファイルのファイル名相当
4.  サーバーのグループを作成する inventory ファイルで設定するグループ
5.  グループのサーバーを追加する。グループの下にしか作れない
6.  ユーザーに Credential を作成する。SSH のキーファイルとかパスワードとか
7.  そして、いよいよ Job を作るのだが、そのためには AWX サーバーのファイルシステム上にプロジェクト用のディレクトリを作成する必要がある。デフォルトでは /var/lib/awx/projects/ の下に作成する。
8.  で、そのディレクトリに playbook を作成する
9.  Projects タブで Create New をクリックし、Playbook Directory を選択する
10.  Job Templates タブでテンプレートを作成する
    1.  任意の名称を入力
    2.  Run か Check のタイプを選択
    3.  Inventory を作成したものから選択
    4.  Projects も先ほど作成したものを選択
    5.  Projects ディレクトリに作成した Playbook (yml) ファイルを選択
    6.  Credential を選択これでやっと作成
11.  作成された Job Template の Launch ボタンをクリックすれば Job が実行され、Job タブで状況・結果が確認できる

今日はひとまずここまで。 後でインストーラーの Playbook を読んでみよう。 2013年8月11日 追記 [続き](/2013/08/ansible-awx-part2/)を書きました。