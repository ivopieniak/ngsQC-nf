#!/usr/bin/env bash

# We need to get the pathname first before doing anything else or it will change
PATHNAME="$_"

# Exit on uncaught error, disallow unset variables and raise an error if any
# command in a pipe fails
set -euo pipefail

# Note whether the script is sourced and get the script's name
if [[ "$PATHNAME" != "$0" ]]; then
    SCRIPT_CALL_PATH="${BASH_SOURCE[0]}"
    SCRIPT_SOURCED="yes"
else
    SCRIPT_CALL_PATH="$0"
    SCRIPT_SOURCED="no"
fi

SCRIPT_NAME=$(basename "${SCRIPT_CALL_PATH}")
SCRIPT_DIRECTORY=$(realpath "${SCRIPT_CALL_PATH}" | xargs dirname)
# Declare the executor options. This could define different types of executors.
declare -r executor_options=(local)

repo_dir=$(realpath "${SCRIPT_DIRECTORY}/..")
logs_base_directory="logs"
input_params_file="${repo_dir}/params/ngsqc_params.yaml"
output_file_arg="ngsQC.log"


# Script metadata
VERSION="0.0.1"
AUTHOR="Iwo Pieniak"
USAGE="
Usage:

    ${SCRIPT_NAME} [OPTIONS]

Description:

    A script to launch the ngsQC workflow.

Options:

    -p PARAMS_FILE
        Default: ${input_params_file}
        Path to the parameters file to be used.

    -o OUTPUT_FILE_ARG
        Default: ${output_file_arg}
        Name to use in terminal output filename.
    -v
        Print script name and version.

    -u -h
        Print this usage/help information.

"

# The main function of the script
main() {
    # Parse the command line arguments. If it has a non-zero exit status, the
    # main function should return immediately. If $noerror is not "yes", main()
    # should return the same exit status, otherwise it is a clean exit 0
    noerror=""
    parseargs "$@"
    parseargs_status=$?
    if [[ "${parseargs_status}" -gt 0 ]]; then
        [[ "${noerror}" == "yes" ]] && return 0
        return "${parseargs_status}"
    fi

    # Get a datestamp for consistentcy across all output files
    launch_date=$(date +'%Y-%m-%d_%H-%M-%S_%Z')

    logs_directory="${logs_base_directory}/ngsQC"
    [[ -d "$logs_directory" ]] || mkdir -p "$logs_directory"

    # The params file to be used for the run
    used_params_file="${logs_directory}/${launch_date}_params.yaml"
    cp "$input_params_file" "$used_params_file"

    output_file="${logs_directory}/${launch_date}_${output_file_arg}"
    echo "Starting custom pipeline at $(date)" | tee "${output_file}"
    echo "launch datestamp: ${launch_date}" | tee -a "${output_file}"


    export PATH="${repo_dir}/bin:$PATH"

    custom_nxf_lib="${repo_dir}/lib/nextflow"
    if [[ -z "${NXF_LIB:-}" ]]; then
        export "NXF_LIB=${custom_nxf_lib}"
    else
        export "NXF_LIB=${custom_nxf_lib}:${NXF_LIB}"
    fi

    # Grab the nextflow version and export for downstream processes
    export NXF_VER=$(yq -r '.nextflowVersion' "${used_params_file}")

    # Nextflow config file
    nextflow_config_file="${repo_dir}/conf/nextflow.config"

    # Ensure Nextflow jar files for required version are pre-fetched:
    nextflow -C "${nextflow_config_file}" -v >/dev/null 2>&1 || true

    # Get the version of Nextflow in use
    nf_version=$(
        nextflow -C "${nextflow_config_file}" -v \
            | tee -a "${output_file}" \
            | sed 's/nextflow version //'
    )
    if [[ "${nf_version}" != ${NXF_VER:-UNSET}* ]]; then
        >&2 echo "Nextflow version setting not adhered to"
        exit 1
    fi
    echo "nextflow version: ${nf_version}" | tee -a "${output_file}"

    # Run the workflow.
    # NB: the '-C' command forces Nextflow to use only the specified config
    # file, ignoring any others in default locations.
    nextflow \
            -trace nextflow \
            -C "${nextflow_config_file}" \
            -log "${logs_directory}/${launch_date}_nextflow.log" \
            run "${repo_dir}/lib/nextflow/ngsqc/ngsqcWf.nf" \
            -params-file "${used_params_file}" \
            --launch-date "${launch_date}" \
            --logs-dir "${logs_directory}" \
            2>&1 \
        | tee -a "${output_file}"

    # Tap-functions code modify bash's response to exit codes. This ensures
    # that we capture the exit code bash and not the tap-function exit code.
    exit_status=$?

    echo "Finished pipeline at $(date)" | tee -a "${output_file}"

    return "${exit_status}"
}

# Check if the provided string is in the provided array
#
# Usage:
#     array_contains "query value" "${array_of_interest[@]}"
#
# Returns an exit code of 0 for true and 1 for false.
function array_contains() {
    local query="${1:-}"
    shift
    local value
    for value; do
        [[ "${value}" == "${query}" ]] && return 0
    done
    return 1
}

# Print usage information
usage() {
    local error="${1:-}"
    version

    if [[ ! -z "${error}" ]]; then
        >&2 echo ""
        >&2 echo "    Error: ${error}"
    fi

    >&2 echo "${USAGE}"
}

# Print the script version
version() {
    >&2 echo "${SCRIPT_NAME} version ${VERSION}"
    >&2 echo "${AUTHOR}"
}

# Parse the command line arguments
parseargs() {

    local OPTIND opt
    while getopts ":vhup:o:" opt; do
        case "${opt}" in
            p)
                input_params_file="${OPTARG}"
                ;;
            o)
                output_file_arg="${OPTARG}"
                ;;
            v)
                version
                noerror="yes"
                return 1
                ;;
            u)
                usage
                noerror="yes"
                return 1
                ;;
            h)
                usage
                noerror="yes"
                return 1
                ;;
            \?)
                usage "Invalid option: -$OPTARG"
                return 1
                ;;
        esac
    done
    shift $((OPTIND-1))

    if [[ ! -f "${input_params_file}" ]]; then
        usage "Specified params file, ${input_params_file}, is not a file"
        return 1
    fi

    if ! array_contains "${process_executor:-}" "${executor_options[@]}"; then
        usage "${process_executor:-} is not a recognised executor choice."
        return 1
    fi

    other_arguments="$@"
}

# Execute the script, capturing the return value in a way that will work even if
# the script is sourced
exitstatus=0
main "$@" || exitstatus=$?

if [[ "${SCRIPT_SOURCED}" == "no" ]]; then
    exit "${exitstatus}"
else
    set +e
    return "${exitstatus}"
fi

