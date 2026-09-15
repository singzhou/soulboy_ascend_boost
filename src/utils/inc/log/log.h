/**
 * Copyright (c) 2025 Huawei Technologies Co., Ltd. All rights reserved.
 * This program is free software, you can redistribute it and/or modify it under the terms and conditions of
 * CANN Open Software License Agreement Version 2.0 (the "License").
 * Please refer to the License for details. You may not use this file except in compliance with the License.
 * THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
 * INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
 * See LICENSE in the root of the software repository for the full text of the License.
 */

/*!
 * \file ops_log.h
 * \brief
 */

#ifndef OPS_H
#define OPS_H

#include "inner/dfx_base.h"

/* 基础日志 */
#define OP_LOGD(OPS_DESC, ...) OPS_LOG_STUB_D(OPS_DESC, __VA_ARGS__)
#define OP_LOGI(OPS_DESC, ...) OPS_LOG_STUB_I(OPS_DESC, __VA_ARGS__)
#define OP_LOGW(OPS_DESC, ...) OPS_LOG_STUB_W(OPS_DESC, __VA_ARGS__)
#define OP_LOGE(OPS_DESC, ...) OPS_INNER_ERR_STUB("EZ9999", OPS_DESC, __VA_ARGS__)

/* 条件日志 */
#define OP_CHECK_IF(condition, log, return_expr) \
    do {                                         \
        if (condition) {               \
            log;                                 \
            return_expr;                         \
        }                                        \
    } while (0)

#define OP_CHECK_NULL_WITH_CONTEXT(context, ptr)                                                           \
    do {                                                                                                   \
        if ((ptr) == nullptr) {                                                                  \
            const char* name = (((context) == nullptr) || (context)->GetNodeName() == nullptr) ? \
                                   "nil" :                                                                 \
                                   (context)->GetNodeName();                                               \
            OP_LOGE(name, "%s is nullptr!", #ptr);                                                         \
            return ge::GRAPH_FAILED;                                                                       \
        }                                                                                                  \
    } while (0)
#endif