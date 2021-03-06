#
# (C) Copyright IBM Corp. 2017
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

#load the r4ml 
library(R4ML)
r4ml.session()

# these are the different dataset we will analysis
# path <- "/user/data-scientist/airline/1987.csv"
# path <- "/user/data-scientist/airline/*.csv"


# we would like to limit the dataset to a size so that we can run test faster
# df_max_size <- 1000
df_max_size <- 100000

# set the predictors and response variables
predictors <- c("Month", "DayofMonth", "DayOfWeek", "Year")
response <- c("Cancelled")

X_names<- predictors
Y_names <- response

D_names <- append(X_names, Y_names)


## use the following for the custom dataset
# path <- "/user/data-scientist/airline/1987.csv"
# df <- R4ML:::r4ml.read.csv(path, inferSchema=TRUE, header=TRUE)

# this example use the airline dataset shipped with R4ML
df <- as.r4ml.frame(airline)

# limit the number of rows so that we can control the size
df <- limit(df, df_max_size)
ignore <- cache(df) # very important step otherwise the partition gets screw up

# convert to the r4ml frame
df <- SparkR::select(df, D_names)
ignore <- cache(df)
hf = as.r4ml.frame(df)
# do the preprocess of the data set
phf_info <- r4ml.ml.preprocess(
  hf
  ,transformPath = "/tmp"
  ,recodeAttrs=D_names
  ,dummycodeAttrs = c("Month")
  ,binningAttrs = c(), numBins=4
  #,missingAttrs = D_names
  ,omit.na = D_names
)

# actual data set
phf <- phf_info$data
# the corresponding metadata
pmdb <- phf_info$metadata

# sample the dataset into the train and test
hm <- as.r4ml.matrix(phf)
ignore <- cache(hm)
rsplit <- r4ml.sample(hm, c(0.7, 0.3))

train_hm <- rsplit[[1]]
test_hm <- rsplit[[2]]
ignore <- cache(train_hm)

# create the support vector machine model
# since one hot encoding will generate many columns we have account for it as
# follows note if there is no dummy coding we can just do 
# ml.coltypes(train_hm) <- c("scale", "scale", "scale", "scale", "nominal")
ml.coltypes(train_hm) <- c(rep("scale", length(names(train_hm))-1), "nominal")
svm_m <- r4ml.svm(Cancelled ~ . , data = train_hm, is.binary.class = TRUE)

# the following is for the non binary response
#svm_m <- r4ml.svm(Cancelled ~ . , data = train_hm)

# run the prediction
ignore <- cache(test_hm)
preds <- predict(svm_m, test_hm)
# To print all outputs, just call preds
head(preds$scores)

# exit R/R4ML
r4ml.session.stop()
quit("no")
