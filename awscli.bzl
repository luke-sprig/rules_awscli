AWSCLI_VERSIONS = {
    "linux-x86_64-2.7.12": "b03e475a0889465bda250f620bec7854e19681a6443bad4f2257a11cc9638564",
    "macos-arm64-2.7.12": "493d9992dc9ba7df36db73e9ac94a0726c3db24c58cb881fb2c10de9b63a164b",
    "macos-x86_64-2.7.12": "493d9992dc9ba7df36db73e9ac94a0726c3db24c58cb881fb2c10de9b63a164b",
}

def _awscli_download_impl(ctx):
    arch = ""
    if ctx.attr.arch == "amd64":
        arch = "x86_64"
    elif ctx.attr.arch == "arm64":
        arch = "aarch64"
    else:
        fail("Unsupported arch: {} {}".format(ctx.attr.arch))

    os_arch_version = "{}-{}-{}".format(ctx.attr.os, arch, ctx.attr.version)

    ctx.report_progress("Downloading")
    if ctx.attr.os == "linux":
        url = "https://awscli.amazonaws.com/awscli-exe-{}.zip".format(os_arch_version)
        ctx.download_and_extract(
            url,
            sha256 = AWSCLI_VERSIONS[os_arch_version],
        )
        ctx.report_progress("Installing")
        result = ctx.execute(
            ["aws/install".format(ctx.attr.version), "-i", "."],
            timeout=600,
            environment={},
            quiet=False,
            working_directory=".",
        )
    elif ctx.attr.os == "darwin":
        url = "https://awscli.amazonaws.com/AWSCLIV2-{}.pkg".format(ctx.attr.version)
        ctx.download(
            url,
            sha256 = AWSCLI_VERSIONS[os_arch_version],
        )
        ctx.report_progress("Installing")
        install_dir = ctx.path(".")
        ctx.template(
            "install.xml",
            ctx.attr._darwin_install_tpl,
            substitutions={
                "install_dir": install_dir,
            },
        )
        result = ctx.execute([
            "installer",
             "-pkg",
             "AWSCLIV2-{}.pkg".format(ctx.attr.version),
             "-target",
            "CurrentUserHomeDirectory",
            "-applyChoiceChangesXML",
            "install.xml"],
            timeout=600,
            environment={},
            quiet=False,
            working_directory=".",
        )
    else:
        fail("Unsupported OS: {}".format(ctx.attr.os))
    ctx.report_progress("Installed awscli {}\n{}\n{}".format(result.return_code, result.stdout, result.stderr))

    ctx.template(
        "BUILD.bazel",
        ctx.attr._build_tpl,
        substitutions = {
            "{version}": ctx.attr.version,
        },
    )

awscli_download = repository_rule(
    implementation = _awscli_download_impl,
    attrs = {
        "os": attr.string(
            values = ["darwin", "linux", "windows"],
            default = "linux",
            doc = "Host operating system",
        ),
        "arch": attr.string(
            values = ["amd64", "arm64"],
            default = "amd64",
            doc = "Host architecture",
        ),
        "version": attr.string(
            default = "2.7.12",
            doc = "AWS CLI version",
        ),
        "_build_tpl": attr.label(
            default = "//internal:BUILD.dist.bazel.tpl",
            doc = "BUILD.bazel template",
        ),
        "_darwin_install_tpl": attr.label(
            default = "//internal:install.xml.tpl",
            doc = "Mac OS install.xml template",
        ),
    },
    local = True,
    doc = "Download awscli",
)
