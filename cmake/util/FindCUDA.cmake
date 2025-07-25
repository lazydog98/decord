# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

#######################################################
# Enhanced version of find CUDA.
#
# Usage:
#   find_cuda(${USE_CUDA})
#
# - When USE_CUDA=ON, use auto search
# - When USE_CUDA=/path/to/cuda-path, use the cuda path
#
# Provide variables:
#
# - CUDA_FOUND
# - CUDA_INCLUDE_DIRS
# - CUDA_TOOLKIT_ROOT_DIR
# - CUDA_CUDA_LIBRARY
# - CUDA_CUDART_LIBRARY
# - CUDA_NVRTC_LIBRARY
# - CUDA_CUDNN_LIBRARY
# - CUDA_CUBLAS_LIBRARY
# - CUDA_NVIDIA_ML_LIBRARY
# - CUDA_NVCUVID_LIBRARY
#
macro(find_cuda use_cuda)
  set(__use_cuda ${use_cuda})
  if(__use_cuda STREQUAL "ON")
    # Try to find CUDA using find_package first
    find_package(CUDAToolkit QUIET)
    if(CUDAToolkit_FOUND)
      set(CUDA_FOUND TRUE)
      set(CUDA_TOOLKIT_ROOT_DIR ${CUDAToolkit_TARGET_DIR})
      set(CUDA_INCLUDE_DIRS ${CUDAToolkit_INCLUDE_DIRS})
      message(STATUS "Found CUDA using CUDAToolkit: ${CUDA_TOOLKIT_ROOT_DIR}")
    else()
      # Fallback to legacy CUDA detection
      find_package(CUDA QUIET)
      if(CUDA_FOUND)
        message(STATUS "Found CUDA using legacy method: ${CUDA_TOOLKIT_ROOT_DIR}")
      endif()
    endif()
  elseif(IS_DIRECTORY ${__use_cuda})
    set(CUDA_TOOLKIT_ROOT_DIR ${__use_cuda})
    message(STATUS "Custom CUDA_PATH=" ${CUDA_TOOLKIT_ROOT_DIR})
    set(CUDA_INCLUDE_DIRS ${CUDA_TOOLKIT_ROOT_DIR}/include)
    set(CUDA_FOUND TRUE)
    if(MSVC)
      find_library(CUDA_CUDART_LIBRARY cudart
        ${CUDA_TOOLKIT_ROOT_DIR}/lib/x64
        ${CUDA_TOOLKIT_ROOT_DIR}/lib/Win32)
    else(MSVC)
      find_library(CUDA_CUDART_LIBRARY cudart
        ${CUDA_TOOLKIT_ROOT_DIR}/lib64
        ${CUDA_TOOLKIT_ROOT_DIR}/lib)
    endif(MSVC)
  endif()
  
  # Additional validation for CUDA installation
  if(CUDA_FOUND AND NOT CUDA_TOOLKIT_ROOT_DIR)
    message(WARNING "CUDA found but CUDA_TOOLKIT_ROOT_DIR is not set. Trying to detect...")
    if(DEFINED ENV{CUDA_PATH})
      set(CUDA_TOOLKIT_ROOT_DIR $ENV{CUDA_PATH})
      message(STATUS "Using CUDA_PATH environment variable: ${CUDA_TOOLKIT_ROOT_DIR}")
    elseif(DEFINED ENV{CUDA_HOME})
      set(CUDA_TOOLKIT_ROOT_DIR $ENV{CUDA_HOME})
      message(STATUS "Using CUDA_HOME environment variable: ${CUDA_TOOLKIT_ROOT_DIR}")
    endif()
  endif()

  # additional libraries
  if(CUDA_FOUND)
    if(MSVC)
      find_library(CUDA_CUDA_LIBRARY cuda
        ${CUDA_TOOLKIT_ROOT_DIR}/lib/x64
        ${CUDA_TOOLKIT_ROOT_DIR}/lib/Win32)
      find_library(CUDA_NVRTC_LIBRARY nvrtc
        ${CUDA_TOOLKIT_ROOT_DIR}/lib/x64
        ${CUDA_TOOLKIT_ROOT_DIR}/lib/Win32)
      find_library(CUDA_CUDNN_LIBRARY cudnn
        ${CUDA_TOOLKIT_ROOT_DIR}/lib/x64
        ${CUDA_TOOLKIT_ROOT_DIR}/lib/Win32)
      find_library(CUDA_CUBLAS_LIBRARY cublas
        ${CUDA_TOOLKIT_ROOT_DIR}/lib/x64
        ${CUDA_TOOLKIT_ROOT_DIR}/lib/Win32)
      find_library(CUDA_NVIDIA_ML_LIBRARY nvml
        ${CUDA_TOOLKIT_ROOT_DIR}/lib/x64
        ${CUDA_TOOLKIT_ROOT_DIR}/lib/Win32)
      find_library(CUDA_NVCUVID_LIBRARY nvcuvid
        ${CUDA_TOOLKIT_ROOT_DIR}/lib/x64
        ${CUDA_TOOLKIT_ROOT_DIR}/lib/Win32)
    else(MSVC)
      find_library(_CUDA_CUDA_LIBRARY cuda
        PATHS ${CUDA_TOOLKIT_ROOT_DIR}
        PATH_SUFFIXES lib lib64 targets/x86_64-linux/lib targets/x86_64-linux/lib/stubs lib64/stubs
        NO_DEFAULT_PATH)
      if(_CUDA_CUDA_LIBRARY)
        set(CUDA_CUDA_LIBRARY ${_CUDA_CUDA_LIBRARY})
      endif()
      find_library(CUDA_NVRTC_LIBRARY nvrtc
        PATHS ${CUDA_TOOLKIT_ROOT_DIR}
        PATH_SUFFIXES lib lib64 targets/x86_64-linux/lib targets/x86_64-linux/lib/stubs lib64/stubs lib/x86_64-linux-gnu
        NO_DEFAULT_PATH)
      find_library(CUDA_CUDNN_LIBRARY cudnn
        ${CUDA_TOOLKIT_ROOT_DIR}/lib64
        ${CUDA_TOOLKIT_ROOT_DIR}/lib)
      find_library(CUDA_CUBLAS_LIBRARY cublas
        ${CUDA_TOOLKIT_ROOT_DIR}/lib64
        ${CUDA_TOOLKIT_ROOT_DIR}/lib)
      find_library(CUDA_NVIDIA_ML_LIBRARY nvidia-ml
        PATHS ${CUDA_TOOLKIT_ROOT_DIR}
        PATH_SUFFIXES lib lib64 targets/x86_64-linux/lib targets/x86_64-linux/lib/stubs lib64/stubs lib/x86_64-linux-gnu
        NO_DEFAULT_PATH)
      find_library(CUDA_NVCUVID_LIBRARY nvcuvid
        PATHS ${CUDA_TOOLKIT_ROOT_DIR}
          PATH_SUFFIXES lib lib64 targets/x86_64-linux/lib targets/x86_64-linux/lib/stubs lib64/stubs lib/x86_64-linux-gnu
          NO_DEFAULT_PATH
        PATHS /usr
          PATH_SUFFIXES lib/x86_64-linux-gnu NO_DEFAULT_PATH)
    endif(MSVC)
    message(STATUS "Found CUDA_TOOLKIT_ROOT_DIR=" ${CUDA_TOOLKIT_ROOT_DIR})
    message(STATUS "Found CUDA_CUDA_LIBRARY=" ${CUDA_CUDA_LIBRARY})
    message(STATUS "Found CUDA_CUDART_LIBRARY=" ${CUDA_CUDART_LIBRARY})
    message(STATUS "Found CUDA_NVRTC_LIBRARY=" ${CUDA_NVRTC_LIBRARY})
    message(STATUS "Found CUDA_CUDNN_LIBRARY=" ${CUDA_CUDNN_LIBRARY})
    message(STATUS "Found CUDA_CUBLAS_LIBRARY=" ${CUDA_CUBLAS_LIBRARY})
    message(STATUS "Found CUDA_NVIDIA_ML_LIBRARY=" ${CUDA_NVIDIA_ML_LIBRARY})
    message(STATUS "Found CUDA_NVCUVID_LIBRARY=" ${CUDA_NVCUVID_LIBRARY})
  endif(CUDA_FOUND)
endmacro(find_cuda)
