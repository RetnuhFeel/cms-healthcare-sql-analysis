#!/usr/bin/env python3
"""
Download the CMS public datasets used in this project and write a small,
reproducible sample to data/sample/*.csv.gz.

Only the Python standard library is used, so this runs anywhere Python 3.9+ is
installed. Every request goes to an official CMS endpoint:

  * data.cms.gov Data API  (https://data.cms.gov/data-api/v1/dataset/<uuid>/data)
  * CMS Provider Data Catalog datastore API
    (https://data.cms.gov/provider-data/api/1/datastore/query/<id>/0/download)

The values are written exactly as CMS publishes them (as text). All cleaning
happens later in SQL - that is the point of the project.

Usage:
    python scripts/download_cms.py                # default sample: Tennessee
    python scripts/download_cms.py --state GA     # any other state
"""
from __future__ import annotations

import argparse
import csv
import gzip
import io
import json
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "data" / "sample"
REF = ROOT / "data" / "reference"

DATA_API = "https://data.cms.gov/data-api/v1/dataset/{uuid}/data"
PDC_API = "https://data.cms.gov/provider-data/api/1/datastore/query/{id}/0/download"
PAGE = 5000

STATE_NAMES = {
    "AL": "Alabama", "AK": "Alaska", "AZ": "Arizona", "AR": "Arkansas", "CA": "California",
    "CO": "Colorado", "CT": "Connecticut", "DE": "Delaware", "DC": "District of Columbia",
    "FL": "Florida", "GA": "Georgia", "HI": "Hawaii", "ID": "Idaho", "IL": "Illinois",
    "IN": "Indiana", "IA": "Iowa", "KS": "Kansas", "KY": "Kentucky", "LA": "Louisiana",
    "ME": "Maine", "MD": "Maryland", "MA": "Massachusetts", "MI": "Michigan", "MN": "Minnesota",
    "MS": "Mississippi", "MO": "Missouri", "MT": "Montana", "NE": "Nebraska", "NV": "Nevada",
    "NH": "New Hampshire", "NJ": "New Jersey", "NM": "New Mexico", "NY": "New York",
    "NC": "North Carolina", "ND": "North Dakota", "OH": "Ohio", "OK": "Oklahoma", "OR": "Oregon",
    "PA": "Pennsylvania", "RI": "Rhode Island", "SC": "South Carolina", "SD": "South Dakota",
    "TN": "Tennessee", "TX": "Texas", "UT": "Utah", "VT": "Vermont", "VA": "Virginia",
    "WA": "Washington", "WV": "West Virginia", "WI": "Wisconsin", "WY": "Wyoming",
}

# Dataset version UUIDs on data.cms.gov (pinned so the sample is reproducible).
PARTD_PROVIDER_DRUG_2024 = "9552739e-3d05-4c1b-8eff-ecabf391e2e5"
PARTD_PROVIDER_2024 = "14d8e8a9-7e9b-4370-a044-bf97c46b4b44"
PHYSICIAN_PROVIDER_2024 = "8889d81e-2ee7-448f-8713-f071038289b5"
MONTHLY_ENROLLMENT = "d7fabe1e-d19b-4333-9eff-e80e0643f2fd"
PARTD_GEO_DRUG = {
    2019: "73a6335e-f16f-4c81-a84b-6b5a986e2bf8",
    2020: "83891e77-99cf-4865-b60a-97703b916e09",
    2021: "7dda2a9d-034a-446a-b4b3-e1254e0127b2",
    2022: "1fc57194-a51d-4864-aee6-de0889488151",
    2023: "3463648b-1971-478d-84ca-80cadc758153",
    2024: "c8ea3f8e-3a09-4fea-86f2-8902fb4b0920",
}
# Provider Data Catalog dataset ids
HOSPITAL_GENERAL_INFO = "xubh-q36u"
HCAHPS_HOSPITAL = "dgck-syfz"

