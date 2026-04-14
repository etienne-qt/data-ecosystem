"""HubSpot API client — companies, contacts, deals."""

from __future__ import annotations

import logging
from typing import Any

from hubspot import HubSpot
from hubspot.crm.companies import SimplePublicObjectInput

from ecosystem.config import settings

logger = logging.getLogger(__name__)

# Default properties to fetch for companies
DEFAULT_COMPANY_PROPS = [
    "name",
    "domain",
    "website",
    "linkedin_company_page",
    "industry",
    "city",
    "state",
    "country",
    "numberofemployees",
    "annualrevenue",
    "founded_year",
    "description",
    "dealroom___id",
    "neq__numero_d_entreprise_du_quebec",
    "hs_object_id",
]


class HubSpotClient:
    """Wrapper around the HubSpot API client for CRM operations."""

    def __init__(self, access_token: str | None = None) -> None:
        token = access_token or settings.hubspot.access_token
        self._client = HubSpot(access_token=token)

    def get_companies(
        self,
        properties: list[str] | None = None,
        limit: int = 100,
        after: str | None = None,
    ) -> tuple[list[dict[str, Any]], str | None]:
        """Fetch a page of companies. Returns (companies, next_page_cursor)."""
        props = properties or DEFAULT_COMPANY_PROPS
        response = self._client.crm.companies.basic_api.get_page(
            limit=limit,
            properties=props,
            after=after,
        )
        companies = [
            {"id": c.id, **c.properties}
            for c in response.results
        ]
        next_cursor = response.paging.next.after if response.paging and response.paging.next else None
        return companies, next_cursor

    def get_all_companies(
        self,
        properties: list[str] | None = None,
        max_pages: int = 0,
    ) -> list[dict[str, Any]]:
        """Fetch all companies with automatic pagination. Set max_pages=0 for unlimited."""
        all_companies: list[dict[str, Any]] = []
        cursor = None
        page = 0
        while True:
            batch, cursor = self.get_companies(properties=properties, after=cursor)
            all_companies.extend(batch)
            page += 1
            logger.info("Fetched page %d (%d companies so far)", page, len(all_companies))
            if not cursor or (max_pages and page >= max_pages):
                break
        return all_companies

    def update_company(self, company_id: str, properties: dict[str, Any]) -> dict[str, Any]:
        """Update a single company's properties."""
        obj = SimplePublicObjectInput(properties=properties)
        result = self._client.crm.companies.basic_api.update(
            company_id=company_id,
            simple_public_object_input=obj,
        )
        return {"id": result.id, **result.properties}

    def batch_update_companies(
        self,
        updates: list[dict[str, Any]],
    ) -> int:
        """Batch update companies. Each dict needs 'id' and 'properties' keys.

        Returns count of successfully updated companies.
        """
        from hubspot.crm.companies import BatchInputSimplePublicObjectBatchInput, SimplePublicObjectBatchInput

        batch_input = BatchInputSimplePublicObjectBatchInput(
            inputs=[
                SimplePublicObjectBatchInput(id=u["id"], properties=u["properties"])
                for u in updates
            ]
        )
        result = self._client.crm.companies.batch_api.update(batch_input_simple_public_object_batch_input=batch_input)
        logger.info("Batch updated %d companies", len(result.results))
        return len(result.results)

    def search_companies(
        self,
        filter_groups: list[dict],
        properties: list[str] | None = None,
        limit: int = 100,
    ) -> list[dict[str, Any]]:
        """Search companies using HubSpot filter groups."""
        from hubspot.crm.companies import PublicObjectSearchRequest

        request = PublicObjectSearchRequest(
            filter_groups=filter_groups,
            properties=properties or DEFAULT_COMPANY_PROPS,
            limit=limit,
        )
        response = self._client.crm.companies.search_api.do_search(
            public_object_search_request=request,
        )
        return [{"id": c.id, **c.properties} for c in response.results]
