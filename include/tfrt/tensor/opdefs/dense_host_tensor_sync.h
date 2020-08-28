/*
 * Copyright 2020 The TensorFlow Runtime Authors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

//===- dense_host_tensor_sync.h - op defs for dht sync dialect --*- C++ -*-===//
//
// This file declares the 'tfrt_dht_sync' dialect.
//
//===----------------------------------------------------------------------===//

#ifndef TFRT_TENSOR_OPDEFS_DENSE_HOST_TENSOR_SYNC_H_
#define TFRT_TENSOR_OPDEFS_DENSE_HOST_TENSOR_SYNC_H_

#include "mlir/IR/Dialect.h"
#include "mlir/IR/OpDefinition.h"
#include "mlir/Interfaces/SideEffectInterfaces.h"

using namespace mlir;

namespace tfrt {
namespace dht {

// Dialect for dense host tensor operations.
class DenseHostTensorSyncDialect : public Dialect {
 public:
  static StringRef getDialectNamespace() { return "tfrt_dht_sync"; }
  explicit DenseHostTensorSyncDialect(MLIRContext *context);
};

#define GET_OP_CLASSES
#include "tfrt/tensor/opdefs/dense_host_tensor_sync.h.inc"

}  // namespace dht
}  // namespace tfrt

#endif  // TFRT_TENSOR_OPDEFS_DENSE_HOST_TENSOR_SYNC_H_
