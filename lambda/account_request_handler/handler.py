"""
Account request Lambda (no Control Tower).

CREATE: ensure OU → generate aws_organizations_account TF → PR
DELETE: remove accounts/<name>.tf → PR
"""

from __future__ import annotations

import json
import logging
import os
import time
import urllib.request
from typing import Any

from git_client import CodeCommitClient
from ou_manager import OUManager
from terraform_generator import TerraformGenerator

LOG_LEVEL = os.environ.get("LOG_LEVEL", "INFO")
logging.basicConfig(level=LOG_LEVEL)
logger = logging.getLogger(__name__)

REPO_NAME = os.environ["ACCOUNT_REQUEST_REPO_NAME"]
DEFAULT_BRANCH = os.environ.get("DEFAULT_BRANCH", "main")
PARENT_OU_ID = os.environ["PARENT_OU_ID"]
REGION = os.environ.get("AWS_REGION_NAME") or os.environ.get("AWS_REGION", "us-east-1")


def _parse_tags(raw: Any) -> dict[str, str]:
    if not raw:
        return {}
    if isinstance(raw, dict):
        return {str(k): str(v) for k, v in raw.items()}
    if isinstance(raw, str) and raw.strip():
        result: dict[str, str] = {}
        for part in raw.split(","):
            if "=" in part:
                k, v = part.split("=", 1)
                result[k.strip()] = v.strip()
        return result
    return {}


def _normalize_params(event: dict[str, Any]) -> dict[str, Any]:
    props = event.get("ResourceProperties") or event
    props = {k: v for k, v in props.items() if k != "ServiceToken"}
    operation = str(props.get("Operation", "CREATE")).upper()
    if event.get("RequestType") == "Delete":
        operation = "DELETE"
    return {
        "AccountName": props["AccountName"],
        "AccountEmail": props.get("AccountEmail", ""),
        "OrganizationalUnit": props.get("OrganizationalUnit", props.get("ManagedOrganizationalUnit", "Sandbox")),
        "RoleName": props.get("RoleName", "OrganizationAccountAccessRole"),
        "ChangeRequestedBy": props.get("ChangeRequestedBy", "service-catalog"),
        "ChangeReason": props.get("ChangeReason", "Account request"),
        "Operation": operation,
        "AccountTags": _parse_tags(props.get("AccountTags")),
    }


def _cfn_response(
    event: dict[str, Any],
    context: Any,
    status: str,
    data: dict[str, Any],
    physical_id: str,
    reason: str | None = None,
) -> None:
    body = {
        "Status": status,
        "Reason": reason or f"See logs: {getattr(context, 'log_stream_name', '')}",
        "PhysicalResourceId": physical_id,
        "StackId": event.get("StackId"),
        "RequestId": event.get("RequestId"),
        "LogicalResourceId": event.get("LogicalResourceId"),
        "Data": data,
    }
    url = event.get("ResponseURL")
    if not url:
        logger.info("Direct invoke response: %s", json.dumps(body))
        return
    req = urllib.request.Request(
        url,
        data=json.dumps(body).encode("utf-8"),
        headers={"Content-Type": ""},
        method="PUT",
    )
    with urllib.request.urlopen(req) as resp:
        logger.info("CFN response HTTP %s", resp.status)


def process_create(params: dict[str, Any]) -> dict[str, Any]:
    account_name = params["AccountName"]
    ou_name = params["OrganizationalUnit"]

    ou_mgr = OUManager(parent_ou_id=PARENT_OU_ID, region=REGION)
    ou = ou_mgr.ensure_ou_exists(ou_name)

    gen = TerraformGenerator()
    content = gen.render_account(
        account_name=account_name,
        account_email=params["AccountEmail"],
        parent_id=ou["Id"],
        role_name=params["RoleName"],
        account_tags=params["AccountTags"],
    )
    file_path = gen.file_path_for_account(account_name)

    git = CodeCommitClient(REPO_NAME, region=REGION)
    base_commit = git.ensure_default_branch(DEFAULT_BRANCH)
    branch = f"account-request/{account_name}-{int(time.time())}"
    git.create_branch(branch, base_commit)
    git.put_file(
        branch_name=branch,
        file_path=file_path,
        content=content,
        commit_message=f"Add account: {account_name}",
        parent_commit_id=base_commit,
    )
    pr = git.create_pull_request(
        title=f"Create account: {account_name}",
        description=(
            f"Operation: CREATE\n"
            f"Account: {account_name}\n"
            f"Email: {params['AccountEmail']}\n"
            f"OU: {ou['Name']} ({ou['Id']})\n"
            f"Requested by: {params['ChangeRequestedBy']}\n"
            f"Reason: {params['ChangeReason']}\n\n"
            f"Approve this pull request. Approval merges it to {DEFAULT_BRANCH} "
            f"and starts the pipeline, which creates the AWS account."
        ),
        source_branch=branch,
        dest_branch=DEFAULT_BRANCH,
    )
    pr_id = pr["pullRequestId"]
    return {
        "PullRequestId": pr_id,
        "PullRequestUrl": git.pr_console_url(pr_id),
        "Branch": branch,
        "FilePath": file_path,
        "OUName": ou["Name"],
        "OUId": ou["Id"],
        "Operation": "CREATE",
    }


