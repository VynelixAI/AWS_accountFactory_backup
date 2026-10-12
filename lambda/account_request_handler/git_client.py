"""CodeCommit: branch, put/delete file, open pull request."""

from __future__ import annotations

import logging
from typing import Any

import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger(__name__)


class CodeCommitClient:
    def __init__(self, repository_name: str, region: str | None = None) -> None:
        self.repository_name = repository_name

        kwargs: dict[str, Any] = {}

        if region:
            kwargs["region_name"] = region

        self.client = boto3.client("codecommit", **kwargs)

        self.region = (
            region
            or boto3.session.Session().region_name
            or "us-east-1"
        )

    def get_branch_commit(self, branch_name: str) -> str | None:
        try:
            resp = self.client.get_branch(
                repositoryName=self.repository_name,
                branchName=branch_name,
            )

            return resp["branch"]["commitId"]

        except ClientError as exc:
            if exc.response["Error"]["Code"] == "BranchDoesNotExistException":
                return None

            raise

    def ensure_default_branch(self, default_branch: str = "main") -> str:
        commit_id = self.get_branch_commit(default_branch)

        if commit_id:
            return commit_id

        logger.info(
            "Empty repo; creating initial commit on %s",
            default_branch,
        )

        put = self.client.put_file(
            repositoryName=self.repository_name,
            branchName=default_branch,
            fileContent=(
                b"# account-request\n\n"
                b"Terraform files for member accounts. "
                b"Merge to main runs terraform apply (Organizations).\n"
            ),
            filePath="README.md",
            commitMessage="Initial commit",
            name="account-factory-lambda",
            email="account-factory@example.com",
        )

        return put["commitId"]

    def create_branch(
        self,
        branch_name: str,
        from_commit_id: str,
    ) -> None:

        try:
            self.client.create_branch(
                repositoryName=self.repository_name,
                branchName=branch_name,
                commitId=from_commit_id,
            )

        except ClientError as exc:
            if exc.response["Error"]["Code"] != "BranchNameExistsException":
                raise

    def put_file(
        self,
        *,
        branch_name: str,
        file_path: str,
        content: str,
        commit_message: str,
        parent_commit_id: str,
    ) -> str:

        kwargs: dict[str, Any] = {
            "repositoryName": self.repository_name,
            "branchName": branch_name,
            "fileContent": content.encode("utf-8"),
            "filePath": file_path,
            "commitMessage": commit_message,
            "name": "account-factory-lambda",
            "email": "account-factory@example.com",
            "parentCommitId": parent_commit_id,
        }

        try:
            return self.client.put_file(**kwargs)["commitId"]

        except ClientError as exc:
            if exc.response["Error"]["Code"] in (
                "FileAlreadyExistsException",
                "SameFileContentException",
            ):

                tip = self.get_branch_commit(branch_name)

                if tip and tip != parent_commit_id:
                    kwargs["parentCommitId"] = tip

                    return self.client.put_file(**kwargs)["commitId"]

            raise

    def delete_file(
        self,
        *,
        branch_name: str,
        file_path: str,
        commit_message: str,
        parent_commit_id: str,
    ) -> str:

        return self.client.delete_file(
            repositoryName=self.repository_name,
            branchName=branch_name,
            filePath=file_path,
            parentCommitId=parent_commit_id,
            commitMessage=commit_message,
            name="account-factory-lambda",
            email="account-factory@example.com",
        )["commitId"]

    def file_exists(
        self,
        branch_name: str,
        file_path: str,
    ) -> bool:

        try:
            self.client.get_file(
                repositoryName=self.repository_name,
                commitSpecifier=branch_name,
                filePath=file_path,
            )

            return True

        except ClientError as exc:
            if exc.response["Error"]["Code"] in (
                "FileDoesNotExistException",
                "CommitDoesNotExistException",
            ):
                return False

            raise

    def find_open_pr_for_branch(
        self,
        source_branch: str,
    ) -> dict[str, Any] | None:

        try:
            resp = self.client.list_pull_requests(
                repositoryName=self.repository_name,
                pullRequestStatus="OPEN",
            )

            for pr_id in resp.get("pullRequestIds", []):

                pr = self.client.get_pull_request(
                    pullRequestId=pr_id
                )["pullRequest"]

                for target in pr.get("pullRequestTargets", []):

                    if target.get("sourceReference") == (
                        f"refs/heads/{source_branch}"
                    ):
                        return pr

        except ClientError:
            logger.exception("list_pull_requests failed")

        return None

    def create_pull_request(
        self,
        *,
        title: str,
        description: str,
        source_branch: str,
        dest_branch: str = "main",
    ) -> dict[str, Any]:

        existing = self.find_open_pr_for_branch(source_branch)

        if existing:
            return existing

        resp = self.client.create_pull_request(
            title=title,
            description=description,
            targets=[
                {
                    "repositoryName": self.repository_name,
                    "sourceReference": source_branch,
                    "destinationReference": dest_branch,
                }
            ],
        )

        pr = resp["pullRequest"]
        logger.info(
            "Opened pull request %s from %s to %s",
            pr.get("pullRequestId"),
            source_branch,
            dest_branch,
        )
        return pr

    def merge_if_approved(self, pull_request_id: str) -> dict[str, Any]:
        """Merge an open PR once its approval rule is satisfied.

        The merge updates main, which starts the account-request pipeline.
        """
        pr = self.client.get_pull_request(pullRequestId=pull_request_id)["pullRequest"]
        status = pr.get("pullRequestStatus")
        if status != "OPEN":
            logger.info("Pull request %s is %s; not merging", pull_request_id, status)
            return {"merged": False, "pullRequestId": pull_request_id, "reason": status or "not-open"}

        evaluation = self.client.evaluate_pull_request_approval_rules(
            pullRequestId=pull_request_id,
            revisionId=pr["revisionId"],
        )["evaluation"]
        if not evaluation.get("approved") and not evaluation.get("overridden"):
            logger.info(
                "Pull request %s is not fully approved yet: %s",
                pull_request_id,
                evaluation,
            )
            return {
                "merged": False,
                "pullRequestId": pull_request_id,
                "reason": "approval rules not satisfied",
            }

        try:
            self.client.merge_pull_request_by_fast_forward(
                pullRequestId=pull_request_id,
                repositoryName=self.repository_name,
            )
        except ClientError as exc:
            code = exc.response["Error"]["Code"]
            if code in (
                "ManualMergeRequiredException",
                "TipOfSourceReferenceIsDifferentException",
            ):
                self.client.merge_pull_request_by_three_way(
                    pullRequestId=pull_request_id,
                    repositoryName=self.repository_name,
                    authorName="account-factory",
                    email="account-factory@example.com",
                    commitMessage=f"Merge approved pull request {pull_request_id}",
                )
            elif code in (
                "PullRequestAlreadyClosedException",
                "PullRequestDoesNotExistException",
            ):
                return {"merged": False, "pullRequestId": pull_request_id, "reason": code}
            else:
                raise

        logger.info("Merged approved pull request %s into %s", pull_request_id, self.repository_name)
        return {"merged": True, "pullRequestId": pull_request_id}

    def pr_console_url(
        self,
        pull_request_id: str,
    ) -> str:

        return (
            f"https://{self.region}.console.aws.amazon.com/"
            f"codesuite/codecommit/repositories/"
            f"{self.repository_name}/pull-requests/"
            f"{pull_request_id}"
        )
