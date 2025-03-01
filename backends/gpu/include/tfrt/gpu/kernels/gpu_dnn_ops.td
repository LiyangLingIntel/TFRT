// Copyright 2020 The TensorFlow Runtime Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

//===- gpu_dnn_ops.td ----------------------------------------------------===//
//
// CUDA based CUDA operation definitions.
//
// The same ops should be implementable with a ROCm backend as well.
// Current doc strings refer to CUDA only.
//
//===----------------------------------------------------------------------===//

#ifdef TFRTGPU_DNN_OPS
#else
#define TFRTGPU_DNN_OPS

include "tfrt/gpu/kernels/gpu_ops_base.td"

def TFRTGPU_DnnHandleType : TFRTGPU_Type<"DnnHandle"> { let mnemonic = "dnn.handle"; }
def TFRTGPU_DnnConvolutionPlanType : TFRTGPU_Type<"DnnConvolutionPlan"> {
  let mnemonic = "dnn.convolution.plan";
}
def TFRTGPU_DnnConvolutionAlgorithmType : TFRTGPU_Type<"DnnConvolutionAlgorithmType"> {
  let mnemonic = "dnn.convolution.algorithm";
}

// TODO(hanbinyoon): Remove these. Move legacy convolution to the
// BuildConvolution(cached)->RunConvolution style API.
def TFRTGPU_DnnActivationDescriptorType : TFRTGPU_Type<"DnnActivationDescriptor"> {
  let mnemonic = "dnn.activation.descriptor";
}
def TFRTGPU_DnnConvolutionDescriptorType : TFRTGPU_Type<"DnnConvolutionDescriptor"> {
  let mnemonic = "dnn.convolution.descriptor";
}
def TFRTGPU_DnnFilterDescriptorType : TFRTGPU_Type<"DnnFilterDescriptor"> {
  let mnemonic = "dnn.filter.descriptor";
}
def TFRTGPU_DnnPoolingDescriptorType : TFRTGPU_Type<"DnnPoolingDescriptor"> {
  let mnemonic = "dnn.pooling.descriptor";
}
def TFRTGPU_DnnTensorDescriptorType : TFRTGPU_Type<"DnnTensorDescriptor"> {
  let mnemonic = "dnn.tensor.descriptor";
}

def TFRTGPU_DnnDataTypeAttr : TFRTGPU_WrapperAttr<"DnnDataType">;
def TFRTGPU_DnnConvolutionModeAttr : TFRTGPU_WrapperAttr<"DnnConvolutionMode">;
def TFRTGPU_DnnActivationModeAttr : TFRTGPU_WrapperAttr<"DnnActivationMode">;
def TFRTGPU_DnnMathTypeAttr : TFRTGPU_WrapperAttr<"DnnMathType">;
def TFRTGPU_DnnConvFwdAlgoAttr : TFRTGPU_WrapperAttr<"DnnConvFwdAlgo">;
def TFRTGPU_DnnConvBwdDataAlgoAttr : TFRTGPU_WrapperAttr<"DnnConvBwdDataAlgo">;
def TFRTGPU_DnnConvBwdFilterAlgoAttr : TFRTGPU_WrapperAttr<"DnnConvBwdFilterAlgo">;

def TFRTGPU_DnnCreateOp : TFRTGPU_Op<"dnn.create"> {
  let description = [{
    tfrt_gpu.dnn.create initializes the DNN library and creates a handle to an
    opaque structure holding the DNN library context. It allocates hardware
    resources on the host and device. Prior to passing the handle to any
    DNN ops, the user should specify which stream to use through
    tfrt_gpu.dnn.set_stream.

    The DNN library context is tied to the provided GPU context.

    Example:
    %dnn = tfrt_gpu.dnn.create %context

  }];
  let arguments = (ins TFRTGPU_ContextType);
  let results = (outs TFRTGPU_DnnHandleType);
}

