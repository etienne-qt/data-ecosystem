"""Centralized configuration loaded from .env via pydantic-settings."""

from pathlib import Path

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict

PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
_ENV_FILE = str(PROJECT_ROOT / ".env")


class SnowflakeSettings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="SNOWFLAKE_", env_file=_ENV_FILE, extra="ignore")

    account: str = ""
    user: str = ""
    password: str = ""
    private_key_file: str = ""
    warehouse: str = "COMPUTE_WH"
    database: str = "DEV_QUEBECTECH"
    schema_: str = Field("PUBLIC", alias="SNOWFLAKE_SCHEMA")
    role: str = ""


class HubSpotSettings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="HUBSPOT_", env_file=_ENV_FILE, extra="ignore")

    access_token: str = ""


class AsanaSettings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="ASANA_", env_file=_ENV_FILE, extra="ignore")

    access_token: str = ""
    client_id: str = ""
    client_secret: str = ""
    oauth_token_file: str = ""
    workspace_gid: str = ""
    project_gid: str = ""


class GoogleSettings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="GOOGLE_", env_file=_ENV_FILE, extra="ignore")

    service_account_file: str = ""
    docs_folder_id: str = ""
    oauth_client_file: str = ""
    oauth_token_file: str = ""


class LLMSettings(BaseSettings):
    model_config = SettingsConfigDict(env_file=_ENV_FILE, extra="ignore")

    llm_provider: str = "ollama"
    ollama_model: str = "llama3"
    ollama_host: str = "http://127.0.0.1:11434"


class Settings(BaseSettings):
    """Top-level settings that aggregates all sub-configs."""

    model_config = SettingsConfigDict(
        env_file=_ENV_FILE,
        env_file_encoding="utf-8",
        extra="ignore",
    )

    snowflake: SnowflakeSettings = Field(default_factory=SnowflakeSettings)
    hubspot: HubSpotSettings = Field(default_factory=HubSpotSettings)
    asana: AsanaSettings = Field(default_factory=AsanaSettings)
    google: GoogleSettings = Field(default_factory=GoogleSettings)
    llm: LLMSettings = Field(default_factory=LLMSettings)

    # Paths
    project_root: Path = PROJECT_ROOT
    sql_dir: Path = PROJECT_ROOT / "sql"
    knowledge_base_dir: Path = PROJECT_ROOT / "knowledge_base"
    logs_dir: Path = PROJECT_ROOT / "logs"
    chromadb_path: str = str(PROJECT_ROOT / "knowledge_base" / ".chromadb")

    # Data subdirectories
    data_dir: Path = PROJECT_ROOT / "data"
    raw_input_dir: Path = PROJECT_ROOT / "data" / "01_raw_input"
    reference_dir: Path = PROJECT_ROOT / "data" / "02_reference"
    reviews_dir: Path = PROJECT_ROOT / "data" / "03_reviews"
    auto_reviews_dir: Path = PROJECT_ROOT / "data" / "04_auto_reviews"
    pipeline_output_dir: Path = PROJECT_ROOT / "data" / "05_pipeline_output"
    cache_dir: Path = PROJECT_ROOT / "data" / "cache"
    intermediate_dir: Path = PROJECT_ROOT / "data" / "intermediate"


# Singleton — import and use: `from ecosystem.config import settings`
settings = Settings()
