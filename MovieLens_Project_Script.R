################################################################
# The following code is provided by the edx course and platform:
################################################################

##########################################################
# Create edx and final_holdout_test sets 
##########################################################

# Note: this process could take a couple of minutes

if(!require(tidyverse)) install.packages("tidyverse", 
                                         repos = "http://cran.us.r-project.org")
if(!require(caret)) install.packages("caret", 
                                     repos = "http://cran.us.r-project.org")

library(tidyverse)
library(caret)

# MovieLens 10M dataset:
# https://grouplens.org/datasets/movielens/10m/
# http://files.grouplens.org/datasets/movielens/ml-10m.zip

options(timeout = 120)

dl <- "ml-10M100K.zip"
if(!file.exists(dl))
  download.file("https://files.grouplens.org/datasets/movielens/ml-10m.zip", dl)

ratings_file <- "ml-10M100K/ratings.dat"
if(!file.exists(ratings_file))
  unzip(dl, ratings_file)

movies_file <- "ml-10M100K/movies.dat"
if(!file.exists(movies_file))
  unzip(dl, movies_file)

ratings <- as.data.frame(str_split(read_lines(ratings_file), fixed("::"), 
                                   simplify = TRUE), stringsAsFactors = FALSE)
colnames(ratings) <- c("userId", "movieId", "rating", "timestamp")
ratings <- ratings %>%
  mutate(userId = as.integer(userId),
         movieId = as.integer(movieId),
         rating = as.numeric(rating),
         timestamp = as.integer(timestamp))

movies <- as.data.frame(str_split(read_lines(movies_file), fixed("::"), 
                                  simplify = TRUE), stringsAsFactors = FALSE)
colnames(movies) <- c("movieId", "title", "genres")
movies <- movies %>% mutate(movieId = as.integer(movieId))

movielens <- left_join(ratings, movies, by = "movieId")

# Final hold-out test set will be 10% of MovieLens data
set.seed(1, sample.kind="Rounding") # using R 3.6 or later
test_index <- createDataPartition(y = movielens$rating, times = 1, 
                                  p = 0.1, list = FALSE)
edx <- movielens[-test_index,]
temp <- movielens[test_index,]

# Make sure userId and movieId in final hold-out test set are also in edx set
final_holdout_test <- temp %>% 
  semi_join(edx, by = "movieId") %>%
  semi_join(edx, by = "userId")

# Add rows removed from final hold-out test set back into edx set
removed <- anti_join(temp, final_holdout_test)
edx <- rbind(edx, removed)

rm(dl, ratings, movies, test_index, temp, movielens, removed)

################################################################
# The following code is my actual project:
################################################################
# Further division of edx into training and testing sets
set.seed(1, sample.kind = "Rounding") # using R 3.6 or later
test_index <- createDataPartition(y = edx$rating, times = 1, 
                                  p = 0.1, list = FALSE)
train_set <- edx[-test_index,]
temp <- edx[test_index,]

# Matching userId and movieId in both train and test sets
test_set <- temp %>%
  semi_join(train_set, by = "movieId") %>%
  semi_join(train_set, by = "userId")

# Adding rows back into train set
removed <- anti_join(temp, test_set)
train_set <- rbind(train_set, removed)

rm(test_index, temp, removed)

### Starting data exploration

# Statistical summary of the dataset edx
summary(edx)

# Output number of users versus number of movies
summarize(edx, num_users = n_distinct(userId), num_movies = n_distinct(movieId))

# Graph top movies
edx %>%
  group_by(title) %>%
  summarize(count = n()) %>%
  top_n(10, count) %>%
  arrange(-count) %>%
  ggplot(aes(count, reorder(title, count))) +
  geom_bar(color = "gray", fill = "firebrick", stat = "identity") +
  labs(x = "Count", y = "Movies", caption = "Source: edx dataset") +
  ggtitle("Most Popular Movies")
  
# Graph number of ratings per rating
edx %>%
  ggplot(aes(rating)) +
  geom_bar(color = "gray", fill = "firebrick") +
  labs(x = "Ratings", y = "Frequency", caption = "Source: edx dataset") +
  scale_x_continuous(breaks = seq(0, 5, by = 0.5)) +
  ggtitle("Rating Count Per Rating")

