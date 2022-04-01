当前的操作环境是刚新安装Ubuntu 20.04系统，实际主机可以是云服务器或本地服务器。
#### 更新日志
 - 2022/03/27: Tag v0327, 初步整理好

在新安装的Ubuntu 20.04系统上，如何部署一个有如下特性的Gitea服务：
  - 可以通过`HTTPS`子域名，比如`https://sub_domain.domian.tld`来访问
  - 支持HTTPS协议来访问代码库
  - 邮件通知等功能正常
  - 以SQLite为后台数据库
  - 未支持`SSH`协议来访问代码库

变量说明：
  - sub_domain.domian.tld 指代实际要用的子域名，比如`gitea.mysite.com`
  - my_gitea_service_name 指代要运行的gitea服务的名字，比如`MyGitea_at_mysite`

请如下实际操作时，做对应修改。

# 安装docker和docker-compose
```bash
# 更新现有的随系统安装的软件库
sudo apt update
sudo apt upgrade -y

sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb https://download.docker.com/linux/ubuntu focal stable"

sudo apt-cache policy docker-ce

sudo apt install -y docker-ce # ver:5:20.10.13~3-0~ubuntu-focal
sudo apt install -y docker-compose # ver:1.25.0-1

sudo apt-mark hold docker-ce docker-compose 
sudo apt-mark hold linux-image-generic linux-headers-generic

# 将当前用户加入到docker用户组，这样不需要sudo即可执行docker命令
id ${USER}
sudo usermod -aG docker ${USER}
# 使得上述用户组更新生效
newgrp docker
# 查看docker组的情况
cat /etc/group | grep docker
# 重启docker服务
sudo service docker restart
## 查看当前用户的分组情况，会看到其在`docker`内
id ${USER}

# （可选）重启系统总是可以让组信息更新的
echo ">>> Done. Pls reboot ..."
#sudo reboot
```

# (可选) 云平台配置
如果将要搭建Gitea服务的主机是不是本地的服务器，而是云服务商提供的。
视具体情况，可能需要对其存储、防火墙等进行配置。

下面以腾讯云上的云主机为例，说明如何挂载云硬盘和设置防火墙。
如果主机是本地服务器，则可跳过本段。

## （可选）挂载云硬盘
https://cloud.tencent.com/document/product/1207/63919

### 首次需创建分区
如果是首次操作，需要先在网页上操作，关联云主机和云硬盘。
之后进行如下操作在云硬盘(`vdb`)创建分区并格式化：
```bash
sudo fdisk -l # 应该看到有多了一个云硬盘`/dev/vdb`
sudo parted -s /dev/vdb mklabel gpt
sudo parted -s /dev/vdb unit mib mkpart primary 0% 100%
sudo mkfs -t ext4 /dev/vdb1
``` 
### 挂载云硬盘分区
如果是`重装系统`，则不需要进行上述操作。

继续如下来挂载该分区：
```bash
# 创建路径用于挂载分区
sudo mkdir /vdata

# 将挂载命令写入fstab，这样重启时也会自动挂载
sudo sh -c 'echo "" >> /etc/fstab'
sudo sh -c 'echo "#`date`, $USER: to mount the cloud disk vdb" >> /etc/fstab'
sudo sh -c 'echo "/dev/vdb1 /vdata ext4 defaults,noatime,nofail 0 0 " >> /etc/fstab'

# 现在手工挂载
sudo mount /vdata # 或 `sudo mount -a`


echo ">>> Verifying ..."
# 查看挂载状态
sudo df -TH | grep vdb1 # 有vdb1的挂载记录则表示挂载成功
sudo cat /etc/fstab
```

经过如上操作后，新增加的云硬盘（分区）在云主机重启时也会自动被挂载上。

### 创建运行时目录
继续创建一个目录`/docker_data`专用于存放后续所有docker容器（含Gitea）的运行数据：

```bash
sudo mkdir /vdata/docker_data
sudo ln -s /vdata/docker_data /docker_data
```

