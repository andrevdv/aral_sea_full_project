# Snakefile
from pathlib import Path
import csv
import sys

configfile: "config_aral.yaml"


# run using: 

# ── Paths ─────────────────────────────────────────────
PROJECT_ROOT = Path(config["paths"]["project_root"])
FORCING_DIR  = PROJECT_ROOT / "data" / "forcing"
SHAPEFILES   = PROJECT_ROOT / config["paths"]["shapefiles_dir"].lstrip("./")
EWATERCYCLE_TAIL = Path(config["forcing"]["ewatercycle_tail"])

# ── Dimensions ────────────────────────────────────────
BASIN     = config["forcing"]["basin"]
MODELS    = config["forcing"]["models"]
ENSEMBLE  = config["forcing"]["ensemble"]
SCENARIOS = config["forcing"]["scenarios"]

# ── Time periods ──────────────────────────────────────
HIST_START = config["simulation_period"]["historical_cmip_start_date"][:4]
HIST_END   = config["simulation_period"]["historical_cmip_end_date"][:4]
FUT_START  = config["simulation_period"]["future_start_date"][:4]
FUT_END    = config["simulation_period"]["future_end_date"][:4]
ERA5_START = config["simulation_period"]["era5_start_date"][:4]
ERA5_END   = config["simulation_period"]["era5_end_date"][:4]


# ── Preflight ─────────────────────────────────────────

def preflight_checks():
    errors = []
    for name, path in [
        ("project root", PROJECT_ROOT),
        ("shapefiles",   SHAPEFILES),
    ]:

        if not Path(path).exists():
            errors.append(f"{name} not found: {path}")
    if errors:
        print("\nPreflight failed:")
        for e in errors: print(e)
        sys.exit(1)

preflight_checks()


def iter_expanded_pcrglob_runs():
    planner_path = PROJECT_ROOT / "config" / "experiment_planner.csv"
    with open(planner_path, newline="", encoding="utf-8-sig") as planner_file:
        planner_rows = csv.DictReader(planner_file, delimiter=";")
        for planner_row in planner_rows:
            time_group = planner_row["time_group"]
            if time_group not in config["active_time_blocks"]:
                raise ValueError(f"Unknown time_group in experiment planner: {time_group}")

            for index, time_block in enumerate(config["active_time_blocks"][time_group]):
                if time_block not in config["time_blocks"]:
                    raise ValueError(f"Unknown time_block in config: {time_block}")

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


def expand_pcrglob_job_ids():
    return [row["job_id"] for row in iter_expanded_pcrglob_runs()]


PCRGLOB_JOB_IDS = expand_pcrglob_job_ids()


# ── Targets ───────────────────────────────────────────