def process_delete(params: dict[str, Any]) -> dict[str, Any]:
    account_name = params["AccountName"]
    gen = TerraformGenerator()
    file_path = gen.file_path_for_account(account_name)

    git = CodeCommitClient(REPO_NAME, region=REGION)
    base_commit = git.ensure_default_branch(DEFAULT_BRANCH)

    if not git.file_exists(DEFAULT_BRANCH, file_path):
        return {
            "PullRequestId": "",
            "PullRequestUrl": "",
            "Branch": "",
            "FilePath": file_path,
            "Message": "File not found; no PR created",
            "Operation": "DELETE",
        }

    branch = f"account-close/{account_name}-{int(time.time())}"
    git.create_branch(branch, base_commit)
    git.delete_file(
        branch_name=branch,
        file_path=file_path,
        commit_message=f"Close account: {account_name}",
        parent_commit_id=base_commit,
    )
    pr = git.create_pull_request(
        title=f"Close account: {account_name}",
        description=(
            f"Operation: DELETE\nRemoves {file_path}. "
            f"Approve this pull request. Approval merges it to {DEFAULT_BRANCH} "
            f"and starts the pipeline, which closes the account."
        ),
        source_branch=branch,
        dest_branch=DEFAULT_BRANCH,
    )
    pr_id = pr["pullRequestId"]
    return {
        "PullRequestId": pr_id,
        "PullRequestUrl": git.pr_console_url(pr_id),
        "Branch": branch,
        "FilePath": file_path,
        "Operation": "DELETE",
    }


def handle_pull_request_approval(event: dict[str, Any]) -> dict[str, Any]:
    """Merge the PR after a human approves it. The merge starts the pipeline."""
    detail = event.get("detail") or {}
    if detail.get("event") != "pullRequestApprovalStateChanged":
        return {"statusCode": 200, "body": "ignored"}
    if str(detail.get("approvalStatus", "")).upper() != "APPROVE":
        return {"statusCode": 200, "body": "not an approval"}

    pr_id = str(detail.get("pullRequestId") or "")
    if not pr_id:
        raise ValueError("pullRequestId missing from approval event")

    repos = detail.get("repositoryNames") or []
    if repos and REPO_NAME not in repos:
        return {"statusCode": 200, "body": "different repository"}

    git = CodeCommitClient(REPO_NAME, region=REGION)
    result = git.merge_if_approved(pr_id)
    logger.info("Approval result: %s", result)
    return {"statusCode": 200, "body": result}


def lambda_handler(event: dict[str, Any], context: Any) -> dict[str, Any]:
    logger.info("Event: %s", json.dumps(event, default=str))
    if event.get("source") == "aws.codecommit":
        return handle_pull_request_approval(event)

    is_cfn = "ResponseURL" in event or event.get("RequestType") in ("Create", "Update", "Delete")

    try:
        params = _normalize_params(event)
        physical_id = f"account-request-{params['AccountName']}"

        if event.get("RequestType") == "Delete" or params["Operation"] == "DELETE":
            result = process_delete(params)
        else:
            if not params.get("AccountEmail"):
                raise ValueError("AccountEmail is required for CREATE")
            result = process_create(params)

        if is_cfn:
            _cfn_response(event, context, "SUCCESS", result, physical_id)
        return {"statusCode": 200, "body": result}

    except Exception as exc:
        logger.exception("Handler failed")
        if is_cfn:
            physical_id = event.get("PhysicalResourceId") or f"account-request-failed-{int(time.time())}"
            _cfn_response(event, context, "FAILED", {"Error": str(exc)}, physical_id, reason=str(exc))
        raise