到这里已完成云硬盘挂载，并在其上面创建了一个文件夹`/vdata/docker_data`用户存放后续docker容器的数据。
该文件夹同时可以通过`/docker_data`访问到。


## （可选）腾讯云上的 防火墙设置 (#TODO)

如果后续使用的SSH通讯端口不是`22`，比如实际下面会是`2222`，还会需要确保云主机对应的防火墙开放了该端口。

以腾讯云上的 防火墙设置 为例，这会需要在腾讯云的对应主机的`防火墙`配置页面上，点击`添加规则`:
```bash
应用类型：自定义
限制来源：不要勾选`启用`
协议：TCP
端口：2222
策略：允许
备注：docker container: my_gitea_service_name 的SSH访问端口
```

## (可选)本地环境添加Host记录
```bash
sudo sh -c 'echo "" >> /etc/hosts'
sudo sh -c 'echo "# Added to support Gitea on localhost" >> /etc/hosts'
sudo sh -c 'echo "127.0.0.1 sub_domain.domian.tld" >> /etc/hosts'

# 在Ubuntu 20.04上述变动会立即生效
# 测试：
ping sub_domain.domian.tld # 应该被解析为`127.0.0.1`
```

# 部署Nginx
要使得用户可以直接通过子域名访问到Gitea服务站点，或通过HTTP(S)访问到代码库，
会需对Gitea HTTP(s)端口的访问进行代理。
这里用Nginx。

先运行如下命令安装Nginx：
```bash
sudo apt install -y nginx-full # ver:1.18.0-0ubuntu1.2
```

## 准备证书
HTTPS访问的实现会需要用到子域名sub_domain.domian.tld的SSL证书。

```
sudo mkdir -p /etc/nginx/conf.d/certs
```
然后其所有的SSL证书上传到`/etc/nginx/conf.d/certs`

它们包括如下两文件：
 - sub_domain.domian.tld_bundle.crt
 - sub_domain.domian.tld.key

## 配置HTTP(S)转发

`sudo vim /etc/nginx/sites-available/sub_domain.domian.tld.conf`, 内容如下：
```bash
server {
    listen 443 ssl;
    #填写绑定证书的域名
    server_name sub_domain.domian.tld;
    #证书文件名称
    ssl_certificate /etc/nginx/conf.d/certs/sub_domain.domian.tld_bundle.crt;
    #私钥文件名称
    ssl_certificate_key /etc/nginx/conf.d/certs/sub_domain.domian.tld.key;
    ssl_session_timeout 5m;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE:ECDH:AES:HIGH:!NULL:!aNULL:!MD5:!ADH:!RC4;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;

    location / {
        # 单次提交最大200MB的文件
        client_max_body_size 200m;
        proxy_pass http://127.0.0.1:33000;
        proxy_set_header Host $host:$server_port;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header REMOTE-HOST $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    location ~ .* {
        client_max_body_size 200m;
        proxy_pass http://127.0.0.1:33000;
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
server {
    listen 80;
    #填写绑定证书的域名
    server_name sub_domain.domian.tld;

    # 单次提交最多耗时10分钟
    client_header_timeout 10m;
    #把http的域名请求转成https
    return 301 https://$host$request_uri;
}

```

然后依次输入如下命令来启用该解析：
```bash
# 使得domain.tld的指向配置生效
sudo ln -s /etc/nginx/sites-available/sub_domain.domian.tld.conf /etc/nginx/sites-enabled/
# 测试各配置是否正常
sudo nginx -t
# 重启nginx，使得新配置生效
sudo service nginx restart
```

到这里，Nginx 会将所有`sub_domain.domian.tld`的访问转为对33000端口的访问。
下面部署Gitea，并使其通过33000端口提供http(s)服务。

# 部署Gitea
## 准备Docker数据目录
我们会在Ubuntu上通过docker运行一个名为`my_gitea_service_name`的容器来提供Gitea服务。

