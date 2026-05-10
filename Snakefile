# Snakefile
from pathlib import Path
import sys

configfile: "config_aral.yaml"




# ── Paths ─────────────────────────────────────────────
PROJECT_ROOT = Path(config["paths"]["project_root"])
FORCING_DIR  = PROJECT_ROOT / "data" / "forcing"
SHAPEFILES   = PROJECT_ROOT / config["paths"]["shapefiles_dir"].lstrip("./")

# ── Dimensions ────────────────────────────────────────
BASIN     = config["forcing"]["basin"]
MODELS    = config["forcing"]["models"]
ENSEMBLE  = config["forcing"]["ensemble"]
SCENARIOS = config["forcing"]["scenarios"]


# ── Preflight ─────────────────────────────────────────

def preflight_checks():
    errors = []
    for name, path in [
        ("project root", PROJECT_ROOT),
        ("shapefiles",   SHAPEFILES),
    ]:

        if not Path(path).exists():
            errors.append(f"{name} not found: {path}")
        else:
            print(f"correct: {name}: {path}")
    if errors:
        print("\nPreflight failed:")
        for e in errors: print(e)
        sys.exit(1)

preflight_checks()


# ── Targets ───────────────────────────────────────────


rule all:
    input:
        # ERA5
        str(FORCING_DIR / "ERA5" / "raw" / "{start}-{end}".format(
            start = config["simulation_period"]["era5_start_date"][:4],
            end   = config["simulation_period"]["era5_end_date"][:4]
        ) / BASIN / "generated.flag"),
        # CMIP historical
        expand(
            str(FORCING_DIR / "CMIP6" / "historical" / "raw" / "{model}" / BASIN / "generated.flag"),
            model = MODELS
        ),
        #cmip future
        expand(
            str(FORCING_DIR / "CMIP6" / "future" / "raw" / "{model}" / "{scenario}" / BASIN / "generated.flag"),
            model    = MODELS,
            scenario = SCENARIOS
        ),


# ── Rules ─────────────────────────────────────────────


rule generate_era5_forcing:
    input:
        shapefile = str(SHAPEFILES / BASIN / f"{BASIN}.shp")
    output:
        flag = str(FORCING_DIR / "ERA5" / "raw" / "{start}-{end}".format(
            start = config["simulation_period"]["era5_start_date"][:4],
            end   = config["simulation_period"]["era5_end_date"][:4]
        ) / BASIN / "generated.flag")
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
                forcing_root = FORCING_DIR,
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
        flag = str(FORCING_DIR / "CMIP6" / "historical" / "raw" / "{model}" / BASIN / "generated.flag")
    log:
        str(PROJECT_ROOT / "logs" / "forcing" / "cmip_historical_{model}.log")
    run:
        import traceback
        from src.forcing import generate_PCRGLOBWB_CMIP_historical_forcing
        try:
            generate_PCRGLOBWB_CMIP_historical_forcing(
                shape_name = BASIN,
                start      = config["simulation_period"]["historical_cmip_start_date"],
                end        = config["simulation_period"]["historical_cmip_end_date"],
                model      = wildcards.model,
                ensemble   = config["forcing"]["ensemble"],
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
        flag = str(FORCING_DIR / "CMIP6" / "future" / "raw" / "{model}" / "{scenario}" / BASIN / "generated.flag")
    log:
        str(PROJECT_ROOT / "logs" / "forcing" / "cmip_future_{model}_{scenario}.log")
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
                ensemble     = config["forcing"]["ensemble"],
                forcing_root = FORCING_DIR / "CMIP6" / "future" / "raw",
            )
        except Exception as e:
            with open(log[0], "w") as f:
                f.write(traceback.format_exc())
            raise
        Path(output.flag).touch()

