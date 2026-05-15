# from __future__ import annotations

from pathlib import Path
import csv

import yaml  # pyright: ignore[reportMissingTypeStubs]


planner_csv = snakemake.input.planner
config_yaml = snakemake.input.yaml
output_yaml = snakemake.output.run_config


def write_text_if_changed(path: Path, content: str) -> None:
    if path.exists() and path.read_text(encoding="utf-8") == content:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def iter_expanded_rows(config: dict):
    with open(planner_csv, newline="", encoding="utf-8-sig") as planner_file:
        planner_rows = csv.DictReader(planner_file, delimiter=";")
        for planner_row in planner_rows:
            time_group = planner_row["time_group"]
            if time_group not in config["active_time_blocks"]:
                raise ValueError(f"Unknown time_group: {time_group}")

            for index, time_block in enumerate(config["active_time_blocks"][time_group]):
                if time_block not in config["time_blocks"]:
                    raise ValueError(f"Unknown time_block: {time_block}")

                yield {
                    "job_id": f'{planner_row["run_id"]}_{index:03d}',
                    "run_id": planner_row["run_id"],
                    "group": time_group,
                    "time_block": time_block,
                    "start_date": config["time_blocks"][time_block]["start_date"],
                    "end_date": config["time_blocks"][time_block]["end_date"],
                    "model": planner_row["model"],
                    "scenario": planner_row["scenario"],
                    "forcing": planner_row["forcing"],
                    "type": planner_row["type"],
                    "parameter_set": planner_row["parameter_set"],
                }


def resolve_forcing_flag(row: dict, config: dict) -> str:
    ensemble = config["forcing"]["ensemble"][0]
    project_root = Path(config["paths"]["project_root"])
    forcing_dir = project_root / "data" / "forcing"
    basin = config["forcing"]["basin"]
    hist_start = config["simulation_period"]["historical_cmip_start_date"][:4]
    hist_end = config["simulation_period"]["historical_cmip_end_date"][:4]
    fut_start = config["simulation_period"]["future_start_date"][:4]
    fut_end = config["simulation_period"]["future_end_date"][:4]
    era5_start = config["simulation_period"]["era5_start_date"][:4]
    era5_end = config["simulation_period"]["era5_end_date"][:4]

    if row["forcing"] == "era5":
        return str(forcing_dir / "ERA5" / "raw" / f"{era5_start}-{era5_end}" / basin / "generated.flag")

    if row["forcing"] == "cmip" and row["scenario"] == "historical" and row["type"] == "raw":
        return str(
            forcing_dir
            / "CMIP6"
            / "historical"
            / "raw"
            / row["model"]
            / ensemble
            / f"{hist_start}-{hist_end}"
            / basin
            / "generated.flag"
        )

    if row["forcing"] == "cmip" and row["scenario"] == "historical" and row["type"] == "bias_corrected":
        return str(
            forcing_dir
            / "CMIP6"
            / "historical"
            / "bias_corrected"
            / row["model"]
            / ensemble
            / f"{hist_start}-{hist_end}"
            / basin
            / "generated.flag"
        )

    if row["forcing"] == "cmip" and row["type"] == "bias_corrected":
        return str(
            forcing_dir
            / "CMIP6"
            / "future"
            / "bias_corrected"
            / row["model"]
            / row["scenario"]
            / ensemble
            / f"{fut_start}-{fut_end}"
            / basin
            / "generated.flag"
        )

    raise ValueError(f"Unsupported PCR-GLOBWB experiment row for job_id={row['job_id']!r}: {row}")


with open(config_yaml, encoding="utf-8") as config_file:
    config = yaml.safe_load(config_file)

selected_row = None
for row in iter_expanded_rows(config):
    if row["job_id"] == snakemake.wildcards.job_id:
        selected_row = row
        break

if selected_row is None:
    raise ValueError(f"No expanded run row found for job_id={snakemake.wildcards.job_id!r}")

parameter_set = selected_row["parameter_set"]
if parameter_set not in config["parameter_sets"]:
    raise KeyError(f"Unknown parameter_set={parameter_set!r} in config_aral.yaml")

run_config = {
    "job": selected_row,
    "forcing": {
        "ewatercycle_tail": config["forcing"]["ewatercycle_tail"],
        "input_flag": resolve_forcing_flag(selected_row, config),
    },
    "parameter_sets": {
        parameter_set: config["parameter_sets"][parameter_set],
    },
}

write_text_if_changed(Path(output_yaml), yaml.safe_dump(run_config, sort_keys=True))
