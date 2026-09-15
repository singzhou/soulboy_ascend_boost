#!/usr/bin/env python3
# coding: utf-8
# Copyright (c) 2025 Huawei Technologies Co., Ltd. All rights reserved.
# This program is free software, you can redistribute it and/or modify it under the terms and conditions of
# CANN Open Software License Agreement Version 2.0 (the "License").
# Please refer to the License for details. You may not use this file except in compliance with the License.
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
# See LICENSE in the root of the software repository for the full text of the License.

import os
import glob
import logging
import shutil
import torch
from setuptools import setup, find_packages
from torch.utils.cpp_extension import BuildExtension

import torch_npu
from torch_npu.utils.cpp_extension import NpuExtension

PYTORCH_NPU_INSTALL_PATH = os.path.dirname(os.path.abspath(torch_npu.__file__))
USE_NINJA = False  # hardcoded; not reading from environment to ensure reproducibility
BASE_DIR = os.path.dirname(os.path.realpath(__file__))
logging.basicConfig(format='%(filename)s:%(lineno)d [%(levelname)s] %(message)s', level=logging.INFO)

BUILD_FLAGS = [
    '-Wsign-compare',
    '-DNDEBUG',
    '-fwrapv',
    '-fPIC',
    '-O3',
    '-Wall',
]


class ReproducibleBuildExtension(BuildExtension):
    """Build with project-owned tools and flags, not Python's sysconfig flags."""

    def build_extensions(self):
        if self.compiler.compiler_type != 'unix':
            raise RuntimeError(
                f"Unsupported compiler type for reproducible build: {self.compiler.compiler_type}"
            )

        cc_path = shutil.which('gcc')
        cxx_path = shutil.which('g++')
        if cc_path is None or cxx_path is None:
            raise RuntimeError('gcc and g++ must be available in PATH')
        cc = os.path.realpath(cc_path)
        cxx = os.path.realpath(cxx_path)

        # Refresh flags here because some torch_npu/setuptools combinations
        # replace extra_compile_args after the extension is constructed.
        for extension in self.extensions:
            extension.extra_compile_args = BUILD_FLAGS + [
                flag
                for flag in extension.extra_compile_args
                if flag not in BUILD_FLAGS and not flag.startswith('-g')
            ]

        self.compiler.set_executables(
            compiler=[cc],
            compiler_so=[cc],
            compiler_cxx=[cxx],
            linker_so=[cxx, '-shared'],
            linker_exe=[cxx],
        )

        original_spawn = self.compiler.spawn

        def spawn_without_debug(command, **kwargs):
            filtered_command = []
            for argument in command:
                if argument != '-g' and not argument.startswith('-g'):
                    filtered_command.append(argument)
            original_spawn(filtered_command, **kwargs)

        self.compiler.spawn = spawn_without_debug
        logging.info('[setup.py] fixed compile flags: %s', ' '.join(BUILD_FLAGS))
        super().build_extensions()

# Detect ACL headers
ACL_INC_DIR = os.path.join(PYTORCH_NPU_INSTALL_PATH, "include/third_party/acl/inc")


def check_acl_float8_support(acl_inc_dir):
    """Check if ACL headers define ACL_FLOAT8."""
    for root, _, files in os.walk(acl_inc_dir):
        for f in files:
            if f.endswith('.h'):
                try:
                    with open(os.path.join(root, f), 'r', errors='ignore') as fh:
                        content = fh.read()
                        if 'ACL_HIFLOAT8' in content or 'ACL_FLOAT8_E4M3FN' in content:
                            return True
                except (IOError, OSError):
                    continue
    return False

extra_compile_flags = BUILD_FLAGS + ['-I' + ACL_INC_DIR]
if check_acl_float8_support(ACL_INC_DIR):
    extra_compile_flags.append('-DSUPPORT_ACL_FLOAT8')
    logging.info("[setup.py] ACL FLOAT8 types detected, enabling SUPPORT_ACL_FLOAT8")
else:
    logging.info("[setup.py] ACL FLOAT8 types NOT detected, disabling FLOAT8 code paths")

source_files = glob.glob(os.path.join(BASE_DIR, "soulboy_custom_ops/csrc_base", "*.cpp"), recursive=True)
source_files += glob.glob(os.path.join(BASE_DIR, "soulboy_custom_ops/*/*/*/csrc", "*.cpp"), recursive=True)

exts = []
ext = NpuExtension(
    name="soulboy_custom_ops.custom_ops_lib",
    sources=source_files,
    extra_compile_args=extra_compile_flags,
)
exts.append(ext)

setup(
    name="soulboy_custom_ops",
    version='1.0',
    keywords='soulboy_custom_ops',
    ext_modules=exts,
    package_data={
        'soulboy_custom_ops': ['*.py', '*.so'],
    },
    packages=find_packages(),
    cmdclass={"build_ext": ReproducibleBuildExtension.with_options(use_ninja=USE_NINJA)},
)
