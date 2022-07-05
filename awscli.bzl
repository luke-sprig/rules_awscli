AWSCLI_VERSIONS = {
    "linux-x86_64-2.7.12": "b03e475a0889465bda250f620bec7854e19681a6443bad4f2257a11cc9638564",
    "darwin-arm64-2.7.12": "493d9992dc9ba7df36db73e9ac94a0726c3db24c58cb881fb2c10de9b63a164b",
    "darwin-x86_64-2.7.12": "493d9992dc9ba7df36db73e9ac94a0726c3db24c58cb881fb2c10de9b63a164b",
}

def os_arch(repository_ctx):
    os_name = repository_ctx.os.name.lower()

    # On Windows, only x86_64 is supported.
    if os_name.find("windows") != -1:
        return ("windows", "x86_64")

    arch = repository_ctx.execute(["uname", "-m"]).stdout.strip()
    if os_name.startswith("mac os"):
        if arch == "x86_64" or arch == "arm64":
            return ("darwin", arch)
    elif os_name.startswith("linux"):
        if arch == "x86_64" or arch == "arm64":
            return ("linux", arch)

    fail("Unsupported OS {} and architecture {}".format(os_name, arch))


def _awscli_download_impl(ctx):
    os, arch = os_arch(ctx)

    os_arch_version = "{}-{}-{}".format(os, arch, ctx.attr.version)

    install_dir = str(ctx.path("."))

    awscli = ""

    ctx.report_progress("Downloading")
    if os == "linux":
        url = "https://awscli.amazonaws.com/awscli-exe-{}.zip".format(os_arch_version)
        ctx.download_and_extract(
            url,
            sha256 = AWSCLI_VERSIONS[os_arch_version],
        )
        ctx.report_progress("Installing")
        result = ctx.execute(
            [install_dir + "/aws/install", "-i", install_dir],
            timeout=600,
            environment={},
            quiet=False,
            working_directory=install_dir,
        )
        awscli = "v2/{version}/bin/aws".format(version=ctx.attr.version)
    elif os == "darwin":
        url = "https://awscli.amazonaws.com/AWSCLIV2-{}.pkg".format(ctx.attr.version)
        ctx.download(
            url = url,
            output = "AWSCLIv2-{}.pkg".format(ctx.attr.version),
            sha256 = AWSCLI_VERSIONS[os_arch_version],
        )
        ctx.report_progress("Installing")
        ctx.template(
            "install.xml",
            ctx.attr._darwin_install_tpl,
            substitutions={
                "{install_dir}": install_dir,
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
            working_directory=install_dir,
        )
        awscli = "aws-cli/aws".format(install_dir)
    else:
        # TODO: add Windows support.
        fail("Unsupported OS: {}".format(os))
    ctx.report_progress("Installed awscli {}\n{}\n{}".format(result.return_code, result.stdout, result.stderr))

    ctx.template(
        "BUILD.bazel",
        ctx.attr._build_tpl,
        substitutions = {
            "{awscli}": awscli,
            "{version}": ctx.attr.version,
        },
    )

awscli_download = repository_rule(
    implementation = _awscli_download_impl,
    attrs = {
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