rule all:
    input:
        # -------------------------
        # ERA5 forcing
        # -------------------------
        str(FORCING_DIR / "ERA5" / "raw" / f"{ERA5_START}-{ERA5_END}" / BASIN / "generated.flag"),

        # -------------------------
        # CMIP6 historical
        # -------------------------
        # expand(
        #     str(FORCING_DIR / "CMIP6" / "historical" / "raw" / "{model}" / "{ensemble}" / f"{HIST_START}-{HIST_END}" / BASIN / "generated.flag"),
        #     model=MODELS,
        #     ensemble=ENSEMBLE
        # ),

        # expand(
        #     str(FORCING_DIR / "CMIP6" / "historical" / "regridded" / "{model}" / "{ensemble}" / f"{HIST_START}-{HIST_END}" / BASIN / "generated.flag"),
        #     model=MODELS,
        #     ensemble=ENSEMBLE
        # ),

        expand(
            str(FORCING_DIR / "CMIP6" / "historical" / "bias_corrected" / "{model}" / "{ensemble}" / f"{HIST_START}-{HIST_END}" / BASIN / "generated.flag"),
            model=MODELS,
            ensemble=ENSEMBLE
        ),

        # -------------------------
        # CMIP6 future
        # -------------------------
        # expand(
        #     str(FORCING_DIR / "CMIP6" / "future" / "raw" / "{model}" / "{scenario}" / "{ensemble}" / f"{FUT_START}-{FUT_END}" / BASIN / "generated.flag"),
        #     model=MODELS,
        #     scenario=SCENARIOS,
        #     ensemble=ENSEMBLE
        # ),

        # expand(
        #     str(FORCING_DIR / "CMIP6" / "future" / "regridded" / "{model}" / "{scenario}" / "{ensemble}" / f"{FUT_START}-{FUT_END}" / BASIN / "generated.flag"),
        #     model=MODELS,
        #     scenario=SCENARIOS,
        #     ensemble=ENSEMBLE
        # ),

        expand(
            str(FORCING_DIR / "CMIP6" / "future" / "bias_corrected" / "{model}" / "{scenario}" / "{ensemble}" / f"{FUT_START}-{FUT_END}" / BASIN / "generated.flag"),
            model=MODELS,
            scenario=SCENARIOS,
            ensemble=ENSEMBLE
        ),

        # -------------------------
        # Experiment planning output
        # -------------------------
        str(PROJECT_ROOT / "results" / "runs" / "pcrglobwb" / "expanded_runs.csv"),

        # -------------------------
        # PCR-GLOBWB experiments (model outputs stored under results/runs/pcrglobwb)
        # -------------------------
        expand(
            str(PROJECT_ROOT / "results" / "runs" / "pcrglobwb" / "{job_id}" / "generated.flag"),
            job_id=PCRGLOB_JOB_IDS,
        )

# ── Rules ─────────────────────────────────────────────


rule generate_era5_forcing:
    input:
        shapefile = str(SHAPEFILES / BASIN / f"{BASIN}.shp")
    output:
        flag = str(FORCING_DIR / "ERA5" / "raw" / f"{ERA5_START}-{ERA5_END}" / BASIN / "generated.flag")
    log:
        str(PROJECT_ROOT / "logs" / "forcing" / "era5.log")
    run:
        import traceback
        from src.forcing import generate_PCRGLOBWB_ERA5_forcing
        try:
            generate_PCRGLOBWB_ERA5_forcing(
                start        = config["simulation_period"]["era5_start_date"],
                end          = config["simulation_period"]["era5_end_date"],
                shape_name   = BASIN,
                forcing_root = FORCING_DIR / "ERA5" / "raw",
            )
            Path(output.flag).touch()
        except Exception as e:
            with open(log[0], "w") as f:
                f.write(traceback.format_exc())
            raise

rule generate_cmip_historical_forcing:
    input:
        shapefile = str(SHAPEFILES / BASIN / f"{BASIN}.shp")
    output:
        flag = str(FORCING_DIR / "CMIP6" / "historical" / "raw" / "{model}" / "{ensemble}" / f"{HIST_START}-{HIST_END}" / BASIN / "generated.flag")
    log:
        str(PROJECT_ROOT / "logs" / "forcing" / f"cmip_historical_{{model}}_{{ensemble}}_{HIST_START}-{HIST_END}.log")
    run:
        import traceback
        from src.forcing import generate_PCRGLOBWB_CMIP_historical_forcing
        try:
            generate_PCRGLOBWB_CMIP_historical_forcing(
                shape_name = BASIN,
                start      = config["simulation_period"]["historical_cmip_start_date"],
                end        = config["simulation_period"]["historical_cmip_end_date"],
                model      = wildcards.model,
                ensemble   = wildcards.ensemble,
                forcing_root = FORCING_DIR / "CMIP6" / "historical" / "raw",
            )
        except Exception as e:
            with open(log[0], "w") as f:
                f.write(traceback.format_exc())
            raise
        Path(output.flag).touch()

