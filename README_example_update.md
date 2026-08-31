# Aral Sea Workflow — Example README Update

A concise example update for the repository README: quickstart commands, configuration notes, run examples, notebooks, outputs layout, data & citation, reproducibility, logs and contact.

## TL;DR

```bash
# 1. Create environment
conda env create -f environment.yaml
conda activate <env-name>

# 2. Edit configuration
# Edit `config_aral.yaml` to set `paths.project_root`, `paths.forcing_dir`, `forcing.models`, and `paths.shapefiles_dir`.

# 3. Run the workflow (example)
snakemake -j 4 --use-singularity

# 4. Inspect outputs in `outputs/` and `results/` or open notebooks/
```

## Quickstart

- Clone the repo: `git clone <placeholder>`
- Change into the project folder and create the environment:

```bash
cd aral_sea_full_project
conda env create -f environment.yaml
conda activate <env-name>
```

## Configuration

All configuration lives in `config_aral.yaml` at the project root. Before running, update the following keys as required:

- `paths.project_root` — absolute project base path
- `paths.forcing_dir` — where ERA5/CMIP forcing files will be written
- `forcing.models` — list of CMIP models to process
- `paths.shapefiles_dir` or `aral_sea_experiment.shapefile_path` — study-area geometry

See `config_aral.yaml` for other runtime and simulation settings.

## Run examples

- Preview workflow (dry-run):

```bash
snakemake -n
```

- Run the full workflow with 4 cores:

```bash
snakemake -j 4
```

- Run with Singularity (bind current working dir):

```bash
snakemake -j 4 --use-singularity --singularity-args "-B $PWD:/work"
```

## Notebooks

- Notebook that generates forcings: `notebooks/03a_aral_sea_model_forcing_generation.ipynb`
- Other notebooks and analysis are in the `notebooks/` folder.

## Outputs layout (high-level)

- `data/forcing/` — ERA5 and CMIP6 forcing data (created by the notebook / workflow)
- `outputs/` — intermediate outputs from rules
- `results/` — aggregated model results, figures and tables
- `logs/` — per-rule logs and error traces

## Data sources & citation

- ERA5 (Copernicus Climate Data Store)
- CMIP6 model outputs (ESGF)
- PCR-GLOBWB2 hydrological model
- Observational discharge: GRDC

Please cite the project using the metadata in `CITATION.cff`.

## Reproducibility

- Environment file: `environment.yaml` (use to recreate the Conda env)
- Singularity images (if available): `ewatercycle_pcr_*.sif` for containerised runs

## Logs & troubleshooting

- Check `logs/` for per-rule errors and stack traces.
- Common fixes: verify paths in `config_aral.yaml`, ensure Singularity or Conda env is available, check internet/ESGF credentials for CMIP downloads.

## Contact

- Author: A.B. van der Veen — see `CITATION.cff` for ORCID and citation metadata.
- Report issues via GitHub Issues on the project repository.

---

This file is an example update. If you want, I can merge these sections into `README.md` or tailor wording/commands to your environment (e.g., set a specific conda env name or add the repository clone URL).