def TFRTGPU_DnnCreateConvolutionDescriptorOp
  : TFRTGPU_Op<"dnn.create_convolution_descriptor", [NoSideEffect]> {
  let description = [{
    tfrt_gpu.dnn.create_convolution_descriptor creates a convolution descriptor
    object by allocating the memory needed to hold its opaque structure. The
    data is initialized to provided values.

    Example:
    %desc = tfrt_gpu.dnn.create_convolution_descriptor CUDNN_DATA_FLOAT,
      CUDNN_CROSS_CORRELATION, CUDNN_TENSOR_OP_MATH, [0 : i32, 0 : i32],
      [1 : i32, 1 : i32], [1 : i32, 1 : i32]
  }];
  let arguments = (ins TFRTGPU_DnnDataTypeAttr:$compute_type,
                   TFRTGPU_DnnConvolutionModeAttr:$conv_mode,
                   TFRTGPU_DnnMathTypeAttr:$math_type, I32ArrayAttr:$pad,
                   I32ArrayAttr:$filter_stride, I32ArrayAttr:$dilation);
  let results = (outs TFRTGPU_DnnConvolutionDescriptorType);
  let assemblyFormat = [{
    custom<Enum>($compute_type)`,` custom<Enum>($conv_mode)`,`
    custom<Enum>($math_type)`,` $pad`,` $filter_stride`,` $dilation attr-dict
  }];
}

def TFRTGPU_DnnCreateFilterDescriptorOp
  : TFRTGPU_Op<"dnn.create_filter_descriptor", [NoSideEffect]> {
  let description = [{
    tfrt_gpu.dnn.create_filter_descriptor creates a filter descriptor object by
    allocating the memory needed to hold its opaque structure. The data is
    initialized to provided values.

    Example:
    %desc = tfrt_gpu.dnn.create_filter_descriptor CUDNN_DATA_FLOAT,
      [3 : i32, 3 : i32]
  }];
  let arguments = (ins TFRTGPU_DnnDataTypeAttr:$data_type,
                   I32Attr:$tensor_format,
                   I32ArrayAttr:$dimensions);
  let results = (outs TFRTGPU_DnnFilterDescriptorType);
  let assemblyFormat = [{
    custom<Enum>($data_type)`,` $tensor_format`,` $dimensions attr-dict
  }];
}

def TFRTGPU_DnnCreatePoolingDescriptorOp
  : TFRTGPU_Op<"dnn.create_pooling_descriptor", [NoSideEffect]> {
  let description = [{
    tfrt_gpu.dnn.create_pooling_descriptor creates a pooling descriptor object
    by allocating the memory needed to hold its opaque structure then it
    initializes created pooling descriptor object.

    mode is an UI32 value with the following meaning:
    0 -> PoolingMax,
    1 -> PoolingAverageCountIncludePadding,
    2 -> PoolingAverageCountExcludePadding,
    3 -> PoolingMaxDeterministic,
    any other value -> Error

    nan_propagation is an UI32 value with the following meaning:
    0 -> NotPropagateNan,
    1 -> PropagateNan,
    any other value -> Error

    Example:
    %mode = tfrt.constant.ui32 0
    %nan_propagation = tfrt.constant.ui32 0
    %pooling_desc = tfrt_gpu.dnn.create_pooling_descriptor %context, %mode,
      %nan_propagation, [3 : i32, 3 : i32], [0 : i32, 0 : i32],
      [1 : i32, 1 : i32]
  }];
  let arguments = (ins TFRTGPU_ContextType:$context, UI32:$mode,
                   UI32:$nan_propagation, I32ArrayAttr:$window_dimensions,
                   I32ArrayAttr:$paddings, I32ArrayAttr:$strides);
  let results = (outs TFRTGPU_DnnPoolingDescriptorType);
  let assemblyFormat = [{
    $context`,` $mode`,` $nan_propagation`,` $window_dimensions`,` $paddings`,`
    $strides attr-dict
  }];
}

def TFRTGPU_DnnCreateTensorDescriptorOp
  : TFRTGPU_Op<"dnn.create_tensor_descriptor", [NoSideEffect]> {
  let description = [{
    tfrt_gpu.dnn.create_tensor_descriptor creates a generic tensor
    descriptor object by allocating the memory needed to hold its opaque
    structure. The data is initialized to provided values.

    Example:
    %desc = tfrt_gpu.dnn.create_tensor_descriptor CUDNN_DATA_FLOAT,
      [3 : i32, 3 : i32], [1 : i32, 1 : i32]
  }];
  let arguments = (ins TFRTGPU_DnnDataTypeAttr:$data_type, I32ArrayAttr:$dimensions,
                   I32ArrayAttr:$strides);
  let results = (outs TFRTGPU_DnnTensorDescriptorType);
  let assemblyFormat = [{
    custom<Enum>($data_type)`,` $dimensions`,` $strides attr-dict
  }];
}

