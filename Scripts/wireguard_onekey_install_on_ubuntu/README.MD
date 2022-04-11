来源：
  - https://teddysun.com/554.html/comment-page-3
  - https://github.com/teddysun/across

以`root`身份登录bash终端，再依次执行如下步骤。

环境：
  - 新安装的Ubuntu 20.04 系统
  - 以`root`用户名登录


# 准备
```bash
apt update
wget --no-check-certificate -O /opt/wireguard.sh https://raw.githubusercontent.com/teddysun/across/master/wireguard.sh
chmod 755 /opt/wireguard.sh
```

# 配置

```bash
# 默认为从 1024 到 20480 随机端口，以下为指定端口
export VPN_SERVER_WG_PORT=12560
# 默认DNS 1为1.1.1.1
export VPN_CLIENT_DNS_1=1.1.1.1
# 默认DNS 2为8.8.8.8
export VPN_CLIENT_DNS_2=8.8.8.8
```

# 安装

```bash
# 从源码安装
/opt/wireguard.sh -s
```

# 使用

```bash 
cp /etc/wireguard/wg0_client ~/wg0_client.conf
cp /etc/wireguard/wg0_client.png ~/wg0_client.png
```

上面两个`.conf`和 `.png`文件即为用于Windows/Linux 和 Android客户端的配置文件。

# 维护

```bash
# 查看已安装 WireGuard 版本号
/opt/wireguard.sh -v

# 编译升级 WireGuard 到当前最新版本
/opt/wireguard.sh -u

# 新增 WireGuard 客户端配置
/opt/wireguard.sh -a

# 删除 WireGuard 客户端配置
# 注意：默认客户端 wg0 不允许删除
/opt/wireguard.sh -d

# 列出 WireGuard 客户端配置
/opt/wireguard.sh -l
```