rule generate_cmip_future_forcing:
    input:
        shapefile = str(SHAPEFILES / BASIN / f"{BASIN}.shp")
    output:
        flag = str(FORCING_DIR / "CMIP6" / "future" / "raw" / "{model}" / "{scenario}" / "{ensemble}" / f"{FUT_START}-{FUT_END}" / BASIN / "generated.flag")
    log:
        str(PROJECT_ROOT / "logs" / "forcing" / f"cmip_future_{{model}}_{{scenario}}_{{ensemble}}_{FUT_START}-{FUT_END}.log")
    run:
        import traceback
        from src.forcing import generate_PCRGLOBWB_CMIP_future_forcing
        try:
            generate_PCRGLOBWB_CMIP_future_forcing(
                shape_name   = BASIN,
                start        = config["simulation_period"]["future_start_date"],
                end          = config["simulation_period"]["future_end_date"],
                ssp          = wildcards.scenario,
                model        = wildcards.model,
                ensemble     = wildcards.ensemble,
                forcing_root = FORCING_DIR / "CMIP6" / "future" / "raw",
            )
        except Exception as e:
            with open(log[0], "w") as f:
                f.write(traceback.format_exc())
            raise
        Path(output.flag).touch()

rule regrid_cmip_historical:
    input:
        cmip_flag = rules.generate_cmip_historical_forcing.output.flag,
        era5_flag = rules.generate_era5_forcing.output.flag,
    output:
        flag = str(FORCING_DIR / "CMIP6" / "historical" / "regridded" / "{model}" / "{ensemble}" / f"{HIST_START}-{HIST_END}" / BASIN / "generated.flag")
    log:
        str(PROJECT_ROOT / "logs" / "regrid" / f"historical_{{model}}_{{ensemble}}_{HIST_START}-{HIST_END}.log")
    script:
        "workflow/regrid_cmip_historical.py"

rule regrid_cmip_future:
    input:
        cmip_flag = rules.generate_cmip_future_forcing.output.flag,
        era5_flag = rules.generate_era5_forcing.output.flag,
    output:
        flag = str(FORCING_DIR / "CMIP6" / "future" / "regridded" / "{model}" / "{scenario}" / "{ensemble}" / f"{FUT_START}-{FUT_END}" / BASIN / "generated.flag")
    log:
        str(PROJECT_ROOT / "logs" / "regrid" / f"future_{{model}}_{{scenario}}_{{ensemble}}_{FUT_START}-{FUT_END}.log")
    script:
        "workflow/regrid_cmip_future.py"

rule bias_correct_historical:
    input:
        historical_flag = rules.regrid_cmip_historical.output.flag,
        era5_flag       = rules.generate_era5_forcing.output.flag,
    output:
        flag = str(FORCING_DIR / "CMIP6" / "historical" / "bias_corrected" / "{model}" / "{ensemble}" / f"{HIST_START}-{HIST_END}" / BASIN / "generated.flag")
    log:
        str(PROJECT_ROOT / "logs" / "bias_correction" / f"historical_{{model}}_{{ensemble}}_{HIST_START}-{HIST_END}.log")
    script:
        "workflow/bias_correct_historical.py"


rule bias_correct_future:
    input:
        future_flag     = rules.regrid_cmip_future.output.flag,
        historical_flag = rules.regrid_cmip_historical.output.flag,
        era5_flag       = rules.generate_era5_forcing.output.flag,
    output:
        flag = str(FORCING_DIR / "CMIP6" / "future" / "bias_corrected" / "{model}" / "{scenario}" / "{ensemble}" / f"{FUT_START}-{FUT_END}" / BASIN / "generated.flag")
    log:
        str(PROJECT_ROOT / "logs" / "bias_correction" / f"future_{{model}}_{{scenario}}_{{ensemble}}_{FUT_START}-{FUT_END}.log")
    script:
        "workflow/bias_correct_future.py"


rule forcing_figures_bias_correction:
    input:
        future_bias_corrected_flag = rules.bias_correct_future.output.flag,
        historical_bias_corrected_flag = rules.bias_correct_historical.output.flag,
        future_regridded_flag = rules.regrid_cmip_future.output.flag,
        historical_regridded_flag = rules.regrid_cmip_historical.output.flag,
        era5_flag = rules.generate_era5_forcing.output.flag,
    output:
        str(PROJECT_ROOT / "figures" / "bias_correction" / "generated.flag")
    log:
        str(PROJECT_ROOT / "logs" / "figures" / f"forcing_figures_bias_correction.log")
    script:
        "workflow/forcing_figures_bias_correction.py"