def TFRTGPU_DnnCreateActivationDescriptorOp
  : TFRTGPU_Op<"dnn.create_activation_descriptor", [NoSideEffect]> {
  let description = [{
    tfrt_gpu.dnn.create_activation_descriptor creates an activation descriptor
    object by allocating the memory needed to hold its opaque structure. The
    data is initialized to provided values.
  }];
  let arguments = (ins F64:$coefficient, TFRTGPU_DnnActivationModeAttr:$mode,
                   BoolAttr:$nan_progapation);
  let results = (outs TFRTGPU_DnnActivationDescriptorType);
  let assemblyFormat = [{
    $coefficient`,` custom<Enum>($mode)`,` $nan_progapation attr-dict
  }];
}

def TFRTGPU_DnnConvolutionForwardAlgorithmOp
  : TFRTGPU_Op<"dnn.convolution_forward_algorithm", [NoSideEffect]> {
  let arguments = (ins TFRTGPU_DnnConvFwdAlgoAttr:$algo);
  let results = (outs TFRTGPU_DnnConvolutionAlgorithmType);
  let assemblyFormat = "custom<Enum>($algo) attr-dict";
}
def TFRTGPU_DnnConvolutionBackwardDataAlgorithmOp
  : TFRTGPU_Op<"dnn.convolution_backward_data_algorithm", [NoSideEffect]> {
  let arguments = (ins TFRTGPU_DnnConvBwdDataAlgoAttr:$algo);
  let results = (outs TFRTGPU_DnnConvolutionAlgorithmType);
  let assemblyFormat = "custom<Enum>($algo) attr-dict";
}
def TFRTGPU_DnnConvolutionBackwardFilterAlgorithmOp
  : TFRTGPU_Op<"dnn.convolution_backward_filter_algorithm", [NoSideEffect]> {
  let arguments = (ins TFRTGPU_DnnConvBwdFilterAlgoAttr:$algo);
  let results = (outs TFRTGPU_DnnConvolutionAlgorithmType);
  let assemblyFormat = "custom<Enum>($algo) attr-dict";
}

def TFRTGPU_DnnPoolingForwardOp : TFRTGPU_Op<"dnn.pooling_forward"> {
  let description = [{
    tfrt_gpu.dnn.pooling_forward computes pooling of input values (meaning,
    the maximum or average of several adjacent values) to produce an
    output with smaller height and/or width.

    Example:
    %ch33 = tfrt_gpu.dnn.pooling_forward %context, %cudnn, %pooling_desc, %alpha, %in_desc, %input_device_buffer, %beta, %out_desc, %output_device_buffer, %ch32

}];
  let arguments = (ins
                   TFRTGPU_DnnHandleType,
                   TFRTGPU_StreamType,
                   TFRTGPU_DnnPoolingDescriptorType,
                   F32,
                   TFRTGPU_DnnTensorDescriptorType,
                   TFRTGPU_BufferType,
                   F32,
                   TFRTGPU_DnnTensorDescriptorType,
                   TFRTGPU_BufferType,
                   TFRT_ChainType
                  );
  let results = (outs TFRT_ChainType);
}

def TFRTGPU_DnnPoolingBackwardOp : TFRTGPU_Op<"dnn.pooling_backward"> {
  let description = [{
    tfrt_gpu.dnn.pooling_backward computes the gradient of a pooling operation.

    Example:
    %ch42 = tfrt_gpu.dnn.pooling_backward %context, %cudnn, %pooling_desc, %alpha, %out_desc, %output_device_buffer, %out_desc, %output_device_buffer, %in_desc, %input_device_buffer, %beta, %in_desc, %in_grad_device_buffer, %ch41

  }];
  let arguments = (ins TFRTGPU_DnnHandleType,
                   TFRTGPU_StreamType,
                   TFRTGPU_DnnPoolingDescriptorType,
                   F32,
                   TFRTGPU_DnnTensorDescriptorType,
                   TFRTGPU_BufferType,
                   TFRTGPU_DnnTensorDescriptorType,
                   TFRTGPU_BufferType,
                   TFRTGPU_DnnTensorDescriptorType,
                   TFRTGPU_BufferType,
                   F32,
                   TFRTGPU_DnnTensorDescriptorType,
                   TFRTGPU_BufferType,
                   TFRT_ChainType
                  );
  let results = (outs TFRT_ChainType);
}

