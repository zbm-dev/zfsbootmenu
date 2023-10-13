# Configuration file for the Sphinx documentation builder.
#
# For the full list of built-in configuration values, see the documentation:
# https://www.sphinx-doc.org/en/master/usage/configuration.html

# -- Project information -----------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#project-information

project = 'ZFSBootMenu'
author = 'ZFSBootMenu Team'
man_author = f'{author} <https://github.com/zbm-dev/zfsbootmenu>'
copyright = f'2019 Zach Dykstra, 2020-2023 {author}'
release = '2.2.1'

# -- General configuration ---------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#general-configuration

extensions = [
    'sphinx.ext.extlinks',
    'sphinx_tabs.tabs',
    'sphinx_rtd_theme',
    'sphinx_copybutton',
    'recommonmark',
]

templates_path = ['_templates']
exclude_patterns = ['_build', 'Thumbs.db', '.DS_Store', '*env', '**/_include', 'README.md']

today_fmt = '%Y-%m-%d'
highlight_language = 'sh'
smartquotes = False
manpages_url = 'https://man.voidlinux.org/{page}.{section}'

# https://www.sphinx-doc.org/en/master/usage/extensions/extlinks.html
extlinks = {
    'zbm': (f'https://github.com/zbm-dev/zfsbootmenu/blob/v{release}/%s', '%s'),
}

# -- Options for HTML output -------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#options-for-html-output

html_theme = 'sphinx_rtd_theme'
html_static_path = ['_static']
html_favicon = '_static/favicon.ico'
smartquotes = False
html_logo = '_static/logo.svg'
html_theme_options = {
    'style_external_links': True,
    'collapse_navigation': False,
    'titles_only': True,
}
html_baseurl = 'https://docs.zfsbootmenu.org'
html_css_files = ['custom.css']

# -- Options for linkcheck output -------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#options-for-linkcheck-builder

linkcheck_ignore = [
    'https://github.com/zbm-dev/zfsbootmenu/blob/master/docs/man/zfsbootmenu.7.rst#',
    f'https://github.com/zbm-dev/zfsbootmenu/blob/v{release}/releng/docker/README.md#',
]

# -- Options for manual page output ------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#options-for-manual-page-output

man_make_section_directory = True
man_pages = [
    ('man/generate-zbm.5', 'generate-zbm', 'configuration file for generate-zbm', man_author, '5'),
    ('man/generate-zbm.8', 'generate-zbm', 'ZFSBootMenu initramfs generator', man_author, '8'),
    ('man/zbm-kcl.8', 'zbm-kcl', 'manipulate kernel command lines for boot environments and EFI executables', man_author, '8'),
    ('man/zfsbootmenu.7', 'zfsbootmenu', 'System Integration', man_author, '7'),
]

if tags.has('manpages'):
    exclude_patterns += ['guides/**']
