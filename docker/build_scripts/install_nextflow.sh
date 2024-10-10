#!/bin/bash -l
set -xe
echo -e "\n\n####\n#\n# Starting nextflow.sh\n#\n####\n\n"

# Build required version(s) of Nextflow.io
curl -s https://get.sdkman.io | bash
source "/root/.sdkman/bin/sdkman-init.sh"
sdk install java 17.0.10-tem
java -version

# Download the release package
INSTALL_RELEASE="23.04.0";

# Get the base release
cd /usr/local/bin;
wget -qO- "https://github.com/nextflow-io/nextflow/releases/download/v${INSTALL_RELEASE}/nextflow" | bash;
chmod +rx nextflow

echo -e "\n\n####\n#\n# Finished running nextflow.sh\n#\n####\n\n"
