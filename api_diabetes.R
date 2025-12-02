# api_diabetes.R
# Plumber API for Diabetes RF model

# Libraries
library(dplyr)
library(readr)
library(tidyr)
library(tibble)
library(tidymodels)
library(janitor)
library(ggplot2)

set.seed(11)

# Read in data and clean column names
data <- read.csv("data/diabetes_binary_health_indicators_BRFSS2015.csv",
                 header = TRUE) |>
  clean_names()

# Factor
data <- data |>
  mutate(diabetes_binary = factor(diabetes_binary))

# Predictors
predictor_vars <- c("high_bp", "high_chol", "diff_walk", "bmi", "age")

diab_full <- data |>
  select(diabetes_binary, all_of(predictor_vars))

# Recipe - on FULL data
diab_rec <- recipe(
  diabetes_binary ~ high_bp + high_chol + diff_walk + bmi + age,
  data = diab_full
) |>
  step_dummy(all_nominal_predictors()) |>
  step_normalize(all_numeric_predictors())

# Specify Model
rf_spec <- rand_forest(
  mtry  = 2,
  trees = 100,
  min_n = 5
) |>
  set_engine("ranger", importance = "impurity") |>
  set_mode("classification")

# Workflow
rf_wf <- workflow() |>
  add_recipe(diab_rec) |>
  add_model(rf_spec)

# Fit RF on the full data set
rf_full_fit <- rf_wf |>
  fit(data = diab_full)

# Defaults: mean of each predictor
default_vals <- diab_full |>
  summarise(
    across(all_of(predictor_vars), ~ mean(.x, na.rm = TRUE))
  ) |>
  as.list()

# Confusion matrix for full data
full_preds <- predict(rf_full_fit, diab_full, type = "class") |>
  bind_cols(
    predict(rf_full_fit, diab_full, type = "prob"),
    diab_full |> select(diabetes_binary)
  ) |>
  rename(truth = diabetes_binary,
         .pred_class = .pred_class)

rf_conf_full <- conf_mat(full_preds,
                         truth   = truth,
                         estimate = .pred_class)

#####################################################
# API endpoints

#* Predict probability of diabetes (RF model)
#*
#* @param high_bp High blood pressure (0 = no, 1 = yes)
#* @param high_chol High cholesterol (0 = no, 1 = yes)
#* @param diff_walk Serious difficulty walking or climbing stairs (0/1)
#* @param bmi Body Mass Index
#* @param age Age category (BRFSS coding, e.g. 1–13)
#* @get /pred
function(
    high_bp    = default_vals$high_bp,
    high_chol  = default_vals$high_chol,
    diff_walk  = default_vals$diff_walk,
    bmi        = default_vals$bmi,
    age        = default_vals$age
) {
  
  new_dat <- tibble(
    high_bp   = as.numeric(high_bp),
    high_chol = as.numeric(high_chol),
    diff_walk = as.numeric(diff_walk),
    bmi       = as.numeric(bmi),
    age       = as.numeric(age)
  )
  
  prob_tbl <- predict(rf_full_fit, new_dat, type = "prob")
  class_tbl <- predict(rf_full_fit, new_dat, type = "class")
  
  # Factor levels are "0" and "1"; "1" = diabetes
  prob_diab <- prob_tbl$.pred_1[1]
  cls       <- as.character(class_tbl$.pred_class[1])
  
  list(
    input = new_dat,
    predicted_class = cls,
    predicted_prob_diabetes = prob_diab
  )
}

# 3 example function calls for testing
# http://localhost:8000/pred
# http://localhost:8000/pred?high_bp=1&high_chol=1&diff_walk=1&bmi=35&age=9
# http://localhost:8000/pred?high_bp=0&high_chol=0&diff_walk=0&bmi=24&age=5


#* Info about API Project
#* @get /info
function() {
  list(
    name = "Elvira McIntyre",
    github_pages_url = "https://elvi-bee.github.io/ST558_PredictiveModelAPI/EDA.html",
    description = "A Random forest model API for predicting diabetes using BRFSS 2015 health indicators."
  )
}


#* Confusion matrix plot for RF model on full data
#* @serializer png
#* @get /confusion
function() {
  
  # COnvert confusion matrix into tidy table
  cm_tbl <- as.data.frame(as.table(rf_conf_full$table))
  names(cm_tbl) <- c("Truth", "Prediction", "Freq")
  
  p <- ggplot(cm_tbl, aes(x = Prediction, y = Truth, fill = Freq)) +
    geom_tile() +
    geom_text(aes(label = Freq), size = 6) +
    scale_fill_continuous(name = "Count") +
    labs(
      title = "Confusion Matrix: RF Model (Full Data)",
      x = "Predicted",
      y = "Actual"
    ) +
    theme_minimal()
  
  print(p)
}
