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

//===- request_handler.cc - Request Handler --------------*- C++ -*--------===//
//
// This file contains implementation of RequestHandler class.
//
//===----------------------------------------------------------------------===//
#include "tfrt/distributed_runtime/request_handler.h"

#include <llvm/Support/SourceMgr.h>

#include <unordered_map>

#include "llvm/Support/Error.h"
#include "llvm/Support/raw_ostream.h"
#include "mlir/IR/MLIRContext.h"
#include "mlir/IR/Module.h"
#include "mlir/Parser.h"
#include "tfrt/bef_converter/mlir_to_bef.h"
#include "tfrt/bef_executor/bef_file.h"
#include "tfrt/host_context/concurrent_work_queue.h"
#include "tfrt/host_context/function.h"
#include "tfrt/host_context/host_allocator.h"
#include "tfrt/host_context/host_context.h"
#include "tfrt/support/aligned_buffer.h"

namespace tfrt {

// TODO(bramandia): Replace this with TFRT FunctionLibrary once available.
class RequestHandler::FunctionCache {
 public:
  explicit FunctionCache(HostContext* host_context) : host_(host_context) {}

  // Register the given program. A program can have multiple functions in it.
  // The program_name serves as both unique ID of this program.
  void Register(const std::string& program_name,
                mlir::OwningModuleRef&& module);

  // Create BEFFile corresponding to the program with the given name.
  RCReference<BEFFile> Prepare(const std::string& program_name);

 private:
  HostContext* host_;

  mutex cached_bef_mutex_;
  // A struct representing a BEFFile and the respective buffer.
  struct CachedBEF {
    RCReference<BEFFile> bef_file;
    std::unique_ptr<tfrt::AlignedBuffer<8>> bef_buffer;
  };
  // Map from the program name to the CachedBEF.
  std::unordered_map<std::string, CachedBEF> cached_bef_
      TFRT_GUARDED_BY(cached_bef_mutex_);
};

void RequestHandler::FunctionCache::Register(const std::string& program_name,
                                             mlir::OwningModuleRef&& module) {
  // TODO(bramandia): Propagate errors to caller.
  auto tmp_bef = tfrt::ConvertMLIRToBEF(module.get(),
                                        /* disable_optional_sections = */ true);
  if (tmp_bef.empty()) {
    TFRT_LOG(ERROR) << tfrt::StrCat("Failed to convert MLIR to BEF: ",
                                    program_name);
  }
  auto bef_buffer =
      std::make_unique<tfrt::AlignedBuffer<8>>(std::move(tmp_bef));
  RCReference<BEFFile> bef_file =
      tfrt::BEFFile::Open(*bef_buffer, host_->GetMutableRegistry(),
                          host_->diag_handler(), host_->allocator());

  if (!bef_file) {
    TFRT_LOG(ERROR) << tfrt::StrCat("Failed to open lowered BEF for function ",
                                    program_name, ".");
    return;
  }
  mutex_lock lock(cached_bef_mutex_);
  cached_bef_[program_name].bef_file = bef_file.CopyRef();
  cached_bef_[program_name].bef_buffer = std::move(bef_buffer);
}

RCReference<BEFFile> RequestHandler::FunctionCache::Prepare(
    const std::string& program_name) {
  mutex_lock lock(cached_bef_mutex_);
  auto iter = cached_bef_.find(program_name);
  if (iter != cached_bef_.end()) {
    return iter->second.bef_file.CopyRef();
  }
  return RCReference<BEFFile>();
}

RequestHandler::RequestHandler() {
  auto diag_handler = [](const DecodedDiagnostic& diag) {
    llvm::errs() << diag.message;
  };

  // TODO(bramandia): Figure out remote configuration.
  host_context_ = std::make_unique<HostContext>(
      diag_handler, CreateMallocAllocator(),
      CreateMultiThreadedWorkQueue(/*num_threads=*/4,
                                   /*num_blocking_threads=*/64));
  tfrt::RegisterStaticKernels(host_context_->GetMutableRegistry());
  function_cache_ = std::make_unique<FunctionCache>(host_context_.get());
}

RequestHandler::~RequestHandler() {}

void RequestHandler::HandleRemoteRegister(
    const RemoteRegisterInvocation& request) {
  // Create MLIR module from the request.
  mlir::MLIRContext context;
  context.allowsUnregisteredDialects();
  llvm::SourceMgr source_mgr;
  source_mgr.AddNewSourceBuffer(
      llvm::MemoryBuffer::getMemBuffer(request.program), llvm::SMLoc());
  auto module = mlir::parseSourceFile(source_mgr, &context);

  function_cache_->Register(request.program_name.str(), std::move(module));
}

void RequestHandler::HandleRemoteExecute(
    const RemoteExecuteInvocation& request) {
  // TODO(bramandia): Propagate errors to caller.
  RCReference<BEFFile> bef_file =
      function_cache_->Prepare(request.program_name.str());
  if (bef_file.get() == nullptr) {
    TFRT_LOG(ERROR) << "Can't find program: " << request.program_name;
    return;
  }
  const Function* fn = bef_file->GetFunction(request.program_name);
  if (fn == nullptr) {
    TFRT_LOG(ERROR) << tfrt::StrCat(
        "Failed to get program from BEFFile with name ", request.program_name,
        ".");
    return;
  }

  // TODO(bramandia): Propagate RequestContext from the request.
  ResourceContext resource_context;
  RCReference<tfrt::RequestContext> req_ctx =
      RequestContext::Create(host_context_.get(), &resource_context);

  tfrt::ExecutionContext exec_ctx{std::move(req_ctx)};

  SmallVector<AsyncValue*, 4> arguments;
  SmallVector<RCReference<AsyncValue>, 4> arguments_ref;
  arguments.reserve(fn->argument_types().size());
  arguments_ref.reserve(fn->argument_types().size());
  SmallVector<RCReference<AsyncValue>, 4> results;
  results.resize(fn->result_types().size());

  fn->Execute(exec_ctx, arguments, results);
}
}  // namespace tfrt
