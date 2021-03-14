ref: https://git.kernel.org/pub/scm/utils/grokmirror/grokmirror.git/tree/README.rst

Version：
1. Draft，2020/01/05
-------------

Grokmirror用于更高效地对多个git repository组成的集合进行镜像。
G使用有master mirror发布的manifest file来确认哪些repository需要clone和更新。这个过程对被镜像的mirror master和各个镜像client来说都极度轻量和高效。

## 概念
Grokmirror的master节点发布一个json格式的manifest文件。它包含旗下所有git repository的信息。该manifest文件的格式如下:

````json
    {
      "/path/to/bare/repository.git": {
        "description": "Repository description",
        "reference":   "/path/to/reference/repository.git",
        "modified":    timestamp,
        "fingerprint": sha1sum(git show-ref),
        "symlinks": [
            "/location/to/symlink",
            ...
        ],
       }
       ...
    }
````
manifest file通常时gzip格式的压缩文件来节省带宽。

每次某个repository有commit更新时，该repository会通过相应的git hook来自动更新该manifest文件中相应记录，从而使得`manifest.js`文件总是包含由各个repository的最新信息。
该信息由对应的git server和相应的repository的最新修改时间确认。

mirror client将不断的poll（拉取）该manifest.js文件，如果它比本地的副本更新则下载更新后的manifest。是否更新时通过``Last-Modified``和``If-Modified-since``http headers来判断。下载到更新后的manifest.js后，client解析它并找出哪些repository存在更新、有哪些新加的repository。

对于所有新加的repository，client将执行如下命令

````shell script
git clone --mirror git://server/path/to/repository.git \
        /local/path/to/repository.git
````

对于存在更新的repository，client执行如下命令
````
GIT_DIR=/local/path/to/repository.git git remote update
````
当带`--purge`参数运行时，各个clinet也会对manifest中不存在的repository进行`purge`操作.


### Shared Repositories
Grokmirror会自动识别哪些repository是Shared（共享的），比如RepositoryB是RepositoryA的Shared Clone（即通过`git clone -s repositoryA`）.这时，manifest会标注这些repository是reference出来的。Grokmirror会首先镜像RepositoryA，然后用`--reference`标志来镜像RepositoryB。对大的repository来说，这将极大的减少带宽和磁盘空间的占用。

更多信息参见： [git-clone](https://www.kernel.org/pub/software/scm/git/docs/git-clone.html)

##Server setup

使用您偏好的方法在服务器端安装Grokmirror。

**重要：目前仅支持bare git repository**

要实现repository有更改时，manifest也会更新，需要对在该repository下增加一个hook。该hook可以是 post-receive或 post-update 中的一种。该hook需要调用如下命令：

````
/usr/bin/grok-manifest -m /repos/manifest.js.gz -t /repos -n `pwd`
````

**-m** 参数的值为要更新的manifest.js文件的路径。
git 进程应该对该路径下文件（含manifest）有写权限。
该进程会先创建一个临时的 manifest.js，然后一次性替换掉旧的manifest，从而保证原子性。

**-t** 参数表明Grokmirror可以裁掉不必要的父目录路径值。比如某个repository的在 /var/lib/git/repository.git, 但它对外公开的是 git://server/repository.git,  则可指定`-t /var/lib/git`.

**-n** 让Grokmirror使用当前时间戳而非各个repository的最新commit的确切时间戳。这能加快速度。

在启用hook之前，需要先生成一个对用所有repository信息的manifest.js文件。使用上面的命令即可达到，但需忽略 `-t` 参数和对应的值`pwd`:

````
/usr/bin/grok-manifest -m /repos/manifest.js.gz -t /repos
````

最后一步是实现自动删除那些manifest中purged掉了的repository。
这不能通过一个 git hook 来实现。可通过如下之一实现：

1. 在Cron中执行`--purge`命令:
````
/usr/bin/grok-manifest -m /repos/manifest.js.gz -t /repos -p
````

2. 通过`--remove`标签，加入到gitolite的`D`命令中:
````
/usr/bin/grok-manifest -m /repos/manifest.js.gz -t /repos -x $repo.git
````

If you would like grok-manifest to honor the ``git-daemon-export-ok``magic file and only add to the manifest those repositories specifically marked as exportable, pass the ``--check-export-ok`` flag. See ``git-daemon(1)`` for more info on ``git-daemon-export-ok`` file.

### Mirror Setup
首先，安装Grokmirror。

确认 repos.conf文件，并根据需要修改它。

根据所期望频率来新增一个cronjob。比如将如下内容新增到`/etc/cron.d/grokmirror.cron` 文件中：

````
# Run grok-pull every minute as user "mirror"
* * * * * mirror /usr/bin/grok-pull -p -c /etc/grokmirror/repos.conf
````

确保用户`mirror`（或您所指定的用户）能对在repos.conf文件中指定的存放各个repository的toplevel（父目录）和 log 路径有写入权限。

如果您已经下载了一系列的repository，且他们的路径结构（hierarchy）和服务器上的相同，而您又想要重用它们而不是从服务器上全部重新下载，则可加上`-r`标识来让Grok-pull知道是可以重新已有的repository。
This will delete any existing remotes defined in the repository and set the new origin to match what is configured in the repos.conf.

#### GROK-FSCK
无论是否有经常更新，git repository都可能不完整。因此，有规律地使用`git fsck`命令来检查它们是有用的。
Grokmirror自带了一个 `grok-fsck` 组件来对各个被镜像的git repository执行`git fsck`命令。
按设计，它应该通过cron设定为每晚执行，并且随机抽取部分repository检查。所有的错误会发送到`MAILTO`所指定的用户。

`Grok-fsck`可通过如下方式启用：
1. 找到并编辑`fsck.conf`文件。编辑内容包括比如本地manifest的路径。
2. 将如下内容加入到`/etc/cron.d/grok-fsck.cron`:
````
# Make sure MAILTO is set, for error reports
MAILTO=root
 # Run nightly repacks to optimize the repos
0 2 1-6 * * mirror /usr/bin/grok-fsck -c /etc/grokmirror/fsck.conf --repack-only
# Run weekly fsck checks on Sunday
0 2 0 * * mirror /usr/bin/grok-fsck -c /etc/grokmirror/fsck.conf
````
您可通过`-f`参数来完整地对所有repository进行检查。如果repository的集合较大，这会需要数小时来完成，故不推荐这样做。使用`man grok-fsck` 来查看支持的其他参数。

检查前，`grok-fsck`会在要检查的git目录下放置advisory lock （劝告锁，`.repository.git.lock`）。Grok-pull命令会识别该锁，并延迟后续更新，知道该锁解除。

### FAQ

Why is it called "grok mirror"?
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Because it's developed at kernel.org and "grok" is a mirror of "korg".
Also, because it groks git mirroring.

为何不使用rsync?
~~~~~~~~~~~~~~~~~~~~~~~
对于大部分是由大量很少被更新的小文件构成的git tree来说，Rsync在镜像它们上十分低效。
Rsync每次运行时，都需要计算每个文件的checksum，从而会有大量的磁盘读取/抖动（thrashing）。

另外，这样做本身也不合理，因为git已自带了十分高效的机制来指出各个文件不同版本之间的变更。

为何不每分钟调用一次 “git pull”
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
这并不是一个完整的镜像策略，它并不会通知用户当由新的repository加入时。
对于服务器，特别是驻有数百个repository的，这也并不好。
另外，git pull 也不会自动处理 shared repository。
