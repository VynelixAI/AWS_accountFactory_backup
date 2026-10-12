"""Organizational Unit helpers — AWS Organizations (no Control Tower)."""

from __future__ import annotations

import logging
from typing import Any

import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger(__name__)


class OUManager:
    def __init__(self, parent_ou_id: str, region: str | None = None) -> None:
        self.parent_ou_id = parent_ou_id
        kwargs: dict[str, Any] = {}
        if region:
            kwargs["region_name"] = region
        self.client = boto3.client("organizations", **kwargs)

    def list_child_ous(self, parent_id: str | None = None) -> list[dict[str, str]]:
        parent = parent_id or self.parent_ou_id
        ous: list[dict[str, str]] = []
        token: str | None = None
        while True:
            kwargs: dict[str, Any] = {"ParentId": parent}
            if token:
                kwargs["NextToken"] = token
            resp = self.client.list_organizational_units_for_parent(**kwargs)
            for ou in resp.get("OrganizationalUnits", []):
                ous.append({"Id": ou["Id"], "Name": ou["Name"]})
            token = resp.get("NextToken")
            if not token:
                break
        return ous

    def find_ou_by_name(self, name: str, parent_id: str | None = None) -> dict[str, str] | None:
        for ou in self.list_child_ous(parent_id):
            if ou["Name"] == name:
                return ou
        return None

    def ensure_ou_exists(self, ou_name: str, parent_id: str | None = None) -> dict[str, str]:
        parent = parent_id or self.parent_ou_id
        existing = self.find_ou_by_name(ou_name, parent)
        if existing:
            logger.info("OU already exists: %s (%s)", existing["Name"], existing["Id"])
            return existing

        logger.info("Creating OU %s under %s", ou_name, parent)
        try:
            resp = self.client.create_organizational_unit(ParentId=parent, Name=ou_name)
            ou = resp["OrganizationalUnit"]
            result = {"Id": ou["Id"], "Name": ou["Name"]}
            logger.info("Created OU: %s (%s)", result["Name"], result["Id"])
            return result
        except ClientError as exc:
            if exc.response["Error"]["Code"] == "DuplicateOrganizationalUnitException":
                existing = self.find_ou_by_name(ou_name, parent)
                if existing:
                    return existing
            raise
