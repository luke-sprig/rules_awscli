#filegroup(
#    name = "awscli",
#    srcs = ["v2/{version}/bin/aws"],
#    visibility = ["//visibility:public"],
#)
alias(
    name = "awscli",
    actual = "v2/{version}/bin/aws",
    visibility = ["//visibility:public"],
)
