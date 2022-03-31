# Copyright 2021 The Pigweed Authors
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not
# use this file except in compliance with the License. You may obtain a copy of
# the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License.
"""Internal tools facades and backends."""

load("//pw_build/bazel_internal:pigweed_internal.bzl", "add_cc_and_c_targets")

_TOOLCHAIN_TYPE = "//pw_build:facade_toolchain_type"

def _pw_cc_library(**kwargs):
    add_cc_and_c_targets(native.cc_library, kwargs)

def pw_cc_facade(
        name,
        default_backend = "@pigweed//pw_build:unimplemented_backend",
        hdrs = None,
        **kwargs):
    """Declares a virtual cc_library.

    A Pigweed facade is an API layer that has a single implementation it must
    link against. Typically this will be done by pointing a build alias like
    `pw_[module]_backend_alias` at a backend implementation for that module.

    pw_cc_facade creates two user-facing targets:

    ${target_name}: The public-facing pw_source_set that provides the API and
        implementation (backend). Users of the facade should depend on this.
    ${target_name}_headers: A cc_library that provides ONLY the API. ONLY
        backends should depend on this.

    The facade's headers are split out into the *_headers target to avoid circular
    dependencies. Here's a concrete example to illustrate why this is needed:

    load("//pw_build:pigweed.bzl", "pw_cc_facade")

    pw_cc_facade(
        name = "foo",
        backend_alias = ":foo_backend_alias",
        default_backend = ":foo_backend_bar",
    )

    cc_library(
        name = "foo_backend_bar",
        srcs = "bar.cc",
        deps = ":foo_headers",
    )

    This creates the following dependency graph:

    foo.facade <----------.
      ^                    \
      |                     \
      |                      \
    foo  --> _foo_facade --> foo_backend_bar

    This allows foo_backend_bar to include "foo.h". If you tried to directly
    depend on `foo` from `foo_backend_bar`, you'd get a dependency cycle error
    in Bazel.

    Accepts the standard cc_library args with the following additions:

    Args:
        name: Unique name for the library.
        hdrs: (required) The headers exposed by this facade. A facade acts as a
            tool to break dependency cycles that come from the backend trying to
            include headers from the facade itself. If the facade doesn't
            expose any headers, it's basically the same as just depending
            directly on the build arg that `backend_alias` resolves to.
        default_backend: The default backend to use if the user doesn't specify
            one.
        **kwargs: All other args are passed through to cc_library.
    """

    # Header-only target to be used by facade and backends.
    headers_name = name + ".facade"
    headers_attrs = ["includes", "strip_include_prefix", "visibility", "deps"]
    headers_kwargs = {a: kwargs.get(a, None) for a in headers_attrs}
    _pw_cc_library(
        name = headers_name,
        hdrs = hdrs,
        **headers_kwargs
    )

    alias_name = name + "_backend_alias"
    pw_alias(
        name = alias_name,
        default_value = default_backend,
    )

    # Facade target that resolves to a backend implementation. This target is
    # intentionally hidden from the user. It only exists to bridge the
    # client-facing cc_library to a backend cc_library resolved at build time.
    facade_name = "_" + name + "_facade"
    pw_facade(
        name = facade_name,
        backend_alias = ":" + alias_name,
    )

    # Inject headers and facade backend into the deps list.
    deps = kwargs.pop("deps", []) + [
        headers_name,
        facade_name,
    ]
    kwargs["deps"] = deps

    # Main facade library target that downstream users depend on.
    _pw_cc_library(
        name = name,
        hdrs = hdrs,
        **kwargs
    )

def pw_facade_toolchain(name, backends = None, **kwargs):
    """Declares a facade-backend mapping.

    Example toolchain definition in a BUILD file:

        pw_facade_toolchain(
            name = "facade_backends_custom_toolchain",
            backends = {
            "//:my_custom_foo_backend": "//foo:foo_backend_alias",
            },
        )

    Corresponding WORKSPACE file that uses the toolchain declared above:

        register_toolchains(
            "//:facade_backends_custom_toolchain",
        )

    Args:
        name: Unique name for this toolchain like
            `facade_backends_<environment>_toolchain`.
        backends: (optional) dict object mapping backend labels to their
            intended facade aliases.
        **kwargs: All other args are passed through to the native.toolchain.
    """

    # Hidden toolchain target containing mappings.
    inner_name = "_" + name
    _pw_facade_toolchain(
        name = inner_name,
        backends = backends,
    )

    # Generic toolchain wrapper that can be added to register_toolchains().
    native.toolchain(
        name = name,
        toolchain = inner_name,
        toolchain_type = _TOOLCHAIN_TYPE,
        **kwargs
    )

PwFacadeToolchainInfo = provider(
    doc = "Facade backend mapping",
    fields = ["backends"],
)

def _pw_facade_toolchain_impl(ctx):
    toolchain_info = platform_common.ToolchainInfo(
        pw_facade_toolchain_info = PwFacadeToolchainInfo(
            backends = ctx.attr.backends,
        ),
    )
    return [toolchain_info]

_pw_facade_toolchain = rule(
    implementation = _pw_facade_toolchain_impl,
    doc = """
Maps facade aliases to backend implementations.

Forwards the provided backends dict as part of ToolchainInfo so that pw_facade
rules can look up which backend deps to inject.

This hidden rule is wrapped by the pw_facade_toolchain macro above.
""",
    attrs = {
        "backends": attr.label_keyed_string_dict(
            doc = "Optional mapping of backends to facade aliases.",
        ),
    },
)

PwAliasInfo = provider(
    doc = "A single mapping between alias and backend",
    fields = ["label", "default_value"],
)

def _pw_alias_impl(ctx):
    return [PwAliasInfo(
        label = ctx.label,
        default_value = ctx.attr.default_value,
    )]

pw_alias = rule(
    implementation = _pw_alias_impl,
    doc = "A label associating facades and backends.",
    attrs = {
        "default_value": attr.label(
            doc = "Optional backend implementation to use by default.",
        ),
    },
)

def _pw_facade_impl(ctx):
    # Bazel provides the first valid toolchain that matches _TOOLCHAIN_TYPE.
    toolchain_info = ctx.toolchains[_TOOLCHAIN_TYPE].pw_facade_toolchain_info
    alias_info = ctx.attr.backend_alias[PwAliasInfo]

    # The toolchain contains a mapping of backends to facade aliases. Search the
    # toolchain for a backend whose alias matches this facade rule. If a match
    # is found, forward the matched backend to depedents of this facade rule.
    for backend, alias in toolchain_info.backends.items():
        if Label(alias) == alias_info.label:
            return [backend[CcInfo]]

    # If there aren't any backend matches, use the default backend.
    if alias_info.default_value:
        return [alias_info.default_value[CcInfo]]

    # If there's no default backend, print an error.
    fail("Couldn't resolve facade backend for alias " + str(alias_info.label))

pw_facade = rule(
    implementation = _pw_facade_impl,
    doc = """
Virtual target that resolves to a swappable backend implementation.

This rule uses a toolchain to resolve to a user-specified backend at build time.
It's as a placeholder dependency that represents a generic interface with
multiple, extensible implementations.
""",
    attrs = {
        "backend_alias": attr.label(
            doc = "pw_alias used to associate this facade with backends.",
            providers = [PwAliasInfo],
            mandatory = True,
        ),
    },
    toolchains = [_TOOLCHAIN_TYPE],
)
