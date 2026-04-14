"""Snowflake connector — run queries, upload DataFrames, execute SQL files."""

from __future__ import annotations

import logging
from contextlib import contextmanager
from pathlib import Path
from typing import TYPE_CHECKING

import pandas as pd
import snowflake.connector

from ecosystem.config import settings

if TYPE_CHECKING:
    from collections.abc import Generator

    from snowflake.connector import SnowflakeConnection
    from snowflake.connector.cursor import SnowflakeCursor

logger = logging.getLogger(__name__)


def _load_private_key(path: str | Path) -> bytes:
    """Load a PKCS8 PEM private key file and return DER bytes for Snowflake."""
    from cryptography.hazmat.backends import default_backend
    from cryptography.hazmat.primitives import serialization

    key_path = Path(path)
    with open(key_path, "rb") as f:
        private_key = serialization.load_pem_private_key(
            f.read(),
            password=None,
            backend=default_backend(),
        )
    return private_key.private_bytes(
        encoding=serialization.Encoding.DER,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption(),
    )


class SnowflakeClient:
    """Thin wrapper around snowflake-connector-python."""

    def __init__(
        self,
        account: str | None = None,
        user: str | None = None,
        password: str | None = None,
        private_key_file: str | None = None,
        warehouse: str | None = None,
        database: str | None = None,
        schema: str | None = None,
        role: str | None = None,
    ) -> None:
        sf = settings.snowflake
        key_file = private_key_file or sf.private_key_file

        self._connect_params: dict = {
            "account": account or sf.account,
            "user": user or sf.user,
            "warehouse": warehouse or sf.warehouse,
            "database": database or sf.database,
            "schema": schema or sf.schema_,
            "role": role or sf.role,
        }

        # Key-pair auth takes precedence over password
        if key_file:
            self._connect_params["private_key"] = _load_private_key(key_file)
        else:
            self._connect_params["password"] = password or sf.password

        # Remove empty strings
        self._connect_params = {k: v for k, v in self._connect_params.items() if v}

    @contextmanager
    def connect(self) -> Generator[SnowflakeConnection, None, None]:
        """Context manager yielding an active Snowflake connection."""
        conn = snowflake.connector.connect(**self._connect_params)
        try:
            yield conn
        finally:
            conn.close()

    @contextmanager
    def cursor(self) -> Generator[SnowflakeCursor, None, None]:
        """Context manager yielding a cursor."""
        with self.connect() as conn:
            cur = conn.cursor()
            try:
                yield cur
            finally:
                cur.close()

    def query(self, sql: str, params: dict | None = None) -> pd.DataFrame:
        """Execute a query and return results as a DataFrame."""
        with self.cursor() as cur:
            cur.execute(sql, params)
            columns = [desc[0] for desc in cur.description] if cur.description else []
            rows = cur.fetchall()
            return pd.DataFrame(rows, columns=columns)

    def execute(self, sql: str, params: dict | None = None) -> int:
        """Execute a statement (INSERT, MERGE, etc.) and return rows affected."""
        with self.cursor() as cur:
            cur.execute(sql, params)
            return cur.rowcount or 0

    def execute_file(self, path: str | Path) -> list[int]:
        """Execute a SQL file (semicolon-separated statements). Returns rows affected per statement."""
        sql_text = Path(path).read_text(encoding="utf-8")
        statements = [s.strip() for s in sql_text.split(";") if s.strip()]
        results = []
        with self.cursor() as cur:
            for stmt in statements:
                logger.info("Executing: %s...", stmt[:80])
                cur.execute(stmt)
                results.append(cur.rowcount or 0)
        return results

    def upload_df(
        self,
        df: pd.DataFrame,
        table: str,
        database: str | None = None,
        schema: str | None = None,
        overwrite: bool = False,
    ) -> None:
        """Upload a DataFrame to a Snowflake table using write_pandas."""
        from snowflake.connector.pandas_tools import write_pandas

        with self.connect() as conn:
            write_pandas(
                conn,
                df,
                table_name=table,
                database=database,
                schema=schema,
                overwrite=overwrite,
                auto_create_table=True,
                quote_identifiers=False,
            )
            logger.info("Uploaded %d rows to %s", len(df), table)
