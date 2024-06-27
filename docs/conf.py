# Configuration file for the Sphinx documentation builder.
#
# For the full list of built-in configuration values, see the documentation:
# https://www.sphinx-doc.org/en/master/usage/configuration.html

# -- Project information -----------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#project-information

project = 'ZFSBootMenu'
author = 'ZFSBootMenu Team'
man_author = f'{author} <https://github.com/zbm-dev/zfsbootmenu>'
copyright = f'2019 Zach Dykstra, 2020-2024 {author}'
release = '2.3.0'

# -- General configuration ---------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#general-configuration

extensions = [
    'sphinx.ext.extlinks',
    'sphinx_tabs.tabs',
    'sphinx_copybutton',
    'recommonmark',
    'sphinx_reredirects',
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

# https://documatt.com/sphinx-reredirects/usage.html
# the target should be relative to ensure it works on RTD
# this is a fallback in case the redirects in the RTD settings are lost or no longer work
# RTD redirects should be:
# - Type: page redirect
# - From URL: /old/absolute/path/to/page.html
# - To URL: /new/absolute/path/to/page.html
# - HTTP status code: 301 Permanent
# - Force redirect: yes
# - Enabled: yes
# use manage-redirects.py to copy the config here to RTD
redirects = {
    # source : target
    "guides/binary-releases": "../../general/binary-releases.html",
    "guides/general/bootenvs-and-you": "../../general/bootenvs-and-you.html",
    "guides/general/container-building": "../../general/container-building.html",
    "guides/general/container-example": "../../general/container-building/example.html",
    "guides/general/mkinitcpio": "../../general/mkinitcpio.html",
    "guides/general/native-encryption": "../../general/native-encryption.html",
    "guides/general/portable": "../../general/portable.html",
    "guides/general/remote-access": "../../general/remote-access.html",
    "guides/general/tailscale": "../../general/tailscale.html",
    "guides/general/uefi-booting": "../../general/uefi-booting.html",
    "guides/ubuntu/uefi": "guides/ubuntu.html",
}

# -- Options for HTML output -------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#options-for-html-output

html_theme = 'sphinx_book_theme'
html_static_path = ['_static']
html_favicon = '_static/favicon.ico'
smartquotes = False
html_theme_options = {
    'repository_url': 'https://github.com/zbm-dev/zfsbootmenu',
    'use_repository_button': True,
    'use_fullscreen_button': False,
    'logo': {
        'image_light': '_static/logo-light.svg',
        'image_dark': '_static/logo-dark.svg',
    },
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

try:
    # tags is set by sphinx when interpreting the config
    if tags.has('manpages'):
        exclude_patterns += ['guides/**']
except NameError:
    ...
