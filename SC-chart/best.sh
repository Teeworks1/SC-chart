#!/bin/bash

# Prints kubectl commands to trim Helm history in excess of the parameter below
# Assumes the default Helm history storage (Secrets)

HISTORY_ENTRIES_TO_RETAIN=2

# Get all namespaces
namespaces=$(kubectl get ns -o name | sed 's/namespace\///g')

secrets_to_drop=()

# Iterate over each namespace
for namespace in $namespaces; do
    # Get all secrets in the namespace
    secrets=$(kubectl get secret --namespace "$namespace" -o name)

    # Iterate over each secret and filter Helm release secrets
    helm_secrets=()
    while IFS= read -r name; do
        if [[ $name =~ ^secret\/(sh\.helm\.release\.v1\..+)\.v([0-9]+)$ ]]; then
            base_name="${BASH_REMATCH[1]}"
            version="${BASH_REMATCH[2]}"
            helm_secrets+=("$namespace|$base_name|$name|$version")
        fi
    done <<< "$secrets"

    # Group secrets by namespace/base_name and sort by version
    if [[ ${#helm_secrets[@]} -gt 0 ]]; then
        IFS=$'\n'
        sorted_secrets=($(printf "%s\n" "${helm_secrets[@]}" | sort -t '|' -k4 -nr))
        unset IFS

        # Remove excess secrets, keeping only the most recent ones
        for i in "${!sorted_secrets[@]}"; do
            if (( i >= HISTORY_ENTRIES_TO_RETAIN )); then
                secrets_to_drop+=("${sorted_secrets[i]}")
            fi
        done
    fi
done

# Print kubectl delete commands for the secrets to drop
for secret_info in "${secrets_to_drop[@]}"; do
    IFS='|' read -r namespace base_name name version <<< "$secret_info"
    echo "kubectl delete secret --namespace $namespace ${name#secret/}"
done