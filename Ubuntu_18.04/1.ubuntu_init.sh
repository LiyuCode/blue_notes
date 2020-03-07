
# For Ubuntu 18.04 LTS
# 2019.12.08

PKG_DIR=$HOME/.ubuntu_init.cache

# on common_pkgs
BM_INIT_APT_REQ=1.ubuntu_init.apt_req.txt

BM_INIT_WG_CONF=1.ubuntu_init.wireguard_conf.zip
BM_INIT_WG_CMDDIR=$HOME/cmds # where the script to connect WG located in

# GIT
GIT_USER_EMAIL=$USER@$HOSTNAME.me
GIT_USER_NAME=$USER@$HOMETNAME

# on CUDA
CUDA_REPO_PKG=cuda-repo-ubuntu1804_10.1.243-1_amd64.deb
CUDA_CUDNN_REPO_PKG=nvidia-machine-learning-repo-ubuntu1804_1.0.0-1_amd64.deb
BM_CUDA_PROFILE=/etc/profile.d/bm_cuda.sh

# RUST Language
BM_RUST_PROF=/etc/profile.d/bm_rust.sh

# GO Language 
GO_PKG=go1.14.linux-amd64.tar.gz
#GO_LANG_DL_LINK=https://dl.google.com/go/$GO_PKG
GO_LANG_DL_LINK=https://studygolang.com/dl/golang/$GO_PKG
BM_GO_PROF=/etc/profile.d/bm_go.sh

# VS Code
## Ubuntu 18.04
VSCODE_REPO=https://packages.microsoft.com/ubuntu/18.04/prod


# Python: Miniconda
CONDA_PKG=Miniconda3-latest-Linux-x86_64.sh
#CONDA_DL_LINK=https://repo.anaconda.com/miniconda/$CONDA_PKG
CONDA_DL_LINK=https://mirrors.tuna.tsinghua.edu.cn/anaconda/miniconda/$CONDA_PKG


#! Change the following variables with caution
## check the CUDA version supported by Tensorflow first: https://www.tensorflow.org/install/gpu
CUDA_REPO_LINK=http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/$CUDA_REPO_PKG
CUDA_CUDNN_LINK=https://developer.download.nvidia.com/compute/machine-learning/repos/ubuntu1804/x86_64/$CUDA_CUDNN_REPO_PKG
BM_OPTION_CUDA_TOOLKITPATH=/usr/local/cuda-10.1 # the default install dir of cuda toolkit


# 2. Predefined help function
print_green() {
	# green text with black backgroud
	echo -e "\E[32;40m"$1"\033[0m"
} 

print_red() {
	# red text with black backgroud
	echo -e "\E[31;43m"$1"\033[0m"
}

waitForKey() {
  echo -e "\E[31;43m"$1"\033[0m"
  if [ $2 ]; then
    read -t $2
  else
    read
  fi
} 

if_reboot() {
	read -p ">>> Rebooting is recommened. Reboot ? [Y/n] :" yn
	[ -z "${yn}" ] && yn="y"
	if [[ $yn == [Yy] ]]; then
		print_red ">>> Rebooting..."
		reboot
	else
		print_red ">>> Please reboot later ..."
	fi
	print_green ">>> if_reboot DONE !"
}

check_if_nv_gpu() {
	if [[ $(lspci | grep -i nvidia) ]]; then
		print_green ">>> Nvidia GPU Found. Start Installation ..."
	else
		print_red ">>> No Nvidia GPU Found. Exit ..."
		exit
	fi
}

