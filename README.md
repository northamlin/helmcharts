# Helm Charts

This repository contains the Helm charts used for deployment in our service hosting.

> **Note:** These charts are designed to run in a specific cluster configuration for this hosting environment and may not work in other clusters.

## Structure

- **Charts**: Charts are located in their own folders.
- **Docker**: Docker files used for building and hosting are located in the `dockers` folder.
- **Releases**: The `release` folder contains the chart releases.

## Charts

| Chart | Description |
|-------|-------------|
| ingress | Ingress configuration |
| kurrier | Kurrier email frontend |
| matomo | Matomo analytics |
| mautic | Mautic marketing automation |
| moodle | Moodle LMS |
| postal | Postal mail server |
| radicale | Radicale CalDAV/CardDAV server |
| wikijs | Wiki.js |
| wordpress | WordPress |

## Workflow

The `release` folder is built and populated automatically during deployment.

**Please do not manually place files in the `release` folder.**
