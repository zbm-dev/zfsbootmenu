import re
from pathlib import Path
from dataclasses import dataclass

from sphinx.application import Sphinx
from sphinx.ext.autodoc import ModuleDocumenter


class ZBMDocDirective(Directive):
    required_arguments = 1  # filename

    def run(self):
        try:
            doc_comments = read_file(self.arguments[0])
        except Exception as e:
            raise self.error(str(e))
        node_list = []
        for cmt in doc_comments:
            ...
        return node_list


@dataclass
class DocComment:
    # filename: Path,
    functions: list[str]
    args: dict[str, str] | str | None = None
    prints: str | None = None
    returns: str | None = None
    description: str | None = None

    def to_doc(self):
        return nodes.


class CommentParseError(Exception):
    def __init__(self, file: Path, line_no: int, line: str, msg: str):
        self.file = file
        self.line_no = line_no
        self.line = line
        self.msg = msg

    def __str__(self):
        return f"In file <{self.file}>, line {self.line_no}:\n\t{self.line}\nUnable to parse: {self.msg}"


def read_file(fn: Path) -> list[DocComment]:
    cmts: list[DocComment] = []
    curr_cmt = None
    with fn.open() as f:
        for i, ln in enumerate(f.readlines(), start=1):
            # doc: <funcs...>
            if curr_cmt is None:
                if ln.startswith("# doc:"):
                    curr_cmt = DocComment(functions=ln.removeprefix("# doc:").strip().split())
            else:
                # args: <description>
                if ln.startswith("# args:"):
                    desc = ln.removeprefix("# args:")
                    if curr_cmt.args is None:
                        if desc.lower() == "none":
                            continue
                        elif isinstance(curr_cmt.args, str):
                            curr_cmt.args = desc.strip()
                        else:
                            raise CommentParseError(fn, i, ln, "Conflicting argument lines")
                    else:
                        raise CommentParseError(fn, i, ln, "Multiple arguments lines")
                # arg1: <description>
                # arg2..arg5: <description>
                elif ln.startswith("# arg"):
                    if m := re.match(r"# arg(?P<start>[^.:]+)(?:\.\.\.?arg(?P<end>[^:]+))?:(?P<desc>.*)$", ln):
                        args = {"-".join(filter(None, m.group("start", "end"))): m.group("desc")}
                        if curr_cmt.args is None:
                            curr_cmt.args = args
                        elif isinstance(curr_cmt.args, dict):
                            curr_cmt.args |= args
                        else:
                            raise CommentParseError(fn, i, ln, "Conflicting arguments lines")
                    else:
                        raise CommentParseError(fn, i, ln, "comment not of the form 'arg#:' or 'arg#..arg#:'")
                # prints: <description>
                elif ln.startswith("# prints:"):
                    if curr_cmt.prints is None:
                        curr_cmt.prints = ln.removeprefix("# prints:").strip()
                    else:
                        raise CommentParseError(fn, i, ln, 'Multiple prints lines')
                # returns: <description>
                elif ln.startswith("# returns:"):
                    if curr_cmt.prints is None:
                        curr_cmt.returns = ln.removeprefix("# returns:").strip()
                    else:
                        raise CommentParseError(fn, i, ln, 'Multiple returns lines')
                # <any content>
                elif ln.startswith("#"):
                    ln = ln.removeprefix("#").strip() + "\n"
                    if curr_cmt.description is None:
                        curr_cmt.description = ln
                    else:
                        curr_cmt.description += ln
                # end of comment
                else:
                    cmts.append(curr_cmt)
                    curr_cmt = None
    return cmts


def setup(app: Sphinx):
    app.setup_extension("sphinx.ext.autodoc")
    app.add_autodocumenter(ZBMFileDocumenter)

    return {
        "version": "0.1",
        "parallel_read_safe": True,
        "parallel_write_safe": True,
    }