# 3. functional functions
add_common_config() {

  print_green ">>> 1. Merge /usr/local/lib/pythonX to /usr/lib/pythonX ..."

  PY_VER=("python2.7" "python3.6" "python3.7" "python3.8")
	for PY in ${PY_VER[@]};do
    if [ -h "/usr/local/lib/$PY/" ]; then
      # it's a directory and not a link, them we back up it
      sudo mv /usr/local/lib/$PY/ /usr/local/lib/$PY.bak
      sudo ln -fs /usr/lib/$PY/ /usr/local/lib/$PY
      sudo touch /usr/lib/$PY/_bm_this_is_usr_lib_$PY
    fi
	done

  print_green ">>> 2. Increase Inotify watches limite to 512k ..."
  BM_CTL_WATCH_LIMIT=/etc/sysctl.d/60-bm_increase_watch_limits.conf
  sudo bash -c "echo '# added by $USER, to increase Inotify watches limite' > $BM_CTL_WATCH_LIMIT"
  sudo bash -c "echo '# ref https://confluence.jetbrains.com/display/IDEADEV/Inotify+Watches+Limit ' >> $BM_CTL_WATCH_LIMIT"
  sudo bash -c "echo 'fs.inotify.max_user_watches = 524288' >> $BM_CTL_WATCH_LIMIT"
  sudo sysctl -p --system



  print_green ">>> 3. add repositories ..."
  #sudo add-apt-repository -y ppa:wireguard/wireguard


  print_green ">>> 4. Update/upgrade existing packages ..."
  sudo apt-get update
  sudo apt-get upgrade -y

  print_green ">>> 5. Grant user USB port access, for USB debugging. Effective after reboot"
  sudo usermod -a -G dialout $USER

  print_green ">>> 4. If you installed an Windows OS on this computer too,"
  print_green "    run 'r' to make "
  print_green "    Ubuntu 18.04 treat BIOS time as local time rather than UTC time,"
  print_green "    same as the Windows did by default."
}


add_common_pkgs() {
  print_green ">>> 1. The fowllowing packages will be installed :"
  cat $BM_INIT_APT_REQ
  print_green "  # [Enter] to continue, auto-exit in 5 seconds : " 5
  print_green "  # Installing ..."
  sudo apt-get -y -qq install $(grep -vE "^\s*#" $BM_INIT_APT_REQ  | tr "\n" " ")

  print_green ">>> 2. Configure Git ..."
  git config --global user.email $GIT_USER_EMAIL
  git config --global user.name $GIT_USER_NAME
  git config --global credential.helper store # save pwd automatically for https
}

add_python_conda() {
	print_green ">>> Task: Install Conda Python3 ..."
	print_green ">>> >>>   You will need to answer some questions ..."
	aria2c --dir=$PKG_DIR -c $CONDA_DL_LINK
	bash $PKG_DIR/$CONDA_PKG
	source ~/.bashrc
        
        conda config --set auto_activate_base false

	#print_green ">>> >>>Tsinghua University provided a repository in China, if interested ref"
	#print_green "       https://mirrors.tuna.tsinghua.edu.cn/help/anaconda/"

	print_green ">>> >>> Here is the output of 'conda --version'"
	conda --version
	
	print_green ">>> >>> To update the base env: 'conda update -n base -c defaults conda'"
	print_green ">>> >>> To activate base env by default: 'conda config --set auto_activate_base true'"
	print_green ">>> >>> Task: DONE"
}

