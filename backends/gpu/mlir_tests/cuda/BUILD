load("@tf_runtime//:build_defs.bzl", "if_oss")
load("@tf_runtime//tools:mlir_to_bef.bzl", "glob_tfrt_lit_tests")

licenses(["notice"])

glob_tfrt_lit_tests(
    data = [":test_utilities"],
    # copybara:uncomment driver = "@tf_runtime//backends/gpu/mlir_tests:run_lit.sh",
    tags_override = dict({
        file: ["requires-gpu-nvidia"]
        for file in glob(["*.mlir"])
    }.items() + {
        # Note: NCCL in the sandbox produces the wrong result in OSS.
        "all_gather.mlir": [
            "requires-gpu-nvidia:2",
            "requires-net:ipv4",
        ] + if_oss(["no-sandbox"]),
        "all_reduce.mlir": [
            "requires-gpu-nvidia:2",
            "requires-net:ipv4",
        ] + if_oss(["no-sandbox"]),
        "all_to_all.mlir": [
            "requires-gpu-nvidia:2",
            "requires-net:ipv4",
        ] + if_oss(["no-sandbox"]),
        "reduce_scatter.mlir": [
            "requires-gpu-nvidia:2",
            "requires-net:ipv4",
        ] + if_oss(["no-sandbox"]),
        "send_recv.mlir": [
            "requires-gpu-nvidia:2",
            "requires-net:ipv4",
        ] + if_oss(["no-sandbox"]),
    }.items() + {
        "dnn.mlir": [
            "requires-gpu-nvidia",
            "no_oss",
        ],
    }.items()),
    tfrt_translate = "@tf_runtime//backends/gpu:tfrt_gpu_translate",
)

# Bundle together all of the test utilities that are used by tests.
filegroup(
    name = "test_utilities",
    testonly = True,
    srcs = [
        "@llvm-project//llvm:FileCheck",
        "@tf_runtime//backends/gpu:tfrt_gpu_executor",
        "@tf_runtime//backends/gpu:tfrt_gpu_opt",
        "@tf_runtime//backends/gpu:tfrt_gpu_translate",
        "@tf_runtime//tools:bef_executor_lite",
    ],
)
