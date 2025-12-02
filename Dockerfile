# Dockerfile for Diabetes RF plumber API (ST 558)

FROM r-base:4.4.1

RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libfontconfig1-dev \
    libfreetype6-dev \
    libpng-dev \
    libtiff5-dev \
    libjpeg-dev \
    && rm -rf /var/lib/apt/lists/*

RUN R -e "install.packages(c('plumber', 'tidyverse', 'tidymodels', 'janitor', 'ggplot2'), repos = 'https://cloud.r-project.org')"

WORKDIR /app

COPY api_diabetes.R ./api_diabetes.R
COPY data ./data

EXPOSE 8000

CMD ["R", "-e", "pr <- plumber::plumb('api_diabetes.R'); pr$run(host='0.0.0.0', port=8000)"]