# Graph number of ratings versus users
edx %>% 
  group_by(userId) %>%
  summarize(count = n()) %>%
  ggplot(aes(count)) +
  geom_histogram(color = "gray", fill = "firebrick", bins = 50) +
  labs(x = "Ratings", y = "Users", caption = "Source: edx dataset") +
  ggtitle("Number of Ratings Versus Users") +
  scale_x_log10()

# Graph number of ratings versus movies
edx %>% 
  group_by(movieId) %>%
  summarize(count = n()) %>%
  ggplot(aes(count)) +
  geom_histogram(color = "gray", fill = "firebrick", bins = 50) +
  labs(x = "Ratings", y = "Movies", caption = "Source: edx dataset") +
  ggtitle("Number of Ratings Versus Movies") +
  scale_x_log10()

### Starting data analysis

# Function to calculate RMSE
rmse <- function(true_ratings, predicted_ratings) {
  sqrt(mean((true_ratings - predicted_ratings)^2))
}

# Mean of all ratings
mean_rating <- mean(train_set$rating)
mean_rating

# RMSE calculated with just the mean
mean_rmse <- rmse(test_set$rating, mean_rating)
mean_rmse

# Add movie bias to calculation
bi <- train_set %>%
  group_by(movieId) %>%
  summarize(b_i = mean(rating - mean_rating))
predicted_ratings <- mean_rating + test_set %>%
  left_join(bi, by = "movieId") %>%
  pull(b_i)

# RMSE calculated with mean and movie bias
movie_bias_rmse <- rmse(predicted_ratings, test_set$rating)
movie_bias_rmse

# Add user bias to calculation
bu <- train_set %>%
  left_join(bi, by = "movieId") %>%
  group_by(userId) %>%
  summarize(b_u = mean(rating - mean_rating - b_i))
predicted_ratings <- test_set %>%
  left_join(bi, by = "movieId") %>%
  left_join(bu, by = "userId") %>%
  mutate(pred = mean_rating + b_i + b_u) %>%
  pull(pred)

# RMSE calculated with mean, movie, and user bias
user_bias_rmse <- rmse(predicted_ratings, test_set$rating)
user_bias_rmse

# Add time bias to calculation
bt <- train_set %>%
  mutate(date = round_date(as_datetime(timestamp), unit = "week")) %>%
  left_join(bi, by = "movieId") %>%
  left_join(bu, by = "userId") %>%
  group_by(date) %>%
  summarize(b_t = mean(rating - mean_rating - b_i - b_u))
predicted_ratings <- test_set %>%
  mutate(date = round_date(as_datetime(timestamp), unit = "week")) %>%
  left_join(bi, by = "movieId") %>%
  left_join(bu, by = "userId") %>%
  left_join(bt, by = "date") %>%
  mutate(pred = mean_rating + b_i + b_u + b_t) %>%
  pull(pred)

# RMSE calculated with mean, movie, user, and time bias
time_bias_rmse <- rmse(predicted_ratings, test_set$rating)
time_bias_rmse

# Applying data regularization
lambdas <- seq(0, 10, 0.25)
rmses <- sapply(lambdas, function(x){
  b_i <- train_set %>%
    group_by(movieId) %>%
    summarize(b_i = sum(rating - mean_rating)/(n() + x)) # adding movie bias
  b_u <- train_set %>%
    left_join(b_i, by = "movieId") %>%
    group_by(userId) %>%
    summarize(b_u = sum(rating - b_i - 
                          mean_rating)/(n() + x)) # adding user bias
  b_t <- train_set %>%
    mutate(date = round_date(as_datetime(timestamp), unit = "week")) %>%
    left_join(b_i, by = "movieId") %>%
    left_join(b_u, by = "userId") %>%
    group_by(date) %>%
    summarize(b_t = mean(rating - b_i - b_u - 
                           mean_rating)/(n() + x)) # adding time bias
  predicted_ratings <- test_set %>%
    mutate(date = round_date(as_datetime(timestamp), unit = "week")) %>%
    left_join(b_i, by = "movieId") %>%
    left_join(b_u, by = "userId") %>%
    left_join(b_t, by = "date") %>%
    mutate(pred = mean_rating + b_i + b_u + b_t) %>%
    pull(pred)
  return(rmse(predicted_ratings, test_set$rating))
})

