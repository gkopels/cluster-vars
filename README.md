# Cluster Variables

This repository contains export variables for each cluster.

## Structure

Each cluster should have its own directory or file containing the necessary environment variables.

## Usage

To use variables for a specific cluster, source the appropriate file:

```bash
source clusters/<cluster-name>/vars.sh
```

Or if using individual files:

```bash
source clusters/<cluster-name>.sh
```

## Adding a New Cluster

1. Create a new file or directory for your cluster
2. Define the export variables
3. Document any special requirements in the cluster's file or README

