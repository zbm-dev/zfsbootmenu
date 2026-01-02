# ZFSBootMenu Release Engineering

Several high-level operations comprise the ZFSBootMenu release process:

1. Ensure that the repository is consistent and suitable for tagging
2. Render all dynamic content (including version information) included in the repository for convenience
3. Produce an updated build-container image configured to build the release by default
4. Use the new image to create all release images, then sign all assets
5. Extract changelog information to use as the body of a release announcement
6. Use the `gh` utility to publish the release, which also tags the repository
7. Render new version information to reflect the post-release development state on the branch head

Several helper scripts effect these operations. While they may be run individually, the normal release process can be
performed with a single invocation (from the repository root) of the coordination script

    ./releng/tag-release.sh <version>

for the desired version number. Note that the script *must* be run with the repository root as the working directory;
sanity checks will fail if run from any other directory, including this one. If the provided version begins with the
character `v`, it will be stripped when used as a version number; if the provided version does not begin with the
character `v`, it will be appended when creating a release tag.

Should the `gh release` command indicate failure when publishing a release, `tag-release.sh` will indicate the failed
command and allow the user to retry the publication. This provides an opportunity to, *e.g.*, re-authenticate `gh` if
needed or run the publication command manually.

## Prerequisites

The release-engineering scripts require several helpers:

- The `gh` command-line tool is used to manipulate GitHub and publish the release
- Both `podman` and `buildah` are required to produce build-container images and prepare release assets
- The `signify` utility is necessary to sign assets for the release

When `jq` is available, `tag-release.sh` will attempt to verify the authentication status of `gh` before the local
repository is modified.

## Branches

The ZFSBootMenu repository maintains branches of the form, *e.g.*, `v3.1.x` that correspond to separate minor releases.
The `tag-release.sh` script expects that any releases tagged will reside on either the `master` branch or one of these
long-lived release branches; attempts to run the script from any other branch will fail. It is expected that
documentation updates on the `master` branch will be backported to the latest release branch, along with any trivial
fixes that might necessitate a patch release.

In general, the first release with a new minor version number (*e.g.*, `3.1.0`) should be made from the `master` branch,
with the corresponding release branch created *post hoc* from the commit tagged for release. Patch releases should be
made from the corresponding release branch

## Manual Activities After Release

Although `tag-release.sh` will perform all steps necessary to publish a release, the release engineer that publishes the
release should take a few actions after publication:

1. If the release was made from the master branch, a corresponding release branch should be created from the commit
   tagged for release. For example, release tag `v1.0.0` should be the branch point for a `v1.0.x` branch on the public
   repository.

2. The release process should leave a local OCI container image with a name of the form
   `ghcr.io/zbm-dev/zbm-builder:YYYYMMDD`. This tag should be pushed upstream to the GitHub container registry. The
   image should also be tagged `ghcr.io/zbm-dev/zbm-builder:latest`, and this tagged pushed to replace any exist
   `:latest` tag. This ensures that the default image will produce ZFSBootMenu artifacts for the latest release.