def TFRTGPU_DnnConvolutionForwardOp : TFRTGPU_Op<"dnn.convolution_forward"> {
  let description = [{
    tfrt_gpu.dnn.convolution_forward executes convolutions or
                                      cross-correlations over x using filters
                                      specified with w, returning results in y.
  }];
  let arguments = (ins TFRTGPU_DnnHandleType:$handle,
                   TFRTGPU_StreamType:$stream,
                   TFRTGPU_DnnDataTypeAttr:$scale_type,
                   TFRTGPU_DnnTensorDescriptorType:$x_desc,
                   TFRTGPU_BufferType:$x,
                   TFRTGPU_DnnFilterDescriptorType:$w_desc,
                   TFRTGPU_BufferType:$w,
                   TFRTGPU_DnnConvolutionDescriptorType:$conv_desc,
                   TFRTGPU_DnnConvolutionAlgorithmType:$algo,
                   TFRTGPU_BufferType:$work_space,
                   TFRTGPU_DnnTensorDescriptorType:$y_desc,
                   TFRTGPU_BufferType:$y,
                   TFRT_ChainType:$chain);
  let results = (outs TFRT_ChainType);
  let assemblyFormat = [{
    $handle`,` $stream`,` custom<Enum>($scale_type)`,` $x_desc`,` $x`,`
    $w_desc`,` $w`,` $conv_desc`,` $algo`,` $work_space`,` $y_desc`,` $y`,`
    $chain attr-dict
  }];
}

def TFRTGPU_DnnConvolutionBackwardDataOp : TFRTGPU_Op<"dnn.convolution_backward_data"> {
  let description = [{
    tfrt_gpu.dnn.convolution_backward_data computes the convolution data
                                            gradient of the tensor dy, where y
                                            is the output of the forward
                                            convolution in
                                            tfrt_gpu.dnn.convolution_forward.
                                            It uses the specified algo, and
                                            returns the results in the output
                                            tensor dx.
}];
  let arguments = (ins TFRTGPU_DnnHandleType:$handle,
                   TFRTGPU_StreamType:$stream,
                   TFRTGPU_DnnDataTypeAttr:$scale_type,
                   TFRTGPU_DnnFilterDescriptorType:$w_desc,
                   TFRTGPU_BufferType:$w,
                   TFRTGPU_DnnTensorDescriptorType:$dy_desc,
                   TFRTGPU_BufferType:$dy,
                   TFRTGPU_DnnConvolutionDescriptorType:$conv_desc,
                   TFRTGPU_DnnConvolutionAlgorithmType:$algo,
                   TFRTGPU_BufferType:$work_space,
                   TFRTGPU_DnnTensorDescriptorType:$dx_desc,
                   TFRTGPU_BufferType:$dx,
                   TFRT_ChainType:$chain);
  let results = (outs TFRT_ChainType);
  let assemblyFormat = [{
    $handle`,` $stream`,` custom<Enum>($scale_type)`,` $w_desc`,` $w`,`
    $dy_desc`,` $dy`,` $conv_desc`,` $algo`,` $work_space`,` $dx_desc`,` $dx`,`
    $chain attr-dict
  }];
}

def TFRTGPU_DnnConvolutionBackwardFilterOp : TFRTGPU_Op<"dnn.convolution_backward_filter"> {
  let description = [{
    tfrt_gpu.dnn.convolution_backward_filter computes the convolution weight
                                              (filter) gradient of the tensor
                                              dy, where y is the output of the
                                              forward convolution in
                                              tfrt_gpu.dnn.convolution_forward.
                                              It uses the specified algo, and
                                              returns the results in the output
                                              tensor dw.
}];
  let arguments = (ins TFRTGPU_DnnHandleType:$handle,
                   TFRTGPU_StreamType:$stream,
                   TFRTGPU_DnnDataTypeAttr:$scale_type,
                   TFRTGPU_DnnTensorDescriptorType:$x_desc,
                   TFRTGPU_BufferType:$x,
                   TFRTGPU_DnnTensorDescriptorType:$dy_desc,
                   TFRTGPU_BufferType:$dy,
                   TFRTGPU_DnnConvolutionDescriptorType:$conv_desc,
                   TFRTGPU_DnnConvolutionAlgorithmType:$algo,
                   TFRTGPU_BufferType:$work_space,
                   TFRTGPU_DnnFilterDescriptorType:$dw_desc,
                   TFRTGPU_BufferType:$dw,
                   TFRT_ChainType:$chain);
  let results = (outs TFRT_ChainType);
  let assemblyFormat = [{
    $handle`,` $stream`,` custom<Enum>($scale_type)`,` $x_desc`,` $x`,`
    $dy_desc`,` $dy`,` $conv_desc`,` $algo`,` $work_space`,` $dw_desc`,` $dw`,`
    $chain attr-dict
  }];
}

