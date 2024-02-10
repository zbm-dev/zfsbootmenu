# ZFSBootMenu Documentation

This document gives an overview of how the Sphinx documentation for ZFSBootMenu works.

## Building

The `Makefile` alongside this document provides several targets to prepare the Sphinx environment and render documentation.

### Prerequisites

Python 3 and several Python 3 packages are needed (see `requirements.txt` for a complete list). These packages can be
installed through your system package manager or via pip in a virtual environment with `make setup`.

Some make targets require further programs: `watchexec` for `make serve` and `rst2ansi` for `make gen-man`.

On Void Linux, `make setup-void` will install these programs and set up the virtual environment.

### Generating Documentation

Generally, the commands to build the documentation are `make html` (to build the web documentation) and `make man` (to
build the manpages).

Several special targets exist too:

- `make serve` can be used to build and locally serve the web documentation using Python's built-in webserver.
- `make gen-man` can be used to build the manpages and update them in `/docs/man/dist`.

See `make help` for a list of all possible targets.

### Cleaning up

- `make clean` will clean up the generated documentation.
- `make envclean` will clean up the virtual environment.
- `make clean-void` will clean up the virtual environment and remove any installed packages.

## Organisation

- `conf.py`: the Sphinx configuration file
- `index.rst`: the main page, and where the primary `toctree`s are listed
- `CHANGELOG.md`: the changelog for ZFSBootMenu
- `general`: where most documentation should reside. Documents about various topics, including various configuration options
  + `general/_include/` contains various documentation snippets
- `guides`: Documents about installation on various distros
  + `guides/_include/` contains distribution agonostic snippets
  + `guides/<distro>/_include/` contains distribution specific snippets
- `man`: manpages
- `online`: documentation primarily to be shown within ZFSBootMenu's help system
- `_static`: various static files for use within the documentation

## Formatting

- Most pages are written in reStructuredText (RST) format
- Some (like the changelog) are written in markdown for compatibility, so markdown is supported but RST is preferred
- When possible, keep lines limited to 120 characters, and use 2 spaces for indentation

To link to files within the ZFSBootMenu repository, use the `:zbm:` macro:

```rst
:zbm:`title <bin/generate-zbm>`
:zbm:`bin/generate-zbm`
```

will both create a link to the file `/bin/generate-zbm` on GitHub.

### Headings

reStructuredText allows various forms of section heading syntax. In this documentation, use:

Level 1:
```rst
My Title
========
```

Level 2:
```rst
My Title
--------
```

Level 3:
```rst
My Title
~~~~~~~~
```

Level 4:
```rst
My Title
^^^^^^^^
```

Also, the number of characters in the underline should match the number of characters in the title.

## Resources

To get a good overview of reStructuredText and Sphinx, take a look at the following resources:

- [reStructuredText Primer](https://www.sphinx-doc.org/en/master/usage/restructuredtext/basics.html)
- [reStructuredText Directives](https://www.sphinx-doc.org/en/master/usage/restructuredtext/directives.html)
- [Docutils reStructuredText Documentation](https://docutils.sourceforge.io/rst.html)