add_wireguard() {
  sudo add-apt-repository -ry ppa:wireguard/wireguard
  sudo add-apt-repository -y ppa:wireguard/wireguard
  sudo apt install -y wireguard

  if ! [ -d "/etc/wireguard/" ]; then
    sudo mkdir /etc/wireguard/
  fi

  if ! [ -d $BM_INIT_WG_CMDDIR ]; then
    mkdir -p $BM_INIT_WG_CMDDIR
  fi

  if [ -f $BM_INIT_WG_CONF ]; then
    sudo unzip $BM_INIT_WG_CONF -d /etc/wireguard/
    echo "wg-quick up dan" > $BM_INIT_WG_CMDDIR/up_dan.sh
    echo "wg-quick down dan" > $BM_INIT_WG_CMDDIR/down_dan.sh
    chmod +x $BM_INIT_WG_CMDDIR/*.sh
    echo ">>> >>> Run the scripts in $BM_INIT_WG_CMDDIR to dis/connect Wireguard"
  fi
}

add_nv_driver() {
  check_if_nv_gpu
  sudo add-apt-repository -ry ppa:graphics-drivers/ppa
  sudo add-apt-repository -y ppa:graphics-drivers/ppa
  ubuntu-drivers devices
  sudo apt purge nvidia*
  sudo apt install -y nvidia-driver-440

}


add_cuda_cudnn() {
  check_if_nv_gpu
  # 1. fetch keys
  sudo apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/7fa2af80.pub

  # 2. install packages
  sudo apt-get update

  print_green ">>>BM: downloading and installing CUDA/CUDNN ... "

  aria2c --dir=$PKG_DIR -c  $CUDA_REPO_LINK
  aria2c --dir=$PKG_DIR -c  $CUDA_CUDNN_LINK

  sudo dpkg -i $PKG_DIR/$CUDA_REPO_PKG
  sudo dpkg -i $PKG_DIR/$CUDA_CUDNN_REPO_PKG
  sudo apt update
  sudo apt-mark hold cuda-repo-ubuntu1804

  sudo apt install -y cuda="10.1.243-1"
  sudo apt-mark hold cuda
  #sudo apt install -y cuda-drivers

  sudo apt install -y libcudnn7="7.6.4.38-1+cuda10.1"
  sudo apt-mark hold libcudnn7

  sudo apt install -y libcudnn7-dev="7.6.4.38-1+cuda10.1"
  sudo apt-mark hold libcudnn7-dev

  rt_version="6.0.1-1+cuda10.1"
  rt_libs=("libnvinfer6" "libnvonnxparsers6" "libnvparsers6" "libnvinfer-plugin6" "libnvinfer-dev" "libnvonnxparsers-dev" "libnvparsers-dev" "libnvinfer-plugin-dev")
  for rt_lib in ${rt_libs[@]};do
    sudo apt install $rt_lib=${rt_version}
    sudo apt-mark hold $rt_lib
  done

  sudo apt-mark hold libnccl2
  sudo apt install -y libnccl2="2.5.6-1+cuda10.1"
  sudo apt-mark hold libnccl-dev
  sudo apt install -y libnccl-dev="2.5.6-1+cuda10.1"

  sudo apt-mark hold cuda cuda-repo-ubuntu1804 libcudnn7 libcudnn7-dev libnccl-dev  libnccl2   libnvinfer-dev libnvinfer-plugin-dev libnvinfer-plugin6  libnvinfer6 libnvonnxparsers-dev libnvonnxparsers6 libnvparsers-dev libnvparsers6


  print_green ">>>BM: create/update /usr/local/cuda linking to $BM_OPTION_CUDA_TOOLKITPATH ... "
  sudo ln -f -s $BM_OPTION_CUDA_TOOLKITPATH /usr/local/cuda

  print_green ">>>BM: update system's PATH and LD_LIBRARY_PATH variables..."
  sudo bash -c "echo '#added by $USER, to install CUDA 10' > $BM_CUDA_PROFILE"
  sudo bash -c "echo 'export CUDA_HOME=/usr/local/cuda' >> $BM_CUDA_PROFILE"
  sudo bash -c "echo 'export CUDA_ROOT=\$CUDA_HOME' >> $BM_CUDA_PROFILE"
  sudo bash -c "echo 'export PATH=\$PATH:\$CUDA_HOME/bin' >> $BM_CUDA_PROFILE"
  sudo bash -c "echo 'export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:\$CUDA_HOME/lib64' >> $BM_CUDA_PROFILE"
  sudo bash -c "echo 'export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:\$CUDA_HOME/extras/CUPTI/lib64' >> $BM_CUDA_PROFILE"
  sudo bash -c "echo ' ' >> $BM_CUDA_PROFILE"

  source $BM_CUDA_PROFILE
}

add_gui_sw() {
 # chrome
  print_green "1. Install Google Chrome ..."
  aria2c --dir=$PKG_DIR -c https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
  sudo dpkg -i $PKG_DIR/google-chrome-stable_current_amd64.deb

 # vs code
  print_green "2. Install Visual Studio Code ..."
  curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
  sudo install -o root -g root -m 644 microsoft.gpg /etc/apt/trusted.gpg.d/
  sudo sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main" > /etc/apt/sources.list.d/vscode.list'
  sudo apt-get install -y apt-transport-https
  sudo apt-get update
  sudo apt-get install -y code # or code-insiders
  rm microsoft.gpg

 # vlc 
  print_green ">>> 3. Install VLC ..."
  sudo apt install -y vlc 
}

## Add Rust-lang
add_rust_lang() {
	print_green ">>> Task: Install RUST Lang ..."
	curl https://sh.rustup.rs -sSf | sh
	sudo bash -c "echo 'export PATH=\$PATH:$HOME/.cargo/bin' > $BM_RUST_PROF"
	source $BM_RUST_PROF
	#rustup target add thumbv6m-none-eabi thumbv7m-none-eabi thumbv7em-none-eabi thumbv7em-none-eabihf
        #cargo install cargo-binutils
        #rustup component add llvm-tools-preview
        #sudo apt install -y gdb-multiarch openocd qemu-system-arm

	print_green ">>> Rust Lang Installation DONE"
	print_green "    Here is 'rustc --version'"
	rustc --version
        print_green ">>> To apply: source $BM_RUST_PROF"

} 

## Add GO language
add_go_lang() {
	print_green ">>> Task: Install GO Lang ..."
	aria2c --dir=$PKG_DIR -c $GO_LANG_DL_LINK

  # If there is a GO in /usr/local/go , remove it, to avoid version conflicts
  [ -d /usr/local/go ] && sudo rm -rf /usr/local/go

	sudo tar -C /usr/local -xzf $PKG_DIR/$GO_PKG
	sudo bash -c "echo 'export PATH=\$PATH:/usr/local/go/bin' > $BM_GO_PROF"
  sudo bash -c "echo 'export GOPATH=$HOME/go' >> $BM_GO_PROF"

	source $BM_GO_PROF

  mkdir -p $GOPATH
	#rm $GO_PKG
	print_green ">>> GO Lang Installation DONE."
	print_green "    By default, it installed to /usr/local/go"
	print_green "    Here is 'go version'"
	go version
} 

# The Start Menu
start_menu() {
    #clear
    print_green "========================="
    print_green " A script to build a dev env on a fresh Ubuntu machine"
    print_green " Author: Alex"
    print_green " Tested on Ubuntu 19.04"
    print_green " This machine is: `lsb_release -rs`"
    print_green " Web:    L.Cai@BlueMatrix.AI"
    print_green "========================="
    print_green "1. Update system and do common configuration"
    print_green "2. Install common pkgs for programming"
    print_green "3. Install Python (Miniconda)"
    print_green "4. Install Wireguard"
    print_green "5. Install Nvidia Driver"
    print_green "6. Install Nvidia CUDA and cuDNN"
    print_green "7. Add GUI SW, e.g., Chrome, VS Code, VLC"
    print_green "8. Add Rust-lang"
    print_green "9. Add Go-lang"
    print_green "0. Exit"
    print_green
    
    read -p "Please input a option number:" num
    case "$num" in
      1)
      add_common_config
      ;;
      2)
      add_common_pkgs
      ;;
      3)
      add_python_conda
      ;;
      4)
      add_wireguard
      ;;
      5)
      add_nv_driver
      ;;
      6)
      add_cuda_cudnn
      ;;
      7)
      add_gui_sw
      ;;
      8)
      add_rust_lang
      ;;
      9)
      add_go_lang
      ;;
      0)
      exit 1
      ;;
      *)
      #clear
      print_red "Please input a correct number ..."
      start_menu
      ;;
    esac
  print_red ">>> $num : DONE!"
  start_menu
} 

# if $PKG_DIR not exists then create it
[ -e $PKG_DIR ] || mkdir -p $PKG_DIR

start_menu




# 104.19.196.151	ajax.googleapis.com