为方便维护，下面会创建一个目录（路径）用于存放其运行时的数据。

在那之前，我们可以创建一个名为`gitea_users`的用户组，使得该组下的用户都能读写该目录。

```bash
# 创建一个用户组`gitea_users`， 组ID为1200
sudo groupadd -g 1200 gitea_users
# 将当前用户加入到该组内
sudo usermod -aG gitea_users $USER

# 创建一个目录用于存放Gitea运行时的数据
sudo mkdir -p /docker_data/my_gitea_service_name/data
# 将上述目录归于`gitea_user`用户组
sudo chgrp -R gitea_users /docker_data/my_gitea_service_name
# 使得该用户组的用户都能读写该目录
sudo chmod -R g+rwx /docker_data/my_gitea_service_name

# 使得上述加入立即生效
newgrp gitea_users # Ubuntu 20.04上似乎不需要
```


## 准备Gitea安装配置

下面编写一个docker-compose配置文件，用于指定gitea（容器）安装时的各种配置：
执行`vim /docker_data/my_gitea_service_name/docker-compose.yml`创建并打开该文件，并添加如下为其内容：
```yml
version: "3"

networks:
  gitea:
    external: false

volumes:
  gitea:
    driver: local

services:
  server:
    image: gitea/gitea:1.16.5
    # 运行Gitea服务的容器名称
    container_name: my_gitea_service_name
    environment:
      # 基本信息
      ## Gitea网站上显示的站点名
      - APP_NAME="Gitea:domian.tld"
      ## Gitea服务启动的模式，默认：`XXX`
      ### dev: 调试模式
      ### prod: 生产模式
      ### test: 测试模式
      - RUN_MODE=prod
      # my_gitea_service_name 内执行各种操作的用户的ID，默认：`localhost:3306`
      - USER_UID=1201
      # 上述用户所在的用户组的ID，默认：`localhost:3306`
      - USER_GID=1200
      # 上述用户的用户名，默认：`git`      
      - USER=gitea_admin

      # [database]:https://docs.gitea.io/en-us/config-cheat-sheet/#database-database
      ## 要使用的数据库的类型，默认：`localhost:3306`
      ### 可选值有：mysql，postgres，mssql，sqlite3
      - GITEA__database__DB_TYPE=sqlite3
      ## 仅对SQLite3有效。数据库文件的路径：
      - GITEA__database__DB_PATH="/data/gitea/gitea.db"

      # [repository]
      - GITEA__repository__DEFAULT_PRIVATE=private

      # [Server]:https://docs.gitea.io/en-us/config-cheat-sheet/#server-server
      - GITEA__server__DOMAIN=sub_domain.domian.tld
      ## 代码仓库页面里，提示用户Git Clone over SSH 的链接时，显示的域名
      - GITEA__server__SSH_DOMAIN=sub_domain.domian.tld
      - GITEA__server__HTTP_PORT=3000
      - GITEA__server__ROOT_URL=https://sub_domain.domian.tld/
      ## 是否禁用Git Clone over SSH，默认：`false`
      ## false:提供SSH访问功能
      ## true: 禁用该功能。注：此时应同时将`SSH_PORT`设为0
      - GITEA__server__DISABLE_SSH=true
      # 代码仓库页面里，提示用户Git Clone over SSH 的链接时，显示的端口，默认：`2222`
      - GITEA__server__SSH_PORT=0
      # my_gitea_service_name本身运行时对Git Clone over SSH请求所实际监听的端口，默认：`22`
      - GITEA__server__SSH_LISTEN_PORT=22
      - GITEA__server__OFFLINE_MODE=false
      - GITEA__server__LANDING_PAGE=home

      # [Service]
      - GITEA__service__DEFAULT_USER_IS_RESTRICTED=true
      - GITEA__service__OFFLINE_MODE=true
      ## 是否禁用用户注册功能，默认：`false`
      ### false: 会在首页提供用户注册功能
      ### true:  仅能通过管理员来增加用户
      - GITEA__service__DISABLE_REGISTRATION=true
      ## 是否需要登录才能在`探索`页面看到公开的用户或代码仓库，默认：`false`
      ### false: 未登陆前，能看到
      ### true:  未登陆前，看不到
      - GITEA__service__REQUIRE_SIGNIN_VIEW=true
      - GITEA__service__REGISTER_EMAIL_CONFIRM=true
      - GITEA__service__ENABLE_NOTIFY_MAIL=true
      - GITEA__service__ALLOW_ONLY_EXTERNAL_REGISTRATION=false
      - GITEA__service__ENABLE_CAPTCHA=false
      - GITEA__service__DEFAULT_KEEP_EMAIL_PRIVATE=false
      - GITEA__service__DEFAULT_ALLOW_CREATE_ORGANIZATION=true
      - GITEA__service__DEFAULT_ENABLE_TIMETRACKING=true
      - GITEA__service__NO_REPLY_ADDRESS=noreply.sub_domain.domian.tld
      - GITEA__service__DEFAULT_KEEP_EMAIL_PRIVATE=true

      # [Admin]
      - GITEA__admin__DEFAULT_EMAIL_NOTIFICATIONS=enabled
      - GITEA__admin__DISABLE_REGULAR_ORG_CREATION=false

      # [Security]
      - GITEA__security__LOGIN_REMEMBER_DAYS=2
      - GITEA__security__PASSWORD_HASH_ALGO=pbkdf2

      # [OpenID]
      - GITEA__openid__ENABLE_OPENID_SIGNIN=false
      - GITEA__openid__ENABLE_OPENID_SIGNUP=false

      # [Picture]
      - GITEA__picture__DISABLE_GRAVATAR=true
      - GITEA__picture__ENABLE_FEDERATED_AVATAR=false

    # 设置my_gitea_service_name容器自动重启
    restart: always
    networks:
      - gitea
    volumes:
      - /docker_data/my_gitea_service_name/data:/data
      - /etc/timezone:/etc/timezone:ro
      - /etc/localtime:/etc/localtime:ro
    ports:
      - "33000:3000"
      - "2222:22"
```

