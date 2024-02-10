#!/usr/bin/env python3
# Usage: RTD_TOKEN="..." python3 manage-redirects.py
# simple IaC-ish script to set redirects in readthedocs's config
# requires an api token from https://readthedocs.org/accounts/tokens/

from os import environ

import requests

from conf import redirects


SLUG = "zfsbootmenu"

URL = f"https://readthedocs.org/api/v3/projects/{SLUG}/redirects/"
HEADERS = {"Authorization": f"Token {environ.get('RTD_TOKEN')}"}


def transform_redirects(redir: dict[str, str]) -> dict[str, str]:
    """transform the redirect dictionary from the reredirects format to what rtd.org will want"""
    return { k+".html": "/"+v.lstrip("../") for k, v in redir.items() }


if __name__ == "__main__":
    # get the existing redirects
    existing = []
    req_url = URL
    while req_url is not None:
        resp = requests.get(req_url, headers=HEADERS)
        resp.raise_for_status()
        existing += resp.json().get("results", [])
        req_url = resp.json().get("next")

    # and delete them all
    for redir in existing:
        if (rid := redir.get('pk')) is not None:
            print(f"=> Deleting redirect {rid}: {redir.get('from_url')} -> {redir.get('to_url')}")
            resp = requests.delete(URL+f"{rid}/", headers=HEADERS)
            resp.raise_for_status()

    # replace them with the redirects defined in conf.py
    for old, new in transform_redirects(redirects).items():
        print(f"=> Creating redirect: {old} -> {new}")
        resp = requests.post(URL, headers=HEADERS, data={
            "from_url": old, "to_url": new, "type": "page", "http_status": 301, "force": True, "enabled": True,
        })
        resp.raise_for_status()