# Plotting lambdas versus RMSEs
qplot(lambdas, rmses, color = I("red"))

# Finding which lambda has the lowest RMSE
lambda <- lambdas[which.min(rmses)]
lambda

# Selecting the lambda with the lowest RMSE
regularized_rmse <- min(rmses)
regularized_rmse

# Applying matrix factorization using the recosystem package
if(!require(recosystem)) install.packages(
  "recosystem", repos = "http://cran.us.r-project.org")
library(recosystem)
set.seed(1, sample.kind = "Rounding") # using R 3.6 or later
reco_train <- with(train_set, data_memory(user_index = userId, 
                                          item_index = movieId, 
                                          rating = rating))
reco_test <- with(test_set, data_memory(user_index = userId, 
                                        item_index = movieId, rating = rating))
reco <- Reco()

reco_para <- reco$tune(reco_train, opts = list(dim = c(20, 30), 
                                               costp_l2 = c(0.01, 0.1),
                                               costq_l2 = c(0.01, 0.1), 
                                               lrate = c(0.01, 0.1),
                                               nthread = 4, niter = 10))

reco$train(reco_train, opts = c(reco_para$min, nthread = 4, niter = 30))
reco_first <- reco$predict(reco_test, out_memory())

# RMSE calculated with matrix factorization
factorization_rmse <- RMSE(reco_first, test_set$rating)
factorization_rmse

# Using matrix factorization on final holdout test
set.seed(1, sample.kind = "Rounding") # using R 3.6 or later
reco_edx <- with(edx, data_memory(user_index = userId, item_index = movieId, 
                                  rating = rating))
reco_final_holdout <- with(final_holdout_test, data_memory(user_index = userId, 
                                                           item_index = movieId, 
                                                           rating = rating))
reco <- Reco()

reco_para <- reco$tune(reco_edx, opts = list(dim = c(20, 30), 
                                             costp_l2 = c(0.01, 0.1),
                                             costq_l2 = c(0.01, 0.1), 
                                             lrate = c(0.01, 0.1),
                                             nthread = 4, niter = 10))

reco$train(reco_edx, opts = c(reco_para$min, nthread = 4, niter = 30))
reco_final <- reco$predict(reco_final_holdout, out_memory())

# Generating final RMSE
final_rmse <- RMSE(reco_final, final_holdout_test$rating)
final_rmse

### Final results

# Table made using the reactable package
if(!require(reactable)) install.packages("reactable", 
                                         repos = "http://cran.us.r-project.org")
library(reactable)
if(!require(webshot2)) install.packages("webshot2", 
                                         repos = "http://cran.us.r-project.org")
library(webshot2)
if(!require(htmlwidgets)) install.packages("htmlwidgets", 
                                        repos = "http://cran.us.r-project.org")
library(htmlwidgets)
Methods <- c("Just the mean", "Mean and movie bias", 
             "Mean, movie, and user bias", "Mean, movie, user, and time bias", 
             "Regularized movie, user, and time effects",
             "Matrix factorization using recosystem", 
             "Final holdout test 
             (generated using matrix factorization)") # first column
RMSE <- c(round(mean_rmse, 7), round(movie_bias_rmse, 7), 
          round(user_bias_rmse, 7), round(time_bias_rmse, 7), 
          round(regularized_rmse, 7), round(factorization_rmse, 7), 
          round(final_rmse, 7)) # second column
final_results <- data.frame(Methods, RMSE)
table <- reactable(final_results,
  highlight = TRUE,
  bordered = TRUE,
  theme = reactableTheme(
    borderColor = "#dfe2e5",
    highlightColor = "#f0f5f9",
    cellPadding = "8px 12px",
    style = list(fontFamily = "-apple-system, BlinkMacSystemFont, 
                 Segoe UI, Helvetica, Arial, sans-serif"),
    )
  )
saveWidget(widget = table, file = "table_html.html", selfcontained = TRUE)
webshot(url = "table_html.html", file = "final_table.png", delay = 0.1, 
        vwidth = 1245)