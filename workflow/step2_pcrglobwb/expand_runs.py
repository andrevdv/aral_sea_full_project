from pathlib import Path
import yaml
import pandas as pd


# --------------------------------------------------
# Snakemake paths
# --------------------------------------------------
planner_csv = snakemake.input.planner
config_yaml = snakemake.input.yaml
output_csv = snakemake.output.expanded_runs

# --------------------------------------------------
# Load config
# --------------------------------------------------
with open(config_yaml) as f:
    config = yaml.safe_load(f)

time_blocks = config["time_blocks"]
active_groups = config["active_time_blocks"]

# --------------------------------------------------
# Load experiment planner
# --------------------------------------------------
df = pd.read_csv(planner_csv, sep=";")

expanded = []


# --------------------------------------------------
# Expand rows
# --------------------------------------------------
for _, row in df.iterrows():
    run_id = row["run_id"]
    group = row["time_group"]

    if group not in active_groups:
        raise ValueError(f"Unknown time_group: {group}")

    blocks = active_groups[group]

    for i, block in enumerate(blocks):

        if block not in time_blocks:
            raise ValueError(f"Unknown time_block: {block}")

        tb = time_blocks[block]

        job_id = f"{run_id}_{i:03d}"

        expanded.append({
            "job_id": job_id,
            "run_id": row["run_id"],
            "group": group,
            "time_block": block,
            "start_date": tb["start_date"],
            "end_date": tb["end_date"],
            "model": row.get("model", ""),
            "scenario": row.get("scenario", ""),
            "parameter_set": row.get("parameter_set", ""),
        })

# --------------------------------------------------
# Write expanded table
# --------------------------------------------------
out = pd.DataFrame(expanded)

Path(output_csv).parent.mkdir(parents=True, exist_ok=True)
out.to_csv(output_csv, index=False)

print(out.head())
print(f"\nTOTAL RUNS: {len(out)}")