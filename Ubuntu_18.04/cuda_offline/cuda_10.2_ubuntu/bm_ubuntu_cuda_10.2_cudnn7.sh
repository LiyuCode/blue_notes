#!/bin/bash
set -e
#####################
## Install "cuDNN v7.6.5.32, for CUDA 10.2"
##
## Usage:
##  1. put the packages downloaded from https://developer.nvidia.com/rdp/cudnn-download
##     in the folder of this script
##  2. use './bm_ubuntu_cuda_10.2_cudnn7.sh' to install
##
#####################

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

# Packages to be used
## cuDNN v7.1 Library for Linux
export BM_CUDNN_ZIP=cudnn-10.2-linux-x64-v7.6.5.32.tgz
## cuDNN v7.1 Runtime Library for Ubuntu16.04 (Deb)
export BM_CUDNN_RUNTIME_DEB=libcudnn7_7.6.5.32-1+cuda10.2_amd64.deb
## cuDNN v7.1 Developer Library for Ubuntu16.04 (Deb)
export BM_CUDNN_DEVLIB_DEB=libcudnn7-dev_7.6.5.32-1+cuda10.2_amd64.deb
## cuDNN v7.1 Code Samples and User Guide for Ubuntu16.04 (Deb)
export BM_CUDNN_DOC_DEB=libcudnn7-doc_7.6.5.32-1+cuda10.2_amd64.deb


# modifiable, variables
export BM_TEMP_FOLDER=`pwd`/bm_temp_`date '+%Y%m%d-%H%M%S-%N-%Z'`
export BM_OPTION_CUDA_TOOLKITPATH=/usr/local/cuda-10.1

echoNotify ">>>BM: copy cuDNN Library to $BM_OPTION_CUDA_TOOLKITPATH..."
if [ -f "$BM_CUDNN_ZIP" ]; then
	#sudo rm -r $BM_TEMP_FOLDER
	mkdir -p $BM_TEMP_FOLDER
	tar -xvf $BM_CUDNN_ZIP -C $BM_TEMP_FOLDER
	
  sudo cp $BM_TEMP_FOLDER/cuda/include/cudnn.h $BM_OPTION_CUDA_TOOLKITPATH/include
  sudo cp $BM_TEMP_FOLDER/cuda/lib64/libcudnn* $BM_OPTION_CUDA_TOOLKITPATH/lib64
  sudo chmod a+r $BM_OPTION_CUDA_TOOLKITPATH/include/cudnn.h $BM_OPTION_CUDA_TOOLKITPATH/lib64/libcudnn*
  
  sudo rm -r $BM_TEMP_FOLDER
else
	echoWarning ">>>>>>BM: haven't found $BM_CUDNN_ZIP, skipped!!"
fi


echoNotify ">>>BM: install cuDNN Runtime Library..."
if [ -f "$BM_CUDNN_RUNTIME_DEB" ]; then
	sudo dpkg -i $BM_CUDNN_RUNTIME_DEB
else
	echoWarning ">>>>>>BM: haven't found $BM_CUDNN_RUNTIME_DEB, skipped!!"
fi

echoNotify ">>>BM: install cuDNN Developer Library..."
if [ -f "$BM_CUDNN_DEVLIB_DEB" ]; then
	sudo dpkg -i $BM_CUDNN_DEVLIB_DEB
else
	echoWarning ">>>>>>BM: haven't found $BM_CUDNN_DEVLIB_DEB, skipped!!"
fi

echoNotify ">>>BM: install cuDNN Code Samples and User Guide..."
if [ -f "$BM_CUDNN_DOC_DEB" ]; then
	sudo dpkg -i $BM_CUDNN_DOC_DEB
  cp -r /usr/src/cudnn_samples_v7/ ~
  echoNotify ">>>>>>BM: a copy of cudnn samples is located at ~/cudnn_samples_v5 "
else
	echoWarning ">>>>>>BM: haven't found $BM_CUDNN_DOC_DEB, skipped!!"
fi

echoNotify ">>>BM: install cuDNN v7.1.4, for CUDA 9.2, DONE!"