细节：
  - Gitea运行的所有参数参见页面：https://docs.gitea.io/en-us/config-cheat-sheet。
  - 如果要在docker-compose.yml指定某一参数，则如上在`environment`加入对应的变量名称即可。
  - 加入变量对应的名称时，变量应该按照`GITEA__$SECTION__$KEYNAME`的格式命名。
    - 比如页面上`picture`section下的`DISABLE_GRAVATAR`参数，其变量名称应该为`GITEA__picture__DISABLE_GRAVATAR`。
    - 这种对应关系在如下提到：https://docs.gitea.io/en-us/install-with-docker/#managing-deployments-with-environment-variables。
  - 上面对部分敏感的参数没有指定，比如SMTP用户名和密码、管理员的用户名和密码。
    - 指定敏感信息的合理的方式之一是通过`Docker Secrets`特性来实现
    - 但本文先不讨论。

现在执行命令：
```bash
# 使用该配置文件构建并启动gitea容器
docker-compose -f /docker_data/my_gitea_service_name/docker-compose.yml up -d
# 列出所有正在运行的容器
docker ps
```

## Gitea初始配置
现在打开浏览器，输入"sub_domain.domian.tld"便会打开Gitea的初始配置页面。

页面中部分已经使用了上面`docker-compose.yml`配置文件的`environment`下的变量所定义的参数。

但如`电子邮箱设置`和`管理员账号设置`两项涉及密码等敏感信息，故没有写入配置文件中。请参照实际情况填写。

这边填写/更新后的页面信息如下：

