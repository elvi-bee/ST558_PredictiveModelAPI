# Dockerfile for Diabetes RF plumber API (ST 558)

FROM rstudio/plumber

RUN R -e "install.packages(c('dplyr','readr','tidyr','tibble','tidymodels','janitor','ggplot2','plumber', 'ranger'), repos = 'https://cloud.r-project.org')"

WORKDIR /app

COPY api_diabetes.R api_diabetes.R
COPY data data

EXPOSE 8000

ENTRYPOINT ["R", "-e", "pr <- plumber::plumb('api_diabetes.R'); pr$run(host='0.0.0.0', port=8000)"]