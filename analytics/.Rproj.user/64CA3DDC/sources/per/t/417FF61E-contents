# =============================================================================
#  R Package Installer
#  Cold-Chain Logistics Tracker — Unit 2 (Analytics)
# =============================================================================
#  Run this script once to install all required R packages.
#  Used by the Dockerfile during image build.
# =============================================================================

cat("Installing required R packages...\n")

# Set CRAN mirror
options(repos = c(CRAN = "https://cloud.r-project.org"))

# List of required packages
packages <- c(
  "dplyr",       # Data manipulation
  "lubridate",   # Date/time handling
  "DBI",         # Database interface
  "RSQLite",     # SQLite driver
  "tidyr",       # Data tidying
  "geosphere",   # GPS Distance calculations (Haversine)
  "shiny",       # Web Dashboard Framework
  "leaflet",     # Interactive Maps
  "plotly",      # Interactive Charts
  "shinythemes"  # CSS Themes for Shiny
)

# Install each package if not already present
for (pkg in packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    cat(sprintf("  Installing: %s...\n", pkg))
    install.packages(pkg, quiet = TRUE)
  } else {
    cat(sprintf("  Already installed: %s\n", pkg))
  }
}

cat("\nAll packages installed successfully.\n")
