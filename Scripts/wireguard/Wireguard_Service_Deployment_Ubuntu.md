## (可选)创建本地账号
创建一个如下内容的脚本，并运行它：

```bash
#!/bin/bash
set -e
TP_NEW_USER=a_new_user
TP_SUDOERS=/etc/sudoers
useradd -d /home/$TP_NEW_USER -m $TP_NEW_USER
echo "下面输入新账号$TP_NEW_USER的密码："
passwd $TP_NEW_USER
cp $TP_SUDOERS $TP_SUDOERS.bak
bash -c "echo '#added by $USER, to add a new user' >> $TP_SUDOERS"
bash -c "echo '$TP_NEW_USER  ALL=(ALL:ALL)  ALL' >> $TP_SUDOERS"
echo "重启系统，让新账号生效。请关闭本终端和对应的文件浏览界面。"
reboot
```


## 准备环境
```bash
cd ~
git clone https://github.com/trailofbits/algo.git
cd algo

sudo apt install -y python-is-python3
sudo apt install -y --no-install-recommends python3-virtualenv

python3 -m virtualenv --python="$(command -v python3)" .env &&
  source .env/bin/activate &&
  python3 -m pip install -U pip virtualenv &&
  python3 -m pip install -r requirements.txt

echo ">>> Perparation Done."
```


## (可选)配置
首先执行`cp $HOME/hub/algo/config.cfg $HOME/hub/algo/config.cfg.factory`对原始配置文件备份。

再执行`vi $HOME/hub/algo/config.cfg`对其进行配置。

常见的有：
 - 用户名单： `users`
 - 端口: `wireguard_port`，建议修改为其他端口


## 部署
然后输入如下命令开始配置:
```bash
# wg的监听端口将更换为如下
export NEW_WG_PORT=51200

cd ~/algo

sed -i "s/^wireguard_port:.*/wireguard_port: ${NEW_WG_PORT}/" ~/algo/config.cfg

source .env/bin/activate
sudo ./algo
```

程序会逐项提示请输入。
按次序，除如下几项外，其他默认都直接回车即可：
``` bash
# 1st. 提示如下这项时，输入`12`后回车
Enter the number of your desired provider
:

# 7th：提示如下项目，直接回车
Proceed? Press ENTER to continue or CTRL+C and A to abort...:

# 9th. 提示如下这项时，输入服务器的公网IP地址
Enter the public IP address or domain name of your server: (IMPORTANT! This is used to verify the certificate)
[localhost]
:

```

如果顺利，配置程序提示如下时，表示部署完成。

最后输出：
```bash
ok: [localhost] => {
    "msg": [
        [
            "\"#                          Congratulations!                            #\"",
            "\"#                     Your Algo server is running.                     #\"",
            "\"#    Config files and certificates are in the ./configs/ directory.    #\"",
            "\"#              Go to https://whoer.net/ after connecting               #\"",
            "\"#        and ensure that all your traffic passes through the VPN.      #\"",
            "\"#                     Local DNS resolver 172.16.234.217, fd00::ead9                   #\"",
            ""
        ],
        "    \"#        The p12 and SSH keys password for new users is {password}     #\"\n",
        "    ",
        "    "
    ]
}
```

用于客户端连接的配置文件会生成到 `$HOME/hub/algo/configs/{公网IP地址}/`文件夹下，文件名形如`desktop.conf`。

其内`apple`文件夹下的，是用于IOS设备配置连接的配置文件。


## 连接
Windows系统，使用wireguard的Windows程序，导入如上的`.conf`文件后连接即可。
