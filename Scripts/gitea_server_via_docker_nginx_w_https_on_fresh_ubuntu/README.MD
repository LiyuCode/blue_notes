
在新安装的Ubuntu 20.04系统上，如何部署一个有如下特性的Gitea服务：
  - 可以通过`HTTPS`子域名，比如`https://gitea.my_domain.tls`来访问
  - 支持HTTPS协议来访问代码库
  - 邮件通知等功能正常
  - 以SQLite为后台数据库
  - 未支持`SSH`协议来访问代码库

#### 更新日志
 - 2022/03/27: Tag v0327, 初步整理好

https://docs.gitea.io/zh-cn/install-with-docker/#%E7%8E%AF%E5%A2%83%E5%8F%98%E9%87%8F

SSH_PORT：22：克隆 URL 中显示的 SSH 端口。
SSH_LISTEN_PORT：%(SSH_PORT)s：内置 SSH 服务器的端口。
DISABLE_SSH：false：如果不可用，请禁用 SSH 功能。如果要禁用 SSH 功能，则在安装 Gitea 时应将 SSH 端口设置为 0。



INSTALL_LOCK：false：禁止访问安装页面。
REQUIRE_SIGNIN_VIEW：false：启用此选项可强制用户登录以查看任何页面。


Inject host's SSH keys into Docker Machine with Docker Compose
https://stackoverflow.com/questions/34932490/inject-hosts-ssh-keys-into-docker-machine-with-docker-compose/34933181#34933181

-------------

This is to install Gitea on a fresh installed Ubuntu server 20.04.

Supports:
  - Git Clone via HTTPS
  - Email Server

Not Supports:
  - Git Clone via SSH