```bash
[数据库设置/Database Settings]
`数据库类型/Database Type` = SQLite3
`数据库文件路径/Path` = /data/gitea/gitea.db

[一般设置/Gnearl Settings]
`站点名称/Site Title` = Gitea:domain.tld
`仓库根目录/Repository Root Path` = /data/git/repositories
`LFS根目录/Git LFS Root Path` = /data/git/lfs
`以用户名运行/Run As Username` = gitea_admin
`服务器域名/Server Domain` = sub_domain.domian.tld
`SSH 服务端口/SSH Server Port` = 0
`HTTP 服务端口/Gitea HTTP Listen Port` = 3000
`基础URL/Gitea Base URL` = https://sub_domain.domian.tld
`SMTP 密码/日志路径/Log Path` = /data/gitea/log

[可选设置/Optional Settings]
[电子邮箱设置/Email Settings]
`SMTP 主机/SMTP Host` = smtp.domain.tld:465
`电子邮件发件人/Send Email As` = "domain.tld Gitea" <support@domain.tld>
`SMTP 用户名/SMTP Username` = support@domain.tld
`SMTP 密码/SMTP Password` = your_smtp_pwd

`需要发电子邮件确认注册/Require Email Confirmation to Register` = [Checked/勾选]
`启用邮件通知提醒/Enable email Notifications` = [Checked/勾选]

[服务器和第三方服务设置/Administrator Account Settings]
`启用本地模式/Enable Local Mode` = [Checked/勾选]
`禁用Gravatar头像/Disable Gravatar` = [Checked/勾选]
`启用Federated 头像/Enable Federated Avatars` = [UnChecked/不勾选]
`启用OpenID登录/Enable OpenID Sign-In` = [UnChecked/不勾选]
`禁止用户自助注册/Diable Self-registration` = [Checked/勾选]
`仅允许通过外部服务注册/Allow Registration Only Through External Services` = [UnChecked/不勾选]
`启用OpenID自助注册/Enable OpenID Self-Registration` = [UnChecked/不勾选]
`启用注册验证码/Enable registration CAPTCHA` = [UnChecked/不勾选]
`启用页面访问限制/Require Sign-In to View Pages` = [UnChecked/不勾选]
`默认情况下隐藏电子邮件/Hide Email Addresses by Default` = [Checked/勾选]
`默认情况下允许创建组织/Allow Creation of Organizations by Default` = [Checked/勾选]
`默认情况下启用时间跟踪/Enable Time Tracking by Default` = [UnChecked/不勾选]

`隐藏电子邮件域/Hidden Email Domain`= noreply.sub_domain.domian.tld
`密码哈希算法/Password Hash Algorithm` = argon2

[管理员账号设置/Administrator Account Settings]
`管理员用户名/Administrator Username` = my_gitea_service_name_admin
`管理员密码/Password` = C3
`确认密码Confirm Password` = C3
`电子邮件地址/Email Address` = support@domain.tld
```

点击`install Gitea` 开始安装。
安装完成后，页面会自动跳转到登录页面。若无显示，按F5强制刷新。 到此，基本配置已经完成，下面验证。


# 验证基础配置
## 邮件发送功能
  应用配置->邮件配置->[填写邮件地址]里填收件人邮箱地址->点击`发送测试邮件`。

  若发送成功，页面会有消息提醒`测试邮件已经发送至 '$填写的邮箱地址'`。
  该收件邮箱地址，也会收到一封标题为`Gitea Test Email! `的测试邮件。

  如果失败，比如页面提示`504 Gateway Time-out`，请参见如下的`FAQ - 测试邮件发送失败`。

## 验证HTTP Clone功能
  通过页面创建一个测试的代码仓库，比如`TestProj`。
  创建后，页面应该会提示`克隆当前仓库`下的`HTTPS`地址为`https://sub_domain.domian.tld/ibb_admin/TestCodebase.git`。

  在自己的工作电脑上，输入如下命令进行克隆`git clone https://my_username@sub_domain.domian.tld/creator_username/TestProj.git`
  其中的两处`my_username`和`creator_username`分别是用于访问该仓库地址的用户名和该仓库创建者的用户名。请参照实际情况修改。

