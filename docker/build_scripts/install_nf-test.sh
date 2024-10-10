#!/bin/bash -l

set -e
# Build required version(s) of NF-Test
TOOL="nf-test"
VERSION="0.9.0"
RELEASE="v${VERSION}"
DOWNLOAD_URL="https://code.askimed.com/install/nf-test"
DESTINATION="/opt/${TOOL}/${RELEASE}";

# Download the desired release
mkdir -p "/src/${TOOL}"
cd "/src/${TOOL}"
curl -fsSL "${DOWNLOAD_URL}" | bash -s - ${VERSION}

# Move to destination
mkdir -p ${DESTINATION}
cp nf-test ${DESTINATION}
cd ${DESTINATION}
bash nf-test init

# Prepare a script to load the required environment variables
cat > ${DESTINATION}/load << EOF
# This file should be sourced, not executed
export PATH=${PATH}:"${DESTINATION}/";
EOF

# Source the above script to test it
cat >> ~/.bashrc << EOF
source ${DESTINATION}/load
# Set the diff tool to icdiff for better nf-test output.
export NFT_DIFF="icdiff"
export NFT_DIFF_ARGS="-N --cols 200 -L expected -L observed -t"
EOF
source ${DESTINATION}/load

# Test build & install worked
nf-test version | grep "nf-test.[0-9].[0-9].[0-9]"

## Set the correct Nextflow version and run Nextflow
# This is required so that the version of Nextflow used by Paris is not
# downloaded each time the Nextflow unit tests are run.
NXF_VER="23.04.0" nextflow

