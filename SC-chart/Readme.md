Vulnerability Reporting Tool
Purpose
This tool extracts container images from a Helm chart, scans them for vulnerabilities using Grype, and generates a CSV report containing vulnerabilities of Medium or higher severity.

Prerequisites
Helm - Install via Helm Docs.
Grype - Install via Grype Releases.
jq - Install via your package manager (apt-get install jq).


pls note for the sake if jq  i specifically used ubuntu OS 
Usage

Run the script with:

bash
./list_container_images.sh ./SC-chart
This generates a CSV file with vulnerability data for each container image, filtered by severity (Medium, High, Critical).

Design Decisions and Assumptions
Grype was selected for vulnerability scanning due to its efficiency with container images.
jq is used for JSON parsing because it's lightweight and fast.
The script only includes vulnerabilities of Medium or higher severity.
The output CSV is named with the current date to avoid overwriting.


Future Improvements
Add parallel scanning for faster processing.
Support other vulnerability scanners (e.g., Trivy).
Implement more advanced filtering and error logging.

The directory structure of the repo

├── SC-chart
│   ├── Chart.yaml
│   ├── Readme.md
│   ├── templates
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   └── values.yaml
└── list_container_images.sh