PARTD_PROVIDER_DRUG_COLS = [
    "Prscrbr_NPI", "Prscrbr_Last_Org_Name", "Prscrbr_First_Name", "Prscrbr_City",
    "Prscrbr_State_Abrvtn", "Prscrbr_State_FIPS", "Prscrbr_Type", "Prscrbr_Type_Src",
    "Brnd_Name", "Gnrc_Name", "Tot_Clms", "Tot_30day_Fills", "Tot_Day_Suply",
    "Tot_Drug_Cst", "Tot_Benes", "GE65_Sprsn_Flag", "GE65_Tot_Clms",
    "GE65_Tot_Drug_Cst", "GE65_Bene_Sprsn_Flag", "GE65_Tot_Benes",
]
PARTD_PROVIDER_COLS = [
    "Prscrbr_NPI", "Prscrbr_Last_Org_Name", "Prscrbr_First_Name", "Prscrbr_Crdntls",
    "Prscrbr_Ent_Cd", "Prscrbr_City", "Prscrbr_State_Abrvtn", "Prscrbr_Zip5",
    "Prscrbr_RUCA", "Prscrbr_RUCA_Desc", "Prscrbr_Type", "Tot_Clms", "Tot_30day_Fills",
    "Tot_Drug_Cst", "Tot_Day_Suply", "Tot_Benes", "Brnd_Tot_Clms", "Brnd_Tot_Drug_Cst",
    "Gnrc_Tot_Clms", "Gnrc_Tot_Drug_Cst", "Opioid_Tot_Clms", "Opioid_Tot_Benes",
    "Opioid_Prscrbr_Rate", "Antbtc_Tot_Clms", "Bene_Avg_Age", "Bene_Dual_Cnt",
    "Bene_Ndual_Cnt", "Bene_Avg_Risk_Scre",
]
PHYSICIAN_PROVIDER_COLS = [
    "Rndrng_NPI", "Rndrng_Prvdr_Last_Org_Name", "Rndrng_Prvdr_First_Name",
    "Rndrng_Prvdr_Crdntls", "Rndrng_Prvdr_Ent_Cd", "Rndrng_Prvdr_City",
    "Rndrng_Prvdr_State_Abrvtn", "Rndrng_Prvdr_Zip5", "Rndrng_Prvdr_RUCA",
    "Rndrng_Prvdr_RUCA_Desc", "Rndrng_Prvdr_Type", "Rndrng_Prvdr_Mdcr_Prtcptg_Ind",
    "Tot_HCPCS_Cds", "Tot_Benes", "Tot_Srvcs", "Tot_Sbmtd_Chrg", "Tot_Mdcr_Alowd_Amt",
    "Tot_Mdcr_Pymt_Amt", "Tot_Mdcr_Stdzd_Amt", "Bene_Avg_Age", "Bene_Feml_Cnt",
    "Bene_Male_Cnt", "Bene_Dual_Cnt", "Bene_Ndual_Cnt", "Bene_CC_PH_Diabetes_V2_Pct",
    "Bene_CC_PH_Hypertension_V2_Pct", "Bene_CC_PH_CKD_V2_Pct",
    "Bene_CC_PH_HF_NonIHD_V2_Pct", "Bene_CC_BH_Depress_V1_Pct", "Bene_Avg_Risk_Scre",
]
PARTD_GEO_COLS = [
    "Prscrbr_Geo_Lvl", "Prscrbr_Geo_Cd", "Prscrbr_Geo_Desc", "Brnd_Name", "Gnrc_Name",
    "Tot_Prscrbrs", "Tot_Clms", "Tot_30day_Fills", "Tot_Drug_Cst", "Tot_Benes",
    "GE65_Sprsn_Flag", "GE65_Tot_Clms", "GE65_Tot_Drug_Cst", "GE65_Bene_Sprsn_Flag",
    "GE65_Tot_Benes", "LIS_Bene_Cst_Shr", "NonLIS_Bene_Cst_Shr", "Opioid_Drug_Flag",
    "Antbtc_Drug_Flag",
]
ENROLLMENT_COLS = [
    "YEAR", "MONTH", "BENE_GEO_LVL", "BENE_STATE_ABRVTN", "BENE_STATE_DESC",
    "TOT_BENES", "ORGNL_MDCR_BENES", "MA_AND_OTH_BENES", "AGED_TOT_BENES",
    "DSBLD_TOT_BENES", "DUAL_TOT_BENES", "PRSCRPTN_DRUG_TOT_BENES",
]


def http_get(url: str, retries: int = 5) -> bytes:
    for attempt in range(1, retries + 1):
        try:
            # Note: the Provider Data Catalog rejects some custom User-Agent
            # strings with HTTP 403, so we keep urllib's default.
            with urllib.request.urlopen(url, timeout=180) as resp:
                return resp.read()
        except Exception as exc:  # network hiccups are common on big pulls
            if attempt == retries:
                raise
            wait = 2 ** attempt
            print(f"  retry {attempt} after error: {exc} (sleep {wait}s)", file=sys.stderr)
            time.sleep(wait)
    raise RuntimeError("unreachable")


def data_api_rows(uuid: str, filters: dict[str, str], columns: list[str]):
    """Yield rows (dicts) from the data.cms.gov Data API, one page at a time."""
    offset = 0
    while True:
        params = {f"filter[{k}]": v for k, v in filters.items()}
        params.update({"size": PAGE, "offset": offset, "column": ",".join(columns)})
        url = DATA_API.format(uuid=uuid) + "?" + urllib.parse.urlencode(params)
        page = json.loads(http_get(url))
        if not page:
            return
        yield from page
        offset += len(page)
        print(f"  ... {offset:,} rows", file=sys.stderr)
        if len(page) < PAGE:
            return


def write_csv_gz(path: Path, header: list[str], rows) -> int:
    n = 0
    with gzip.open(path, "wt", newline="", encoding="utf-8", compresslevel=9) as fh:
        w = csv.writer(fh)
        w.writerow(header)
        for row in rows:
            w.writerow(row)
            n += 1
    print(f"wrote {path.relative_to(ROOT)} ({n:,} rows)")
    return n


def diabetes_drug_names() -> set[str]:
    with open(REF / "diabetes_drug_classes.csv", newline="", encoding="utf-8") as fh:
        return {r["gnrc_name"].strip().lower() for r in csv.DictReader(fh)}