def TFRTGPU_DnnConvolutionBiasActivationForwardOp :
             TFRTGPU_Op<"dnn.convolution_bias_activation_forward"> {
  let description = [{
    tfrt_gpu.dnn.convolution_bias_activation_forward applies a bias and then
                        an activation to the convolutions or cross-correlations
                        of tfrt_gpu.dnn.convolution_forward, returning results
                        in y. The full computation follows the equation
                        y = act ( alpha1 * conv(x) + alpha2 * z + bias ).
  }];
  let arguments = (ins TFRTGPU_DnnHandleType:$handle,
                   TFRTGPU_StreamType:$stream,
                   TFRTGPU_DnnDataTypeAttr:$scale_type,
                   AnyType:$alpha1,
                   TFRTGPU_DnnTensorDescriptorType:$x_desc,
                   TFRTGPU_BufferType:$x,
                   TFRTGPU_DnnFilterDescriptorType:$w_desc,
                   TFRTGPU_BufferType:$w,
                   TFRTGPU_DnnConvolutionDescriptorType:$conv_desc,
                   TFRTGPU_DnnConvolutionAlgorithmType:$algo,
                   TFRTGPU_BufferType:$work_space,
                   AnyType:$alpha2,
                   TFRTGPU_DnnTensorDescriptorType:$z_desc,
                   TFRTGPU_BufferType:$z,
                   TFRTGPU_DnnTensorDescriptorType:$bias_desc,
                   TFRTGPU_BufferType:$bias,
                   TFRTGPU_DnnActivationDescriptorType:$activation_desc,
                   TFRTGPU_DnnTensorDescriptorType:$y_desc,
                   TFRTGPU_BufferType:$y,
                   TFRT_ChainType:$chain);
  let results = (outs TFRT_ChainType);
  let assemblyFormat = [{
    $handle`,` $stream`,` custom<Enum>($scale_type, type($alpha1),
    type($alpha2))`,` $alpha1`,` $x_desc`,` $x`,` $w_desc`,` $w`,` $conv_desc`,`
    $algo`,` $work_space`,` $alpha2`,` $z_desc`,` $z`,` $bias_desc`,` $bias`,`
    $activation_desc`,` $y_desc`,` $y`,` $chain attr-dict
  }];
}

def TFRTGPU_DnnBuildConvolutionOp : TFRTGPU_Op<"dnn.build_convolution"> {
  let description = [{
    tfrt_gpu.dnn.build_convolution returns a tfrt_gpu.dnn.convolution_plan for
    the convolution that is described by the supplied input, output, filter, and
    convolution configuration parameters.
  }];
  let arguments = (ins TFRTGPU_DnnHandleType:$handle,
                   TFRTGPU_DnnDataTypeAttr:$input_type,
                   TFRTGPU_DnnDataTypeAttr:$output_type,
                   I64ArrayAttr:$input_dims, I64ArrayAttr:$input_strides,
                   I64ArrayAttr:$output_dims, I64ArrayAttr:$output_strides,
                   I64ArrayAttr:$filter_dims, I64ArrayAttr:$filter_strides,
                   TFRTGPU_DnnConvolutionModeAttr:$conv_mode, I32Attr:$conv_dim,
                   I64ArrayAttr:$conv_dilations, I64ArrayAttr:$conv_padding,
                   I64ArrayAttr:$conv_strides,
                   // TODO(hanbinyoon): Add custom parsing/printing for these
                   // attributes.
                   I32Attr:$backend_type, I32Attr:$engine_id,
                   I64ArrayAttr:$tuning_knob_ids,
                   I64ArrayAttr:$tuning_knob_values);
  let results = (outs TFRTGPU_DnnConvolutionPlanType);
  let assemblyFormat = [{
    $handle`,` custom<Enum>($input_type)`,` custom<Enum>($output_type)`,`
    $input_dims`,` $input_strides`,` $output_dims`,` $output_strides`,`
    $filter_dims`,` $filter_strides`,` custom<Enum>($conv_mode)`,` $conv_dim`,`
    $conv_dilations`,` $conv_padding`,` $conv_strides`,` $backend_type`,`
    $engine_id`,` $tuning_knob_ids`,` $tuning_knob_values attr-dict
  }];
}

