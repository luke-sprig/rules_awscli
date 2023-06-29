load("@bazel_skylib//lib:paths.bzl", "paths")


AWSCLI_VERSIONS = {
    "linux-aarch64-2.7.12": "a43dfb19889930652b849d14bc0234bf0165b36e525cff01da7f447a28890f09",
    "linux-x86_64-2.7.12": "b03e475a0889465bda250f620bec7854e19681a6443bad4f2257a11cc9638564",
    "darwin-x86_64-2.7.12": "493d9992dc9ba7df36db73e9ac94a0726c3db24c58cb881fb2c10de9b63a164b",
}


def os_arch(repository_respository_ctx):
    os_name = repository_respository_ctx.os.name.lower()

    # On Windows, only x86_64 is supported.
    if os_name.find("windows") != -1:
        return ("windows", "x86_64")

    arch = repository_respository_ctx.execute(["uname", "-m"]).stdout.strip()
    if arch == "arm64":
        arch = "aarch64"
    if os_name.startswith("mac os"):
        # we have to force this to x86_64 for now because there is no binary equivalent for m1
        if arch in ("x86_64", "aarch64"):
            return ("darwin", "x86_64")
    elif os_name.startswith("linux"):
        if arch == "x86_64" or arch == "aarch64":
            return ("linux", arch)

    fail("Unsupported OS {} and architecture {}".format(os_name, arch))


def _awscli_download_impl(respository_ctx):
    os, arch = os_arch(respository_ctx)

    os_arch_version = "{}-{}-{}".format(os, arch, respository_ctx.attr.version)

    install_dir = str(respository_ctx.path("."))

    bin_dir = paths.join(install_dir, "bin")

    awscli = ""

    respository_ctx.report_progress("Downloading")
    if os == "linux":
        url = "https://awscli.amazonaws.com/awscli-exe-{}.zip".format(os_arch_version)
        respository_ctx.download_and_extract(
            url,
            sha256 = AWSCLI_VERSIONS[os_arch_version],
        )
        respository_ctx.report_progress("Installing")
        result = respository_ctx.execute(
            [install_dir + "/aws/install", "-i", install_dir, "-b", bin_dir],
            timeout=600,
            environment={},
            quiet=False,
            working_directory=install_dir,
        )
        awscli = "v2/{version}/bin/aws".format(version=respository_ctx.attr.version)
    elif os == "darwin":
        url = "https://awscli.amazonaws.com/AWSCLIV2-{}.pkg".format(respository_ctx.attr.version)
        respository_ctx.download(
            url = url,
            output = "AWSCLIv2-{}.pkg".format(respository_ctx.attr.version),
            sha256 = AWSCLI_VERSIONS[os_arch_version],
        )
        respository_ctx.report_progress("Installing")
        respository_ctx.template(
            "install.xml",
            respository_ctx.attr._darwin_install_tpl,
            substitutions={
                "{install_dir}": install_dir,
            },
        )
        result = respository_ctx.execute([
            "installer",
             "-pkg",
             "AWSCLIV2-{}.pkg".format(respository_ctx.attr.version),
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
    respository_ctx.report_progress("Installed awscli {}\n{}\n{}".format(result.return_code, result.stdout, result.stderr))

    respository_ctx.symlink(awscli, "awscli")

    respository_ctx.file("BUILD.bazel", "exports_files([\"awscli\"])")

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