# ── PCR-GLOBWB2 RUNS ──────────────────────────────────────────


# this takes the list with experiments and expands it to the full list. does snakemake magic i still don't fully understand.
# prevents expanseive rerruning of the full list when we add new experiments
# also makes it easier to keep track of what experiments are done.  and what their parameters are in a single file.
#also makes it easier to add new parameters if we want to later on without having to change the snakemake rules etc
rule expand_runs:
    input:
        planner="config/experiment_planner.csv",
        yaml="config_aral.yaml"
    output:
        expanded_runs=str(PROJECT_ROOT / "results" / "runs" / "pcrglobwb" / "expanded_runs.csv")
    log:
        "logs/planning/expand_runs.log"
    script:
        "workflow/step2_pcrglobwb/expand_runs.py"


rule prepare_pcrglobwb_run:
    input:
        planner = "config/experiment_planner.csv",
        yaml = "config_aral.yaml"
    output:
        run_config = str(PROJECT_ROOT / "results" / "runs" / "pcrglobwb" / "{job_id}" / "run_config.yaml")
    log:
        str(PROJECT_ROOT / "logs" / "model_runs" / "pcrglobwb" / "{job_id}_prepare.log")
    script:
        "workflow/step2_pcrglobwb/prepare_pcrglob_run.py"

rule run_pcrglobwb_experiment:
    input:
        run_config = rules.prepare_pcrglobwb_run.output.run_config,
    output:
        flag =  str(PROJECT_ROOT / "results" / "runs" / "pcrglobwb" / "{job_id}" / "generated.flag")
    log:
        str(PROJECT_ROOT / "logs" / "model_runs" / "pcrglobwb" / "{job_id}.log")
    script:
        "workflow/step2_pcrglobwb/run_pcrglob_experiment.py"





# rule run_pcrglobwb_era5:
#     input:
#         forcing_flag = rules.generate_era5_forcing.output.flag
#     output:
#         flag = str(PROJECT_ROOT / "model_runs" / "ERA5" / f"{HIST_START}-{HIST_END}" / BASIN / "generated.flag")
#     log:
#         str(PROJECT_ROOT / "logs" / "model_runs" / f"pcrglob_era5_{HIST_START}-{HIST_END}.log")
#     params:
#         config = config
#     script:
#         "workflow/step2_pcrglobwb/run_pcrglob_era5.py"







# TODO: rule run_pcrglobwb_ensemble
# already in .py form per experiment  just needs to be converted to Snakemake rules
# used to only store discharge, maybe look at others?
# decide on exact scnaerios etc
# skip calibration, will be seperate process and not part of the main pipeline for now, but maybe add later if time allows

# ── Post-Processing & Station Extraction ────────────────

# TODO: rule extract_grdc_stations
# already in notebook form, just needs to be converted to a Snakemake rule
# Extract simulated discharge at GRDC station locations


# ── Performance Evaluation ──────────────────────────────

# TODO: rule evaluate_model_performance
# Calculate NSE, KGE etc for historical runs
# Compare extracted station data against GRDC observations
# make table of results, maybe for appendix
# partly already done in notebooks, just needs to be converted to Snakemake rules and add latest results
# use aral.rivers etc


# ── Aral Sea Model - simulation ─────────────────────────────

# TODO: automatically run aral sea model
# use aral.rivers etc to run the model for each scenario and store outputs in a structured way
# enemble results for aral sea already possible
# Karakum Ultra janky possible



# ── Aral Sea Model - evaluation ─────────────────────────────

# TODO: make some kind of evaluation
# enemble results for aral sea already possible
# Karakum Ultra janky possible
# various visualizations already exist
# 


# ── Paper Figures and Tables ───────────────────────────

# TODO: make some master figures script or something
# figures can be dependent on pipeline or be run indepnedently, but should be able to be run with a single command
# stuff like NASA imagery should be able to run indepentenly, but should still be generated
# focus on the graphs and the tables .tex files for now, but maybe also some of the maps etc
