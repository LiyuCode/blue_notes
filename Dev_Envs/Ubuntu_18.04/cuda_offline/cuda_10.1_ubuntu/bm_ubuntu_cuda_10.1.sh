#!/bin/bash
set -e
#####################
## Install CUDA 10.1 on Ubuntu 18.04 64-bit LTS
##
## Usage:
##  1. put the packages downloaded from https://developer.nvidia.com/cuda-downloads
##     in the folder of this script
##  2. use './bm_ubuntu_cuda_10.1.sh' to install
##
## on ubuntu 18.04 ,need --override to skip 'cuda Error: unsupported compiler: 7.3.0.'
## Last tested on Ubuntu 18.04 64-bit LTS with "cuda_10.1.243_418.87.00_linux.run"
#####################

# files to be used
export BM_CUDA_RUN=cuda_10.1.243_418.87.00_linux.run
export BM_CUDA_PROFILE=/etc/profile.d/bm_cuda_10.1.sh

# variables
# highly recommended to use this default value
export BM_OPTION_CUDA_TOOLKITPATH=/usr/local/cuda-10.1
export BM_OPTION_CUDA_SAMPLEPATH_ROOT=$HOME
export BM_OPTION_CUDA_COPY_DOC_TO=$HOME/Documents

# fixed,dont't change these variables
export BM_OPTION_CUDA_SAMPLEPATH=$BM_OPTION_CUDA_SAMPLEPATH_ROOT/NVIDIA_CUDA-10.1_Samples

# predefined functions
function echoNotify {
  # green text with black backgroud
  echo -e "\E[32;40m"$1"\033[0m"
}

function echoWarning {
  # red text with yellow backgroud
  echo -e "\E[31;43m"$1"\033[0m"
}

function waitForKey ()
{
  echo -e "\E[31;43m"$1"\033[0m"
  if [ $2 ]; then
    read -t $2
  else
    read
  fi
}

echoWarning "===BM: Script to install CUDA 10.1 (without driver) and its patchs==="
# Usage
echoNotify ">>>Usage: put $BM_CUDA_RUN in the folder containing this script"
# Process
waitForKey ">>>BM: [Ctrl+c] to stop, [Enter] to continue or auto-exit in 5 seconds..." 5

if [ ! -f "$BM_CUDA_RUN" ]; then
  waitForKey ">>>BM: can't find $BM_CUDA_RUN under current folder $PWD. [Enter] to EXIT..."
  exit 1
fi

echoNotify ">>>BM: install CUDA 10.1 using $BM_CUDA_RUN ..."

if [ -f "$BM_CUDA_RUN" ]; then
	chmod +x $BM_CUDA_RUN
	sudo ./$BM_CUDA_RUN \
	  --silent \
	  --override \
	  --toolkit --toolkitpath=$BM_OPTION_CUDA_TOOLKITPATH \
	  --samples --samplespath=$BM_OPTION_CUDA_SAMPLEPATH_ROOT

else
	echoWarning ">>>>>>BM: haven't found $BM_CUDA_RUN, EXIT!!"
  	exit 0
fi

echoNotify ">>>BM: create/update /usr/local/cuda linking to $BM_OPTION_CUDA_TOOLKITPATH ... "
sudo ln -f -s $BM_OPTION_CUDA_TOOLKITPATH /usr/local/cuda

echoNotify ">>>BM: change the owner of $BM_OPTION_CUDA_SAMPLEPATH_ROOT to current user..."
sudo chown -R $USER $BM_OPTION_CUDA_SAMPLEPATH

echoNotify ">>>BM: update system's PATH and LD_LIBRARY_PATH variables..."
sudo bash -c "echo '#added by $USER, to install CUDA 10.1' > $BM_CUDA_PROFILE"
sudo bash -c "echo 'export CUDA_HOME=/usr/local/cuda' >> $BM_CUDA_PROFILE"
sudo bash -c "echo 'export CUDA_ROOT=/usr/local/cuda' >> $BM_CUDA_PROFILE"
sudo bash -c "echo 'export PATH=/usr/local/cuda/bin:\$PATH' >> $BM_CUDA_PROFILE"
sudo bash -c "echo 'export LD_LIBRARY_PATH=/usr/local/cuda/lib64:\$LD_LIBRARY_PATH' >> $BM_CUDA_PROFILE"
sudo bash -c "echo 'export LD_LIBRARY_PATH=/usr/local/cuda/extras/CUPTI/lib64:\$LD_LIBRARY_PATH' >> $BM_CUDA_PROFILE"
sudo bash -c "echo ' ' >> $BM_CUDA_PROFILE"
source $BM_CUDA_PROFILE #fix it <- not working

echoNotify ">>>BM: copy cuda documents to $BM_OPTION_CUDA_COPY_DOC_TO/cuda-doc..."
sudo cp -r /usr/local/cuda/doc $BM_OPTION_CUDA_COPY_DOC_TO/cuda-doc
sudo chown -R $USER $BM_OPTION_CUDA_COPY_DOC_TO

# check/summary
echoWarning ">>>BM: Installation finished. Here is a summary:"
echoNotify ">>>>>>BM: CUDA 10.1 toolkit's installation folder is $BM_OPTION_CUDA_TOOLKITPATH"
echoNotify ">>>>>>BM: A copy of CUDA documents is located at $BM_OPTION_CUDA_COPY_DOC_TO/cuda-doc"
echoNotify ">>>>>>BM: Here is 'nvcc --version'"
nvcc --version

echoNotify ">>>BM: reboot to be finished"
