# 1. Target
To install tensorflow-gpu on Windows with latest CUDA support.

# 2. Overview
## Bare OS:
OS: Winwdows Pro 64 bits, 1903, 18362.356

## Build Env:
- bazel : 0.26.1

- msys64 : MYSIS2 64 Bit, 20190524

- Visual Studio: Community 2019,  Version 16.2.5

- CUDA: 10.1
  - cuDNN : 
  - TensorRT : 

- Conda : 4.7.10, 64 bits
  - Python : 3.6.9
  
## Target:
- Tensorflow v2.0.0-rc1 with CUDA 10.1 support

# 3. Perparing the building environment

## Bazel
1. Downloading `bazel-0.26.1-windows-x86_64.exe` from `https://github.com/bazelbuild/bazel/releases/tag/0.26.1`
2. Renaming it to `bazel.exe`
2. Creating a new folder `C:\App\Tools` and place the `bazel.exe` inside it
3. Adding the folder into the `PATH` variable under the `System variables (S)` of Windows's 'Enviroment Variables'

## msys64
1. Downloading `msys2-x86_64-20190524.exe` from `https://www.msys2.org/`
2. Installing it using `C:\App\msys64` as its installtion directory
3. Adding `C:\App\msys64\usr\bin` into the `PATH` variable.
4. Executing `pacman -S git patch unzip`

## Visual Studio
1. Downloading `vs_community.exe` from `https://visualstudio.microsoft.com/downloads/`
2. Installing it with the following options:
   - In `Workload` tab, clicking `Using C++ for Desktop Devlopment`
   - In `Component` tab, ensuring `C++ 2019 redistributable update` and `MSBuild` is choosen.
3. Adding a new `System variable` named `BAZEL_VC` with value of `C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC`
4. Adding a new `System variable` named `BAZEL_VS` with value of `C:\Program Files (x86)\Microsoft Visual Studio\`
5. **Reboot** your computer

## CUDA
1. Downloading the following files:
   - `cuda_10.1.243_426.00_win10.exe` from 
   - `cudnn-10.1-windows10-x64-v7.6.3.30.zip`
   - `TensorRT-6.0.1.5.Windows10.x86_64.cuda-10.1.cudnn7.6.zip`
2. Installing the `cuda*.exe` with default configuration.
   You may do not need `Geforce Experience` component.
3. Unziping the `cudnn*.zip` directly to `C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v10.1`.
   That is , merging the subfolders inside the zip, e.g., `bin`, `lib` and `include`, to the directory.
4. Unziping the `TensorRT*.zip` to `C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v10.1`.
   That is , the subfolder of the zip file, `TensorRT-6.0.1.5`, will be placed under the directory.
5. Adding `C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v10.1\TensorRT-6.0.1.5\lib` to the `PATH`
6. Adding `C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v10.1\extras\CUPTI\lib64` to the `PATH`
7. **Reboot**

## Conda
1. Downloading `Miniconda3-latest-Windows-x86.exe` from `https://docs.conda.io/en/latest/miniconda.html`
2. Installing it to `C:\Users\alex\Miniconda3` with the following options:
    - check `Add anaconda to my PATH environment variable`
3. Run `cmd.exe` via shutcut `[Windows]+R`
4. Runing the following ones in the pop-up `cmd` window:
   - `conda create -n env_tf_v2.0.0-rc1`
   - `conda activate env_tf_v2.0.0-rc1`
   - `conda install python==3.6.9`
   - `pip install six numpy wheel`
   - `pip install keras_applications==1.0.6 --no-deps`
   - `pip install keras_preprocessing==1.0.5 --no-deps`


# 5. Install Tensorflow with CUDA support.
All commands below are typed in the same `cmd` window following in `Conda` section.

1. Cloning the codebase of `tensorflow`:

```bash
cd %HOMEPATH%
mkdir Hub
cd Hub
git clone https://github.com/tensorflow/tensorflow.git
cd tensorflow
```

2. Checking out the `v2.0.0-rc1` version:
```bash
git checkout v2.0.0-rc1
```
Besides `v2.0.0-rc1`, one can find other version tags on `https://github.com/tensorflow/tensorflow/tags`.

3. Configuration:

```bash
python configure.py

# 1. Please specify the location of python.
[Enter] # Using default `env_tf_v2.0.0-rc1`'s Python executable

# 2. Please input the desired Python library path to use.
[Enter] # Using default value

# 3. Do you wish to build TensorFlow with XLA JIT support?
[Enter] # By default, don't enable XLA JIT, see `Known issues` for detail. 

# 4. Do you wish to build TensorFlow with ROCm support? [y/N]:
[Enter] # No. ROCm is similary to CUDA but for AMD GPU

# 5. Do you wish to build TensorFlow with CUDA support? [y/N]:
y       # Yes, we do

# 6. Please specify a list of comma-separated CUDA compute capabilities you want to build with.
6.1,7.5 # Open the link in the question, find the corresponding capabilities of your GPU. I got `2080 ti` and `1060`, so "6.1,7.1"

# 7. Please specify optimization flags to use during compilation when bazel option "--config=opt" is specified [Default is /arch:AVX]:
[Enter] # TODO

# 8. Would you like to override eigen strong inline for some C++ compilation to reduce the compilation time? [Y/n]:
[Enter]
```

4. Compiling

```
bazel build --config=opt --config=cuda --config=v2 --define=no_tensorflow_py_deps=true --copt=-nvcc_options=disable-warnings //tensorflow/tools/pip_package:build_pip_package
```


5. Installation

```
# Output the compiled .whl to `c:\output_tf_pkg`
bazel-bin\tensorflow\tools\pip_package\build_pip_package C:\output_tf_pkg\
# Install it 
pip install C:\output_tf_pkg\tensorflow-2.0.0rc1-cp36-cp36m-win_amd64.whl
```

# 6. Verification
Using the code below to verify the installation:

```python
TODO
```


# 8. Known issues:
## `XLA JIT` support
When doing `python configure.py`, if one choosed to build with `XLA JIT`, there would be errors like the following:
```
# Error msg, TODO
```

## MKL support
by adding ' --config=mkl', ref https://github.com/fo40225/tensorflow-windows-wheel/issues/67

