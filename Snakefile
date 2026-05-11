# Snakefile
from pathlib import Path
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


# ── Targets ───────────────────────────────────────────


rule all:
    input:
        # ERA5
        str(FORCING_DIR / "ERA5" / "raw" / f"{ERA5_START}-{ERA5_END}" / BASIN / "generated.flag"),

        # ---- CMIP6 ----
        # CMIP historical raw
        expand(
            str(FORCING_DIR / "CMIP6" / "historical" / "raw" / "{model}" / "{ensemble}" / f"{HIST_START}-{HIST_END}" / BASIN / "generated.flag"),
            model = MODELS, ensemble = ENSEMBLE
        ),

        # CMIP historical regridded
        expand(
            str(FORCING_DIR / "CMIP6" / "historical" / "regridded" / "{model}" / "{ensemble}" / f"{HIST_START}-{HIST_END}" / BASIN / "generated.flag"),
            model = MODELS, ensemble = ENSEMBLE
        ),
        # CMIP historical bias corrected
        expand(
            str(FORCING_DIR / "CMIP6" / "historical" / "bias_corrected" / "{model}" / "{ensemble}" / f"{HIST_START}-{HIST_END}" / BASIN / "generated.flag"),
            model = MODELS, ensemble = ENSEMBLE
        ),


        #cmip future 
        expand(
            str(FORCING_DIR / "CMIP6" / "future" / "raw" / "{model}" / "{scenario}" / "{ensemble}" / f"{FUT_START}-{FUT_END}" / BASIN / "generated.flag"),
            model = MODELS, scenario = SCENARIOS, ensemble = ENSEMBLE
        ),

        #cmip future regridded
        expand(
            str(FORCING_DIR / "CMIP6" / "future" / "regridded" / "{model}" / "{scenario}" / "{ensemble}" / f"{FUT_START}-{FUT_END}" / BASIN / "generated.flag"),
            model = MODELS, scenario = SCENARIOS, ensemble = ENSEMBLE
        ),
        #cmip future bias corrected
        expand(
            str(FORCING_DIR / "CMIP6" / "future" / "bias_corrected" / "{model}" / "{scenario}" / "{ensemble}" / f"{FUT_START}-{FUT_END}" / BASIN / "generated.flag"),
            model = MODELS, scenario = SCENARIOS, ensemble = ENSEMBLE
        ),


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


# ── Basin-Wide Aggregation ─────────────────────────────

# TODO: automatically run aral sea model
# use aral.rivers etc to run the model for each scenario and store outputs in a structured way
# enemble results for aral sea already possible
# Karakum Ultra janky possible
# 

# ── Paper Figures and Tables ───────────────────────────

# TODO: make some master figures script or something
# figures can be dependent on pipeline or be run indepnedently, but should be able to be run with a single command
# stuff like NASA imagery should be able to run indepentenly, but should still be generated
# focus on the graphs and the tables .tex files for now, but maybe also some of the maps etc