def TFRTGPU_DnnRunConvolutionOp : TFRTGPU_Op<"dnn.run_convolution"> {
  let description = [{
    tfrt_gpu.dnn.run_convolution runs the convolution according to the supplied
    convolution plan using the input, output, filter, and workspace buffers.
  }];
  let arguments = (ins TFRTGPU_DnnHandleType:$handle,
                   TFRTGPU_StreamType:$stream,
                   TFRTGPU_DnnConvolutionPlanType:$convolution_plan,
                   TFRTGPU_BufferType:$input, TFRTGPU_BufferType:$output,
                   TFRTGPU_BufferType:$filter, TFRTGPU_BufferType:$workspace,
                   TFRT_ChainType:$chain);
  let results = (outs TFRT_ChainType);
  let assemblyFormat = [{
    $handle`,` $stream`,` $convolution_plan`,` $input`,` $output`,` $filter`,`
    $workspace`,` $chain attr-dict
  }];
}

def TFRTGPU_DnnBuildFusedConvolutionOp : TFRTGPU_Op<"dnn.build_fused_convolution"> {
  let description = [{
    tfrt_gpu.dnn.build_fused_convolution returns a tfrt_gpu.dnn.convolution_plan
    for the convolution that is described by the supplied input, output, filter,
    and convolution configuration parameters. Additionally, bias, side input
    (scaling), and activation are fused into the convolution plan.
  }];
  let arguments = (ins TFRTGPU_DnnHandleType:$handle,
                   TFRTGPU_DnnDataTypeAttr:$input_type,
                   TFRTGPU_DnnDataTypeAttr:$output_type,
                   TFRTGPU_DnnDataTypeAttr:$bias_type,
                   I64ArrayAttr:$input_dims, I64ArrayAttr:$input_strides,
                   I64ArrayAttr:$output_dims, I64ArrayAttr:$output_strides,
                   I64ArrayAttr:$filter_dims, I64ArrayAttr:$filter_strides,
                   I64ArrayAttr:$bias_dims, I64ArrayAttr:$bias_strides,
                   TFRTGPU_DnnConvolutionModeAttr:$conv_mode, I32Attr:$conv_dim,
                   I64ArrayAttr:$conv_dilations, I64ArrayAttr:$conv_padding,
                   I64ArrayAttr:$conv_strides,
                   // TODO(hanbinyoon): Add custom parsing/printing for these
                   // attributes.
                   I32Attr:$backend_type, F64:$alpha, F64:$alpha2,
                   I32Attr:$activation_mode, I32Attr:$engine_id,
                   I64ArrayAttr:$tuning_knob_ids,
                   I64ArrayAttr:$tuning_knob_values);
  let results = (outs TFRTGPU_DnnConvolutionPlanType);
  let assemblyFormat = [{
    $handle`,` custom<Enum>($input_type)`,` custom<Enum>($output_type)`,`
    custom<Enum>($bias_type)`,` $input_dims`,` $input_strides`,` $output_dims`,`
    $output_strides`,` $filter_dims`,` $filter_strides`,` $bias_dims`,`
    $bias_strides`,` custom<Enum>($conv_mode)`,` $conv_dim`,`
    $conv_dilations`,` $conv_padding`,` $conv_strides`,` $backend_type`,`
    $alpha`,` $alpha2`,` $activation_mode`,` $engine_id`,` $tuning_knob_ids`,`
    $tuning_knob_values attr-dict
  }];
}

def TFRTGPU_DnnRunFusedConvolutionOp : TFRTGPU_Op<"dnn.run_fused_convolution"> {
  let description = [{
    tfrt_gpu.dnn.run_fused_convolution runs the fused convolution according to
    the supplied convolution plan using the input, output, filter, side_input,
    bias, and workspace buffers.
  }];
  let arguments = (ins TFRTGPU_DnnHandleType:$handle,
                   TFRTGPU_StreamType:$stream,
                   TFRTGPU_DnnConvolutionPlanType:$convolution_plan,
                   TFRTGPU_BufferType:$input, TFRTGPU_BufferType:$output,
                   TFRTGPU_BufferType:$filter, TFRTGPU_BufferType:$side_input,
                   TFRTGPU_BufferType:$bias, TFRTGPU_BufferType:$workspace,
                   TFRT_ChainType:$chain);
  let results = (outs TFRT_ChainType);
  let assemblyFormat = [{
    $handle`,` $stream`,` $convolution_plan`,` $input`,` $output`,` $filter`,`
    $side_input`,` $bias`,` $workspace`,` $chain attr-dict
  }];
}

#endif  // TFRTGPU_DNN_OPS
