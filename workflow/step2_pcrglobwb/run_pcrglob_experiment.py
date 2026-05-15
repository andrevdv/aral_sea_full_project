from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
import ewatercycle.parameter_sets
import yaml  # pyright: ignore[reportMissingTypeStubs]
from snakemake.script import Snakemake  # pyright: ignore[reportMissingTypeStubs]

from src.models import simulate_PCRGLOBWB_experiment


def resolve_ini_name(config: dict, parameter_set: str) -> str:
    try:
        parameter_path = Path(config["parameter_sets"][parameter_set]["path"])
    except KeyError as exc:
        raise KeyError(f"Unknown parameter_set={parameter_set!r} in run_config.yaml") from exc
    return parameter_path.name



def main(snakemake: Snakemake) -> None:
    with open(snakemake.input.run_config, encoding="utf-8") as config_file:
        run_config = yaml.safe_load(config_file)

    job = run_config["job"]
    job_id = str(job["job_id"])
    experiment_start_date = str(job["start_date"])
    experiment_end_date = str(job["end_date"])
    parameter_set = str(job["parameter_set"])
    ini_name = resolve_ini_name(run_config, parameter_set)

    forcing_flag = Path(run_config["forcing"]["input_flag"])
    forcing_tail = Path(run_config["forcing"]["ewatercycle_tail"])
    forcing_dir = forcing_flag.parent / forcing_tail

    run_output_dir = Path(snakemake.output.flag).parent
    run_output_dir.mkdir(parents=True, exist_ok=True)

    # Get the INI files directory (relative to the snakemake project root)
    ini_files_dir = Path(snakemake.config["paths"]["project_root"]) / "data" / "ini_file"

    log_file = run_output_dir / "tqdm.log"
    with open(log_file, "a", encoding="utf-8") as log_stream:
        log_stream.write(
            f"Starting {job_id} ({job['run_id']} / {job['time_block']})\n"
        )
        log_stream.write(f"Dates: {experiment_start_date} -> {experiment_end_date}\n")
        log_stream.write(f"Forcing flag: {forcing_flag}\n")
        log_stream.write(f"Forcing dir: {forcing_dir}\n")
        log_stream.write(f"Parameter set: {parameter_set} -> {ini_name}\n")

        with redirect_stdout(log_stream), redirect_stderr(log_stream):
            simulate_PCRGLOBWB_experiment(
                forcing_dir,
                ini_name,
                experiment_start_date,
                experiment_end_date,
                run_output_dir,
                ini_files_dir=ini_files_dir,
            )

        Path(snakemake.output.flag).touch()
        log_stream.write(f"Finished {job_id}\n")


main(globals()["snakemake"])
