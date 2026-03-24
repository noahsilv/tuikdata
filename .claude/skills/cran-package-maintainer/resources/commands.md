# Local pre-push checklist

- devtools::document()

- devtools::test()

- devtools::check()

# CRAN preflight

- R CMD build .

- R CMD check --as-cran tuikr_<version>.tar.gz