def get_partd_prescriber_drug(st: str) -> None:
    """1. Part D prescribers by provider and drug (2024) - one state, diabetes drugs only.

    The full state file is ~700k rows, so we keep the diabetes-drug subset to
    keep the sample small. The filter is a plain name match against the
    hand-built reference list in data/reference/diabetes_drug_classes.csv.
    """
    wanted = diabetes_drug_names()
    rows = (
        [r.get(c, "") for c in PARTD_PROVIDER_DRUG_COLS]
        for r in data_api_rows(PARTD_PROVIDER_DRUG_2024, {"Prscrbr_State_Abrvtn": st}, PARTD_PROVIDER_DRUG_COLS)
        if (r.get("Gnrc_Name") or "").strip().lower() in wanted
    )
    write_csv_gz(OUT / "partd_prescriber_drug_2024.csv.gz", PARTD_PROVIDER_DRUG_COLS, rows)


def get_partd_prescriber(st: str) -> None:
    """2. Part D prescribers by provider (2024) - one row per prescriber in the state."""
    rows = ([r.get(c, "") for c in PARTD_PROVIDER_COLS]
            for r in data_api_rows(PARTD_PROVIDER_2024, {"Prscrbr_State_Abrvtn": st}, PARTD_PROVIDER_COLS))
    write_csv_gz(OUT / "partd_prescriber_2024.csv.gz", PARTD_PROVIDER_COLS, rows)


def get_physician_provider(st: str) -> None:
    """3. Physician & Other Practitioners by provider (2024) - one row per clinician."""
    rows = ([r.get(c, "") for c in PHYSICIAN_PROVIDER_COLS]
            for r in data_api_rows(PHYSICIAN_PROVIDER_2024, {"Rndrng_Prvdr_State_Abrvtn": st}, PHYSICIAN_PROVIDER_COLS))
    write_csv_gz(OUT / "physician_provider_2024.csv.gz", PHYSICIAN_PROVIDER_COLS, rows)


def get_partd_geo_drug(st: str) -> None:
    """4. Part D by geography and drug, 2019-2024 - the state plus the national total."""
    def rows():
        for year, uuid in PARTD_GEO_DRUG.items():
            for flt in ({"Prscrbr_Geo_Desc": STATE_NAMES[st]}, {"Prscrbr_Geo_Lvl": "National"}):
                for r in data_api_rows(uuid, flt, PARTD_GEO_COLS):
                    yield [str(year)] + [r.get(c, "") for c in PARTD_GEO_COLS]
    write_csv_gz(OUT / "partd_geo_drug_2019_2024.csv.gz", ["Data_Year"] + PARTD_GEO_COLS, rows())


def get_monthly_enrollment(st: str) -> None:
    """5. Medicare Monthly Enrollment - every state and the national total, all months."""
    def rows():
        for lvl in ("State", "National"):
            for r in data_api_rows(MONTHLY_ENROLLMENT, {"BENE_GEO_LVL": lvl}, ENROLLMENT_COLS):
                yield [r.get(c, "") for c in ENROLLMENT_COLS]
    write_csv_gz(OUT / "monthly_enrollment.csv.gz", ENROLLMENT_COLS, rows())


def get_hospital_general_info(st: str) -> None:
    """6. Hospital General Information - all U.S. hospitals (about 5,400 rows)."""
    raw = http_get(PDC_API.format(id=HOSPITAL_GENERAL_INFO) + "?format=csv")
    reader = csv.reader(io.StringIO(raw.decode("utf-8-sig")))
    header = next(reader)
    write_csv_gz(OUT / "hospital_general_info.csv.gz", header, reader)


def get_hcahps(st: str) -> None:
    """7. HCAHPS patient survey, hospital level - one state (the full file is ~170 MB)."""
    q = urllib.parse.urlencode({
        "conditions[0][property]": "state", "conditions[0][value]": st,
        "conditions[0][operator]": "=", "format": "csv",
    })
    raw = http_get(PDC_API.format(id=HCAHPS_HOSPITAL) + "?" + q)
    reader = csv.reader(io.StringIO(raw.decode("utf-8-sig")))
    header = next(reader)
    write_csv_gz(OUT / "hcahps_hospital.csv.gz", header, reader)


DATASETS = {
    1: get_partd_prescriber_drug,
    2: get_partd_prescriber,
    3: get_physician_provider,
    4: get_partd_geo_drug,
    5: get_monthly_enrollment,
    6: get_hospital_general_info,
    7: get_hcahps,
}


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--state", default="TN", help="two-letter state code for the provider-level sample")
    ap.add_argument("--only", nargs="*", type=int, metavar="N",
                    help="download only these dataset numbers (1-7); default: all")
    args = ap.parse_args()
    st = args.state.upper()
    if st not in STATE_NAMES:
        sys.exit(f"unknown state code: {st}")
    OUT.mkdir(parents=True, exist_ok=True)
    for n in sorted(set(args.only or DATASETS)):
        fn = DATASETS[n]
        print(f"[{n}] {fn.__doc__.splitlines()[0][3:]}")
        fn(st)


if __name__ == "__main__":
    main()
