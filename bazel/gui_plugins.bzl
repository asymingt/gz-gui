load("@rules_cc//cc:defs.bzl", "cc_binary")

def gz_gui_plugin(name, srcs = [], hdrs = [], qrc = None, qml = [], moc_headers = [], deps = []):
    """Helper macro to build a simple plugin shared library for gz-gui.

    Args:
      name: Name of the plugin.
      srcs: Source files.
      hdrs: Header files.
      qrc: RCC resource file.
      qml: QML source files.
      moc_headers: Headers that need MOC compilation.
      deps: Dependencies.
    """
    moc_files = []
    for hdr in moc_headers:
        moc_name = "moc_" + name + "_" + hdr.split("/")[-1].replace(".hh", "").replace(".h", "")
        native.genrule(
            name = moc_name,
            srcs = [hdr],
            outs = [hdr.replace(".hh", "_moc.cpp").replace(".h", "_moc.cpp")],
            cmd = select({
                "@platforms//os:linux": "$(location @qt_linux_x86_64//:moc) $(locations %s) -o $@ -f'%s'" % (hdr, hdr),
                "//conditions:default": "$(location @qt_linux_x86_64//:moc) $(locations %s) -o $@" % hdr,
            }),
            tools = ["@qt_linux_x86_64//:moc"],
        )
        moc_files.append(":" + moc_name)

    rcc_files = []
    if qrc:
        rcc_name = "qrc_" + name
        native.genrule(
            name = rcc_name,
            srcs = [qrc] + qml,
            outs = [qrc.replace(".qrc", "_rcc.cpp")],
            cmd = "ROOT=$$PWD && cd $$(dirname $(location %s)) && $$ROOT/$(location @qt_linux_x86_64//:rcc) --name %s --output $$ROOT/$@ $$(basename $(location %s))" % (qrc, name, qrc),
            tools = ["@qt_linux_x86_64//:rcc"],
        )
        rcc_files.append(":" + rcc_name)

    dir_name = srcs[0].rsplit("/", 1)[0] if srcs else ""

    cc_binary(
        name = "lib" + name + ".so",
        srcs = srcs + hdrs + moc_headers + moc_files + rcc_files,
        linkshared = True,
        linkstatic = True,
        copts = [
            "-fPIC",
            "-I" + dir_name,
            "-I$(GENDIR)/" + dir_name,
            "-Iexternal/gz-gui+/" + dir_name,
            "-I$(GENDIR)/external/gz-gui+/" + dir_name,
            "-Iexternal/gz-gui+",
            "-I$(GENDIR)/external/gz-gui+",
        ] if dir_name else ["-fPIC"],
        deps = [
            "//:gz-gui",
            "@rules_qt//:qt_core",
            "@rules_qt//:qt_gui",
            "@rules_qt//:qt_widgets",
            "@rules_qt//:qt_qml",
            "@rules_qt//:qt_quick",
            "@qt_linux_x86_64//:qt_hdrs",
            "@gz-plugin//:register",
        ] + deps,
        visibility = ["//visibility:public"],
    )
