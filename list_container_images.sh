#!/bin/bash

# Check if Helm and Grype and jq are installed
for CMD in helm grype jq ; do
    if ! command -v $CMD &> /dev/null; then
        echo "Error: $CMD is not installed. Please install $CMD to use this script."
        exit 1
    fi
done

# Validate input arguments
if [ $# -ne 1 ]; then
    echo "Usage: $0 <chart_path>"
    echo "Example: $0 ./my-chart"
    exit 1
fi

CHART_PATH=$1

# Check if the chart directory exists
if [ ! -d "$CHART_PATH" ]; then
    echo "Error: Chart directory '$CHART_PATH' not found."
    exit 1
fi

# Render the Helm chart to extract images
echo "Rendering Helm chart from path '$CHART_PATH'..."
RENDERED=$(helm template "$CHART_PATH")

if [ $? -ne 0 ]; then
    echo "Error: Failed to render Helm chart."
    exit 1
fi

# Extract container images
echo "Extracting container images from the Helm chart..."
IMAGES=$(echo "$RENDERED" | grep -Po '(?<=image: ).*' | sort -u)

if [ -z "$IMAGES" ]; then
    echo "Error: No container images found in the Helm chart."
    exit 1
fi

# Run vulnerability scans using Grype
echo "Starting vulnerability scan on extracted images..."
OUTPUT_DIR="./grype_scans"
mkdir -p "$OUTPUT_DIR"

for IMAGE in $IMAGES; do
    echo "Scanning image: $IMAGE"

    #generate a filename for storing the result of the vulnerability scan and run the grype scanner on the image
    SCAN_FILE="$OUTPUT_DIR/$(echo "$IMAGE" | tr '/: ' '_').txt"
    grype "$IMAGE" -o json > "$SCAN_FILE"
    echo "Results saved to $SCAN_FILE"
done

# Summarize vulnerabilities by severity
echo "Summarizing vulnerabilities by severity..."
for SCAN_FILE in "$OUTPUT_DIR"/*.txt; do
    IMAGE=$(basename "$SCAN_FILE" .txt | tr '_' '/: ')
    echo "Image: $IMAGE"
    jq -r '.matches[] | "\(.vulnerability.severity): \(.vulnerability.id) - \(.artifact.name)"' "$SCAN_FILE" | sort | uniq
    echo "-----------------------------------------"
done

echo "Vulnerability scan completed. Results saved in $OUTPUT_DIR."

# Define the existing output directory
OUTPUT_DIR="./grype_scans"

# Check if the output directory exists; exit if not
if [ ! -d "$OUTPUT_DIR" ]; then
    echo "Error: The directory '$OUTPUT_DIR' does not exist. Ensure the scans directory is available."
    exit 1
fi

# Define the CSV file path with a date prefix
DATE=$(date +%Y-%m-%d)
CSV_FILE="${OUTPUT_DIR}/${DATE}_vulnerability_scan.csv"

# Initialize CSV file if it doesn't already exist
if [ ! -f "$CSV_FILE" ]; then
    echo "image:tag,component/library,vulnerability,severity" > "$CSV_FILE"
fi
    # Populate the CSV with data from existing scan files
    for SCAN_FILE in "$OUTPUT_DIR"/*.txt; do
        # Extract the image name from the file name
        IMAGE=$(basename "$SCAN_FILE" .txt | tr '_' '/: ')

        # Parse the scan results and append to the CSV
        jq -r --arg IMAGE "$IMAGE" '
            .matches[] |
            select(.vulnerability.severity | test("Medium|High|Critical")) | 
            [$IMAGE, .artifact.name, .vulnerability.id, .vulnerability.severity] |
            @csv
        ' "$SCAN_FILE" >> input.txt
    done

if [ ! -f "$CSV_FILE" ]; then
    echo "image:tag,component/library,vulnerability,severity" > "$CSV_FILE"
fi

# Temporary file to collect ordered results
TEMP_FILE="${OUTPUT_DIR}/temp_results.txt"
> "$TEMP_FILE"  # Clear any existing content in the temp file

# Process input.txt for each severity level in the desired order
ORDER=("Critical" "High" "Medium")
for level in "${ORDER[@]}"; do
    grep "$level" input.txt >> "$TEMP_FILE"
done

# Append sorted results to the CSV file
sort -t',' -k4,4r "$TEMP_FILE" >> "$CSV_FILE"

# Clean up temporary file
rm -f "$TEMP_FILE"

echo "Vulnerability scan results appended to $CSV_FILE"

#clean temporary files 
echo "Cleaning up temporary files..."
rm -rf "$OUTPUT_DIR"/*.txt input.txt