## 验证SSH Clone功能 (#TODO)
  本文的部署中禁用了通过SSH来访问代码仓库的功能。


到此，我们在Ubuntu系统上，用Docker容器部署了Gitea服务，且该服务站点借助`Nginx`能通过子域名`sub_domain.domian.tld`以HTTPS协议来访问。

# 维护
## 如何更新配置
  按如上Gitea on Docker创建完后，其配置文件位于`/docker_data/my_gitea_service_name/data/gitea/conf/app.ini`。
  要修改配置，更新该文件内容即可。步骤如：
  ```bash
  # 停止正在运行的Gitea站点服务
  docker stop my_gitea_service_name
  vim /docker_data/my_gitea_service_name/data/gitea/conf/app.ini #修改某些配置
  # 重启Gitea服务，重启时会使用app.ini中的信息
  docker restart my_gitea_service_name
  ```
  
  Gitea运行时所有的参数可参见： https://docs.gitea.io/en-us/config-cheat-sheet/ 。
  以修改站名为`New Gitea Site Name`为例，可以将上述`app.ini`文件里的`APP_NAME`对应的值修改为`New Gitea Site Name`。
  然后`docker restart my_gitea_service_name`，重启Gitea。再访问`sub_domain.domian.tld`时，会发现站点标题为上述的`New Gitea Site Name`。

  另外以修改创建用户时默认其信息非公开可见为例，可以向上面配置文件内的`[service]`项下添加`DEFAULT_USER_VISIBILITY = private`。
  然后`docker restart my_gitea_service_name`，重启Gitea。再创建用户时，会发现默认其用户信息不可见。即如果没有登录Gitea，在`探索`->` 用户`中不会显示该用户。

  Gitea运行的所有的参数可参见如下sheet： https://docs.gitea.io/en-us/config-cheat-sheet/ 。
  按如上Gitea on Docker创建完后，其配置文件位于`/docker_data/my_gitea_service_name/data/gitea/conf/app.ini`。
  要修改配置，更新该文件内的对应内容后重启Gitea即可。

## 备份与恢复(#TODO)

  ###  备份
  https://docs.gitea.io/en-us/backup-and-restore/#using-docker-dump
  在Ubuntu上运行如下命令：
  ```bash
  mkdir /docker_data/my_gitea_service_name/data/backups
  docker exec -u gitea_admin -it -w /data/backups $(docker ps -qf 'name=^my_gitea_service_name$') bash -c '/app/gitea/gitea dump -c /data/gitea/conf/app.ini'
  ```

  备份文件位于`/docker_data/my_gitea_service_name/data/backups`：
  ```bash
  u@u20:/docker_data/my_gitea_service_name/data/backups$ ls
  gitea-dump-1648364573.zip
  ```

  ### 恢复
  https://docs.gitea.io/en-us/backup-and-restore/#using-docker-restore

# 常见问题
## 不能通过SSH访问repos
  是的，本文里没有设置该功能。
  有兴趣的参见：
   - https://docs.gitea.io/en-us/faq/#ssh-issues
   - https://docs.gitea.io/en-us/install-with-docker/#ssh-container-passthrough
   - [Inject host's SSH keys into Docker Machine with Docker Compose](https://stackoverflow.com/questions/34932490/inject-hosts-ssh-keys-into-docker-machine-with-docker-compose/34933181#34933181)

## 测试邮件发送失败
  常见出错地方如下：
  - 确认端口填写是否正确
  - 确认发送者邮箱是否拼写正确
  - 确认邮箱本身是否开启了SMTP服务
  - SMTP对用的服务器地址，你的服务器是否能访问到。
    - 比如在Gitea部署在国内云上，而SMTP使用的服务器地址不能访问到的国外域名的。

## 密码Hash算法的选择
  - 默认选pbkdf2
  - 内存足够的情况下，请考虑`argon2`会更安全
  - 差别请自行搜索
