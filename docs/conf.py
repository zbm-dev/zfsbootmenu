# Configuration file for the Sphinx documentation builder.
#
# For the full list of built-in configuration values, see the documentation:
# https://www.sphinx-doc.org/en/master/usage/configuration.html

# -- Project information -----------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#project-information

project = 'ZFSBootMenu'
author = 'Zach Dykstra'
copyright = f'2019 {author}'
release = '2.0.0'

# -- General configuration ---------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#general-configuration

extensions = [
    'sphinx.ext.extlinks',
    'sphinx_tabs.tabs',
    'sphinx_rtd_theme',
    'recommonmark',
]

templates_path = ['_templates']
exclude_patterns = ['_build', 'Thumbs.db', '.DS_Store', '*env', '**/_include']

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
smartquotes = False
html_logo = '_static/logo.svg'
html_theme_options = {
    'style_external_links': True,
    'collapse_navigation': False,
    'titles_only': True,
}
html_baseurl = 'https://docs.zfsbootmenu.org'
html_css_files = ['custom.css']
